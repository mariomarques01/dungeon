extends SceneTree

var failures=0

func check(condition: bool,message: String) -> void:
 if not condition:
  failures+=1
  push_error(message)

func _initialize() -> void:
 call_deferred('run')

func run() -> void:
 var game=load('res://scenes/tavern.tscn').instantiate()
 root.add_child(game)
 await process_frame
 game.audio_engine.set_enabled(false)
 game.start_match()
 var player=game.rules.players[0]
 var rival=game.rules.players[1]
 player.hand=['scout','bolt']
 player.mana=10
 var unit=game.rules.spawn(0,'wolf')
 unit.entry_lock=0
 rival.hand=['scout']
 rival.mana=1
 game.view.prepare()
 var enemy={'side':1,'hero':true}
 game.request_attack(unit.uid,enemy)
 game.request_play(0)
 game.request_play(0)
 game.place_support(0,0)
 game.request_attack(unit.uid,enemy)
 game.request_play(1,enemy)
 game.rival_elapsed=3
 game.advance_battle(0.01)
 check(game.active_actions.size()==3,'Expected one attack and two independent casts')
 check(rival.health==30 and player.board.size()==1 and rival.board.is_empty(),'Rules changed before impact')
 check(player.supports[0].id=='','Support consumed a casting card')
 game.advance_battle(0.38)
 check(rival.health==30-unit.attack and rival.board.is_empty() and player.board.size()==1,'Only attack should have hit')
 game.advance_battle(0.15)
 check(player.board.size()==2 and rival.board.size()==1,'Both summons should have landed')
 game.advance_battle(1)
 check(game.active_actions.is_empty(),'Finished actions retained their locks')

 # Area damage can remove an explicitly targeted creature between cast and impact.
 game.start_match()
 player=game.rules.players[0]
 player.mana=10
 player.hand=['meteor','bolt']
 var victim=game.rules.spawn(1,'wolf')
 victim.health=1
 game.view.prepare()
 game.request_play(0)
 game.advance_battle(0.1)
 game.request_play(1,{'side':1,'uid':victim.uid})
 game.advance_battle(0.53)
 check(game.rules.find_unit(1,victim.uid)==null,'Meteor should kill the target')
 check(not player.cooldowns.has(1) and game.toast_text.begins_with('Ação cancelada'),'Missing fizzle feedback or spell consumed')
 game.advance_battle(1)
 check(game.active_actions.is_empty(),'Fizzle retained a lock')

 # Run the normal battle clock from opening hand through the result and rematch.
 game.start_match()
 game.rules.start(game.profile.deck,[],42,true)
 for step in range(12000):
  game.advance_battle(0.1)
  game.view.geometry()
  if game.rules.done:break
 check(game.rules.done and game.rewarded and game.panel=='result' and game.active_actions.is_empty(),'Match did not settle')
 game.start_match()
 check(not game.rules.done and game.panel.is_empty() and game.active_actions.is_empty(),'Rematch inherited a pending action')
 game.queue_free()
 await process_frame
 print('Concurrent actions: %d failures'%failures)
 quit(1 if failures else 0)
