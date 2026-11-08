extends RefCounted
# Simulation shared by practice and the authoritative room server. No rendering or I/O.
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
  'cooldowns':[0.0,0.0],'winner':-2,'revision':0,'casts':[0,0],'effects':[]}
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
 if not card.get('spell',false) and state.units.size()+(2 if id == 'portal' else 1) > 64:return 'Arena cheia'
 state.energy[side] -= card.cost
 state.hands[side][index] = state.queues[side].pop_front()
 state.queues[side].append(id)
 state.casts[side] += 1
 if id == 'fire' or id == 'heal':
  area(side,x,y,170,230 if id == 'fire' else -240)
 elif id == 'portal':
  for dx in [-22,22]:spawn(side,'skeleton',clampf(x+dx,135,570),y)
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
   unit.hp = mini(unit.max_hp,unit.hp-damage)
func spawn(side: int, id: String, x: float, y: float) -> void:
 var c: Dictionary = CARDS[id]
 serial += 1
 state.units.append({'uid':serial,'id':id,'side':side,'x':x,'y':y,'hp':c.hp,'max_hp':c.hp,'attack':0.5,'flash':0.0})
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
 for unit in state.units:
  if unit.hp <= 0:continue
  var c: Dictionary = CARDS[unit.id]
  unit.attack = maxf(0,unit.attack-dt)
  unit.flash = maxf(0,unit.flash-dt)
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
     target.hp -= c.damage;target.flash = 0.22;unit.attack = 1.0
     state.effects.append({'x':target.x,'y':target.y,'kind':'hit','life':0.22})
   else:move_unit(unit,Vector2(target.x,target.y),float(c.speed),dt)
  elif core_distance < 95+c.range:
   if unit.attack <= 0:
    state.cores[1-unit.side] = maxi(0,state.cores[1-unit.side]-c.damage)
    unit.attack = 1.0
    state.effects.append({'x':core_pos.x,'y':core_pos.y,'kind':'hit','life':0.25})
  else:
   # Moving dungeon: left bridge accelerates; right trap damages; center seals.
   var waypoint = core_pos
   if unit.side == 0 and unit.y > 430:waypoint = Vector2(240 if state.phase == 1 else 440,390)
   if unit.side == 1 and unit.y < 560:waypoint = Vector2(240 if state.phase == 1 else 440,590)
   if state.phase == 2 and unit.x > 405 and unit.y > 490 and unit.y < 640:unit.hp -= 32*dt;unit.flash = 0.05
   move_unit(unit,waypoint,float(c.speed)*(1.45 if state.phase == 1 and unit.x < 320 else 1.0),dt)
 state.units = state.units.filter(func(u):return u.hp > 0)
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
 var next = Vector2(unit.x,unit.y).move_toward(target,speed*dt)
 unit.x = clampf(next.x,135,570);unit.y = clampf(next.y,175,820)
