extends RefCounted
# Simulation shared by practice and the authoritative room server. No rendering or I/O.
const WALL_STEP = Vector2(82,-32)
const DECK = ['golem','goblin','wall','portal','skeleton','mage','orc','fire','heal','wisp']
const CARDS = {
 'golem': {'name':'GOLEM','cost':4,'hp':640,'damage':64,'speed':24,'range':48,'sprite':0},
 'goblin': {'name':'GOBLIN','cost':2,'hp':210,'damage':32,'speed':48,'range':110,'sprite':1},
 'wall': {'name':'MURALHA','cost':3,'hp':950,'damage':0,'speed':0,'range':0,'sprite':5},
 'portal': {'name':'PORTAL','cost':2,'hp':200,'damage':0,'speed':0,'range':0,'sprite':-1},
 'skeleton': {'name':'OSSADA','cost':2,'hp':170,'damage':30,'speed':38,'range':42,'sprite':4},
 'mage': {'name':'ARCANISTA','cost':3,'hp':280,'damage':55,'speed':27,'range':145,'sprite':3},
 'orc': {'name':'SAQUEADOR','cost':4,'hp':530,'damage':80,'speed':30,'range':50,'sprite':2},
 'fire': {'name':'METEORO','cost':4,'spell':true},
 'heal': {'name':'RENOVAR','cost':3,'spell':true},
 'wisp': {'name':'FAÍSCA','cost':1,'hp':90,'damage':24,'speed':60,'range':90,'sprite':-1}
}
var state: Dictionary
var serial = 0
var ai_clock = 0.0
var events: Array = []
func _init() -> void:
 reset()
func reset() -> void:
 serial = 0
 ai_clock = 0.0
 state = {'time':240.0,'phase':0,'units':[],'cores':[2400,2400],'energy':[7.0,7.0],
  'hands':[DECK.slice(0,4),DECK.slice(0,4)],'queues':[DECK.slice(4),DECK.slice(4)],
  'cooldowns':[0.0,0.0],'winner':-2,'revision':0,'casts':[0,0],'effects':[],'strikes':[]}
 events.clear()
func play(side: int, index: int, x: float, y: float) -> String:
 if side < 0 or side > 1 or state.winner != -2:return 'Partida encerrada'
 if index < 0 or index >= 4:return 'Carta inválida'
 if not is_finite(x) or not is_finite(y):return 'Posição inválida'
 var id: String = state.hands[side][index]
 var card: Dictionary = CARDS[id]
 if state.energy[side] < card.cost:return 'Energia insuficiente'
 if x < 135 or x > 570 or y < 285 or y > 710:return 'Escolha o piso da arena'
 if not card.get('spell',false) and ((side == 0 and y < 500) or (side == 1 and y > 495)):
  return 'Invoque na sua metade da arena'
 if id == 'wall':
  var snapped = wall_position(side,Vector2(x,y))
  x = snapped.x;y = snapped.y
  if x < 135 or x > 570 or (side == 0 and (y < 500 or y > 710)) or (side == 1 and (y < 285 or y > 495)):return 'Encaixe fora da sua arena'
  for u in state.units:
   if u.id == 'wall' and Vector2(u.x,u.y).distance_to(snapped) < 40:return 'Já existe uma muralha aqui'
 if id != 'portal' and not card.get('spell',false) and state.units.size() >= 64:return 'Arena cheia'
 state.energy[side] -= card.cost
 state.hands[side][index] = state.queues[side].pop_front()
 state.queues[side].append(id)
 state.casts[side] += 1
 if id == 'fire' or id == 'heal':
  area(side,x,y,170,230 if id == 'fire' else -240)
 elif id == 'portal':
  cast_portal(side,Vector2(x,y))
 else:spawn(side,id,x,y)
 state.revision += 1
 return ''
func ability(side: int, x: float, y: float) -> String:
 if side < 0 or side > 1 or state.winner != -2:return 'Partida encerrada'
 if state.cooldowns[side] > 0:return 'Habilidade recarregando'
 if not is_finite(x) or not is_finite(y) or x < 100 or x > 620 or y < 250 or y > 740:return 'Alvo inválido'
 state.cooldowns[side] = 22.0
 area(side,x,y,155,180)
 state.revision += 1
 return ''
func area(side: int, x: float, y: float, radius: float, damage: int) -> void:
 state.effects.append({'x':x,'y':y,'kind':'heal' if damage < 0 else 'fire','life':0.6})
 for unit in state.units:
  if (unit.side != side if damage > 0 else unit.side == side) and Vector2(unit.x,unit.y).distance_to(Vector2(x,y)) <= radius:
   if damage > 0:receive_hit(unit,damage,Vector2(x,y))
   else:unit.hp = mini(unit.max_hp,unit.hp-damage)
func spawn(side: int, id: String, x: float, y: float) -> void:
 var c: Dictionary = CARDS[id]
 serial += 1
 state.units.append({'uid':serial,'id':id,'side':side,'x':x,'y':y,'hp':c.hp,'max_hp':c.hp,'attack':0.7,'flash':0.0,'spawn_time':0.45,'strike_time':0.0,'hurt_time':0.0,'warp_time':0.0,'moving':false,'facing_x':0.0,'facing_y':-1.0 if side == 0 else 1.0,'target_x':x,'target_y':y,'links':[]})
 if id == 'wall':link_walls()
func step(dt: float, ai: bool = false) -> void:
 if state.winner != -2:return
 dt = clampf(dt,0,0.1)
 state.time = maxf(0,state.time-dt)
 state.phase = int((240.0-state.time)/30.0)%3
 for side in [0,1]:
  state.energy[side] = minf(10,state.energy[side]+dt*(0.7 if state.time > 60 else 1.1))
  state.cooldowns[side] = maxf(0,state.cooldowns[side]-dt)
 for fx in state.effects:fx.life -= dt
 state.effects = state.effects.filter(func(fx):return fx.life > 0)
 resolve_strikes(dt)
 for unit in state.units:
  if unit.hp <= 0:continue
  var c: Dictionary = CARDS[unit.id]
  unit.attack = maxf(0,unit.attack-dt)
  unit.flash = maxf(0,unit.flash-dt)
  unit.moving = false
  for timer in ['spawn_time','strike_time','hurt_time','warp_time']:unit[timer] = maxf(0,float(unit.get(timer,0))-dt)
  if unit.warp_time > 0:continue
  if state.phase == 2 and unit.x > 405 and unit.y > 490 and unit.y < 640:unit.hp -= 32*dt;unit.flash = 0.05
  if unit.spawn_time > 0:continue
  if c.speed == 0:continue
  var pos = Vector2(unit.x,unit.y)
  var target = null
  var distance = INF
  for enemy in state.units:
   if enemy.side == unit.side or enemy.hp <= 0:continue
   var d = pos.distance_to(Vector2(enemy.x,enemy.y))
   if d < distance:distance = d;target = enemy
  var core_pos = Vector2(360,190 if unit.side == 0 else 795)
  var core_distance = pos.distance_to(core_pos)
  if target != null and distance < 220:
   if distance <= c.range:
    if unit.attack <= 0:
     begin_strike(unit,target,Vector2(target.x,target.y),-1)
   else:move_unit(unit,Vector2(target.x,target.y),float(c.speed),dt)
  elif core_distance < 95+c.range:
   if unit.attack <= 0:
    begin_strike(unit,null,core_pos,1-int(unit.side))
  else:
   # Moving dungeon: left bridge accelerates; right trap damages; center seals.
   var waypoint = core_pos
   if unit.side == 0 and unit.y > 430:waypoint = Vector2(240 if state.phase == 1 else 440,390)
   if unit.side == 1 and unit.y < 560:waypoint = Vector2(240 if state.phase == 1 else 440,590)
   move_unit(unit,waypoint,float(c.speed)*(1.45 if state.phase == 1 and unit.x < 320 else 1.0),dt)
 var removed_wall = false
 for unit in state.units:
  if unit.hp <= 0:
   effect('death',Vector2(unit.x,unit.y),0.5,{'id':unit.id,'side':unit.side})
   if unit.id == 'wall':removed_wall = true
 state.units = state.units.filter(func(u):return u.hp > 0)
 if removed_wall:link_walls()
 if ai:
  ai_clock -= dt
  if ai_clock <= 0:
   ai_clock = 1.8
   for i in range(4):
    if state.energy[1] >= CARDS[state.hands[1][i]].cost:
     play(1,i,230.0+float(state.casts[1]%3)*110.0,350.0+float(state.casts[1]%2)*60.0);break
   if not state.units.is_empty() and state.cooldowns[1] <= 0:
    for u in state.units:
     if u.side == 0:ability(1,u.x,u.y);break
 if state.cores[0] <= 0 or state.cores[1] <= 0 or state.time <= 0:
  state.winner = -1 if state.cores[0] == state.cores[1] else (0 if state.cores[0] > state.cores[1] else 1)
 state.revision += 1
func move_unit(unit: Dictionary, target: Vector2, speed: float, dt: float) -> void:
 var pos = Vector2(unit.x,unit.y)
 var next = pos.move_toward(target,speed*dt)
 for wall in state.units:
  if wall.id != 'wall' or wall.hp <= 0:continue
  var center = Vector2(wall.x,wall.y)
  var nearest = Geometry2D.get_closest_point_to_segment(next,center-WALL_STEP*0.5,center+WALL_STEP*0.5)
  if next.distance_to(nearest) < 21:
   var away = (next-nearest).normalized()
   if away == Vector2.ZERO:away = Vector2(-WALL_STEP.y,WALL_STEP.x).normalized()
   next = nearest+away*21
 var delta = next-pos
 unit.moving = delta.length() > 0.01
 if delta.length() > 0.01:unit.facing_x = delta.normalized().x;unit.facing_y = delta.normalized().y
 unit.x = clampf(next.x,135,570);unit.y = clampf(next.y,175,820)

func effect(kind: String, pos: Vector2, duration: float, extra: Dictionary = {}) -> void:
 var fx = {'kind':kind,'x':pos.x,'y':pos.y,'life':duration,'duration':duration}
 fx.merge(extra);state.effects.append(fx)
func wall_position(side: int, pos: Vector2) -> Vector2:
 var best = pos
 var distance = 86.0
 for wall in state.units:
  if wall.id != 'wall' or int(wall.side) != side or wall.hp <= 0:continue
  for direction in [-1,1]:
   var candidate = Vector2(wall.x,wall.y)+WALL_STEP*direction
   var occupied = false
   for other in state.units:
    if other.id == 'wall' and Vector2(other.x,other.y).distance_to(candidate) < 40:occupied = true;break
   var d = pos.distance_to(candidate)
   if not occupied and d < distance:best = candidate;distance = d
 return best
func link_walls() -> void:
 for wall in state.units:
  if wall.id != 'wall':continue
  wall.links = []
  for other in state.units:
   if other.id != 'wall' or other.uid == wall.uid or other.side != wall.side:continue
   var delta = Vector2(other.x-wall.x,other.y-wall.y)
   if delta.distance_to(WALL_STEP) < 1:wall.links.append(1)
   elif delta.distance_to(-WALL_STEP) < 1:wall.links.append(-1)
func cast_portal(side: int, pos: Vector2) -> void:
 effect('portal',pos,1.25)
 var index = 0
 for unit in state.units:
  if int(unit.side) == side or unit.hp <= 0 or CARDS[unit.id].speed == 0:continue
  var from = Vector2(unit.x,unit.y)
  unit.warp_from_x = unit.x;unit.warp_from_y = unit.y
  unit.x = 300.0+(index%6)*24.0
  unit.y = (710.0 if int(unit.side) == 0 else 285.0)+int(index/6)*(-6 if int(unit.side) == 0 else 6)
  unit.y = clampf(unit.y,650,710) if int(unit.side) == 0 else clampf(unit.y,285,335)
  unit.warp_time = 0.9;unit.strike_time = 0.0;unit.attack = 1.2;unit.moving = false
  # Cancel attacks to/from a creature in transit. No remote damage after banishment.
  state.strikes = state.strikes.filter(func(hit):return hit.source != unit.uid and hit.target != unit.uid)
  effect('banish',from,0.9,{'to_x':unit.x,'to_y':unit.y})
  index += 1
func begin_strike(unit: Dictionary, target, destination: Vector2, core: int) -> void:
 var c: Dictionary = CARDS[unit.id]
 var ranged = c.range >= 90
 var direction = (destination-Vector2(unit.x,unit.y)).normalized()
 unit.facing_x = direction.x;unit.facing_y = direction.y
 unit.target_x = destination.x;unit.target_y = destination.y
 unit.strike_time = 0.6;unit.attack = 1.1
 var delay = 0.45 if ranged else 0.22
 state.strikes.append({'source':unit.uid,'target':int(target.uid) if target != null else -1,'core':core,'side':unit.side,'id':unit.id,'damage':c.damage,'x':unit.x,'y':unit.y,'to_x':destination.x,'to_y':destination.y,'life':delay,'duration':delay,'ranged':ranged})
func resolve_strikes(dt: float) -> void:
 for hit in state.strikes:
  hit.life -= dt
  if hit.life > 0:continue
  if hit.core >= 0:
   state.cores[int(hit.core)] = maxi(0,state.cores[int(hit.core)]-int(hit.damage))
   effect('impact',Vector2(hit.to_x,hit.to_y),0.32,{'id':hit.id})
  else:
   for unit in state.units:
    if unit.uid == hit.target and unit.hp > 0 and float(unit.get('warp_time',0)) <= 0:
     receive_hit(unit,int(hit.damage),Vector2(hit.x,hit.y));break
 state.strikes = state.strikes.filter(func(hit):return hit.life > 0)
func receive_hit(unit: Dictionary, damage: int, from: Vector2) -> void:
 unit.hp -= damage;unit.flash = 0.28;unit.hurt_time = 0.32
 var away = (Vector2(unit.x,unit.y)-from).normalized()
 unit.recoil_x = away.x;unit.recoil_y = away.y
 effect('guard' if unit.id == 'wall' else 'impact',Vector2(unit.x,unit.y),0.32,{'id':unit.id})
