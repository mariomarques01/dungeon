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
 game.difficulty=game.rules.DEFAULT_AI_LEVEL
 game.start_match()
 var player=game.rules.players[0]
 var rival=game.rules.players[1]
 player.hand=['scout','bolt']
 player.mana=10
 var unit=game.rules.spawn(0,'wolf')
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
 game.rival_elapsed=game.rival_interval()
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

 check_match_controls(game)

 # Run the normal battle clock from opening hand through the result and rematch.
 game.start_match()
 game.rules.start(game.profile.deck,[],42,true)
 for step in range(12000):
  game.advance_battle(0.1)
  game.view.prepare()
  if game.rules.done:break
 check(game.rules.done and game.rewarded and game.panel=='result' and game.active_actions.is_empty(),'Match did not settle')
 game.start_match()
 check(not game.rules.done and game.panel.is_empty() and game.active_actions.is_empty(),'Rematch inherited a pending action')
 game.view.prepare()
 game.queue_free()
 await process_frame
 print('Concurrent actions: %d failures'%failures)
 quit(1 if failures else 0)


func check_match_controls(game) -> void:
 for level in range(3):
  game.difficulty=level
  game.start_match()
  check(game.rules.ai_level==level and game.rival_interval()==[4.5,3.0,2.0][level],'Selected level must set rival cadence')
  var rival=game.rules.players[1]
  rival.hand=['scout']
  rival.mana=1
  game.advance_battle(game.rival_interval()-0.01)
  check(game.active_actions.is_empty(),'Rival acted before its interval')
  game.advance_battle(0.02)
  check(game.active_actions.size()==1 and game.active_actions[0].side==1,'Rival did not act at its interval')
 game.difficulty=game.rules.DEFAULT_AI_LEVEL
 game.start_match()
 game.view.prepare()
 check(game.view.buttons.any(func(b):return b.id=='pause'),'Pause control is missing')
 for i in range(game.EMOTES.size()):
  game.activate_button('emotes')
  game.view.prepare()
  check(game.view.buttons.filter(func(b):return b.id.begins_with('emote_')).size()==4,'Expected four available emotes')
  game.activate_button('emote_%d'%i)
  check(game.emote_text==game.EMOTES[i] and game.emote_time==2 and not game.emotes_open,'Emote did not display or close selector')
 var player=game.rules.players[0]
 player.hand=['scout','scout']
 player.mana=1
 player.cooldowns[1]=2.0
 game.view.prepare()
 game.request_play(0)
 game.advance_battle(0.25)
 var before=[game.active_actions[0].age,game.energy_elapsed,game.rival_elapsed,game.support_elapsed,player.cooldowns[1],game.emote_time,game.view.clock]
 game.activate_button('pause')
 game._process(7)
 game.advance_actions(7)
 game.request_play(1)
 check(game.panel=='pause' and game.view.buttons.any(func(b):return b.id=='resume'),'Pause panel did not offer resume')
 check(game.active_actions.size()==1 and player.board.is_empty() and player.mana==1,'A move resolved or was added while paused')
 check(before==[game.active_actions[0].age,game.energy_elapsed,game.rival_elapsed,game.support_elapsed,player.cooldowns[1],game.emote_time,game.view.clock],'A timer advanced while paused')
 game.activate_button('resume')
 game._process(0.30)
 check(game.panel.is_empty() and player.board.size()==1 and player.mana==0,'Resume did not continue the pending move')
 check(game.emote_time<2 and player.cooldowns[1]<before[4],'Resume did not continue the timers')
