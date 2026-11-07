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
 print('FX RESULT: ',ids.size(),' card timelines completed; ',failures,' failures')
 game.queue_free();await process_frame;quit(1 if failures else 0)
