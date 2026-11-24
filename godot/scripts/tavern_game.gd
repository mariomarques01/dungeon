extends Control
const Rules=preload('res://scripts/tavern_rules.gd')
const View=preload('res://scripts/tavern_view.gd')
const ArenaRoom=preload("res://scripts/tavern_environment.gd")
const Audio=preload('res://scripts/combat_audio.gd')
const STORAGE='dungeon_tavern_v3'
const EMOTES=['Olá!','Boa jogada!','Obrigado!','Belo duelo!']
const PANEL_BUTTONS={'pause':['resume'],'settings':['mute','speed','motion','credits','theme','tilt','difficulty','close'],'credits':['close'],'result':['home'],'rewards':['close'],'missions':['close'],'shop':['collection','close']}
var title_font=preload('res://assets/title.ttf')
var body_font=preload('res://tavern_assets/reading.ttf')
var cards: Dictionary
var rules
var view
var audio_engine
var art_layer: Control
var overlay: Control
var screen='home'
var panel=''
var difficulty=Rules.DEFAULT_AI_LEVEL
var emotes_open=false
var emote_text=''
var emote_time=0.0
var profile={'deck':Rules.DEFAULT_DECK.duplicate(),'coins':0,'xp':0,'wins':0,'losses':0,'intro_seen':false,'support_hint_seen':false,'reduced_motion':false}
var reduced_motion=false
var arena_theme=0
var parallax_contact=false
var tilt_available=false
var tilt_enabled=false
var tilt_home=Vector2.ZERO
var tilt_value=Vector2.ZERO
var tilt_calibrated=false
var web_tilt_callback
var sound_on=true
var speed=1.0
var active_actions: Array[Dictionary]=[]
var next_action_id=0
var portrait=false
var logical_size=Vector2(1280,800)
var board_transform=Transform2D.IDENTITY
var pointer=Vector2.ZERO
var press={}
var drag={}
var selected_card=-1
var selected_attacker=-1
var hover_card=-1
var inspect_id=''
var collection_page=0
var collection_filter=0
var toast_text=''
var toast_time=0.0
var clock=0.0
var match_serial=0
var rewarded=false
var qa_enabled=false
var qa_seed=-1
var qa_sample_start=0
var qa_frames=0
var qa_frame_label=''
var previous_viewport=Vector2.ZERO
var backdrop_screen=''
var web_touch_callback
var done: bool:
 get: return rules!=null and rules.done
class TopLayer extends Control:
 var game
 func _draw() -> void:
  game.view.paint_overlay(self)

func _exit_tree() -> void:
 if OS.has_feature('web'):
  JavaScriptBridge.eval("window.dungeonClassicActive=false; window.dungeonSetTilt?.(false); delete window.dungeonTilt; delete window.dungeonSetTilt;")

func _ready() -> void:
 if OS.has_feature('web'):JavaScriptBridge.eval('window.dungeonClassicActive=true;')
 title_font.fallbacks=[preload('res://assets/symbols.ttf')]
 body_font.fallbacks=[preload('res://assets/symbols.ttf')]
 cards=JSON.parse_string(FileAccess.get_file_as_string('res://tavern_assets/cards.json'))
 rules=Rules.new(cards)
 load_profile()
 art_layer=Control.new();art_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art_layer)
 overlay=TopLayer.new();overlay.z_index=100;overlay.game=self;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(overlay)
 view=View.new(self)
 audio_engine=Audio.new(self);audio_engine.set_enabled(sound_on)
 if OS.has_feature('web'):
  install_web_touch()
  install_web_tilt()
 else:tilt_available=OS.has_feature('mobile')
 if OS.has_feature('web'): qa_enabled=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''"))=='1'
 if qa_enabled:
  var seed_text=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed') || ''"))
  if seed_text.is_valid_int():qa_seed=seed_text.to_int()
 layout_board();view.prepare();queue_redraw();overlay.queue_redraw()

func install_web_touch() -> void:
 web_touch_callback=JavaScriptBridge.create_callback(web_touch)
 JavaScriptBridge.get_interface('window').dungeonTouch=web_touch_callback
 JavaScriptBridge.eval("""
 (() => {
  const canvas=document.getElementById('canvas');
  let finger=null;
  canvas.style.touchAction='none';
  for(const type of ['touchstart','touchmove','touchend','touchcancel']) {
   canvas.addEventListener(type,event=>{
    if(!window.dungeonClassicActive)return;
    event.preventDefault();event.stopImmediatePropagation();
    if(type==='touchstart' && finger===null) finger=event.changedTouches[0].identifier;
    const touch=Array.from(event.changedTouches).find(t=>t.identifier===finger);
    if(!touch)return;
    const rect=canvas.getBoundingClientRect();
    window.dungeonTouch(type,(touch.clientX-rect.left)/rect.width,(touch.clientY-rect.top)/rect.height);
    if(type==='touchend'||type==='touchcancel')finger=null;
   },{capture:true,passive:false});
  }
 })();
 """)

func web_touch(args: Array) -> void:
 if not view or args.size()<3:return
 pointer=board_transform.affine_inverse()*(Vector2(float(args[1]),float(args[2]))*size)
 match str(args[0]):
  'touchstart':pointer_down()
  'touchmove':pointer_move()
  'touchend':pointer_up()
  'touchcancel':press={};drag={};hover_card=-1;parallax_contact=false

func install_web_tilt() -> void:
 tilt_available=str(JavaScriptBridge.eval("window.isSecureContext && typeof window.DeviceOrientationEvent !== 'undefined' && navigator.maxTouchPoints > 0 ? 'yes' : 'no'"))=='yes'
 if not tilt_available:return
 web_tilt_callback=JavaScriptBridge.create_callback(web_tilt)
 JavaScriptBridge.get_interface('window').dungeonTilt=web_tilt_callback
 JavaScriptBridge.eval("""
 (() => {
  function sample(event) {
   if (event.gamma == null || event.beta == null) return;
   const angle=(screen.orientation?.angle ?? window.orientation ?? 0)*Math.PI/180;
   const x=event.gamma/90, y=event.beta/90;
   window.dungeonTilt?.(x*Math.cos(angle)+y*Math.sin(angle),-x*Math.sin(angle)+y*Math.cos(angle));
  }
  let ticket=0;
  window.dungeonSetTilt=async enabled=>{
   const current=++ticket;
   window.removeEventListener('deviceorientation',sample);
   if (!enabled) return;
   try {
    const Device=window.DeviceOrientationEvent;
    const allowed=typeof Device.requestPermission!=='function' || await Device.requestPermission()==='granted';
    if (current!==ticket) return;
    if (allowed) window.addEventListener('deviceorientation',sample,{passive:true});
    else window.dungeonTilt?.('denied');
   } catch (_) {
    if (current===ticket) window.dungeonTilt?.('denied');
   }
  };
 })();
 """)

func web_tilt(args: Array) -> void:
 if not tilt_enabled or args.is_empty():return
 if args.size()==1:
  tilt_enabled=false
  notify('Inclinação indisponível. O parallax por toque continua ativo.')
  return
 record_tilt(Vector2(float(args[0]),float(args[1])))

func record_tilt(sample: Vector2) -> void:
 if not tilt_calibrated:
  tilt_home=sample
  tilt_calibrated=true
 tilt_value=((sample-tilt_home)*2.4).limit_length()

func toggle_tilt() -> void:
 if not tilt_available or reduced_motion:return
 tilt_enabled=not tilt_enabled
 tilt_calibrated=false
 tilt_value=Vector2.ZERO
 if OS.has_feature('web'):
  JavaScriptBridge.eval("window.dungeonSetTilt("+str(tilt_enabled)+");")

func environment_lean() -> Vector2:
 if reduced_motion or screen!='battle' or not panel.is_empty():return Vector2.ZERO
 if tilt_enabled and not OS.has_feature('web'):
  var gravity=Input.get_gravity()
  if gravity.length_squared()>0.01:record_tilt(Vector2(gravity.x,-gravity.y)/9.81)
 var touch=Vector2.ZERO
 if parallax_contact and logical_size.x>0 and logical_size.y>0:
  touch=(pointer/logical_size*2.0-Vector2.ONE).limit_length()
 return (touch*0.74+(tilt_value if tilt_enabled else Vector2.ZERO)).limit_length()

func load_profile() -> void:
 var raw=''
 if OS.has_feature('web'):
  raw=str(JavaScriptBridge.eval("localStorage.getItem('"+STORAGE+"') || ''"))
  sound_on=str(JavaScriptBridge.eval("localStorage.getItem('dungeon_sound') || 'on'"))!='off'
  var saved=str(JavaScriptBridge.eval("localStorage.getItem('dungeon_battle_speed') || '1'")).to_float()
  if saved in [1.0,1.5,2.0]:speed=saved
 elif FileAccess.file_exists('user://tavern-profile.json'):raw=FileAccess.get_file_as_string('user://tavern-profile.json')
 var data=JSON.parse_string(raw) if not raw.is_empty() else null
 if data is Dictionary:
  var saved_level=data.get('difficulty',Rules.DEFAULT_AI_LEVEL)
  if saved_level is float or saved_level is int:difficulty=clampi(int(saved_level),0,Rules.AI_LEVELS.size()-1)
  var saved_theme=data.get('arena_theme','tavern')
  for i in range(ArenaRoom.THEMES.size()):
   if saved_theme==ArenaRoom.THEMES[i].id:arena_theme=i
  reduced_motion=data.get('reduced_motion',false)==true
  profile.reduced_motion=reduced_motion
  profile.intro_seen=data.get('intro_seen',data.get('support_hint_seen',false))==true
  profile.support_hint_seen=data.get('support_hint_seen',false)==true
  if data.get('deck',null) is Array:profile.deck=rules.migrate_deck(data.deck)
  for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(data.get(key,0)))
 elif OS.has_feature('web'):
  var old=JSON.parse_string(str(JavaScriptBridge.eval("localStorage.getItem('dungeon_cards_v15') || '{}'")))
  if old is Dictionary:
   for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(old.get(key,0)))
 profile.difficulty=difficulty
 profile.arena_theme=ArenaRoom.THEMES[arena_theme].id

func save_profile() -> void:
 profile.reduced_motion=reduced_motion
 profile.difficulty=difficulty
 profile.arena_theme=ArenaRoom.THEMES[arena_theme].id
 var raw=JSON.stringify(profile)
 if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('"+STORAGE+"',"+JSON.stringify(raw)+")")
 else:
  var file=FileAccess.open('user://tavern-profile.json',FileAccess.WRITE)
  if file:file.store_string(raw)

var safe_origin=Vector2.ZERO
var safe_margin=Vector2.ZERO

func layout_board() -> void:
 if previous_viewport!=size:
  drag={};press={};hover_card=-1;selected_card=-1;selected_attacker=-1;parallax_contact=false;tilt_calibrated=false;tilt_value=Vector2.ZERO;previous_viewport=size
  queue_redraw()
  if OS.has_feature('web'):
   var raw=JavaScriptBridge.eval("JSON.stringify(['top','right','bottom','left'].map(s=>parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-'+s))||0))")
   var inset=JSON.parse_string(str(raw))
   if inset is Array:
    var ratio=size.x/maxf(1,float(JavaScriptBridge.eval("document.getElementById('canvas').getBoundingClientRect().width")))
    safe_origin=Vector2(inset[3],inset[0])*ratio
    safe_margin=Vector2(inset[1],inset[2])*ratio
 var usable=size-safe_origin-safe_margin
 portrait=usable.y>usable.x*1.05
 var height=760.0*usable.y/maxf(1,usable.x) if portrait else 800.0
 var width=760.0 if portrait else height*usable.x/maxf(1,usable.y)
 logical_size=Vector2(width,height)
 var factor=minf(usable.x/width,usable.y/height)
 board_transform=Transform2D(0,Vector2(factor,factor),0,safe_origin+(usable-logical_size*factor)/2)
 if screen=='battle' and panel.is_empty():board_transform.origin+=view.camera_offset()*factor
 art_layer.position=board_transform.origin;art_layer.scale=Vector2(factor,factor)
 overlay.position=board_transform.origin;overlay.scale=Vector2(factor,factor)

const ENERGY_SECONDS=3.0
const SUPPORT_SECONDS=12.0
var energy_elapsed=0.0
var rival_elapsed=0.0
var support_elapsed=0.0
var rival_energy=0.0

func advance_battle(delta: float) -> void:
 if screen!='battle' or rules.done or not panel.is_empty() or not inspect_id.is_empty():return
 var player=rules.players[0]
 if player.mana<player.max_mana:
  energy_elapsed+=delta
  var earned=floori(energy_elapsed/ENERGY_SECONDS)
  player.mana=mini(player.max_mana,player.mana+earned)
  energy_elapsed=fmod(energy_elapsed,ENERGY_SECONDS)
 if player.mana>=player.max_mana:energy_elapsed=0.0
 var player_ready=rules.advance_cooldowns(delta/speed)
 if player_ready and not reduced_motion:
  audio_engine.play('ui',-20,1.45,{'event':'cooldown_ready'})
 var rival=rules.players[1]
 rival_energy+=delta
 rival.mana=mini(10,rival.mana+floori(rival_energy/ENERGY_SECONDS))
 rival_energy=fmod(rival_energy,ENERGY_SECONDS)
 support_elapsed+=delta
 rival_elapsed+=delta
 advance_actions(delta)
 if rules.done:return
 if support_elapsed>=SUPPORT_SECONDS:
  support_elapsed=0
  var before=rules.players.duplicate(true)
  rules.events=[]
  for side in range(2):
   rules.resolve_supports(side)
   if rules.done:break
   if rules.players[side].hand.size()<rules.MAX_HAND:rules.draw(side)
  rules.check_end()
  view.ingest(rules.events,before);play_events(rules.events,'dark',before);check_result()
 if rival_elapsed>=rival_interval() and not rules.done:
  rival_elapsed=0
  rival_action()

func rival_interval() -> float:
 return Rules.AI_LEVELS[rules.ai_level].interval

func _process(delta: float) -> void:
 if not view:return
 var battle_delta=0.0
 if panel!='pause':
  clock+=delta;toast_time=maxf(0,toast_time-delta)
  emote_time=maxf(0,emote_time-delta)
  battle_delta=view.battle_delta(delta)
  view.tick(battle_delta)
  audio_engine.update(delta)
 layout_board()
 advance_battle(battle_delta*speed)
 if not press.is_empty() and drag.is_empty() and clock-float(press.time)>0.6 and press.kind in ['card','unit','collection']:
  inspect_id=press.id;press={};selected_card=-1
 view.prepare();overlay.queue_redraw()
 if backdrop_screen!=screen:
  backdrop_screen=screen
  queue_redraw()
 if qa_enabled:
  var now=Time.get_ticks_usec()
  if qa_sample_start==0:qa_sample_start=now
  qa_frames+=1
  var elapsed=now-qa_sample_start
  if elapsed>=500000:
   var ms=elapsed/1000.0/qa_frames
   qa_frame_label='%.0f FPS · %.1f ms' % [1000.0/ms,ms]
   qa_sample_start=now
   qa_frames=0
  var hand=[]
  for item in view.hand_views:hand.append({'index':item.index,'id':item.id,'rect':rect_json(item.rect),'angle':item.angle})
  var units=[]
  for uid in view.unit_views:
   var item=view.unit_views[uid];units.append({'uid':uid,'side':item.side,'rect':rect_json(item.rect),'unit':item.unit})
  var buttons=[]
  for item in view.buttons:buttons.append({'id':item.id,'rect':rect_json(item.rect),'enabled':item.enabled})
  var latest={} if active_actions.is_empty() else active_actions.back()
  var snap={'environment':{'theme':profile.arena_theme,'portrait':portrait,'offset':[view.room.offset.x,view.room.offset.y],'light':[view.room.room_light.r,view.room.room_light.g,view.room.room_light.b]},'difficulty':difficulty,'nextCard':rules.next_card(0) if screen=='battle' else '','emote':emote_text if emote_time>0 else '','tutorial':tutorial_visible,'screen':screen,'panel':panel,'busy':not active_actions.is_empty(),'actions':active_actions,'drag':drag,'preview':view.drag_preview(),'selected':selected_card,'logical':{'x':logical_size.x,'y':logical_size.y},'transform':{'scale':board_transform.x.x,'x':board_transform.origin.x,'y':board_transform.origin.y},'players':rules.players,'active':rules.active,'turn':rules.turn,'done':rules.done,'outcome':rules.outcome,'handViews':hand,'unitViews':units,'heroes':[rect_json(view.layout.player_hero),rect_json(view.layout.enemy_hero)],'drop':rect_json(view.layout.player_drop),'buttons':buttons,'profile':profile,'sound':sound_on,'speed':speed,'musicPlaying':audio_engine.music.playing and not audio_engine.music.stream_paused,'animation':latest,'animationTime':latest.get('age',0),'effectHistory':view.effect_history,'deathProfiles':view.ghosts.map(func(g):return {'id':g.id,'element':g.element}),'scenery':view.scenery.map(func(effect):return {'element':effect.element,'age':effect.age}),'modalRect':rect_json(view.panel_rect()),'overlayZ':overlay.z_index,'audioHistory':audio_engine.history,'toast':toast_text if toast_time>0 else '','collection':view.collection_views.map(func(item):return {'id':item.id,'rect':rect_json(item.rect),'action':rect_json(item.action),'count':item.count}),'inspect':inspect_id}
  JavaScriptBridge.eval('window.__dungeonState='+JSON.stringify(snap))

func rect_json(rect: Rect2) -> Dictionary:
 return {'x':rect.position.x,'y':rect.position.y,'w':rect.size.x,'h':rect.size.y}

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color('17121b'))
 if not view:return
 if screen=='home':view.paint_home_background(self)
 elif screen=='collection':view.paint_collection_background(self)
 elif view.room.back.texture and (safe_origin!=Vector2.ZERO or safe_margin!=Vector2.ZERO):
  draw_texture_rect(view.room.back.texture,Rect2(Vector2.ZERO,size),false)

func notify(message: String) -> void:
 toast_text=message;toast_time=2.1

func collectible_ids() -> Array:
 var ids=cards.keys().filter(func(id):return not cards[id].get('token',false) and (collection_filter==0 or cards[id].kind==['','minion','spell','trap'][collection_filter]))
 ids.sort_custom(func(a,b):return int(cards[a].cost)<int(cards[b].cost) if cards[a].cost!=cards[b].cost else cards[a].name<cards[b].name)
 return ids

func hand_at(point: Vector2) -> int:
 if hover_card>=0 and hover_card<view.hand_views.size():
  var hovered=view.hand_views[hover_card]
  if hovered.get('base_rect',hovered.rect).has_point(point):return hover_card
 for i in range(view.hand_views.size()-1,-1,-1):
  var hand=view.hand_views[i]
  var local=(point-hand.rect.get_center()).rotated(-hand.angle)
  if Rect2(-hand.rect.size/2,hand.rect.size).has_point(local) or hand.get('base_rect',hand.rect).has_point(point):return i
 return -1

func target_at(point: Vector2) -> Dictionary:
 for uid in view.unit_views:
  var item=view.unit_views[uid]
  if item.rect.grow(9).has_point(point):return {'side':item.side,'uid':uid}
 for hero in view.hero_views:
  if hero.rect.grow(8).has_point(point):return {'side':hero.side,'hero':true}
 return {}

func _input(event: InputEvent) -> void:
 if not view:return
 if event is InputEventScreenTouch:
  if event.index!=0:return
  pointer=board_transform.affine_inverse()*event.position
  if event.pressed:pointer_down()
  else:pointer_up()
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag:
  if event.index==0:pointer=board_transform.affine_inverse()*event.position;pointer_move();get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.device!=-1:
  pointer=board_transform.affine_inverse()*event.position
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:pointer_down()
   else:pointer_up()
   get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and panel.is_empty():
   if screen=='collection':
    for item in view.collection_views:
     if item.rect.has_point(pointer):inspect_id=item.id;return
   var index=hand_at(pointer)
   if index>=0:inspect_id=rules.players[0].hand[index]
   else:
    var target=target_at(pointer)
    if target.has('uid'):inspect_id=rules.find_unit(target.side,target.uid).id
 elif event is InputEventMouseMotion and event.device!=-1:
  pointer=board_transform.affine_inverse()*event.position;pointer_move()
 elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  if panel=='result':activate_button('home')
  elif panel=='pause':set_match_paused(false)
  elif screen=='battle' and panel.is_empty() and inspect_id.is_empty():set_match_paused(true)
  else:drag={};press={};selected_card=-1;selected_attacker=-1;inspect_id='';panel=''
  get_viewport().set_input_as_handled()

var pending_support = -1

func support_at(point: Vector2) -> int:
 for i in range(view.layout.supports.size()):
  if view.layout.supports[i].has_point(point):return i
 return -1

func place_support(slot: int,index: int) -> void:
 if panel=='pause':return
 pending_support=-1;selected_card=-1;selected_attacker=-1
 if card_locked(0,index):notify('Carta em ação.');return
 var result=rules.equip_support(slot,index)
 if not result.ok:notify(result.reason);return
 audio_engine.play('card_soft',-15.0)
 tutorial_visible=false
 if result.get('trap',false):
  notify('Armadilha armada. Ela será revelada ao disparar.')
  return
 if not profile.support_hint_seen:
  notify('A cada 12 s: ataque fere, defesa dá armadura. Toque para alternar.')
  toast_time=5.0
  profile.support_hint_seen=true
  save_profile()
 else:notify('Apoio equipado. Toque nele para alternar ataque e defesa.')

func pointer_down() -> void:
 parallax_contact=true
 if not inspect_id.is_empty():inspect_id='';press={};return
 for i in range(view.buttons.size()-1,-1,-1):
  var item=view.buttons[i]
  if not panel.is_empty() and item.id not in PANEL_BUTTONS[panel]:continue
  if item.rect.has_point(pointer):
   if item.enabled:
    if item.id=='power' and screen=='battle':press={'kind':'power','origin':item.rect.get_center(),'time':clock}
    else:press={'kind':'button','id':item.id,'time':clock}
   return
 if not panel.is_empty():return
 if screen=='collection':
  for item in view.collection_views:
   if item.action.has_point(pointer):
    press={'kind':'collection_remove' if item.count>0 else 'collection_add','id':item.id,'time':clock}
    return
   if item.rect.has_point(pointer):press={'kind':'collection','id':item.id,'time':clock};return
  return
 if screen!='battle' or rules.done:return
 var slot=support_at(pointer)
 if slot>=0:
  if selected_card>=0:place_support(slot,selected_card)
  elif rules.players[0].supports[slot].id!='':
   pending_support=-1
   tutorial_visible=false
   rules.players[0].supports[slot].defense=not rules.players[0].supports[slot].defense
   notify('Apoio em defesa.' if rules.players[0].supports[slot].defense else 'Apoio em ataque.')
  else:
   pending_support=slot
   notify('Escolha uma carta da mão para este apoio.')
  return
 var index=hand_at(pointer)
 if pending_support>=0 and index>=0:
  place_support(pending_support,index)
  return
 pending_support=-1
 if index>=0:
  if card_locked(0,index):notify('Carta em ação.');return
  if rules.players[0].cooldowns.has(index):notify('Carta recarregando.');return
  press={'kind':'card','index':index,'id':rules.players[0].hand[index],'origin':pointer,'time':clock};return
 var target=target_at(pointer)
 if selected_card>=0:
  var selected=selected_card;selected_card=-1
  if cards[rules.players[0].hand[selected]].kind=='minion' and view.layout.player_drop.has_point(pointer):request_play(selected,{},drop_position(pointer))
  else:request_play(selected,target)
  return
 if selected_attacker>=0 and not target.is_empty():
  var uid=selected_attacker;selected_attacker=-1;request_attack(uid,target);return
 if target.has('uid'):
  var unit=rules.find_unit(target.side,target.uid)
  if int(target.side)==0:
   if target_locked(target):notify('Criatura em ação.');return
   press={'kind':'unit','uid':unit.uid,'id':unit.id,'origin':view.target_center(target),'time':clock,'can_attack':unit.attacks>0}
  else:inspect_id=unit.id

func pointer_move() -> void:
 hover_card=hand_at(pointer) if screen=='battle' and press.is_empty() else -1
 if press.is_empty() or not drag.is_empty():return
 if press.kind in ['card','unit','power'] and pointer.distance_to(press.origin)>10:
  if press.kind=='unit' and not press.get('can_attack',true):notify('Esta criatura está recarregando.');press={};return
  drag=press.duplicate(true)
  if drag.kind=='card':audio_engine.play('card_soft',-15.0)
  selected_card=-1;selected_attacker=-1

func pointer_up() -> void:
 parallax_contact=false
 var held=press.duplicate(true);press={}
 if not drag.is_empty():
  var released=drag.duplicate(true);drag={}
  if released.kind=='card':
   var slot=support_at(pointer)
   if slot>=0:
    place_support(slot,released.index)
    return
   if cards[released.id].kind=='trap':
    notify('Arme a armadilha em uma casa dourada.')
   elif cards[released.id].kind=='minion':
    if view.layout.player_drop.has_point(pointer):request_play(int(released.index),{},drop_position(pointer),released.origin)
    else:notify('Solte a criatura no seu lado do tabuleiro.')
   else:
    var target=target_at(pointer)
    if cards[released.id].get('target','none')=='none' and not view.layout.board_zone.has_point(pointer) and target.is_empty():notify('Solte o feitiço sobre o tabuleiro.')
    else:request_play(int(released.index),target,-1,released.origin)
  elif released.kind=='unit':request_attack(int(released.uid),target_at(pointer))
  elif released.kind=='power':request_power(target_at(pointer))
  return
 if held.is_empty():return
 match held.kind:
  'button':activate_button(held.id)
  'collection','collection_add':cycle_card(held.id)
  'collection_remove':
   if held.id in profile.deck:profile.deck.erase(held.id);save_profile()
  'card':selected_attacker=-1;selected_card=int(held.index);notify('Arraste para jogar, ou toque no campo/alvo.')
  'unit':
   if held.get('can_attack',true):selected_attacker=int(held.uid);notify('Arraste esta criatura até um inimigo.')
   else:inspect_id=held.id
  'power':notify('Arraste o poder até um inimigo. Custa 2 de energia.')

func drop_position(point: Vector2) -> int:
 var board: Array=rules.players[0].board
 for i in range(board.size()):
  if point.x<view.unit_views[int(board[i].uid)].rect.get_center().x:return i
 return board.size()

func set_match_paused(paused: bool) -> void:
 if screen!='battle' or rules.done:return
 if (paused and not panel.is_empty()) or (not paused and panel!='pause'):return
 panel='pause' if paused else ''
 drag={};press={};hover_card=-1;selected_card=-1;selected_attacker=-1;pending_support=-1;inspect_id=''
 emotes_open=false
 art_layer.process_mode=Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
 view.set_match_paused(paused)
 audio_engine.set_match_paused(paused)

func activate_button(id: String) -> void:
 if not panel.is_empty() and id not in PANEL_BUTTONS[panel]:return
 if id.begins_with('emote_'):
  var choice=id.trim_prefix('emote_')
  if not choice.is_valid_int():return
  var index=choice.to_int()
  if screen=='battle' and emotes_open and index>=0 and index<EMOTES.size():
   emote_text=EMOTES[index]
   emote_time=2.0
   emotes_open=false
  return
 match id:
  'pause':set_match_paused(true)
  'resume':set_match_paused(false)
  'emotes':
   if screen=='battle' and not rules.done:emotes_open=not emotes_open
  'difficulty':
   if screen=='home':
    difficulty=(difficulty+1)%Rules.AI_LEVELS.size()
    save_profile()
  'help':tutorial_visible=not tutorial_visible
  'exchange':
   if screen!='battle' or not panel.is_empty():return
   if card_locked(0,selected_card):notify('Carta em ação.');return
   var result=rules.exchange_card(0,selected_card)
   if not result.ok:notify(result.reason);return
   tutorial_visible=false
   selected_card=-1;hover_card=-1
   audio_engine.play('card_soft',-15.0)
   notify('Nova carta: '+str(cards[result.id].name))
  'solar':request_solar()
  'start':start_match()
  'collection':screen='collection';panel='';collection_page=0;selected_card=-1
  'home':screen='home';panel='';inspect_id='';match_serial+=1;active_actions.clear();audio_engine.stop_music()
  'settings':panel='settings'
  'rewards','missions','shop':
   if screen=='home':panel=id
  'close':panel=''
  'theme':
   arena_theme=(arena_theme+1)%ArenaRoom.THEMES.size()
   view.room.configure(logical_size,arena_theme,portrait,screen=='battle')
   queue_redraw()
   save_profile()
  'tilt':toggle_tilt()
  'credits':panel='credits'
  'motion':
   reduced_motion=not reduced_motion
   view.stop_motion()
   for number in view.floats:view.animate_number(number)
   save_profile()
  'mute':
   sound_on=not sound_on;audio_engine.set_enabled(sound_on)
   if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('dungeon_sound','"+('on' if sound_on else 'off')+"')")
  'speed':
   speed=1.5 if speed==1.0 else 2.0 if speed==1.5 else 1.0
   view.update_burst_speed()
   if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('dungeon_battle_speed','"+str(speed)+"')")
  'previous':collection_page=maxi(0,collection_page-1)
  'next':collection_page+=1
  'filter':collection_filter=(collection_filter+1)%4;collection_page=0
  'reset_deck':profile.deck=Rules.DEFAULT_DECK.duplicate();save_profile();notify('Baralho inicial restaurado.')

func cycle_card(id: String) -> void:
 var maximum=1 if cards[id].get('legendary',false) else 2
 if profile.deck.count(id)>=maximum:notify('Você já tem o máximo de cópias desta carta.');return
 if profile.deck.size()>=30:notify('Toque em REMOVER abaixo de uma carta para abrir espaço.');return
 profile.deck.append(id)
 save_profile()

var tutorial_visible=false

func start_match() -> void:
 if not rules.valid_deck(profile.deck):notify('Monte um baralho de 30 cartas antes de duelar.');return
 match_serial+=1;screen='battle';panel='';active_actions.clear();rewarded=false;selected_card=-1;selected_attacker=-1;drag={};press={};inspect_id=''
 pending_support=-1
 emotes_open=false;emote_text='';emote_time=0.0
 art_layer.process_mode=Node.PROCESS_MODE_INHERIT
 audio_engine.set_match_paused(false)
 energy_elapsed=0.0; rival_elapsed=0.0;support_elapsed=0.0;rival_energy=0.0
 rules.ai_level=difficulty
 rules.start(profile.deck,rules.rival_deck(),qa_seed,true)
 view.reset_effects();view.scenery=[]
 audio_engine.start_music();toast_time=0
 tutorial_visible=not profile.intro_seen
 if tutorial_visible:
  profile.intro_seen=true
  save_profile()

func card_locked(side: int,index: int) -> bool:
 return active_actions.any(func(a):return a.side==side and a.get('index',-1)==index and index>=0)

func target_locked(target: Dictionary) -> bool:
 if target.is_empty():return false
 for action in active_actions:
  if action.target==target:return true
  if target.has('uid') and action.get('uid',-1)==target.uid:return true
 return false

func power_locked(side: int,id: String) -> bool:
 return active_actions.any(func(a):return a.side==side and a.id==id and a.kind=='power')

func schedule(action: Dictionary,impact: float,duration: float) -> void:
 if action.side==0:tutorial_visible=false
 action.sequence=next_action_id
 next_action_id+=1
 action.age=0.0
 action.impact=impact
 action.duration=duration
 action.resolved=false
 if cards.has(action.id):action.fx=Rules.effect_style(cards[action.id])
 active_actions.append(action)
 view.begin(action)
 if action.kind!='attack':audio_engine.charge(action.element)

func advance_actions(delta: float) -> void:
 if panel=='pause':return
 var impacts=[]
 for action in active_actions:
  action.age+=delta
  if not action.resolved and action.age>=action.impact:impacts.append(action)
 impacts.sort_custom(func(a,b):
  var first=a.impact-a.age
  var second=b.impact-b.age
  return a.sequence<b.sequence if is_equal_approx(first,second) else first<second)
 for action in impacts:
  resolve_action(action)
  if rules.done:
   check_result()
   return
 active_actions=active_actions.filter(func(a):return a.age<a.duration)

func resolve_action(action: Dictionary) -> void:
 action.resolved=true
 var before=rules.players.duplicate(true)
 var result: Dictionary
 match action.kind:
  'attack':result=rules.attack(action.side,action.uid,action.target)
  'card':result=rules.play(action.side,action.index,action.target,action.position)
  'power':
   if action.id=='solar':
    result=rules.solar_flare()
    if result.ok:energy_elapsed=0.0
   else:result=rules.power(action.side,action.target)
 if not result.ok:
  notify('Ação cancelada: '+str(result.reason))
  action.duration=action.age
  return
 action.impact_points=[]
 for event in result.events:
  if event.kind=='damage':action.impact_points.append(view.target_center(event.target))
 view.ingest(result.events,before,action)
 play_events(result.events,action.element,before,action)
 if action.side==1 and not rules.done:rules.choose_rival_support(card_locked)

func request_play(index: int,target: Dictionary={},position = -1,origin=Vector2.ZERO,side=0) -> void:
 if rules.done or panel=='pause':return
 var valid=rules.can_play(side,index,target)
 if not valid.ok:notify(valid.reason);return
 if cards[rules.players[side].hand[index]].get('target','none')=='none':target={}
 if card_locked(side,index) or target_locked(target):notify('Carta ou alvo em ação.');return
 if side==0:selected_card=-1;selected_attacker=-1
 var id=rules.players[side].hand[index];var card=cards[id]
 var from=origin
 if from==Vector2.ZERO:from=view.hand_views[index].rect.get_center() if side==0 and index<view.hand_views.size() else view.layout.enemy_hero.get_center()
 var destination=view.target_center(target) if not target.is_empty() else Vector2(logical_size.x/2,view.layout.player_row if side==0 else view.layout.enemy_row)
 schedule({'kind':'card','side':side,'id':id,'index':index,'position':position,'origin':from,'destination':destination,'target':target,'element':card.element,'card_kind':card.kind},0.52,1.3 if card.kind=='spell' else 1.15)

func request_attack(uid: int,target: Dictionary,side=0) -> void:
 if rules.done or panel=='pause':return
 var valid=rules.can_attack(side,uid,target)
 if not valid.ok:notify(valid.reason);return
 if target_locked({'side':side,'uid':uid}) or target_locked(target):notify('Criatura ou alvo em ação.');return
 if side==0:selected_attacker=-1
 var attacker=rules.find_unit(side,uid)
 var element=cards[attacker.id].element
 var destination=view.target_center(target)
 schedule({'kind':'attack','id':attacker.id,'uid':uid,'side':side,'target':target,'origin':view.target_center({'side':side,'uid':uid}),'destination':destination,'element':element},0.38,0.85)

func request_solar() -> void:
 if screen!='battle' or not panel.is_empty() or not inspect_id.is_empty() or not rules.solar_ready():return
 if target_locked({'side':1,'hero':true}):notify('Alvo em ação.');return
 selected_card=-1;selected_attacker=-1;pending_support=-1
 var target={'side':1,'hero':true}
 schedule({'kind':'power','side':0,'id':'solar','card_kind':'spell','element':'fire','origin':view.layout.player_hero.get_center(),'destination':view.target_center(target),'target':target},0.52,1.12)

func request_power(target: Dictionary,side=0) -> void:
 if rules.done or panel=='pause':return
 var valid=rules.can_power(side,target)
 if not valid.ok:notify(valid.reason);return
 var id='power' if side==0 else Rules.RIVAL_POWER_CARD
 if power_locked(side,id) or target_locked(target):notify('Poder ou alvo em ação.');return
 var destination=view.target_center(target) if side==0 else Vector2(logical_size.x/2,view.layout.enemy_row)
 schedule({'kind':'power','side':side,'id':id,'card_kind':'spell' if side==0 else 'minion','element':'fire' if side==0 else cards[id].element,'origin':view.layout.power.get_center() if side==0 else view.layout.enemy_hero.get_center(),'destination':destination,'target':target},0.5,0.95)

func vibrate(pattern: Variant) -> void:
 if reduced_motion or not OS.has_feature('web'):return
 JavaScriptBridge.eval("if (typeof navigator.vibrate === 'function') navigator.vibrate("+JSON.stringify(pattern)+");")

func play_events(events: Array,element: String,before: Array=[],action: Dictionary={}) -> void:
 var damage_peak=0
 var summoned=false
 var played={}
 var causes={}
 var action_fx: String=action.get('fx',element)
 for event in events:
  var kind=str(event.kind);var sound='';var gain=-11.0
  var source=str(action.get('id',''))
  var event_element=str(event.get('fx',event.get('element',action_fx)))
  if kind=='damage':
   damage_peak=maxi(damage_peak,int(event.amount))
   if event.target.has('uid'):causes[int(event.target.uid)]=event_element
   if action.get('kind','')=='attack' and event.target.side==action.get('side',0) and not before.is_empty():
    var defender=action.get('target',{})
    for unit in before[int(defender.get('side',1))].board:
     if unit.uid==defender.get('uid',-1):source=unit.id;break
   sound=audio_engine.action_clip(source,event_element)
  elif kind=='trap_reveal':sound='card_soft';gain=-10
  elif kind=='shield_break':sound='ward_break';gain=-10
  elif kind in ['armor','blocked']:sound='armor';gain=-12
  elif kind=='heal':sound='heal';gain=-13
  elif kind=='buff':sound='steel_light' if source=='rune_blade' else 'heal';gain=-13
  elif kind=='freeze':sound='freeze';gain=-12
  elif kind=='death':
   event_element=str(causes.get(int(event.uid),action_fx))
   source=str(event.id)
   if event_element=='ice':sound='ward_break'
   elif event_element in ['fire','dark','arcane','storm','lightning']:sound=audio_engine.clip_for(event_element)
   elif source in ['golem','stoneguard','treant','beetle']:sound=audio_engine.action_clip(source,Rules.effect_style(cards[source]))
   else:sound='death_soft'
   gain=-16
  elif kind=='summon':
   summoned=true
   if not played.has('summon'):audio_engine.summon_card(event.id,Rules.effect_style(cards[event.id]));played.summon=true
  elif kind in ['mana','draw','debuff','destroy']:sound=audio_engine.clip_for(event_element);gain=-16
  if not sound.is_empty() and not played.has(sound):
   audio_engine.play(sound,gain,1.0,{'card':source,'event':kind,'element':event_element});played[sound]=true

 if rules.done and rules.outcome=='win':return
 if damage_peak>0:
  var duration=clampi(12+damage_peak*4,16,45)
  vibrate([20,30,duration] if summoned else duration)
 elif summoned:vibrate(20)

func rival_action() -> void:
 var plan=rules.ai_attack(target_locked)
 if not plan.is_empty():
  request_attack(plan.uid,plan.target,1)
  return
 plan=rules.ai_play(target_locked,card_locked)
 if not plan.is_empty():
  request_play(plan.index,plan.target,-1,Vector2.ZERO,1)
 elif rules.can_power(1).ok:request_power({},1)
 else:rules.choose_rival_support(card_locked)

func check_result() -> void:
 if not rules.done:return
 if not rewarded:
  rewarded=true
  profile.coins+=50 if rules.outcome=='win' else 10 if rules.outcome=='draw' else 5
  profile.xp+=35 if rules.outcome=='win' else 12 if rules.outcome=='draw' else 8
  if rules.outcome=='win':
   profile.wins+=1
   vibrate([45,45,85])
  if rules.outcome=='lose':profile.losses+=1
  save_profile()
 panel='result';active_actions.clear();selected_card=-1;selected_attacker=-1;drag={};press={};inspect_id='';view.pointer_trail=[];view.result_time=0;audio_engine.finish_music()
