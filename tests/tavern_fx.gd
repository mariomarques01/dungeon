extends SceneTree
var failures=0
func _initialize() -> void:call_deferred('run')
func run() -> void:
 var game=load('res://scenes/tavern.tscn').instantiate();root.add_child(game)
 await process_frame
 game.speed=2.0
 game.sound_on=false;game.audio_engine.set_enabled(false)
 game.start_match()
 game.reduced_motion=false
 for i in range(18):game.view.burst(Vector2(50,50),Color.GOLD)
 game.view.tick(0.01)
 if game.view.bursts.size()!=6 or game.view.torches.size()!=2:
  push_error('Particle pool exceeded its budget');failures+=1
 game.reduced_motion=true
 game.view.stop_motion()
 game.view.tick(0.01)
 if game.view.bursts.any(func(n):return n.visible or n.emitting) or game.view.torches.any(func(n):return n.emitting):
  push_error('Reduced motion left particles running');failures+=1
 game.reduced_motion=false
 check_summon_attack(game)
 var ids=game.cards.keys()
 for id in ids:
  print("FX CARD: ",id)
  game.start_match();game.rules.players[0].mana=10;game.rules.players[0].max_mana=10
  game.rules.players[0].health=20
  game.rules.players[0].hand=[id]
  game.rules.spawn(0,'stoneguard');game.rules.spawn(1,'stoneguard')
  game.view.prepare()
  var card=game.cards[id];var target={}
  if card.kind=='trap':
   await check_trap_reveal(game,card)
   continue
  match card.get('target','none'):
   'enemy':target={'side':1,'hero':true}
   'enemy_minion':target={'side':1,'uid':game.rules.players[1].board[0].uid}
   'friendly':target={'side':0,'hero':true}
   'friendly_minion':target={'side':0,'uid':game.rules.players[0].board[0].uid}
  var valid=game.rules.can_play(0,0,target)
  if not valid.ok:push_error('Fixture invalid: '+id);failures+=1;continue
  game.request_play(0,target)
  await finish_animation(game)
  if not game.active_actions.is_empty() or game.view.effect_history[-1].id!=id:push_error('Animation did not complete: '+id);failures+=1
  if card.kind=='minion' and not game.rules.players[0].board.is_empty():
   var unit=game.rules.players[0].board[-1]
   var victim={'side':1,'hero':true} if game.rules.players[1].board.is_empty() else {'side':1,'uid':game.rules.players[1].board[0].uid}
   if game.rules.can_attack(0,unit.uid,victim).ok:
    game.request_attack(unit.uid,victim)
    await finish_animation(game)
  for voice in game.audio_engine.voices:
   if is_instance_valid(voice):voice.stop()
 # Lethal spell effects keep the element that actually killed the target.
 for spell in ['fireball','frost','bolt','vortex']:
  game.start_match();game.rules.players[0].mana=10;game.rules.players[0].hand=[spell]
  var victim=game.rules.spawn(1,'stoneguard');victim.health=1
  game.view.prepare()
  game.request_play(0,{'side':1,'uid':victim.uid})
  await finish_animation(game)
  var remains=game.view.ghosts.filter(func(g):return g.uid==victim.uid)
  if remains.is_empty() or remains[0].element!=game.cards[spell].element:push_error('Wrong death element: '+spell);failures+=1
 print('Fire, ice, lightning and shadow death profiles checked')
 # A multi-kill banner depends on actual enemy deaths in one resolution.
 for count in [1,2,3]:
  game.start_match();game.rules.players[0].mana=10;game.rules.players[0].hand=['meteor']
  for i in range(count):game.rules.spawn(1,'wolf').health=1
  game.view.prepare()
  game.request_play(0,{})
  await finish_animation(game)
  var banners=game.view.floats.filter(func(f):return f.text.begins_with('QUEDA'))
  var expected='QUEDA DUPLA' if count==2 else 'QUEDA MÚLTIPLA'
  if (count==1 and not banners.is_empty()) or (count>1 and (banners.size()!=1 or banners[0].text!=expected)):
   push_error('Wrong defeat banner for '+str(count)+' deaths');failures+=1
 game.start_match();game.rules.players[0].mana=10;game.view.prepare()
 game.request_solar()
 await finish_animation(game)
 if not game.active_actions.is_empty() or game.view.effect_history[-1].id!='solar':
  push_error('Solar timeline did not finish');failures+=1
 # A real lethal action opens the victory panel with live units still on the board.
 game.start_match();game.rules.spawn(0,'dragon');game.rules.spawn(1,'wolf')
 game.rules.players[0].mana=10;game.rules.players[0].hand=['fireball']
 game.rules.players[1].health=1;game.view.prepare()
 game.request_play(0,{'side':1,'hero':true})
 await finish_animation(game)
 if game.panel!='result' or game.rules.outcome!='win':push_error('Victory panel did not open');failures+=1
 for node in game.view.nodes.values():
  if node.z_index>=game.overlay.z_index:push_error('Card art overlaps result');failures+=1
 if game.audio_engine.action_clip('wolf','bite')!='bite_hit' or game.audio_engine.action_clip('golem','earth')!='stone_hit' or game.audio_engine.action_clip('orc','steel')!='steel_heavy':push_error('Wrong creature sound family');failures+=1
 print('Victory layers and creature audio profiles checked')
 # Rapid hits merge by target. Health warnings must survive a simultaneous first hit.
 game.start_match()
 game.reduced_motion=false
 game.view.prepare()
 var snapshot=game.rules.players.duplicate(true)
 game.rules.players[1].health=9
 var hit={'kind':'damage','amount':3,'element':'fire','target':{'side':1,'hero':true}}
 game.view.ingest([hit,hit],snapshot)
 if game.view.floats.size()!=1 or game.view.floats[0].text!='−6' or game.view.banners!=['PRIMEIRO SANGUE','HERÓI RIVAL EM PERIGO']:
  push_error('Incorrect damage accumulation or event order');failures+=1
 var advantaged=hit.duplicate()
 advantaged.modifier=1
 game.view.ingest([advantaged],snapshot)
 if game.view.floats.size()!=2 or game.view.floats[1].text!='−3 ▲':
  push_error('Elemental and neutral numbers must retain distinct markers');failures+=1
 if game.view.battle_delta(0.005)!=0 or game.view.battle_delta(0.2)<=0:
  push_error('Hit-stop must hold briefly and release');failures+=1
 var sprite=game.view.floats[0].sprite
 game.view.tick(2)
 game.view.ingest([hit],game.rules.players.duplicate(true))
 if game.view.floats[0].sprite!=sprite:push_error('Floating number was not reused');failures+=1
 game.activate_button('motion')
 game.view.ingest([hit],game.rules.players.duplicate(true))
 if game.view.battle_delta(0.02)!=0.02 or game.view.camera_offset()!=Vector2.ZERO:
  push_error('Reduced motion still triggers hit-stop or shake');failures+=1
 game.activate_button('motion')
 game.start_match()
 if not game.view.banners.is_empty() or game.view.first_blood:
  push_error('Rematch inherited event banners');failures+=1
 print('FX RESULT: ',ids.size(),' card timelines completed; ',failures,' failures')
 game.queue_free();await process_frame;quit(1 if failures else 0)

func finish_animation(game) -> void:
 for frame in range(600):
  if game.active_actions.is_empty():return
  await process_frame
 push_error('Animation timed out')
 failures+=1

func check_trap_reveal(game,card: Dictionary) -> void:
 var player=game.rules.players[0]
 var rival=game.rules.players[1]
 game.place_support(0,0)
 if player.supports[0].trap!=card.id or not game.view.trap_reveals.is_empty():
  push_error('Trap must remain hidden when placed: '+card.id);failures+=1
 var hero={'side':0,'hero':true}
 match card.trigger:
  'attacked':
   var attacker=game.rules.spawn(1,'wolf')
   game.view.prepare()
   # The fixture has a guard with Taunt, so the rival must attack it first.
   game.request_attack(attacker.uid,{'side':0,'uid':player.board[0].uid},1)
  'enemy_spell','low_health':
   rival.mana=10;rival.hand=['fireball']
   if card.has('threshold'):player.health=int(card.threshold)
   game.request_play(0,hero,-1,Vector2.ZERO,1)
 game.advance_actions(0.55)
 if game.view.trap_reveals.size()!=1 or game.view.trap_reveals[0].id!=card.id or player.supports[0].trap!='':
  push_error('Trap reveal did not reach the view: '+card.id);failures+=1
 game.view.tick(0.15)
 game.overlay.queue_redraw()
 await process_frame
 game.reduced_motion=true
 game.overlay.queue_redraw()
 await process_frame
 game.reduced_motion=false
 game.view.tick(2)
 if not game.view.trap_reveals.is_empty():
  push_error('Trap reveal must expire: '+card.id);failures+=1

func check_summon_attack(game) -> void:
 game.start_match()
 game.rules.players[0].mana=10
 game.rules.players[0].hand=['wolf']
 var enemy=game.rules.spawn(1,'scout')
 game.view.prepare()
 game.request_play(0)
 game.advance_actions(0.53)
 var unit=game.rules.players[0].board[-1]
 var hero={'side':1,'hero':true}
 game.request_attack(unit.uid,hero)
 if game.active_actions.size()!=1 or game.toast_text!=game.rules.ENTRY_LOCK_REASON:
  push_error('A freshly summoned creature must receive the hero lock message');failures+=1
 game.view.prepare()
 game.request_attack(unit.uid,{'side':1,'uid':enemy.uid})
 game.advance_actions(0.39)
 if game.rules.find_unit(1,enemy.uid)!=null or unit.delay!=game.rules.REUSE_SECONDS or game.view.effect_history[-1].kind!='attack':
  push_error('Summon must allow an immediate attack timeline against a creature');failures+=1
