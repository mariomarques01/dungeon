extends SceneTree
const Rules = preload('res://scripts/mutable_rules.gd')
var listener = TCPServer.new()
var clients: Dictionary = {}
var rooms: Dictionary = {}
var next_id = 0
var broadcast_clock = 0.0
var port = 9080
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--port='):port = int(arg.split('=')[1])
 var error = listener.listen(port,'0.0.0.0')
 if error != OK:push_error('Cannot listen: '+str(error));quit(1);return
 print('DUNGEON_ROOMS_READY port=',port)
func send_to(id: int, data: Dictionary) -> void:
 if clients.has(id) and clients[id].socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  clients[id].socket.send_text(JSON.stringify(data))
func _process(delta: float) -> bool:
 while listener.is_connection_available():
  var stream = listener.take_connection()
  if clients.size() >= 128:stream.disconnect_from_host();continue
  var socket = WebSocketPeer.new()
  socket.inbound_buffer_size = 8192;socket.max_queued_packets = 32
  socket.accept_stream(stream)
  next_id += 1
  clients[next_id] = {'socket':socket,'room':'','side':-1,'age':0.0,'budget':25.0,'idle':0.0}
 for id in clients.keys():
  var client: Dictionary = clients[id]
  client.age += delta;client.idle += delta;client.budget = minf(25,client.budget+delta*12)
  var socket: WebSocketPeer = client.socket
  socket.poll()
  if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or (socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING and client.age > 10) or client.idle > 45:
   drop_client(id);continue
  while socket.get_available_packet_count() > 0:
   var bytes = socket.get_packet()
   if bytes.size() > 2048 or client.budget < 1:socket.close(1008,'Rate limit');break
   client.budget -= 1
   var message = JSON.parse_string(bytes.get_string_from_utf8())
   if message is Dictionary:
    client.idle = 0.0
    command(id,message)
 for room in rooms.values():
  room.age += delta
  if room.players.size() == 2:room.rules.step(delta)
 broadcast_clock += delta
 if broadcast_clock >= 0.1:
  broadcast_clock = 0.0
  for room in rooms.values():
   if room.players.size() == 2:
    for id in room.players:send_to(id,{'type':'state','state':room.rules.state})
 for code in rooms.keys():
  if rooms[code].age > 900:
   for id in rooms[code].players:
    send_to(id,{'type':'ended','reason':'Sala expirada'})
    if clients.has(id):clients[id].room = ''
   rooms.erase(code)
 return false
func command(id: int, msg: Dictionary) -> void:
 var client: Dictionary = clients[id]
 var kind = str(msg.get('type',''))
 if kind == 'ping':send_to(id,{'type':'pong'});return
 if kind == 'leave':leave_room(id);return
 if kind == 'create' or kind == 'join':
  if not client.room.is_empty():send_to(id,{'type':'error','message':'Você já está em uma sala'});return
  var code = str(msg.get('code','')).to_upper()
  if kind == 'create':
   if rooms.size() >= 64:send_to(id,{'type':'error','message':'Servidor cheio'});return
   code = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
   while rooms.has(code):code = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
   rooms[code] = {'rules':Rules.new(),'players':[],'age':0.0}
  if not rooms.has(code) or rooms[code].players.size() >= 2:
   send_to(id,{'type':'error','message':'Sala inexistente ou cheia'});return
  var room: Dictionary = rooms[code]
  client.side = room.players.size();client.room = code;room.players.append(id)
  send_to(id,{'type':'joined','code':code,'side':client.side})
  if room.players.size() == 2:
   for peer in room.players:send_to(peer,{'type':'start','state':room.rules.state})
  return
 if client.room.is_empty() or not rooms.has(client.room):return
 var room: Dictionary = rooms[client.room]
 if room.players.size() != 2:return
 var result = ''
 if kind in ['play','ability']:
  if not (msg.get('x') is float or msg.get('x') is int) or not (msg.get('y') is float or msg.get('y') is int):return
  if kind == 'play':
   if not (msg.get('index') is float or msg.get('index') is int):return
   result = room.rules.play(client.side,int(msg.index),float(msg.x),float(msg.y))
  else:result = room.rules.ability(client.side,float(msg.x),float(msg.y))
  if not result.is_empty():send_to(id,{'type':'error','message':result})
func leave_room(id: int) -> void:
 var code: String = clients[id].room
 if rooms.has(code):
  var room: Dictionary = rooms[code]
  for other in room.players:
   if other != id:
    if room.players.size() == 2 and room.rules.state.winner == -2:room.rules.state.winner = clients[other].side
    send_to(other,{'type':'ended','reason':'O adversário desconectou','state':room.rules.state})
   if clients.has(other):clients[other].room = ''
  rooms.erase(code)
 clients[id].room = ''
func drop_client(id: int) -> void:
 leave_room(id)
 clients.erase(id)
