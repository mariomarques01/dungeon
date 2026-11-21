extends Control
const Rules=preload('res://scripts/tavern_rules.gd')
const View=preload('res://scripts/tavern_view.gd')
const Audio=preload('res://scripts/combat_audio.gd')
const STORAGE='dungeon_tavern_v3'
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
var profile={'deck':Rules.DEFAULT_DECK.duplicate(),'coins':0,'xp':0,'wins':0,'losses':0,'intro_seen':false,'support_hint_seen':false,'reduced_motion':false}
var reduced_motion=false
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
var web_touch_callback
var done: bool:
 get: return rules!=null and rules.done
class TopLayer extends Control:
 var game
 func _draw() -> void:
  game.view.paint_overlay(self)

func _exit_tree() -> void:
 if OS.has_feature('web'):JavaScriptBridge.eval('window.dungeonClassicActive=false;')

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
 if OS.has_feature('web'): install_web_touch()
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
  'touchcancel':press={};drag={};hover_card=-1

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
  reduced_motion=data.get('reduced_motion',false)==true
  profile.reduced_motion=reduced_motion
  profile.intro_seen=data.get('intro_seen',data.get('support_hint_seen',false))==true
  profile.support_hint_seen=data.get('support_hint_seen',false)==true
  if data.get('deck',null) is Array and data.deck.all(func(id): return cards.has(id) and not cards[id].get('token',false)):profile.deck=data.deck
  for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(data.get(key,0)))
 elif OS.has_feature('web'):
  var old=JSON.parse_string(str(JavaScriptBridge.eval("localStorage.getItem('dungeon_cards_v15') || '{}'")))
  if old is Dictionary:
   for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(old.get(key,0)))

func save_profile() -> void:
 profile.reduced_motion=reduced_motion
 var raw=JSON.stringify(profile)
 if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('"+STORAGE+"',"+JSON.stringify(raw)+")")
 else:
  var file=FileAccess.open('user://tavern-profile.json',FileAccess.WRITE)
  if file:file.store_string(raw)

var safe_origin=Vector2.ZERO
var safe_margin=Vector2.ZERO

func layout_board() -> void:
 if previous_viewport!=size:
  drag={};press={};hover_card=-1;selected_card=-1;selected_attacker=-1;previous_viewport=size
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
const RIVAL_SECONDS=12.0
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
 rules.advance_cooldowns(delta/speed)
 var rival=rules.players[1]
 rival_energy+=delta
 rival.mana=mini(10,rival.mana+floori(rival_energy/ENERGY_SECONDS))
 rival_energy=fmod(rival_energy,ENERGY_SECONDS)
 support_elapsed+=delta
 rival_elapsed+=delta
 advance_actions(delta)
 if rules.done:return
 if support_elapsed>=RIVAL_SECONDS:
  support_elapsed=0
  var before=rules.players.duplicate(true)
  rules.events=[]
  for side in range(2):
   rules.resolve_supports(side)
   if rules.done:break
   if rules.players[side].hand.size()<rules.MAX_HAND:rules.draw(side)
  rules.check_end()
  view.ingest(rules.events,before);play_events(rules.events,'dark',before);check_result()
 if rival_elapsed>=3.0 and not rules.done:
  rival_elapsed=0
  rival_action()

func _process(delta: float) -> void:
 if not view:return
 clock+=delta;toast_time=maxf(0,toast_time-delta)
 var battle_delta=view.battle_delta(delta)
 view.tick(battle_delta)
 layout_board()
 audio_engine.update(delta)
 advance_battle(battle_delta*speed)
 if not press.is_empty() and drag.is_empty() and clock-float(press.time)>0.6 and press.kind in ['card','unit','collection']:
  inspect_id=press.id;press={};selected_card=-1
 view.prepare();queue_redraw();overlay.queue_redraw()
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
  var snap={'tutorial':tutorial_visible,'screen':screen,'panel':panel,'busy':not active_actions.is_empty(),'actions':active_actions,'drag':drag,'preview':view.drag_preview(),'selected':selected_card,'logical':{'x':logical_size.x,'y':logical_size.y},'transform':{'scale':board_transform.x.x,'x':board_transform.origin.x,'y':board_transform.origin.y},'players':rules.players,'active':rules.active,'turn':rules.turn,'done':rules.done,'outcome':rules.outcome,'handViews':hand,'unitViews':units,'heroes':[rect_json(view.layout.player_hero),rect_json(view.layout.enemy_hero)],'drop':rect_json(view.layout.player_drop),'buttons':buttons,'profile':profile,'sound':sound_on,'speed':speed,'musicPlaying':audio_engine.music.playing and not audio_engine.music.stream_paused,'animation':latest,'animationTime':latest.get('age',0),'effectHistory':view.effect_history,'deathProfiles':view.ghosts.map(func(g):return {'id':g.id,'element':g.element}),'scenery':view.scenery.map(func(effect):return {'element':effect.element,'age':effect.age}),'modalRect':rect_json(view.panel_rect()),'overlayZ':overlay.z_index,'audioHistory':audio_engine.history,'toast':toast_text if toast_time>0 else '','collection':view.collection_views.map(func(item):return {'id':item.id,'rect':rect_json(item.rect)}),'inspect':inspect_id}
  JavaScriptBridge.eval('window.__dungeonState='+JSON.stringify(snap))

func rect_json(rect: Rect2) -> Dictionary:
 return {'x':rect.position.x,'y':rect.position.y,'w':rect.size.x,'h':rect.size.y}

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color('17121b'))
 if view:
  if screen=='battle' and (safe_origin!=Vector2.ZERO or safe_margin!=Vector2.ZERO):draw_texture_rect(view.ROYAL_ARENA,Rect2(Vector2.ZERO,size),false)
  draw_set_transform_matrix(board_transform);view.paint_base(self);draw_set_transform_matrix(Transform2D.IDENTITY)

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
  elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
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
 elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  if panel=='result':activate_button('home');return
  drag={};press={};selected_card=-1;selected_attacker=-1;inspect_id='';panel=''

var pending_support = -1

func support_at(point: Vector2) -> int:
 for i in range(view.layout.supports.size()):
  if view.layout.supports[i].has_point(point):return i
 return -1

func place_support(slot: int,index: int) -> void:
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
 if not inspect_id.is_empty():inspect_id='';press={};return
 for i in range(view.buttons.size()-1,-1,-1):
  var item=view.buttons[i]
  if not panel.is_empty() and item.id not in ['mute','speed','motion','credits','close','home']:continue
  if item.rect.has_point(pointer):
   if item.enabled:
    if item.id=='power' and screen=='battle':press={'kind':'power','origin':item.rect.get_center(),'time':clock}
    else:press={'kind':'button','id':item.id,'time':clock}
   return
 if not panel.is_empty():return
 if screen=='collection':
  for item in view.collection_views:
   if Rect2(item.rect.position+Vector2(0,item.rect.size.y+2),Vector2(item.rect.size.x,32)).has_point(pointer):press={'kind':'collection_remove','id':item.id,'time':clock};return
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
  'collection':cycle_card(held.id)
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

func activate_button(id: String) -> void:
 match id:
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
  'collection':screen='collection';collection_page=0;selected_card=-1
  'home':screen='home';panel='';inspect_id='';match_serial+=1;active_actions.clear();audio_engine.stop_music()
  'settings':panel='settings'
  'close':panel=''
  'credits':panel='credits'
  'motion':
   reduced_motion=not reduced_motion
   view.stop_motion()
   save_profile()
  'mute':
   sound_on=not sound_on;audio_engine.set_enabled(sound_on)
   if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('dungeon_sound','"+('on' if sound_on else 'off')+"')")
  'speed':
   speed=1.5 if speed==1.0 else 2.0 if speed==1.5 else 1.0
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
 energy_elapsed=0.0; rival_elapsed=0.0;support_elapsed=0.0;rival_energy=0.0
 rules.start(profile.deck,[],qa_seed,true)
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
 active_actions.append(action)
 view.begin(action)
 if action.kind!='attack':audio_engine.charge(action.element)

func advance_actions(delta: float) -> void:
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
 if rules.done:return
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
 if rules.done:return
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
 if rules.done:return
 var valid=rules.can_power(side,target)
 if not valid.ok:notify(valid.reason);return
 if power_locked(side,'power' if side==0 else 'token_guard') or target_locked(target):notify('Poder ou alvo em ação.');return
 var destination=view.target_center(target) if side==0 else Vector2(logical_size.x/2,view.layout.enemy_row)
 schedule({'kind':'power','side':side,'id':'power' if side==0 else 'token_guard','card_kind':'spell' if side==0 else 'minion','element':'fire' if side==0 else 'steel','origin':view.layout.power.get_center() if side==0 else view.layout.enemy_hero.get_center(),'destination':destination,'target':target},0.5,0.95)

func play_events(events: Array,element: String,before: Array=[],action: Dictionary={}) -> void:
 var played={}
 var causes={}
 for event in events:
  var kind=str(event.kind);var sound='';var gain=-11.0
  var source=str(action.get('id',''))
  var event_element=str(event.get('element',element))
  if kind=='damage':
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
   event_element=str(causes.get(int(event.uid),element))
   source=str(event.id)
   if event_element=='ice':sound='ward_break'
   elif event_element in ['fire','dark','arcane','storm','lightning']:sound=audio_engine.clip_for(event_element)
   elif source in ['golem','stoneguard','treant','beetle']:sound=audio_engine.action_clip(source,str(cards[source].element))
   else:sound='death_soft'
   gain=-16
  elif kind=='summon':
   if not played.has('summon'):audio_engine.summon_card(event.id,cards[event.id].element);played.summon=true
  elif kind in ['mana','draw','debuff','destroy']:sound=audio_engine.clip_for(event_element);gain=-16
  if not sound.is_empty() and not played.has(sound):
   audio_engine.play(sound,gain,1.0,{'card':source,'event':kind,'element':event_element});played[sound]=true

func rival_action() -> void:
 var plan=rules.ai_attack(target_locked)
 if not plan.is_empty():
  request_attack(plan.uid,plan.target,1)
  return
 plan=rules.ai_play(target_locked)
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
  if rules.outcome=='win':profile.wins+=1
  if rules.outcome=='lose':profile.losses+=1
  save_profile()
 panel='result';active_actions.clear();selected_card=-1;selected_attacker=-1;drag={};press={};inspect_id='';view.pointer_trail=[];view.result_time=0;audio_engine.finish_music()
