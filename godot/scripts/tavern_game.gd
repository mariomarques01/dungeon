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
var profile={'deck':Rules.DEFAULT_DECK.duplicate(),'coins':0,'xp':0,'wins':0,'losses':0}
var sound_on=true
var speed=1.0
var busy=false
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
var web_touch_callback
var done: bool:
 get: return rules!=null and rules.done
class TopLayer extends Control:
 var game
 func _draw() -> void:
  game.view.paint_overlay(self)

func _ready() -> void:
 title_font.fallbacks=[preload('res://assets/symbols.ttf')]
 body_font.fallbacks=[preload('res://assets/symbols.ttf')]
 cards=JSON.parse_string(FileAccess.get_file_as_string('res://tavern_assets/cards.json'))
 rules=Rules.new(cards)
 load_profile()
 art_layer=Control.new();art_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art_layer)
 overlay=TopLayer.new();overlay.game=self;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(overlay)
 view=View.new(self)
 audio_engine=Audio.new(self);audio_engine.set_enabled(sound_on)
 if OS.has_feature('web'): install_web_touch()
 if OS.has_feature('web'): qa_enabled=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''"))=='1'
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
  if data.get('deck',null) is Array and data.deck.all(func(id): return cards.has(id) and not cards[id].get('token',false)):profile.deck=data.deck
  for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(data.get(key,0)))
 elif OS.has_feature('web'):
  var old=JSON.parse_string(str(JavaScriptBridge.eval("localStorage.getItem('dungeon_cards_v15') || '{}'")))
  if old is Dictionary:
   for key in ['coins','xp','wins','losses']:profile[key]=maxi(0,int(old.get(key,0)))

func save_profile() -> void:
 var raw=JSON.stringify(profile)
 if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('"+STORAGE+"',"+JSON.stringify(raw)+")")
 else:
  var file=FileAccess.open('user://tavern-profile.json',FileAccess.WRITE)
  if file:file.store_string(raw)

func layout_board() -> void:
 portrait=size.y>size.x*1.05
 var width=760.0 if portrait else 1280.0
 var height=clampf(width*size.y/maxf(1,size.x),1180,1740) if portrait else clampf(width*size.y/maxf(1,size.x),700,960)
 logical_size=Vector2(width,height)
 var factor=minf(size.x/width,size.y/height)
 board_transform=Transform2D(0,Vector2(factor,factor),0,(size-logical_size*factor)/2)
 art_layer.position=board_transform.origin;art_layer.scale=Vector2(factor,factor)
 overlay.position=board_transform.origin;overlay.scale=Vector2(factor,factor)

func _process(delta: float) -> void:
 if not view:return
 clock+=delta;toast_time=maxf(0,toast_time-delta)
 layout_board();view.tick(delta);audio_engine.update(delta)
 if not press.is_empty() and drag.is_empty() and clock-float(press.time)>0.6 and press.kind in ['card','unit','collection']:
  inspect_id=press.id;press={};selected_card=-1
 view.prepare();queue_redraw();overlay.queue_redraw()
 if qa_enabled:
  var hand=[]
  for item in view.hand_views:hand.append({'index':item.index,'id':item.id,'rect':rect_json(item.rect),'angle':item.angle})
  var units=[]
  for uid in view.unit_views:
   var item=view.unit_views[uid];units.append({'uid':uid,'side':item.side,'rect':rect_json(item.rect),'unit':item.unit})
  var buttons=[]
  for item in view.buttons:buttons.append({'id':item.id,'rect':rect_json(item.rect),'enabled':item.enabled})
  var snap={'screen':screen,'panel':panel,'busy':busy,'drag':drag,'selected':selected_card,'logical':{'x':logical_size.x,'y':logical_size.y},'transform':{'scale':board_transform.x.x,'x':board_transform.origin.x,'y':board_transform.origin.y},'players':rules.players,'active':rules.active,'turn':rules.turn,'done':rules.done,'outcome':rules.outcome,'handViews':hand,'unitViews':units,'heroes':[rect_json(view.layout.player_hero),rect_json(view.layout.enemy_hero)],'drop':rect_json(view.layout.player_drop),'buttons':buttons,'profile':profile,'sound':sound_on,'speed':speed,'musicPlaying':audio_engine.music.playing and not audio_engine.music.stream_paused,'animation':view.anim,'animationTime':view.anim_time,'effectHistory':view.effect_history,'audioHistory':audio_engine.history,'toast':toast_text if toast_time>0 else '','collection':view.collection_views.map(func(item):return {'id':item.id,'rect':rect_json(item.rect)}),'inspect':inspect_id}
  JavaScriptBridge.eval('window.__dungeonState='+JSON.stringify(snap))

func rect_json(rect: Rect2) -> Dictionary:
 return {'x':rect.position.x,'y':rect.position.y,'w':rect.size.x,'h':rect.size.y}

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color('17121b'))
 if view:
  draw_set_transform_matrix(board_transform);view.paint_base(self);draw_set_transform_matrix(Transform2D.IDENTITY)

func notify(message: String) -> void:
 toast_text=message;toast_time=2.1

func collectible_ids() -> Array:
 var ids=cards.keys().filter(func(id):return not cards[id].get('token',false) and (collection_filter==0 or cards[id].kind==('minion' if collection_filter==1 else 'spell')))
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
  drag={};press={};selected_card=-1;selected_attacker=-1;inspect_id='';panel=''

func pointer_down() -> void:
 if not inspect_id.is_empty():inspect_id='';press={};return
 for i in range(view.buttons.size()-1,-1,-1):
  var item=view.buttons[i]
  if not panel.is_empty() and item.id not in ['mute','speed','credits','close','home']:continue
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
 if screen!='battle' or busy or rules.active!=0 or rules.done:return
 var index=hand_at(pointer)
 if index>=0:
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
   press={'kind':'unit','uid':unit.uid,'id':unit.id,'origin':view.target_center(target),'time':clock,'can_attack':unit.attacks>0}
  else:inspect_id=unit.id

func pointer_move() -> void:
 hover_card=hand_at(pointer) if screen=='battle' and press.is_empty() else -1
 if press.is_empty() or not drag.is_empty():return
 if press.kind in ['card','unit','power'] and pointer.distance_to(press.origin)>10:
  if press.kind=='unit' and not press.get('can_attack',true):notify('Esta criatura aguarda o próximo turno ou já atacou.');press={};return
  drag=press.duplicate(true)
  if drag.kind=='card':audio_engine.play('card_soft',-15.0)
  selected_card=-1;selected_attacker=-1

func pointer_up() -> void:
 var held=press.duplicate(true);press={}
 if not drag.is_empty():
  var released=drag.duplicate(true);drag={}
  if released.kind=='card':
   if cards[released.id].kind=='minion':
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
  'card':selected_card=int(held.index);notify('Arraste para jogar, ou toque no campo/alvo.')
  'unit':
   if held.get('can_attack',true):selected_attacker=int(held.uid);notify('Arraste esta criatura até um inimigo.')
   else:inspect_id=held.id
  'power':notify('Arraste o poder até um inimigo. Custa 2 de mana.')

func drop_position(point: Vector2) -> int:
 var board: Array=rules.players[0].board
 for i in range(board.size()):
  if pointer.x<view.unit_views[int(board[i].uid)].rect.get_center().x:return i
 return board.size()

func activate_button(id: String) -> void:
 match id:
  'start':start_match()
  'collection':screen='collection';collection_page=0;selected_card=-1
  'home':screen='home';panel='';inspect_id='';match_serial+=1;busy=false;audio_engine.stop_music()
  'settings':panel='settings'
  'close':panel=''
  'credits':panel='credits'
  'mute':
   sound_on=not sound_on;audio_engine.set_enabled(sound_on)
   if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('dungeon_sound','"+('on' if sound_on else 'off')+"')")
  'speed':
   speed=1.5 if speed==1.0 else 2.0 if speed==1.5 else 1.0
   if OS.has_feature('web'):JavaScriptBridge.eval("localStorage.setItem('dungeon_battle_speed','"+str(speed)+"')")
  'end':end_player_turn()
  'previous':collection_page=maxi(0,collection_page-1)
  'next':collection_page+=1
  'filter':collection_filter=(collection_filter+1)%3;collection_page=0
  'reset_deck':profile.deck=Rules.DEFAULT_DECK.duplicate();save_profile();notify('Baralho inicial restaurado.')

func cycle_card(id: String) -> void:
 var maximum=1 if cards[id].get('legendary',false) else 2
 if profile.deck.count(id)>=maximum:notify('Você já tem o máximo de cópias desta carta.');return
 if profile.deck.size()>=30:notify('Toque em REMOVER abaixo de uma carta para abrir espaço.');return
 profile.deck.append(id)
 save_profile()

func start_match() -> void:
 if not rules.valid_deck(profile.deck):notify('Monte um baralho de 30 cartas antes de duelar.');return
 match_serial+=1;screen='battle';panel='';busy=false;rewarded=false;selected_card=-1;selected_attacker=-1;drag={};press={};inspect_id=''
 rules.start(profile.deck)
 view.anim={};view.particles=[];view.ghosts=[];view.floats=[]
 audio_engine.start_music();toast_time=0

func at_time(value: float) -> void:
 while view.anim_time<value and not view.anim.is_empty():await get_tree().process_frame

func request_play(index: int,target: Dictionary={},position = -1,origin=Vector2.ZERO,side=0) -> void:
 if busy or rules.done:return
 var valid=rules.can_play(side,index,target)
 if not valid.ok:notify(valid.reason);return
 busy=true;selected_card=-1;selected_attacker=-1
 var serial=match_serial
 var id=rules.players[side].hand[index];var card=cards[id]
 var from=origin
 if from==Vector2.ZERO:from=view.hand_views[index].rect.get_center() if side==0 and index<view.hand_views.size() else view.layout.enemy_hero.get_center()
 var destination=view.target_center(target) if not target.is_empty() else Vector2(logical_size.x/2,view.layout.player_row if side==0 else view.layout.enemy_row)
 view.begin({'kind':'card','side':side,'id':id,'index':index,'origin':from,'destination':destination,'target':target,'target_position':destination,'element':card.element,'card_kind':card.kind,'resolved':false})
 audio_engine.charge(card.element)
 await at_time(0.52)
 if serial!=match_serial:return
 var before=rules.players.duplicate(true)
 var result=rules.play(side,index,target,position)
 view.anim.resolved=true
 view.anim.impact_points=[]
 for event in result.events:
  if event.kind=='damage':view.anim.impact_points.append(view.target_center(event.target))
 view.ingest(result.events,before)
 play_events(result.events,card.element)
 await at_time(1.3 if card.kind=='spell' else 1.15)
 if serial!=match_serial:return
 view.finish();busy=false;check_result()

func request_attack(uid: int,target: Dictionary,side=0) -> void:
 if busy or rules.done:return
 var valid=rules.can_attack(side,uid,target)
 if not valid.ok:notify(valid.reason);return
 busy=true;selected_attacker=-1
 var serial=match_serial
 var attacker=rules.find_unit(side,uid)
 var element=cards[attacker.id].element
 var destination=view.target_center(target)
 view.begin({'kind':'attack','id':attacker.id,'uid':uid,'side':side,'target':target,'target_position':destination,'origin':view.target_center({'side':side,'uid':uid}),'destination':destination,'element':element})
 await at_time(0.38)
 if serial!=match_serial:return
 var before=rules.players.duplicate(true)
 var result=rules.attack(side,uid,target)
 view.ingest(result.events,before);play_events(result.events,element)
 await at_time(0.85)
 if serial!=match_serial:return
 view.finish();busy=false;check_result()

func request_power(target: Dictionary,side=0) -> void:
 if busy or rules.done:return
 var valid=rules.can_power(side,target)
 if not valid.ok:notify(valid.reason);return
 busy=true
 var serial=match_serial
 var destination=view.target_center(target) if side==0 else Vector2(logical_size.x/2,view.layout.enemy_row)
 view.begin({'kind':'power','id':'power' if side==0 else 'token_guard','card_kind':'spell' if side==0 else 'minion','element':'fire' if side==0 else 'steel','origin':view.layout.power.get_center() if side==0 else view.layout.enemy_hero.get_center(),'destination':destination,'target':target})
 audio_engine.charge('fire');await at_time(0.5)
 if serial!=match_serial:return
 var before=rules.players.duplicate(true)
 var result=rules.power(side,target)
 view.ingest(result.events,before);play_events(result.events,'fire')
 await at_time(0.95)
 if serial!=match_serial:return
 view.finish();busy=false;check_result()

func play_events(events: Array,element: String) -> void:
 var damage=false;var heal=false;var shield=false;var summon=false;var death=false
 for event in events:
  damage=damage or event.kind=='damage';heal=heal or event.kind=='heal';shield=shield or event.kind=='shield_break';summon=summon or event.kind=='summon';death=death or event.kind=='death'
 if damage:audio_engine.play(audio_engine.clip_for(element),-9.0)
 if heal:audio_engine.play('heal',-12.0)
 if shield:audio_engine.play('shield',-6.0)
 if summon:
  for event in events:
   if event.kind=='summon':audio_engine.summon_card(event.id,cards[event.id].element);break
 if death:audio_engine.play('death_soft',-17.0)
 if events.any(func(e):return e.kind in ['armor','blocked','shield_break']):audio_engine.play('armor',-13.0)
 if events.any(func(e):return e.kind=='freeze'):audio_engine.play('freeze',-14.0)
 if events.any(func(e):return e.kind=='buff'):audio_engine.play('heal',-15.0)
 if not damage and not summon and not heal and events.any(func(e):return e.kind in ['mana','draw','debuff','destroy']):audio_engine.play(audio_engine.clip_for(element),-15.0)

func end_player_turn() -> void:
 if busy or rules.done or rules.active!=0:return
 selected_card=-1;selected_attacker=-1;drag={};inspect_id=''
 var serial=match_serial
 var before=rules.players.duplicate(true)
 var result=rules.end_turn();view.ingest(result.events,before);play_events(result.events,'dark');check_result()
 if rules.done:return
 notify('Turno do rival')
 await get_tree().create_timer(0.45/speed).timeout
 if serial!=match_serial:return
 for i in range(12):
  if rules.done or serial!=match_serial:return
  var plan=rules.ai_play()
  if plan.is_empty():break
  await request_play(int(plan.index),plan.target,-1,Vector2.ZERO,1)
  await get_tree().create_timer(0.12/speed).timeout
 for i in range(20):
  if rules.done or serial!=match_serial:return
  var plan=rules.ai_attack()
  if plan.is_empty():break
  await request_attack(int(plan.uid),plan.target,1)
 if not rules.done and rules.can_power(1).ok:await request_power({},1)
 if serial!=match_serial or rules.done:return
 before=rules.players.duplicate(true)
 result=rules.end_turn();view.ingest(result.events,before);play_events(result.events,'dark');check_result()
 if not rules.done:notify('Seu turno · +1 cristal de mana')

func check_result() -> void:
 if not rules.done:return
 if not rewarded:
  rewarded=true
  profile.coins+=50 if rules.outcome=='win' else 10 if rules.outcome=='draw' else 5
  profile.xp+=35 if rules.outcome=='win' else 12 if rules.outcome=='draw' else 8
  if rules.outcome=='win':profile.wins+=1
  if rules.outcome=='lose':profile.losses+=1
  save_profile()
 panel='result';busy=false;audio_engine.finish_music()
