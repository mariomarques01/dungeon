extends SceneTree
var failures=0
func _initialize() -> void:call_deferred('run')
func run() -> void:
 var game=load('res://scenes/main.tscn').instantiate();root.add_child(game)
 await process_frame
 game.speed=2.0
 game.sound_on=false;game.audio_engine.set_enabled(false)
 var ids=game.cards.keys()
 for id in ids:
  print("FX CARD: ",id)
  game.start_match();game.rules.players[0].mana=10;game.rules.players[0].max_mana=10
  game.rules.players[0].health=20
  game.rules.players[0].hand=[id]
  game.rules.spawn(0,'stoneguard');game.rules.spawn(1,'stoneguard')
  game.view.prepare()
  var card=game.cards[id];var target={}
  match card.get('target','none'):
   'enemy':target={'side':1,'hero':true}
   'enemy_minion':target={'side':1,'uid':game.rules.players[1].board[0].uid}
   'friendly':target={'side':0,'hero':true}
   'friendly_minion':target={'side':0,'uid':game.rules.players[0].board[0].uid}
  var valid=game.rules.can_play(0,0,target)
  if not valid.ok:push_error('Fixture invalid: '+id);failures+=1;continue
  await game.request_play(0,target)
  if game.busy or game.view.effect_history[-1].id!=id:push_error('Animation did not complete: '+id);failures+=1
  if card.kind=='minion' and not game.rules.players[0].board.is_empty():
   var unit=game.rules.players[0].board[-1]
   unit.sleeping=false;unit.attacks=1;unit.frozen=0
   var victim={'side':1,'hero':true} if game.rules.players[1].board.is_empty() else {'side':1,'uid':game.rules.players[1].board[0].uid}
   if game.rules.can_attack(0,unit.uid,victim).ok:await game.request_attack(unit.uid,victim)
  for voice in game.audio_engine.voices:
   if is_instance_valid(voice):voice.stop()
 # Lethal spell effects keep the element that actually killed the target.
 for spell in ['fireball','frost','bolt','vortex']:
  game.start_match();game.rules.players[0].mana=10;game.rules.players[0].hand=[spell]
  var victim=game.rules.spawn(1,'stoneguard');victim.health=1
  game.view.prepare()
  await game.request_play(0,{'side':1,'uid':victim.uid})
  var remains=game.view.ghosts.filter(func(g):return g.uid==victim.uid)
  if remains.is_empty() or remains[0].element!=game.cards[spell].element:push_error('Wrong death element: '+spell);failures+=1
 print('Fire, ice, lightning and shadow death profiles checked')
 # A real lethal action opens the victory panel with live units still on the board.
 game.start_match();game.rules.spawn(0,'dragon');game.rules.spawn(1,'wolf')
 game.rules.players[0].mana=10;game.rules.players[0].hand=['fireball']
 game.rules.players[1].health=1;game.view.prepare()
 await game.request_play(0,{'side':1,'hero':true})
 if game.panel!='result' or game.rules.outcome!='win':push_error('Victory panel did not open');failures+=1
 for node in game.view.nodes.values():
  if node.z_index>=game.overlay.z_index:push_error('Card art overlaps result');failures+=1
 if game.audio_engine.action_clip('wolf','bite')!='bite_hit' or game.audio_engine.action_clip('golem','earth')!='stone_hit' or game.audio_engine.action_clip('orc','steel')!='steel_heavy':push_error('Wrong creature sound family');failures+=1
 print('Victory layers and creature audio profiles checked')
 print('FX RESULT: ',ids.size(),' card timelines completed; ',failures,' failures')
 game.queue_free();await process_frame;quit(1 if failures else 0)
