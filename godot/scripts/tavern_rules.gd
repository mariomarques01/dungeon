extends RefCounted
const MAX_BOARD=7
const MAX_HAND=10
const DECK_SIZE=30
const DEFAULT_DECK=['scout','scout','stoneguard','stoneguard','wolf','wolf','apprentice','apprentice','drake','drake','shieldbearer','shieldbearer','dryad','dryad','panther','panther','beetle','beetle','orc','orc','fireball','fireball','frost','frost','healing','healing','wisdom','wisdom','treant','dragon']
var cards: Dictionary
var players: Array=[]
var active=0
var turn=1
var done=false
var outcome=''
var next_uid=1
var events: Array=[]
var random=RandomNumberGenerator.new()

func _init(definitions: Dictionary) -> void:
 cards=definitions
 random.randomize()

func start(deck: Array, enemy_deck: Array=[], random_seed = -1) -> Array:
 if random_seed>=0: random.seed=random_seed
 players=[]; active=0; turn=1; done=false; outcome=''; next_uid=1; events=[]
 for side in range(2):
  var chosen=deck if side==0 else enemy_deck if not enemy_deck.is_empty() else DEFAULT_DECK
  var pile=chosen.duplicate()
  for i in range(pile.size()-1,0,-1):
   var j=random.randi_range(0,i)
   var swap=pile[i]; pile[i]=pile[j]; pile[j]=swap
  players.append({'health':30,'armor':0,'mana':0,'max_mana':0,'deck':pile,'hand':[],'board':[],'fatigue':0,'power_used':false})
  for i in range(3): draw(side)
  # An opening one-cost creature keeps the first match interactive for both sides.
  var opening: Array=players[side].hand
  if not opening.any(func(id): return cards[id].kind=='minion' and cards[id].cost==1):
   for i in range(players[side].deck.size()):
    var id=players[side].deck[i]
    if cards[id].kind=='minion' and cards[id].cost==1:
     var old=opening[0]; opening[0]=id; players[side].deck[i]=old; break
 start_turn(0)
 return events.duplicate(true)

func valid_deck(deck: Array) -> bool:
 if deck.size()!=DECK_SIZE: return false
 var counts={}
 for id in deck:
  if not cards.has(id) or cards[id].get('token',false): return false
  counts[id]=counts.get(id,0)+1
  if counts[id]>(1 if cards[id].get('legendary',false) else 2): return false
 return true

func draw(side: int, count=1) -> void:
 for i in range(count):
  if done:break
  var p=players[side]
  if p.deck.is_empty():
   p.fatigue+=1
   damage({'side':side,'hero':true},int(p.fatigue),'fatigue')
   events.append({'kind':'fatigue','side':side,'amount':p.fatigue})
  else:
   var id=p.deck.pop_back()
   if p.hand.size()<MAX_HAND:
    p.hand.append(id); events.append({'kind':'draw','side':side,'id':id})
   else: events.append({'kind':'burn','side':side,'id':id})
 check_end()

func start_turn(side: int) -> void:
 active=side
 var p=players[side]
 p.max_mana=mini(10,int(p.max_mana)+1); p.mana=p.max_mana; p.power_used=false
 for unit in p.board:
  unit.sleeping=false;unit.frozen_lock=false
  if unit.frozen>0: unit.frozen-=1; unit.attacks=0;unit.frozen_lock=true
  else: unit.attacks=2 if 'windfury' in unit.keywords else 1
 draw(side)
 events.append({'kind':'turn','side':side,'turn':turn})

func end_turn() -> Dictionary:
 if done: return failure('A partida terminou.')
 events=[]
 for unit in players[active].board:unit.frozen_lock=false
 turn+=1
 start_turn(1-active)
 return success()

func failure(reason: String) -> Dictionary:
 return {'ok':false,'reason':reason,'events':[]}
func success() -> Dictionary:
 check_end()
 return {'ok':true,'events':events.duplicate(true)}

func find_unit(side: int, uid: int):
 for unit in players[side].board:
  if int(unit.uid)==uid: return unit
 return null

func target_exists(target: Dictionary) -> bool:
 if not target.has('side') or int(target.side)<0 or int(target.side)>1: return false
 return target.get('hero',false) or find_unit(int(target.side),int(target.get('uid',-1)))!=null

func spellpower(side: int) -> int:
 var total=0
 for unit in players[side].board: total+=int(cards[unit.id].get('spellpower',0))
 return total

func can_play(side: int,index: int,target: Dictionary={}) -> Dictionary:
 if done or side!=active: return failure('Aguarde seu turno.')
 var p=players[side]
 if index<0 or index>=p.hand.size(): return failure('Carta indisponível.')
 var c=cards[p.hand[index]]
 if int(c.cost)>int(p.mana): return failure('Mana insuficiente.')
 if c.kind=='minion':
  if p.board.size()>=MAX_BOARD: return failure('Seu campo já tem 7 criaturas.')
  return {'ok':true}
 var rule=c.get('target','none')
 if rule!='none':
  if not target_exists(target): return failure('Arraste o feitiço até um alvo.')
  if rule.begins_with('enemy') and int(target.side)==side: return failure('Escolha um inimigo.')
  if rule.begins_with('friendly') and int(target.side)!=side: return failure('Escolha um aliado.')
  if rule.ends_with('minion') and target.get('hero',false): return failure('Escolha uma criatura.')
 if c.effect=='summon_wolves' and p.board.size()>=MAX_BOARD: return failure('Seu campo está cheio.')
 return {'ok':true}

func spawn(side: int,id: String,position = -1) -> Dictionary:
 if players[side].board.size()>=MAX_BOARD: return {}
 var c=cards[id]
 var keys=c.get('keywords',[]).duplicate()
 var rush='rush' in keys or 'charge' in keys
 var unit={'uid':next_uid,'id':id,'attack':int(c.attack),'health':int(c.health),'max_health':int(c.health),'keywords':keys,'shield':'shield' in keys,'sleeping':true,'attacks':(2 if 'windfury' in keys else 1) if rush else 0,'frozen':0}
 next_uid+=1
 var board: Array=players[side].board
 if position<0 or position>=board.size(): board.append(unit)
 else: board.insert(position,unit)
 events.append({'kind':'summon','side':side,'uid':unit.uid,'id':id})
 return unit

func play(side: int,index: int,target: Dictionary={},position = -1) -> Dictionary:
 var valid=can_play(side,index,target)
 if not valid.ok: return valid
 events=[]
 var p=players[side]
 var id=p.hand[index]
 var c=cards[id]
 p.mana-=int(c.cost); p.hand.remove_at(index)
 events.append({'kind':'card','side':side,'id':id})
 if c.kind=='minion':
  spawn(side,id,position)
  battlecry(side,c.get('battlecry',''))
 else: cast(side,c,target)
 resolve_deaths()
 return success()

func battlecry(side: int,ability: String) -> void:
 match ability:
  'ping':
   var targets=enemy_targets(side)
   if not targets.is_empty(): damage(targets[random.randi_range(0,targets.size()-1)],1,'fire')
  'heal': heal({'side':side,'hero':true},3)
  'blast','inferno':
   for unit in players[1-side].board.duplicate(): damage({'side':1-side,'uid':unit.uid},3 if ability=='inferno' else 2,'fire')
  'freeze':
   var board: Array=players[1-side].board
   if not board.is_empty(): freeze_unit(1-side,int(board[random.randi_range(0,board.size()-1)].uid))
  'frost_all':
   for unit in players[1-side].board: freeze_unit(1-side,int(unit.uid))

func cast(side: int,c: Dictionary,target: Dictionary) -> void:
 var power=spellpower(side)
 var amount=int(c.amount)
 match c.effect:
  'damage': damage(target,amount+power,c.element)
  'heal': heal(target,amount)
  'frost': damage(target,amount+power,'ice'); freeze_unit(int(target.side),int(target.uid))
  'aoe','blizzard':
   for unit in players[1-side].board.duplicate():
    damage({'side':1-side,'uid':unit.uid},amount+power,c.element)
    if c.effect=='blizzard': freeze_unit(1-side,int(unit.uid))
  'armor':
   players[side].armor+=amount; events.append({'kind':'armor','side':side,'amount':amount})
  'missiles':
   for i in range(amount+power):
    if done:break
    var targets=enemy_targets(side)
    if targets.is_empty(): break
    damage(targets[random.randi_range(0,targets.size()-1)],1,'arcane')
    resolve_deaths()
  'draw': draw(side,amount)
  'weaken':
   var unit=find_unit(int(target.side),int(target.uid))
   if unit: unit.attack=maxi(0,int(unit.attack)-amount); events.append({'kind':'debuff','target':target,'amount':amount})
   draw(side)
  'buff','buff_attack':
   var unit=find_unit(int(target.side),int(target.uid))
   if unit:
    unit.attack+=amount
    if c.effect=='buff': unit.max_health+=amount; unit.health+=amount
    events.append({'kind':'buff','target':target,'amount':amount})
  'destroy':
   var unit=find_unit(int(target.side),int(target.uid))
   if unit: unit.health=0; events.append({'kind':'destroy','target':target})
  'summon_wolves':
   spawn(side,'token_wolf'); spawn(side,'token_wolf')
  'mana':
   players[side].mana=mini(10,int(players[side].mana)+amount)
   events.append({'kind':'mana','side':side,'amount':amount})

func damage(target: Dictionary,amount: int,element='steel',poison=false) -> int:
 if not target_exists(target): return 0
 amount=maxi(0,amount)
 var side=int(target.side)
 var actual=0
 if target.get('hero',false):
  var p=players[side]
  var block=mini(int(p.armor),amount)
  p.armor-=block; amount-=block
  actual=mini(int(p.health),amount); p.health=maxi(0,int(p.health)-amount)
  if block>0: events.append({'kind':'blocked','target':target.duplicate(),'amount':block})
 else:
  var unit=find_unit(side,int(target.uid))
  if unit.shield and amount>0:
   unit.shield=false; events.append({'kind':'shield_break','target':target.duplicate()}); return 0
  actual=mini(maxi(0,int(unit.health)),amount)
  unit.health-=amount
  if poison and actual>0: unit.health=0
 if actual>0: events.append({'kind':'damage','target':target.duplicate(),'amount':actual,'element':element})
 return actual

func heal(target: Dictionary,amount: int) -> int:
 if not target_exists(target): return 0
 var actual=0
 if target.get('hero',false):
  var p=players[int(target.side)]
  if p.health<=0:return 0
  actual=mini(maxi(0,amount),30-int(p.health)); p.health+=actual
 else:
  var unit=find_unit(int(target.side),int(target.uid))
  actual=mini(maxi(0,amount),int(unit.max_health)-int(unit.health)); unit.health+=actual
 if actual>0: events.append({'kind':'heal','target':target.duplicate(),'amount':actual})
 return actual

func freeze_unit(side: int,uid: int) -> void:
 var unit=find_unit(side,uid)
 if unit:
  unit.frozen=1; unit.attacks=0
  events.append({'kind':'freeze','target':{'side':side,'uid':uid}})

func resolve_deaths() -> void:
 for iteration in range(20):
  var dead=[]
  for side in range(2):
   for unit in players[side].board.duplicate():
    if int(unit.health)<=0:
     players[side].board.erase(unit)
     dead.append({'side':side,'unit':unit})
     events.append({'kind':'death','side':side,'uid':unit.uid,'id':unit.id})
  if dead.is_empty(): break
  for entry in dead:
   var side=int(entry.side)
   var death=cards[entry.unit.id].get('deathrattle','')
   match death:
    'skeletons': spawn(side,'token_skeleton'); spawn(side,'token_skeleton')
    'heal': heal({'side':side,'hero':true},5)
 check_end()

func can_attack(side: int,uid: int,target: Dictionary) -> Dictionary:
 if done or side!=active: return failure('Aguarde seu turno.')
 var attacker=find_unit(side,uid)
 if not attacker: return failure('Criatura indisponível.')
 if attacker.attacks<=0: return failure('Esta criatura precisa aguardar o próximo turno.' if attacker.sleeping else 'Esta criatura já atacou ou está congelada.')
 if attacker.attack<=0: return failure('Esta criatura não tem ataque.')
 if not target_exists(target) or int(target.side)==side: return failure('Arraste até um inimigo.')
 if target.get('hero',false) and attacker.sleeping and not 'charge' in attacker.keywords: return failure('Investida só permite atacar criaturas neste turno.')
 var taunts=players[1-side].board.filter(func(u): return 'taunt' in u.keywords and u.health>0)
 if not taunts.is_empty():
  if target.get('hero',false) or not taunts.any(func(u): return int(u.uid)==int(target.get('uid',-1))): return failure('Ataque primeiro uma criatura com Provocar.')
 return {'ok':true}

func attack(side: int,uid: int,target: Dictionary) -> Dictionary:
 var valid=can_attack(side,uid,target)
 if not valid.ok: return valid
 events=[]
 var attacker=find_unit(side,uid)
 attacker.attacks-=1
 var attacker_target={'side':side,'uid':uid}
 var retaliation=0
 var defender=null
 if not target.get('hero',false):
  defender=find_unit(int(target.side),int(target.uid)); retaliation=int(defender.attack)
 var dealt=damage(target,int(attacker.attack),cards[attacker.id].element,'poison' in attacker.keywords)
 if 'lifesteal' in attacker.keywords: heal({'side':side,'hero':true},dealt)
 if defender:
  var returned=damage(attacker_target,retaliation,cards[defender.id].element,'poison' in defender.keywords)
  if 'lifesteal' in defender.keywords: heal({'side':int(target.side),'hero':true},returned)
 events.append({'kind':'attack','side':side,'uid':uid,'target':target.duplicate()})
 resolve_deaths()
 return success()

func can_power(side: int,target: Dictionary={}) -> Dictionary:
 if done or side!=active: return failure('Aguarde seu turno.')
 var p=players[side]
 if p.power_used: return failure('Poder já usado neste turno.')
 if p.mana<2: return failure('O poder custa 2 de mana.')
 if side==0 and (not target_exists(target) or int(target.side)==side): return failure('Arraste o poder até um inimigo.')
 if side==1 and p.board.size()>=MAX_BOARD: return failure('Campo cheio.')
 return {'ok':true}

func power(side: int,target: Dictionary={}) -> Dictionary:
 var valid=can_power(side,target)
 if not valid.ok: return valid
 events=[]
 players[side].mana-=2; players[side].power_used=true
 if side==0: damage(target,1,'fire')
 else: spawn(side,'token_guard')
 events.append({'kind':'power','side':side})
 resolve_deaths()
 return success()

func enemy_targets(side: int) -> Array:
 var result=[]
 for unit in players[1-side].board:
  if unit.health>0: result.append({'side':1-side,'uid':unit.uid})
 if players[1-side].health>0: result.append({'side':1-side,'hero':true})
 return result

func check_end() -> void:
 if players.size()!=2: return
 if players[0].health<=0 or players[1].health<=0:
  done=true
  outcome='draw' if players[0].health<=0 and players[1].health<=0 else 'win' if players[1].health<=0 else 'lose'

func ai_target(c: Dictionary) -> Dictionary:
 var rule=c.get('target','none')
 if rule=='none': return {}
 if rule.begins_with('friendly'):
  if rule=='friendly' and players[1].health<26: return {'side':1,'hero':true}
  var allies=players[1].board.duplicate()
  allies.sort_custom(func(a,b): return a.attack>b.attack)
  for unit in allies:
   if c.effect!='heal' or unit.health<unit.max_health: return {'side':1,'uid':unit.uid}
  return {}
 var enemies=players[0].board.duplicate()
 enemies.sort_custom(func(a,b): return a.attack>b.attack)
 if rule=='enemy' and int(c.get('amount',0))+spellpower(1)>=int(players[0].health): return {'side':0,'hero':true}
 for unit in enemies:
  if c.effect in ['destroy','weaken','frost'] or int(c.get('amount',0))+spellpower(1)>=int(unit.health): return {'side':0,'uid':unit.uid}
 if rule=='enemy': return {'side':0,'hero':true}
 if not enemies.is_empty(): return {'side':0,'uid':enemies[0].uid}
 return {}

func ai_play() -> Dictionary:
 var best={}; var score=-1000.0
 for i in range(players[1].hand.size()):
  var c=cards[players[1].hand[i]]
  var target=ai_target(c)
  if not can_play(1,i,target).ok: continue
  var value=float(c.cost)*2
  if c.kind=='minion': value+=float(c.attack)+float(c.health)*0.8
  elif c.effect in ['aoe','blizzard']:
   if players[0].board.is_empty(): continue
   value+=players[0].board.size()*3
  elif c.effect=='heal':
   if target.is_empty(): continue
   value+=4
  elif c.effect=='draw':
   if players[1].hand.size()>7: continue
   value+=3
  elif c.effect=='armor':
   if players[1].health>23: value-=8
  elif c.effect=='mana':
   if players[1].mana>=10: continue
  else: value+=3
  if value>score: score=value; best={'kind':'play','index':i,'target':target}
 return best

func ai_attack() -> Dictionary:
 var best={}; var best_score=-1000.0
 for unit in players[1].board:
  for target in enemy_targets(1):
   if not can_attack(1,int(unit.uid),target).ok: continue
   var score=float(unit.attack)*0.5
   if target.get('hero',false): score+=10000 if unit.attack>=players[0].health else 3
   else:
    var enemy=find_unit(0,int(target.uid))
    if unit.attack>=enemy.health or 'poison' in unit.keywords: score+=int(cards[enemy.id].cost)*3+4
    if enemy.attack>=unit.health: score-=int(cards[unit.id].cost)*2
    if 'taunt' in enemy.keywords: score+=5
   if score>best_score: best_score=score; best={'kind':'attack','uid':unit.uid,'target':target}
 return best
