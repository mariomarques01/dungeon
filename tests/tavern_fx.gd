extends SceneTree

class HapticTavern extends "res://scripts/tavern_game.gd":
 var patterns=[]
 func vibrate(pattern: Variant) -> void:
  patterns.append(pattern)

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
  var card=game.cards[spell]
  if remains.is_empty() or remains[0].element!=card.element or remains[0].fx!=card.get('fx',card.element):
   push_error('Wrong death element or visual style: '+spell);failures+=1
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
 if not is_equal_approx(game.view.battle_delta(0.04),0.04):
  push_error('Light hits must not trigger hit-stop, even when their number is combined');failures+=1
 check_hit_feedback(game)
 game.start_match()
 game.view.ingest([hit],game.rules.players.duplicate(true))
 var sprite=game.view.floats[0].sprite
 game.view.tick(2)
 game.view.ingest([hit],game.rules.players.duplicate(true))
 if game.view.floats[0].sprite!=sprite:push_error('Floating number was not reused');failures+=1
 game.activate_button('motion')
 hit.amount=9
 game.view.ingest([hit],game.rules.players.duplicate(true))
 if game.view.battle_delta(0.02)!=0.02 or game.view.camera_offset()!=Vector2.ZERO:
  push_error('Reduced motion still triggers hit-stop or shake');failures+=1
 game.activate_button('motion')
 game.start_match()
 if not game.view.banners.is_empty() or game.view.first_blood:
  push_error('Rematch inherited event banners');failures+=1
 check_haptic_routes()
 check_status_feedback(game)
 check_environment(game)
 if game.view.element_hint('wind')!='Vento  ▲ Água  ▼ Terra' or game.view.element_color('water')==game.view.element_color('wind'):
  push_error('Inspect must show the canonical element, matchup names and color');failures+=1
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
 game.view.prepare()
 game.request_play(0)
 game.advance_actions(0.53)
 var unit=game.rules.players[0].board[-1]
 var hero={'side':1,'hero':true}
 game.request_attack(unit.uid,hero)
 if game.active_actions.size()!=2 or unit.delay!=0:
  push_error('Summon must schedule an immediate hero attack without starting cooldown before impact');failures+=1
 game.advance_actions(0.39)
 if game.rules.players[1].health!=30-unit.attack or unit.delay!=game.rules.REUSE_SECONDS or game.view.effect_history[-1].kind!='attack':
  push_error('Immediate hero attack must deal damage and start cooldown at impact');failures+=1


func check_hit_feedback(game) -> void:
 game.start_match()
 var attacker=game.rules.spawn(0,'golem')
 var unit=game.rules.spawn(1,'dragon')
 var target={'side':1,'uid':unit.uid}
 game.view.prepare()
 var attacker_width: float=game.view.unit_views[attacker.uid].draw_rect.size.x
 var target_height: float=game.view.unit_views[unit.uid].draw_rect.size.y
 game.request_attack(attacker.uid,target)
 game.advance_actions(0.06)
 game.view.prepare()
 if game.view.unit_views[attacker.uid].draw_rect.size.x<=attacker_width:
  push_error('Attack anticipation must squash the sprite');failures+=1
 game.advance_actions(0.25)
 game.view.prepare()
 if game.view.unit_views[attacker.uid].draw_rect.size.x>=attacker_width:
  push_error('Attack lunge must stretch the sprite');failures+=1
 var before=game.rules.players.duplicate(true)
 var hit={'kind':'damage','amount':5,'element':'steel','target':target}
 game.view.ingest([hit],before)
 game.view.prepare()
 var portrait: TextureRect=game.view.nodes['unit'+str(unit.uid)]
 var label: Label=game.view.floats[0].sprite
 if portrait.material.get_shader_parameter('effect')!=game.view.UNIT_FLASH or game.view.unit_views[unit.uid].draw_rect.size.y>=target_height:
  push_error('A hit must flash white and compress the target');failures+=1
 if label.get_theme_font_size('font_size')!=42 or label.get_theme_color('font_color')!=Color('ff936a'):
  push_error('Heavy damage must use the larger orange number');failures+=1
 if not is_equal_approx(game.view.freeze_left,0.06) or not is_zero_approx(game.view.battle_delta(0.06)):
  push_error('Heavy hits must freeze the battle for 60 ms');failures+=1
 hit.amount=8
 game.view.ingest([hit],before)
 if not is_equal_approx(game.view.freeze_left,0.09) or not is_equal_approx(game.view.battle_delta(0.10),0.01):
  push_error('Critical hits must freeze the battle for at most 90 ms');failures+=1
 if label.get_theme_font_size('font_size')!=51 or label.get_theme_color('font_color')!=Color('ffd369'):
  push_error('Critical damage must use the larger gold number');failures+=1
 game.view.tick(0.08)
 game.view.prepare()
 if portrait.material.get_shader_parameter('effect')!=game.view.UNIT_NORMAL:
  push_error('The hit sprite must release its white material');failures+=1
 game.reduced_motion=true
 game.view.ingest([hit],before)
 game.view.prepare()
 if portrait.material.get_shader_parameter('effect')!=game.view.UNIT_NORMAL or not is_zero_approx(game.view.freeze_left):
  push_error('Reduced motion must suppress the flash and hit-stop');failures+=1
 game.reduced_motion=false


func check_haptic_routes() -> void:
 var game=HapticTavern.new()
 game.size=Vector2(1280,800)
 root.add_child(game)
 game.audio_engine.set_enabled(false)
 game.start_match()
 var hit={'kind':'damage','amount':6,'element':'steel','target':{'side':1,'hero':true}}
 var summon={'kind':'summon','id':'scout'}
 game.play_events([summon],'steel')
 game.play_events([hit],'steel')
 game.play_events([hit,summon],'steel')
 game.rules.players[1].health=0
 game.rules.check_end()
 game.play_events([hit],'steel')
 game.check_result()
 game.check_result()
 if game.patterns!=[20,36,[20,30,36],[45,45,85]]:
  push_error('Haptics must distinguish summon, damage and victory without duplicate pulses');failures+=1
 game.queue_free()


func check_status_feedback(game) -> void:
 game.start_match()
 game.reduced_motion=false
 var attacker=game.rules.spawn(0,'phoenix')
 var guard=game.rules.spawn(1,'knight')
 var poisonous=game.rules.spawn(1,'serpent')
 var target={'side':1,'uid':guard.uid}
 var hero={'side':1,'hero':true}
 var selection={'kind':'unit','uid':attacker.uid}
 game.view.prepare()
 if game.view.taunt_pull_target(selection,hero)!=target or not game.view.taunt_pull_target(selection,target).is_empty():
  push_error('Taunt preview must point only a blocked attack toward a legal guard');failures+=1
 if game.view.fx.unit_statuses(guard)!=[&"shield",&"taunt"] or game.view.fx.unit_statuses(poisonous)!=[&"poison"]:
  push_error('Unit badges must reflect active battle statuses');failures+=1
 game.rules.players[0].health=20
 var before=game.rules.players.duplicate(true)
 game.rules.attack(0,attacker.uid,target)
 game.view.ingest(game.rules.events,before)
 if game.rules.players[0].health!=20 or game.rules.events.any(func(e):return e.has('drained_from')):
  push_error('A shielded attack must not create a life drain');failures+=1
 var cracks=game.view.particles.filter(func(p):return p.kind=='shield_break')
 if cracks.size()!=1 or cracks[0].bubble_radius.x<=0 or game.view.fx.unit_statuses(guard)!=[&"taunt"]:
  push_error('Shield break must preserve the bubble shape and remove the persistent badge');failures+=1
 game.rules.advance_cooldowns(game.rules.REUSE_SECONDS)
 game.rules.events=[]
 game.rules.freeze_unit(1,guard.uid)
 game.view.ingest(game.rules.events,game.rules.players.duplicate(true))
 game.view.prepare()
 var portrait: TextureRect=game.view.nodes['unit'+str(guard.uid)]
 var initial_growth: float=game.view.unit_views[guard.uid].ice_growth
 game.view.tick(0.12)
 game.view.prepare()
 if portrait.material.get_shader_parameter('effect')!=game.view.UNIT_FROZEN or initial_growth>=game.view.unit_views[guard.uid].ice_growth:
  push_error('Frozen creature must grow ice and use the desaturated sprite');failures+=1
 game.reduced_motion=true
 if game.view.fx.unit_statuses(guard)!=[&"taunt",&"frozen"] or game.view.fx.unit_statuses(attacker)!=[&"lifesteal"]:
  push_error('Frozen and lifesteal badges must persist with reduced motion');failures+=1
 game.reduced_motion=false
 game.rules.advance_cooldowns(game.rules.REUSE_SECONDS)
 game.view.prepare()
 if portrait.material.get_shader_parameter('effect')!=game.view.UNIT_NORMAL or &"frozen" in game.view.fx.unit_statuses(guard):
  push_error('Thaw must remove the status and restore the portrait');failures+=1
 before=game.rules.players.duplicate(true)
 game.rules.attack(0,attacker.uid,target)
 game.view.ingest(game.rules.events,before)
 var drains=game.view.particles.filter(func(p):return p.has('drain_origin'))
 if drains.size()!=1 or drains[0].drain_origin!=game.view.target_center(target) or game.rules.players[0].health<=20:
  push_error('Life thread must connect the drained target to the hero when health is restored');failures+=1
 # A defender's life steal must drain the attacker, using the defending hero.
 game.start_match()
 var rival=game.rules.spawn(1,'phoenix')
 var challenger=game.rules.spawn(0,'golem')
 game.rules.players[1].health=20
 game.view.prepare()
 game.rules.attack(0,challenger.uid,{'side':1,'uid':rival.uid})
 var restored=game.rules.events.filter(func(e):return e.kind=='heal' and e.has('drained_from'))
 if restored.size()!=1 or restored[0].target.side!=1 or restored[0].drained_from.uid!=challenger.uid:
  push_error('Retaliation must send life steal to the defending hero');failures+=1


func check_environment(game) -> void:
 game.start_match()
 game.reduced_motion=false
 var room=game.view.room
 var textures={}
 for theme in range(room.THEMES.size()):
  for is_portrait in [false,true]:
   var size=Vector2(760,1350) if is_portrait else Vector2(1280,800)
   room.configure(size,theme,is_portrait,true)
   textures[room.back.texture.resource_path]=true
   if room.middle.position!=size/2 or (room.back.texture.get_width()<room.back.texture.get_height())!=is_portrait:
    push_error('Theme must use orientation-specific art with a fixed playing surface');failures+=1
 if textures.size()!=6 or room.lights.size()!=2 or room.smoke.size()!=2:
  push_error('Expected six theme variants and two torches with light and smoke');failures+=1
 game.view.prepare()
 game.parallax_contact=true
 game.pointer=game.logical_size*Vector2(0.8,0.5)
 game.view.tick(0.2)
 if room.offset.x<=0 or room.back.position.x>=room.middle.position.x or room.front.position.x<=room.middle.position.x:
  push_error('Touch must shift scenery layers without moving the board');failures+=1
 game.parallax_contact=false
 game.view.begin({'kind':'card','card_kind':'spell','element':'fire'})
 game.view.tick(0.12)
 if room.room_light.r<=1 or not room.motes.emitting or not room.smoke[0].emitting:
  push_error('A fire cast must brighten the scenery while ambient emitters are active');failures+=1
 game.view.begin({'kind':'card','card_kind':'spell','element':'earth'})
 game.view.tick(0.2)
 if room.room_light.r>=1:
  push_error('An earth cast must dim the scenery');failures+=1
 game.reduced_motion=true
 game.view.tick(0.01)
 if room.offset!=Vector2.ZERO or room.room_light!=Color.WHITE or room.motes.emitting or room.smoke[0].emitting:
  push_error('Reduced motion must neutralize scenery motion and flashes');failures+=1
 game.reduced_motion=false
