extends Control
const Rules = preload('res://scripts/mutable_rules.gd')
const REFERENCE = preload('res://mutable_assets/reference.jpg')
const BACKGROUND = preload('res://mutable_assets/arena.png')
const FONT = preload('res://assets/title.ttf')
const BODY = preload('res://tavern_assets/reading.ttf')
var sprites: Texture2D
var rules = Rules.new()
var selected = -1
var ability_selected = false
var mode = 'home'
var side = 0
var elapsed = 0.0
var factor = 1.0
var origin = Vector2.ZERO
var ui: Control
var socket: WebSocketPeer
var pending = ''
var room_code = ''
var connection_age = 0.0
var last_packet = 0.0
var heartbeat = 0.0
var server_url = ''
var status = ''
var toast = ''
var toast_life = 0.0
var drag_start = Vector2.ZERO
var dragging = false
var rewarded = false
var profile = {'wins':0,'losses':0,'xp':0,'coins':0,'mastery':0}
var qa = false
var qa_callback
var touch_callback
var toast_label: Label
var server_input: LineEdit
var code_input: LineEdit
func _ready() -> void:
 if OS.has_feature('web') and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode') === 'classic' && !window.dungeonClassicOpened")):
  JavaScriptBridge.eval('window.dungeonClassicOpened=true;');set_process(false);call_deferred('open_classic');return
 sprites = load('res://mutable_assets/units.png') if ResourceLoader.exists('res://mutable_assets/units.png') else null
 ui = Control.new();add_child(ui)
 load_profile()
 if OS.has_feature('web'):
  qa = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''")) == '1'
  var supplied = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''"))
  if not supplied.is_empty():server_url = supplied
  install_touch()
 toast_label = Label.new();toast_label.position = Vector2(30,1095);toast_label.size = Vector2(660,90);toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;toast_label.add_theme_font_size_override('font_size',23);toast_label.add_theme_color_override('font_shadow_color',Color.BLACK);toast_label.add_theme_constant_override('shadow_outline_size',8);toast_label.z_index = 200;toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(toast_label)
 show_home()
func install_touch() -> void:
 touch_callback = JavaScriptBridge.create_callback(web_touch)
 JavaScriptBridge.get_interface('window').mutableTouch = touch_callback
 JavaScriptBridge.eval("""
 (()=>{const c=document.getElementById('canvas');let finger=null;
 c.style.touchAction='none';
 for(const type of ['touchstart','touchmove','touchend','touchcancel'])window.addEventListener(type,e=>{
 if(e.target!==c||window.dungeonClassicActive)return;
 e.preventDefault();e.stopImmediatePropagation();
 if(type==='touchstart'&&finger===null)finger=e.changedTouches[0].identifier;
 const t=Array.from(e.changedTouches).find(t=>t.identifier===finger);if(!t)return;
 const r=c.getBoundingClientRect();window.mutableTouch(type,(t.clientX-r.left)/r.width,(t.clientY-r.top)/r.height);
 if(type==='touchend'||type==='touchcancel')finger=null;
 },{capture:true,passive:false});})();
 """)
func web_touch(args: Array) -> void:
 if args.size()<3:return
 var pixel = Vector2(float(args[1]),float(args[2]))*size
 if ui.get_child_count() > 0:
  if str(args[0]) in ['touchstart','touchend','touchcancel']:
   var mouse = InputEventMouseButton.new();mouse.position = pixel;mouse.global_position = pixel;mouse.button_index = MOUSE_BUTTON_LEFT;mouse.pressed = str(args[0]) == 'touchstart';Input.parse_input_event(mouse)
  return
 var p = (pixel-origin)/factor
 if str(args[0]) == 'touchstart':pointer_down(p)
 elif str(args[0]) == 'touchend':pointer_up(p)
 elif str(args[0]) == 'touchcancel':dragging = false
func load_profile() -> void:
 var raw = FileAccess.get_file_as_string('user://mutable-profile.json') if FileAccess.file_exists('user://mutable-profile.json') else ''
 if OS.has_feature('web'):raw = str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('dungeon_mutable_v1') || ''}catch(e){return ''}})()"))
 var saved = JSON.parse_string(raw) if not raw.is_empty() else null
 if saved is Dictionary:
  for key in profile:profile[key] = maxi(0,int(saved.get(key,0)))
 var config = ConfigFile.new()
 if config.load('user://mutable.cfg') == OK:server_url = str(config.get_value('network','url',''))
func save_profile() -> void:
 var file = FileAccess.open('user://mutable-profile.json',FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(profile))
 if OS.has_feature('web'):
  JavaScriptBridge.eval("try{localStorage.setItem('dungeon_mutable_v1',"+JSON.stringify(JSON.stringify(profile))+")}catch(e){}")
func _process(dt: float) -> void:
 elapsed += dt;toast_life -= dt
 factor = minf(size.x/720.0,size.y/1280.0)
 origin = (size-Vector2(720,1280)*factor)/2
 ui.position = origin;ui.scale = Vector2.ONE*factor
 toast_label.position = origin+Vector2(30,1095)*factor;toast_label.scale = Vector2.ONE*factor;toast_label.text = toast if toast_life > 0 and ui.get_child_count() > 0 else ''
 if mode == 'practice':rules.step(dt,true)
 if socket != null:poll_network(dt)
 if mode in ['practice','online'] and rules.state.winner != -2 and not rewarded:
  rewarded = true
  if rules.state.winner == side:profile.wins += 1;profile.xp += 100;profile.coins += 25
  elif rules.state.winner >= 0:profile.losses += 1;profile.xp += 25
  else:profile.xp += 40
  profile.mastery += int(rules.state.casts[side]);save_profile();show_result()
 if qa and OS.has_feature('web'):
  var menu_buttons: Array = []
  var menu_inputs: Array = []
  for child in ui.get_children():
   for item in child.get_children():
    if item is Button:
     var r = item.get_global_rect();menu_buttons.append({'text':item.text,'rect':[r.position.x,r.position.y,r.size.x,r.size.y]})
    elif item is LineEdit:
     var r = item.get_global_rect();menu_inputs.append({'placeholder':item.placeholder_text,'rect':[r.position.x,r.position.y,r.size.x,r.size.y]})
  var snapshot = {'inputs':menu_inputs,'buttons':menu_buttons,'mode':mode,'side':side,'state':rules.state,'selected':selected,'room':room_code,'status':status,'profile':profile,'viewport':[size.x,size.y],'board':[origin.x,origin.y,factor]}
  JavaScriptBridge.eval('window.dungeonArena='+JSON.stringify(snapshot)+';')
 queue_redraw()
func clear_ui() -> void:
 for child in ui.get_children():ui.remove_child(child);child.queue_free()
 if OS.has_feature('web'):JavaScriptBridge.eval('window.dungeonMutableMenu=false;')
func panel(title: String, subtitle: String) -> VBoxContainer:
 clear_ui()
 if OS.has_feature('web'):JavaScriptBridge.eval('window.dungeonMutableMenu=true;')
 var backdrop = ColorRect.new();backdrop.color = Color(0.02,0.025,0.055,0.88);backdrop.size = Vector2(720,1280);ui.add_child(backdrop)
 var box = VBoxContainer.new();box.position = Vector2(65,310);box.size = Vector2(590,650);box.add_theme_constant_override('separation',18);ui.add_child(box)
 var heading = Label.new();heading.text = title;heading.add_theme_font_override('font',FONT);heading.add_theme_font_size_override('font_size',36);heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(heading)
 var desc = Label.new();desc.text = subtitle;desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;desc.add_theme_font_override('font',BODY);desc.add_theme_font_size_override('font_size',23);desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(desc)
 return box
func button(box: VBoxContainer, label: String, action: Callable) -> void:
 var b = Button.new();b.text = label;b.custom_minimum_size = Vector2(590,64);b.add_theme_font_override('font',BODY);b.add_theme_font_size_override('font_size',25);b.pressed.connect(action);box.add_child(b)
func show_home() -> void:
 mode = 'home'
 var box = panel('DUNGEON','A masmorra muda. Sua estratégia também.\nDuelos de invocadores · 4 minutos')
 button(box,'JOGAR · TREINO CONTRA IA',start_practice)
 button(box,'DUELO PvP · SALAS',show_rooms)
 button(box,'COLEÇÃO E MAESTRIA',show_collection)
 button(box,'MODO CLÁSSICO · TAVERNA',open_classic)
 var label = Label.new();label.text = 'Toque na carta e depois na arena para invocar.\nDestrua o núcleo rival antes do tempo acabar.';label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override('font_size',20);box.add_child(label)
func start_practice() -> void:
 disconnect_server();rules.reset();side = 0;selected = -1;ability_selected = false;rewarded = false;mode = 'practice';status = '';clear_ui()
 rules.state.hands[1] = ['orc','skeleton','wall','portal'];rules.state.queues[1] = ['golem','goblin','mage','fire','heal','wisp']
func show_collection() -> void:
 var league = ['Bronze','Prata','Ouro','Arcano'][mini(3,int(profile.wins/10))]
 var box = panel('COLEÇÃO · '+league.to_upper(),'10 cartas disponíveis · níveis iguais em todos os duelos\n%d vitórias · %d XP · %d moedas\nMaestria: %d invocações' % [profile.wins,profile.xp,profile.coins,profile.mastery])
 var label = Label.new();label.text = 'GOLEM · 4     GOBLIN · 2\nMURALHA · 3     PORTAL · 2\nOSSADA · 2     ARCANISTA · 3\nSAQUEADOR · 4     METEORO · 4\nRENOVAR · 3     FAÍSCA · 1\n\nO baralho usa as 10 cartas. Cada jogada\ntraz a próxima carta da sua fila.\nPonte veloz, runa e armadilhas mudam a rota\na cada 30 segundos.';label.add_theme_font_size_override('font_size',24);label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;box.add_child(label)
 button(box,'VOLTAR',show_home)
func open_classic() -> void:
 disconnect_server();get_tree().change_scene_to_file('res://scenes/tavern.tscn')
func show_rooms() -> void:
 mode = 'rooms'
 var box = panel('DUELO ENTRE JOGADORES','Crie uma sala e compartilhe o código.\nÉ necessário um servidor de salas acessível.\nNa versão HTTPS, use um endereço wss://.')
 server_input = LineEdit.new();server_input.placeholder_text = 'wss://seu-servidor-de-salas';server_input.text = server_url;server_input.custom_minimum_size.y = 58;server_input.add_theme_font_size_override('font_size',22);box.add_child(server_input)
 code_input = LineEdit.new();code_input.placeholder_text = 'Código da sala';code_input.max_length = 6;code_input.custom_minimum_size.y = 58;code_input.add_theme_font_size_override('font_size',25);box.add_child(code_input)
 button(box,'CRIAR SALA',func():connect_room('create'))
 button(box,'ENTRAR NA SALA',func():room_code = code_input.text.strip_edges().to_upper();connect_room('join'))
 button(box,'VOLTAR',func():disconnect_server();show_home())
func connect_room(action: String) -> void:
 var url = server_input.text.strip_edges()
 if not (url.begins_with('ws://') or url.begins_with('wss://')):notify('Informe o endereço ws:// ou wss:// do servidor');return
 if action == 'join' and room_code.length() != 6:notify('O código da sala tem 6 caracteres');return
 disconnect_server();server_url = url
 var config = ConfigFile.new();config.set_value('network','url',server_url);config.save('user://mutable.cfg')
 socket = WebSocketPeer.new()
 var error = socket.connect_to_url(server_url)
 if error != OK:socket = null;notify('Não foi possível conectar ao servidor');return
 pending = action;connection_age = 0;last_packet = 0;heartbeat = 0;status = 'Conectando…';notify(status)
func send(data: Dictionary) -> void:
 if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:socket.send_text(JSON.stringify(data))
func disconnect_server() -> void:
 if socket != null:
  socket.close();socket = null
 pending = ''
func poll_network(dt: float) -> void:
 connection_age += dt;last_packet += dt;heartbeat += dt
 socket.poll()
 var ready = socket.get_ready_state()
 if ready == WebSocketPeer.STATE_CLOSED or (ready == WebSocketPeer.STATE_CONNECTING and connection_age > 12) or last_packet > 20:
  disconnect_server();status = 'Conexão perdida. Retorne às salas para reconectar.'
  if mode in ['online','waiting']:
   mode = 'disconnected';var box = panel('CONEXÃO ENCERRADA',status);button(box,'SALAS',show_rooms);button(box,'VOLTAR',show_home)
  else:notify(status)
  return
 if ready != WebSocketPeer.STATE_OPEN:return
 if not pending.is_empty():send({'type':pending,'code':room_code});pending = ''
 if heartbeat > 5:send({'type':'ping'});heartbeat = 0
 while socket != null and socket.get_available_packet_count() > 0:
  var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
  if not data is Dictionary:continue
  last_packet = 0
  match str(data.get('type','')):
   'joined':
    side = int(data.side);room_code = str(data.code);mode = 'waiting'
    var box = panel('SALA '+room_code,'Compartilhe o código acima.\nAguardando o segundo invocador…')
    button(box,'COPIAR CÓDIGO',func():DisplayServer.clipboard_set(room_code);notify('Código: '+room_code))
    button(box,'CANCELAR',func():disconnect_server();show_rooms())
   'start':rules.state = data.state;rewarded = false;mode = 'online';selected = -1;ability_selected = false;status = '';clear_ui()
   'state':
    if mode == 'online' and not rewarded:rules.state = data.state
   'error':notify(str(data.message))
   'ended':
    status = str(data.reason)
    if data.has('state') and mode == 'online':rules.state = data.state;notify(status)
    elif mode == 'waiting':disconnect_server();show_rooms();notify(status)
func show_result() -> void:
 var result = 'EMPATE' if rules.state.winner == -1 else ('VITÓRIA' if rules.state.winner == side else 'DERROTA')
 var box = panel(result,status+'\nNúcleos: %d × %d\n%d XP · %d moedas · %d vitórias' % [rules.state.cores[side],rules.state.cores[1-side],profile.xp,profile.coins,profile.wins])
 button(box,'JOGAR NOVAMENTE',start_practice);button(box,'SALAS PvP',func():disconnect_server();show_rooms());button(box,'VOLTAR',func():disconnect_server();show_home())
func notify(message: String) -> void:
 toast = message;toast_life = 4
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  var p = (event.position-origin)/factor
  if event.pressed:pointer_down(p)
  else:pointer_up(p)
 elif event is InputEventScreenTouch:
  var p = (event.position-origin)/factor
  if event.pressed:pointer_down(p)
  else:pointer_up(p)
func pointer_down(p: Vector2) -> void:
 if mode not in ['practice','online'] or rewarded:return
 drag_start = p;dragging = false
 if Rect2(640,10,80,80).has_point(p):
  var box = panel('PAUSA' if mode == 'practice' else 'MENU · DUELO EM ANDAMENTO','O duelo online continua enquanto o menu está aberto.')
  if mode == 'practice':mode = 'paused'
  button(box,'CONTINUAR',func():if mode == 'paused':mode = 'practice'
  );box.get_child(box.get_child_count()-1).pressed.connect(clear_ui)
  button(box,'SAIR PARA O MENU',func():disconnect_server();show_home());return
 if p.y > 995 and p.y < 1197:
  for i in range(4):
   if card_rect(i).has_point(p):selected = i;ability_selected = false;dragging = true;return
 if p.distance_to(Vector2(650,940)) < 64:ability_selected = true;selected = -1;notify('Toque em um alvo na arena');return
 if p.y >= 260 and p.y <= 735:cast(p)
func pointer_up(p: Vector2) -> void:
 if dragging and p.y >= 260 and p.y <= 735 and p.distance_to(drag_start) > 20:cast(p)
 dragging = false
func cast(p: Vector2) -> void:
 var x = 720-p.x if side == 1 else p.x
 var y = 985-p.y if side == 1 else p.y
 var error = ''
 if ability_selected:
  if mode == 'online':send({'type':'ability','x':x,'y':y})
  else:error = rules.ability(side,x,y)
 elif selected >= 0:
  if mode == 'online':send({'type':'play','index':selected,'x':x,'y':y})
  else:error = rules.play(side,selected,x,y)
 else:notify('Selecione uma carta primeiro');return
 if error.is_empty():selected = -1;ability_selected = false;toast_life = 0
 else:notify(error)
func card_rect(i: int) -> Rect2:
 return Rect2(40+i*148,1000,143,191)
func text_at(value: String, p: Vector2, font_size: int, color: Color = Color('#fff1ca'), centered: bool = false) -> void:
 var x = p.x-FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2 if centered else p.x
 draw_string_outline(FONT,Vector2(x,p.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color('#131625'))
 draw_string(FONT,Vector2(x,p.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func source(rect: Rect2, destination: Rect2) -> void:
 draw_texture_rect_region(REFERENCE,destination,rect)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color('#080d18'))
 draw_set_transform(origin,0,Vector2.ONE*factor)
 draw_texture_rect(BACKGROUND,Rect2(0,0,720,1280),false)
 # Reuse the approved UI artwork, with live values and independently selectable cards.
 source(Rect2(0,0,720,112),Rect2(0,0,720,112))
 source(Rect2(0,879,720,401),Rect2(0,879,720,401))
 draw_rect(Rect2(177,54,120,26),Color('#760f18'));text_at(str(int(rules.state.cores[1-side])),Vector2(243,78),28,Color.WHITE,true)
 draw_rect(Rect2(168,941,127,28),Color('#07526b'));text_at(str(int(rules.state.cores[side])),Vector2(242,968),28,Color.WHITE,true)
 draw_rect(Rect2(365,31,104,34),Color('#1b202b'))
 var seconds = int(ceil(rules.state.time))
 text_at('%02d:%02d' % [int(seconds/60),seconds%60],Vector2(417,62),34,Color('#fff0c4'),true)
 draw_rect(Rect2(314,103,90,13),Color('#151320'));draw_rect(Rect2(316,105,86*float(rules.state.cores[1-side])/2400.0,8),Color('#e33443'))
 draw_rect(Rect2(305,742,108,14),Color('#151320'));draw_rect(Rect2(308,745,102*float(rules.state.cores[side])/2400.0,8),Color('#35e7ef'))
 if selected >= 0 or ability_selected:
  draw_rect(Rect2(135,500,435,210),Color(0.05,0.9,1,0.10),true)
  draw_rect(Rect2(135,500,435,210),Color(0.2,0.9,1,0.5),false,2)
 var phase = int(rules.state.phase)
 var colors = [Color('#b958ed'),Color('#31f2ed'),Color('#ff9b3b')]
 if mode in ['practice','online','paused']:
  var next_change = 30-int(240-rules.state.time)%30
  text_at(['RUNA','PONTE VIVA','ARMADILHAS'][phase]+' · '+str(next_change)+'s',Vector2(417,93),12,colors[phase],true)
  if phase == 2:draw_rect(Rect2(405,490,165,150),Color(1,0.32,0.06,0.10+sin(elapsed*4)*0.04))
 draw_arc(Vector2(360,532),50+sin(elapsed*3)*3,0,TAU,64,Color(colors[phase],0.6),2,true)
 var units: Array = rules.state.units.duplicate();units.sort_custom(func(a,b):return a.y < b.y if side == 0 else a.y > b.y)
 for u in units:draw_unit(u)
 for fx in rules.state.effects:
  var p = Vector2(fx.x,fx.y)
  if side == 1:p = Vector2(720-p.x,985-p.y)
  var c = Color('#61f8b3') if fx.kind == 'heal' else Color('#ffaf3a')
  draw_circle(p,12+(0.6-float(fx.life))*70,Color(c,clampf(float(fx.life),0,0.65)),false,4,true)
 for i in range(4):draw_card(i)
 draw_next_card()
 draw_rect(Rect2(98,1222,81,36),Color('#171e2d'));text_at('%d/10' % int(rules.state.energy[side]),Vector2(138,1249),27,Color('#fff4d0'),true)
 for i in range(10):
  var r = Rect2(202+i*46,1226,40,24)
  draw_style_box(gem_style(Color('#24dce9') if rules.state.energy[side] >= i+1 else Color('#253044')),r)
 var cooldown = float(rules.state.cooldowns[side])
 if cooldown > 0:
  draw_circle(Vector2(650,940),48,Color(0.01,0.02,0.05,0.75));text_at(str(int(ceil(cooldown))),Vector2(650,953),35,Color.WHITE,true)
 elif ability_selected:draw_arc(Vector2(650,940),56,0,TAU,64,Color('#ffcd68'),4,true)
 if toast_life > 0:
  draw_rect(Rect2(45,837,630,43),Color(0.02,0.03,0.08,0.92));text_at(toast,Vector2(360,865),19,Color('#fff1ce'),true)
func gem_style(color: Color) -> StyleBoxFlat:
 var style = StyleBoxFlat.new();style.bg_color = color;style.set_border_width_all(2);style.border_color = color.lightened(0.2);style.skew = Vector2(-0.28,0);return style
func draw_card(i: int) -> void:
 var id: String = rules.state.hands[side][i]
 var r = card_rect(i)
 var source_index = ['golem','goblin','wall','portal'].find(id)
 if source_index >= 0:
  source(Rect2(40+source_index*148,1000,143,191),r)
 else:
  source(Rect2(40,1000,143,191),r)
  draw_rect(Rect2(r.position+Vector2(12,20),Vector2(119,125)),Color('#172135'))
  var c: Dictionary = Rules.CARDS[id]
  if c.get('sprite',-1) >= 0:draw_sprite(int(c.sprite),Rect2(r.position+Vector2(8,15),Vector2(127,135)))
  else:
   draw_circle(r.position+Vector2(72,83),35,Color('#ef8834') if id == 'fire' else Color('#4cd7ac'))
   text_at('✦',r.position+Vector2(72,99),45,Color.WHITE,true)
  draw_rect(Rect2(r.position+Vector2(10,142),Vector2(122,27)),Color('#382b24'));text_at(str(c.name),r.position+Vector2(71,163),17,Color('#ffedcc'),true)
  draw_rect(Rect2(r.position+Vector2(6,9),Vector2(28,28)),Color('#146c9d'));text_at(str(c.cost),r.position+Vector2(20,32),27,Color.WHITE,true)
 if float(rules.state.energy[side]) < Rules.CARDS[id].cost:draw_rect(r,Color(0.02,0.03,0.08,0.5))
 if selected == i:draw_rect(r.grow(3),Color('#51f5fb'),false,3)
func draw_sprite(index: int, destination: Rect2) -> void:
 if sprites == null:return
 var cell = sprites.get_size()/Vector2(3,2)
 draw_texture_rect_region(sprites,destination,Rect2(Vector2(index%3,int(index/3))*cell,cell))
func draw_unit(u: Dictionary) -> void:
 var c: Dictionary = Rules.CARDS[u.id]
 var p = Vector2(u.x,u.y)
 if side == 1:p = Vector2(720-p.x,985-p.y)
 var friendly = int(u.side) == side
 draw_ellipse_shadow(p)
 var width = 158.0 if u.id in ['golem','orc'] else 125.0
 var height = width*1.05
 var bounce = sin(elapsed*6+float(u.uid))*2
 if int(c.get('sprite',-1)) >= 0:draw_sprite(int(c.sprite),Rect2(p.x-width/2,p.y-height+bounce,width,height))
 else:
  draw_circle(p-Vector2(0,25),18+sin(elapsed*4)*3,Color('#4ceaf3'));draw_arc(p-Vector2(0,25),25,elapsed,elapsed+4.0,24,Color('#b894ff'),4,true)
 if float(u.flash) > 0:draw_arc(p-Vector2(0,height/2),width/3,0,TAU,32,Color('#ffda8d'),3,true)
 draw_rect(Rect2(p.x-28,p.y-height,56,9),Color('#101526'));draw_rect(Rect2(p.x-26,p.y-height+2,52*maxf(0,float(u.hp)/float(u.max_hp)),5),Color('#37dfef') if friendly else Color('#ee454e'))
func draw_ellipse_shadow(p: Vector2) -> void:
 draw_set_transform(origin+(p*factor),0,Vector2(factor,factor*0.3));draw_circle(Vector2.ZERO,33,Color(0,0,0,0.36));draw_set_transform(origin,0,Vector2.ONE*factor)

func draw_next_card() -> void:
 var id: String = rules.state.queues[side][0]
 var i = ['golem','goblin','wall','portal'].find(id)
 var r = Rect2(648,1081,62,84)
 source(Rect2(40+maxi(0,i)*148,1000,143,191),r)
 if i < 0:
  draw_rect(Rect2(654,1092,50,48),Color('#172135'))
  var c: Dictionary = Rules.CARDS[id]
  if c.get('sprite',-1) >= 0:draw_sprite(int(c.sprite),Rect2(654,1092,50,48))
  else:draw_circle(Vector2(679,1115),17,Color('#ffad4b') if id == 'fire' else Color('#4adca9'))
  draw_rect(Rect2(653,1141,52,17),Color('#382b24'));text_at(str(c.name),Vector2(679,1153),8,Color.WHITE,true)
  draw_rect(Rect2(650,1083,16,17),Color('#12618e'));text_at(str(c.cost),Vector2(658,1098),15,Color.WHITE,true)
 text_at('A SEGUIR',Vector2(680,1074),10,Color('#e6d9b7'),true)
