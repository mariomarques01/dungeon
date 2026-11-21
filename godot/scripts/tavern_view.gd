extends RefCounted
const GOLD=Color('eac67e')
const PAPER=Color('f1dfb6')
const INK=Color('30251e')
const ELEMENT_NAMES={'fire':'Fogo','ice':'Gelo','storm':'Tempestade','steel':'Aço'}
var game
var fx
var effect_history=[]
var pointer_trail=[]
var hand_lifts={}
var ready_mask=0
var observed_match=-1
var pulse_ends=PackedFloat64Array([0,0,0,0,0])
var energy_pulse_end=0.0
var previous_mana=0
var frame_delta=0.016
var result_time=0.0
var freeze_left=0.0
var shake_left=0.0
var shake_strength=0.0
var first_blood=false
var banners: Array[String]=[]
var banner_left=0.0
var deal_started=[]
var known_hand_size=0

func stop_motion() -> void:
 freeze_left=0
 shake_left=0
 shake_strength=0
 deal_started.clear()

func battle_delta(delta: float) -> float:
 var held=minf(freeze_left,delta)
 freeze_left-=held
 return delta-held

func camera_offset() -> Vector2:
 if shake_left<=0 or game.reduced_motion:return Vector2.ZERO
 return Vector2(sin(shake_left*126),sin(shake_left*93))*shake_strength*(shake_left/0.17)

func banner(message: String) -> void:
 if banners.is_empty():banner_left=1.3
 if message not in banners:banners.append(message)

func stretch(rect: Rect2,amount: float) -> Rect2:
 var size=rect.size*Vector2(1.0-amount,1.0+amount)
 return Rect2(Vector2(rect.get_center().x-size.x/2,rect.end.y-size.y),size)

var scenery=[]
var fragment_cache={}
var styles={}
var board: Texture2D
var portrait_board: Texture2D
const SLOT_ZOOM=1.18
const SLOT_COLUMNS=[89,141,192,243,295]
const ROYAL_ARENA = preload("res://tavern_assets/royal/arena.webp")
const HAND_FRAME = preload("res://tavern_assets/royal/hand-frame.webp")
var creatures: Texture2D
var spells: Texture2D
var frames: Texture2D
var atlas_cache={}
var nodes={}
var used={}
var shader: Shader
var layout={}
var hand_views=[]
var unit_views={}
var hero_views=[]
var buttons=[]
var collection_views=[]
# The scene owns these CanvasItems. Only active effects request redraws.
class EffectSprite extends Node2D:
 var owner_view: WeakRef
 var record: Dictionary
 var category: StringName

 func _draw() -> void:
  if record.is_empty():return
  var view=owner_view.get_ref()
  if view==null:return
  var previous=view.canvas
  view.canvas=self
  match category:
   &"particle":
    if not view.game.reduced_motion:view.fx.event(record)
   &"number":view.draw_float(record)
   &"remains":
    if not view.game.reduced_motion:view.draw_remains(record)
  view.canvas=previous

# Cache the face of each hand slot. Hover/deal moves the CanvasItem without
# rebuilding text and texture commands. Cooldown indicators stay on the overlay.
class HandFace extends Node2D:
 var owner_view: WeakRef
 var card_id=''
 var card_size=Vector2.ZERO
 var available=false
 var affordable=false

 func update(hand: Dictionary,ready: bool,can_pay: bool) -> void:
  position=hand.rect.position
  if card_id==hand.id and card_size==hand.rect.size and ready==available and affordable==can_pay:return
  card_id=hand.id
  card_size=hand.rect.size
  available=ready
  affordable=can_pay
  queue_redraw()

 func _draw() -> void:
  var view=owner_view.get_ref()
  if view==null:return
  var previous=view.canvas
  view.canvas=self
  view.paint_hand_card({'id':card_id,'rect':Rect2(Vector2.ZERO,card_size)},available)
  view.canvas=previous

var hand_faces: Array[HandFace]=[]

func prepare_hand_faces() -> void:
 for hand in hand_views:
  if hand.index>=hand_faces.size():
   var face=HandFace.new()
   face.owner_view=weakref(self)
   face.z_index=3
   game.art_layer.add_child(face)
   hand_faces.append(face)
  var card=game.cards[hand.id]
  var player=game.rules.players[0]
  hand.full=player.board.size()>=game.rules.MAX_BOARD and (card.kind=='minion' or card.get('effect','')=='summon_wolves')
  var target=card.get('target','none')
  var missing=(target=='enemy_minion' and game.rules.players[1].board.is_empty()) or (target=='friendly_minion' and player.board.is_empty())
  hand.ready=not missing and not hand.full and not player.cooldowns.has(hand.index) and card.cost<=player.mana
  if card.kind=='trap':
   hand.ready=game.rules.can_equip_support(0,hand.index).ok or game.rules.can_equip_support(1,hand.index).ok
  hand_faces[hand.index].update(hand,hand.ready,card.cost<=player.mana)
 for i in range(hand_faces.size()):
  hand_faces[i].visible=i<hand_views.size() and not (game.drag.get('kind','')=='card' and game.drag.index==i)

var free_effects={&"particle":[],&"number":[],&"remains":[]}

func acquire_effect(active: Array,category: StringName,record: Dictionary) -> void:
 var free: Array=free_effects[category]
 var sprite: EffectSprite
 if free.is_empty():
  sprite=EffectSprite.new()
  sprite.owner_view=weakref(self)
  sprite.category=category
  sprite.z_index=2 if category==&"remains" else 90
  game.art_layer.add_child(sprite)
 else:sprite=free.pop_back()
 sprite.record=record
 record.sprite=sprite
 active.append(record)
 sprite.show()
 sprite.queue_redraw()

func advance_effects(active: Array,elapsed: float,lifetime: float) -> void:
 for i in range(active.size()-1,-1,-1):
  var record=active[i]
  var sprite: EffectSprite=record.sprite
  record.age+=elapsed
  if record.age>=lifetime:
   active.remove_at(i)
   sprite.hide()
   sprite.record={}
   free_effects[sprite.category].append(sprite)
  else:sprite.queue_redraw()

func reset_effects() -> void:
 stop_motion()
 first_blood=false
 trap_reveals.clear()
 banners.clear()
 known_hand_size=0
 advance_effects(particles,INF,1.15)
 advance_effects(floats,INF,1.25)
 advance_effects(ghosts,INF,1.4)

var ghosts=[]
var particles=[]
var trap_reveals=[]
var floats=[]

var canvas
var clock=0.0

func _init(owner) -> void:
 game=owner
 fx=preload("res://scripts/tavern_fx.gd").new(self)
 board=load('res://tavern_assets/board.png')
 portrait_board=load('res://tavern_assets/board_portrait.png') if ResourceLoader.exists('res://tavern_assets/board_portrait.png') else board
 creatures=load('res://tavern_assets/creatures.png'); spells=load('res://tavern_assets/spells.png'); frames=load('res://tavern_assets/frames.png')
 shader=Shader.new()
 shader.code='shader_type canvas_item; uniform bool ellipse=false; uniform vec4 uv_rect=vec4(0.0,0.0,1.0,1.0); void fragment(){ if(ellipse){vec2 p=(UV-uv_rect.xy)/uv_rect.zw;float d=length((p-vec2(0.5))*2.0);COLOR.a*=1.0-smoothstep(0.97,1.0,d);} }'

func slice(texture: Texture2D,index: int,columns: int,rows: int) -> AtlasTexture:
 var key=str(texture.get_instance_id())+':'+str(index)
 if not atlas_cache.has(key):
  var at=AtlasTexture.new(); at.atlas=texture
  var cell=texture.get_size()/Vector2(columns,rows)
  at.region=Rect2(Vector2(index%columns,index/columns)*cell+Vector2(1,1),cell-Vector2(2,2)); atlas_cache[key]=at
 return atlas_cache[key]

func art(key: String,texture: Texture2D,rect: Rect2,ellipse=false,angle=0.0,tint=Color.WHITE,z=0) -> void:
 used[key]=true
 if not nodes.has(key):
  var node=TextureRect.new(); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
  node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  game.art_layer.add_child(node); nodes[key]=node
 var node=nodes[key]
 node.texture=texture; node.position=rect.position; node.size=rect.size; node.pivot_offset=rect.size/2; node.rotation=angle; node.modulate=tint; node.z_index=z
 if not ellipse:
  node.material=null
  return
 if not node.material:
  node.material=ShaderMaterial.new()
  node.material.shader=shader
  node.material.set_shader_parameter('ellipse',true)
 if texture is AtlasTexture:
  var region=texture.region;var size=texture.atlas.get_size()
  node.material.set_shader_parameter('uv_rect',Vector4(region.position.x/size.x,region.position.y/size.y,region.size.x/size.x,region.size.y/size.y))

func tick(delta: float) -> void:
 shake_left=maxf(0,shake_left-delta)
 if not banners.is_empty():
  banner_left-=delta
  if banner_left<=0:
   banners.pop_front()
   banner_left=1.3
 result_time+=delta
 for effect in scenery:effect.age+=delta*game.speed
 scenery=scenery.filter(func(effect):return effect.age<2.4)
 frame_delta=delta
 clock+=delta
 for point in pointer_trail:point.age+=delta
 pointer_trail=pointer_trail.filter(func(point):return point.age<0.4)
 if not game.reduced_motion and game.drag.get('kind','')=='card':
  if pointer_trail.is_empty() or pointer_trail[-1].position.distance_to(game.pointer)>8:
   pointer_trail.append({'position':game.pointer,'id':game.drag.id,'age':0.0})
   if pointer_trail.size()>18:pointer_trail.pop_front()
 if not trap_reveals.is_empty():
  for reveal in trap_reveals:reveal.age+=delta*game.speed
  trap_reveals=trap_reveals.filter(func(reveal):return reveal.age<1.15)
 advance_effects(particles,delta*game.speed,1.15)
 advance_effects(floats,delta*game.speed,1.25)
 advance_effects(ghosts,delta*game.speed,1.4)

func geometry() -> void:
 var w=game.logical_size.x; var h=game.logical_size.y; var mobile=game.portrait
 layout={'w':w,'h':h,'mobile':mobile}
 layout.enemy_hero=Rect2(w*0.40,h*0.032,w*0.20,h*0.128)
 layout.player_hero=Rect2(w*0.374,h*0.614,w*0.252,h*0.139)
 # Coordinates measured on a 384 x 512 reference of the painted arena.
 var arena_scale=Vector2(w/384.0,h/512.0)
 layout.slot_sizes=[]
 layout.slots=[[],[]]
 layout.slot_sources=[[],[]]
 var texture_scale=ROYAL_ARENA.get_size()/Vector2(384,512)
 layout.player_row=282*arena_scale.y
 layout.enemy_row=170.5*arena_scale.y
 for side in range(2):
  var original_size=Vector2(40,54 if side==0 else 57)
  var size=original_size*arena_scale*SLOT_ZOOM
  layout.slot_sizes.append(size)
  for x in SLOT_COLUMNS:
   var center=Vector2(x*arena_scale.x,layout.player_row if side==0 else layout.enemy_row)
   var floor_sample=Rect2(42,258 if side==0 else 139,22,54)
   layout.slots[side].append(Rect2(center-size/2,size))
   layout.slot_sources[side].append(Rect2(floor_sample.position*texture_scale,floor_sample.size*texture_scale))
 layout.player_drop=Rect2(w*0.045,h*0.468,w*0.91,h*0.205)
 layout.board_zone=Rect2(w*0.035,h*0.15,w*0.93,h*0.57)
 var gold_width=minf(w*0.15,h*0.118)
 layout.gold_size=Vector2(gold_width,h*0.114)
 layout.enemy_supports=[]
 layout.supports=[]
 for x in [0.253,0.747]:
  layout.enemy_supports.append(Rect2(Vector2(w*x,h*0.202)-layout.gold_size/2,layout.gold_size))
  layout.supports.append(Rect2(Vector2(w*x,h*0.675)-layout.gold_size/2,layout.gold_size))
 var power_size=clampf(w*0.055,36,52)
 layout.power=Rect2(w*0.94-power_size/2,h*0.73-power_size/2,power_size,power_size)
 var gear_size=clampf(w*0.066,44,62)
 layout.settings=Rect2(w*0.986-gear_size,h*0.011,gear_size,gear_size)
 hand_views=[]; unit_views={}; hero_views=[]; buttons=[]; collection_views=[]
 if game.screen!='battle': return
 var state=game.rules
 for side in range(2):
  hero_views.append({'side':side,'hero':true,'rect':layout.player_hero if side==0 else layout.enemy_hero})
  var list: Array=state.players[side].board
  var first_slot=floori((state.MAX_BOARD-list.size())/2.0)
  for i in range(list.size()):
   var column=first_slot+i
   var uid=int(list[i].uid)
   unit_views[uid]={'side':side,'uid':uid,'rect':layout.slots[side][column],'unit':list[i]}
 var hand: Array=state.players[0].hand
 if hand.size()>known_hand_size and not game.reduced_motion:
  deal_started.resize(hand.size())
  for index in range(known_hand_size,hand.size()):
   deal_started[index]=clock+0.045*(index-known_hand_size)
 known_hand_size=hand.size()
 var frame_ratio=float(HAND_FRAME.get_width())/HAND_FRAME.get_height()
 var width=minf(w*0.95/maxi(1,hand.size()),h*0.190*frame_ratio)
 var size=Vector2(width,width/frame_ratio)
 var spacing=minf(size.x*1.025,(w*0.98-size.x)/maxi(1,hand.size()-1))
 for i in range(hand.size()):
  var f=i-(hand.size()-1)/2.0
  var center=Vector2(w/2+f*spacing,h*0.851)
  var angle=0.0
  var base_rect=Rect2(center-size/2,size)
  var lifted=game.selected_card==i or game.hover_card==i or (game.press.get('kind','')=='card' and int(game.press.get('index',-1))==i)
  var lift=move_toward(float(hand_lifts.get(i,0)),1.0 if lifted and game.drag.is_empty() else 0.0,frame_delta*9)
  hand_lifts[i]=lift
  center.y-=(70 if mobile else 110)*lift
  if not game.reduced_motion and i<deal_started.size() and deal_started[i]!=null:
   var travel=smoothstep(0,0.24,clock-float(deal_started[i]))
   center=Vector2(w*0.92,h*0.77).lerp(center,travel)
   if travel>=1:deal_started[i]=null
  angle*=1-lift*0.8
  hand_views.append({'index':i,'id':hand[i],'rect':Rect2(center-size/2,size),'base_rect':base_rect,'angle':angle})

func button(id: String,rect: Rect2,label: String,enabled=true,primary=false) -> void:
 buttons.append({'id':id,'rect':rect,'label':label,'enabled':enabled,'primary':primary})

func held_card_rect() -> Rect2:
 var size=Vector2(178,267) if game.portrait else Vector2(175,262)
 var offset=Vector2(48 if game.pointer.x<layout.w*0.5 else -size.x-48,-size.y*0.85)
 return Rect2(game.pointer+offset,size)

func prepare() -> void:
 used={}; geometry()
 prepare_hand_faces()
 if game.screen=='battle':
  var state=game.rules
  for uid in unit_views:
   var info=unit_views[uid]; var rect: Rect2=info.rect
   var opacity=1.0
   var attacking=false
   for action in game.active_actions:
    if action.kind!='attack' or action.get('uid',-1)!=uid:continue
    attacking=true
    var attack_time=action.age
    var direction: Vector2=(action.destination-action.origin).normalized()
    var windup=sin(PI*clampf(attack_time/0.12,0,1))
    var advance=smoothstep(0.12,0.38,attack_time)*(1.0-smoothstep(0.38,0.80,attack_time))
    if game.reduced_motion:continue
    rect=stretch(rect,advance*0.12-windup*0.10)
    if fx.ranged(str(info.unit.id)):
     rect.position-=direction*(windup*6+advance*10)
    else:
     rect.position-=direction*windup*16
     rect.position=rect.position.lerp(action.destination-rect.size/2,advance*0.9)
   var spawn=particles.filter(func(p): return p.get('uid',-1)==uid and p.kind=='summon')
   if not spawn.is_empty() and not game.reduced_motion:
    var arrival=clampf(spawn[0].age/0.46,0,1)
    var factor=lerpf(0.12,1.0,ease(arrival,0.35))+0.12*sin(PI*arrival)
    rect=Rect2(rect.get_center()-rect.size*factor/2,rect.size*factor)
    rect=stretch(rect,-sin(arrival*TAU)*0.13*(1-arrival))
   elif not attacking and not game.reduced_motion:
    rect=stretch(rect,0.013*sin(clock*2.1+uid*1.7))
   var hits=particles.filter(func(p): return p.kind=='damage' and int(p.get('target',{}).get('uid',-1))==uid and p.age<0.28)
   if not hits.is_empty():
    var hit=hits[-1]
    var recovery=clampf(hit.age/0.28,0,1)
    var recoil=clampf(hit.amount*2.0,4,16)*sin(recovery*TAU)*(1-recovery)
    if not game.reduced_motion:rect.position.y+=recoil*(1 if info.side==0 else -1)
   info.draw_rect=rect
   var resonating=attacking or particles.any(func(p):return p.get('response_id','')==info.unit.id and p.get('target',{}).get('uid',-1)==uid and p.age<0.65)
   if resonating and not game.reduced_motion:
    var spirit=rect.grow(14);spirit.position.y-=20+sin(clock*7)*5
    art('spirit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),spirit,false,0,Color(element_color(game.cards[info.unit.id].element).lightened(0.5),0.35),0)
   art('unit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),rect.grow(-3),false,0,Color(1,0.6,0.5,opacity) if not hits.is_empty() else Color(1,1,1,opacity),1)
  if not game.drag.is_empty() and game.drag.kind=='card':
   var rect=held_card_rect()
   prepare_card('drag',game.drag.id,rect,0,50)
  for anim in game.active_actions:
   var anim_time=anim.age
   if game.reduced_motion or anim.kind!='card' or anim_time>=0.62:continue
   var size=Vector2(170,255)
   var p=anim.origin.lerp(anim.destination,clampf(anim_time/0.6,0,1))
   prepare_card('cast%d_%d'%[anim.side,anim.index],anim.id,Rect2(p-size/2,size),0,45,Color(1,1,1,clampf(1-anim_time/0.85,0,1)))
  button('settings',layout.settings,'⚙')
  if state.solar_ready() and not game.target_locked({'side':1,'hero':true}):
   button('solar',energy_bar().grow_individual(0,5,0,5),'Lançar Erupção Solar')
  if game.selected_card>=0 and not game.card_locked(0,game.selected_card) and not state.done:
   var exchange_rect=Rect2(layout.w*0.5-108,layout.h*0.448-22,216,44)
   button('exchange',exchange_rect,'Trocar · 1 energia',state.players[0].mana>=1 and not state.players[0].deck.is_empty())
  button('power',layout.power,'1 DANO\n2 ENERGIA',not game.power_locked(0,'power') and not state.players[0].power_used and state.players[0].mana>=2)
 elif game.screen=='home': prepare_home()
 elif game.screen=='collection': prepare_collection()
 if not game.inspect_id.is_empty():
  var rect=inspect_rect()
  prepare_card('inspect',game.inspect_id,rect,0,70)
 if game.panel=='settings':
  var rect=panel_rect()
  button('mute',Rect2(rect.position+Vector2(45,105),Vector2(rect.size.x-90,55)),'SOM LIGADO' if game.sound_on else 'SOM DESLIGADO')
  button('speed',Rect2(rect.position+Vector2(45,177),Vector2(rect.size.x-90,55)),'ANIMAÇÕES ×'+str(game.speed))
  button('motion',Rect2(rect.position+Vector2(45,321),Vector2(rect.size.x-90,55)),'REDUZIR MOVIMENTO · '+('SIM' if game.reduced_motion else 'NÃO'))
  button('credits',Rect2(rect.position+Vector2(45,249),Vector2(rect.size.x-90,55)),'CRÉDITOS DE ÁUDIO')
  button('close',Rect2(rect.position+Vector2(rect.size.x-58,14),Vector2(42,42)),'×')
 if game.panel=='credits': button('close',Rect2(panel_rect().position+Vector2(panel_rect().size.x-58,14),Vector2(42,42)),'×')
 if game.panel=='result':
  var r=panel_rect()
  button('home',Rect2(r.position+Vector2(55,r.size.y-105),Vector2(r.size.x-110,60)),'VOLTAR À TAVERNA',true,true)
 for key in nodes.keys():
  if not used.has(key): nodes[key].queue_free(); nodes.erase(key)

func draw_remains(g: Dictionary) -> void:
 var t=clampf(float(g.age)/1.4,0,1)
 var base=slice(creatures,int(game.cards[g.id].art),5,5)
 var element=str(g.get('element','dark'))
 for part in range(9):
  var cache_key=str(game.cards[g.id].art)+':'+str(part)
  if not fragment_cache.has(cache_key):
   var piece=AtlasTexture.new();piece.atlas=creatures
   piece.region=Rect2(base.region.position+Vector2(part%3,part/3)*base.region.size/3,base.region.size/3)
   fragment_cache[cache_key]=piece
  var cell=Vector2(part%3,part/3)
  var rect=Rect2(g.rect.position+cell*g.rect.size/3,g.rect.size/3)
  var direction=(cell-Vector2.ONE+Vector2(sin(part*7+g.uid)*0.3,-0.15)).normalized()
  var tint=Color.WHITE
  if element=='fire':
   rect.position+=Vector2(sin(part*3+t*6)*t*30,-t*(40+part*9))
   tint=Color('ffc17d').lerp(Color('342326'),t)
  elif element=='ice':
   rect.position+=direction*t*105+Vector2(0,t*t*70)
   tint=Color('b9efff')
  elif element in ['dark','arcane']:
   rect.position=rect.position.lerp(g.rect.get_center()-rect.size/2,t)+Vector2.from_angle(part*2.4+t*5)*t*18
   tint=Color('c4a0ff')
  else:
   rect.position+=direction*t*65+Vector2(0,t*t*90)
   tint=element_color(element).lightened(0.55)
  var shrink=1-t*0.7
  rect=Rect2(rect.get_center()-rect.size*shrink/2,rect.size*shrink)
  tint.a=clampf(1-t*1.1,0,1)
  canvas.draw_set_transform(rect.get_center(),t*(part-4)*0.12)
  canvas.draw_texture_rect(fragment_cache[cache_key],Rect2(-rect.size/2,rect.size),false,tint)


func prepare_card(key: String,id: String,rect: Rect2,angle=0.0,z=0,tint=Color.WHITE) -> void:
 var card=game.cards[id]
 var local=Rect2(rect.position+rect.size*Vector2(0.145,0.085),rect.size*Vector2(0.72,0.435))
 var center=(local.get_center()-rect.get_center()).rotated(angle)+rect.get_center()
 local.position=center-local.size/2
 art(key,slice(creatures if card.kind=='minion' else spells,int(card.art),5 if card.kind=='minion' else 4,5 if card.kind=='minion' else 4),local,card.kind=='minion',angle,tint,z)

func prepare_home() -> void:
 var w=layout.w; var h=layout.h
 var positions=[Vector2(w/2-185,h*0.46),Vector2(w/2,h*0.43),Vector2(w/2+185,h*0.46)] if game.portrait else [Vector2(w*0.65,h*0.5),Vector2(w*0.79,h*0.43),Vector2(w*0.91,h*0.52)]
 for i in range(3): prepare_card('home'+str(i),['treant','dragon','fireball'][i],Rect2(positions[i]-Vector2(100,150),Vector2(200,300)),(i-1)*0.1)
 var x=w/2-245 if game.portrait else 150.0
 var y=h*0.66 if game.portrait else h*0.57
 button('start',Rect2(x,y,490,78),'DUELAR',game.rules.valid_deck(game.profile.deck),true)
 button('collection',Rect2(x,y+98,490,65),'COLEÇÃO E BARALHO')
 button('settings',layout.settings,'⚙')

func prepare_collection() -> void:
 var ids=game.collectible_ids()
 var columns=4 if game.portrait else 6
 var page_size=columns*2
 var card_size=Vector2(155,232) if game.portrait else Vector2(150,225)
 var space=16.0
 var width=columns*(card_size.x+space)-space
 var top=layout.h/2-card_size.y-20
 for slot in range(page_size):
  var index=game.collection_page*page_size+slot
  if index>=ids.size(): break
  var rect=Rect2(Vector2(layout.w/2-width/2+(slot%columns)*(card_size.x+space),top+(slot/columns)*(card_size.y+38)),card_size)
  collection_views.append({'id':ids[index],'rect':rect})
  prepare_card('collection'+str(slot),ids[index],rect)
 button('home',Rect2(35,30,170,50),'VOLTAR')
 button('filter',Rect2(layout.w-260,30,225,50),['TODAS','CRIATURAS','FEITIÇOS','ARMADILHAS'][game.collection_filter])
 button('previous',Rect2(50,layout.h-98,155,55),'ANTERIOR',game.collection_page>0)
 button('next',Rect2(layout.w-205,layout.h-98,155,55),'PRÓXIMA',(game.collection_page+1)*page_size<ids.size())
 button('reset_deck',Rect2(layout.w/2-150,layout.h-98,300,55),'BARALHO INICIAL')

func panel_rect() -> Rect2:
 return Rect2(Vector2(layout.w/2-280,layout.h/2-260),Vector2(560,520))
func inspect_rect() -> Rect2:
 var size=Vector2(440,660) if game.portrait else Vector2(260,390)
 return Rect2(Vector2(layout.w/2-size.x/2,layout.h/2-size.y/2-25),size)

func target_center(target: Dictionary) -> Vector2:
 if target.get('hero',false): return (layout.player_hero if int(target.side)==0 else layout.enemy_hero).get_center()
 if unit_views.has(int(target.get('uid',-1))): return unit_views[int(target.uid)].rect.get_center()
 return Vector2(layout.w/2,layout.player_row)

func begin(action: Dictionary) -> void:
 effect_history.append({'phase':'cast','id':action.get('id','power'),'kind':action.kind,'element':action.get('element','arcane')})
 if effect_history.size()>60:effect_history.pop_front()

func ingest(events: Array,before: Array,action: Dictionary={}) -> void:
 var elemental=events.filter(func(event):return event.kind in ['damage','freeze','armor','heal','destroy'])
 if not elemental.is_empty():
  var element=str(action.get('element',elemental[0].get('element','arcane')))
  scenery.append({'element':element,'age':0.0,'position':target_center(elemental[0].get('target',{}))})
  if scenery.size()>4:scenery.pop_front()
 var defeated=events.filter(func(event):return event.kind=='death' and event.side!=action.get('side',-1))
 if defeated.size()>=2 and action.has('side'):
  var banner_at=Vector2(layout.w*0.5,(layout.enemy_row+layout.player_row)*0.5)
  acquire_effect(floats,&"number",{'position':banner_at+Vector2(0,55),'text':'QUEDA DUPLA' if defeated.size()==2 else 'QUEDA MÚLTIPLA','color':GOLD,'age':0.0})
 for side in range(2):
  var health=game.rules.players[side].health
  if before[side].health>=10 and health>0 and health<10:
   banner('SEU HERÓI EM PERIGO' if side==0 else 'HERÓI RIVAL EM PERIGO')
 var causes={}
 for event in events:
  var kind=event.kind
  if kind=='damage':
   if not first_blood:
    first_blood=true
    banners.push_front('PRIMEIRO SANGUE')
    banner_left=1.3
   if not game.reduced_motion:
    freeze_left=maxf(freeze_left,minf(0.055,0.018+event.amount*0.004))
    shake_strength=maxf(shake_strength if shake_left>0 else 0,minf(8,1.4*event.amount))
    shake_left=0.17
  if kind in ['damage','destroy'] and event.get('target',{}).has('uid'):causes[int(event.target.uid)]=event.get('element',action.get('element','dark'))
  if kind in ['damage','heal','buff','debuff','blocked','shield_break','freeze','destroy','armor','draw','mana']:
   var at=target_center(event.get('target',{'side':event.get('side',0),'hero':true}))
   var label='+'+str(event.get('amount',0))+' ARMADURA' if kind=='armor' else 'DESTRUÍDO' if kind=='destroy' else '+ ENERGIA' if kind=='mana' else 'COMPRA' if kind=='draw' else '−'+str(event.get('amount',0)) if kind=='damage' else '+'+str(event.get('amount',0)) if kind in ['heal','buff'] else 'ESCUDO ROMPIDO' if kind=='shield_break' else 'GELO' if kind=='freeze' else '−'+str(event.get('amount',0)) if kind=='debuff' else 'BLOQUEOU '+str(event.get('amount',0))
   var color=Color('ffe29b') if kind in ['armor','blocked','shield_break'] else Color('ff615d') if kind=='damage' else Color('8cffbe') if kind in ['heal','buff'] else Color('96dfff')
   if kind in ['damage','heal']:
    accumulate(event,at,color)
   elif not event.get('target',{}).has('uid'):
    acquire_effect(floats,&"number",{'position':at,'text':label,'color':color,'age':0.0,'element':event.get('element',action.get('element','arcane')),'id':action.get('id','')})
   acquire_effect(particles,&"particle",{'kind':kind,'amount':event.get('amount',0),'position':at,'target':event.get('target',{}).duplicate(),'color':color,'age':0.0,'element':event.get('element',action.get('element','arcane')),'id':action.get('id','')})
   if kind in ['damage','blocked','shield_break'] and event.get('target',{}).has('uid'):
    for unit in before[int(event.target.side)].board:
     if int(unit.uid)==int(event.target.uid):particles[-1].response_id=unit.id;break
  elif kind=='element_resist':
   accumulate(event,target_center(event.target),Color('96dfff'))
  elif kind=='trap_reveal':
   trap_reveals.append({'age':0.0,'side':event.side,'slot':event.slot,'id':event.id})
   effect_history.append({'phase':'reveal','kind':kind,'id':event.id,'side':event.side,'slot':event.slot})
   if effect_history.size()>60:effect_history.pop_front()
  elif kind=='support':
   var slot_rect: Rect2=layout.supports[event.slot] if event.side==0 else layout.enemy_supports[event.slot]
   acquire_effect(particles,&"particle",{'kind':kind,'age':0.0,'origin':slot_rect.get_center(),'position':target_center(event.target),'element':event.element,'defense':event.defense,'id':event.id})
  elif kind=='summon':
   acquire_effect(particles,&"particle",{'kind':'summon','uid':event.uid,'side':event.side,'position':Vector2(layout.w/2,layout.player_row if int(event.side)==0 else layout.enemy_row),'color':Color('b9a0ff'),'age':0.0,'element':game.cards[event.id].element,'id':event.id})
  elif kind=='death':
   for unit in before[int(event.side)].board:
    if int(unit.uid)==int(event.uid):
     var rect=unit_views[event.uid].get('draw_rect',unit_views[event.uid].rect) if unit_views.has(event.uid) else Rect2(Vector2(layout.w/2,layout.player_row if int(event.side)==0 else layout.enemy_row)-layout.slot_sizes[event.side]/2,layout.slot_sizes[event.side])
     var cause=str(causes.get(int(event.uid),action.get('element','dark')))
     acquire_effect(ghosts,&"remains",{'uid':event.uid,'id':event.id,'rect':rect,'age':0.0,'element':cause})
     acquire_effect(particles,&"particle",{'kind':'death','position':rect.get_center(),'color':element_color(cause),'element':cause,'age':0.0})

func accumulate(event: Dictionary,at: Vector2,color: Color) -> void:
 var modifier=int(event.get('modifier',0))
 var marker: String=game.rules.elemental_marker(modifier)
 var prefix='+' if event.kind=='heal' else '−'
 var stack_depth=0
 for number in floats:
  if number.get('target',{})!=event.target or number.age>=0.35:continue
  if number.get('kind','')==event.kind and number.get('modifier',0)==modifier:
   number.amount+=event.amount
   number.text=prefix+str(number.amount)+marker
   number.age=0
   return
  if event.kind in ['damage','element_resist'] and number.kind in ['damage','element_resist']:stack_depth+=1
 acquire_effect(floats,&"number",{'position':at+Vector2(0,stack_depth*35),'kind':event.kind,'target':event.target,'amount':event.amount,'modifier':modifier,'text':prefix+str(event.amount)+marker,'color':color,'age':0.0})

func style(fill: Color,border: Color,radius=12,width=2) -> StyleBoxFlat:
 var key=[fill.to_rgba32(),border.to_rgba32(),radius,width]
 if styles.has(key):return styles[key]
 var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius);s.shadow_color=Color(0,0,0,0.45);s.shadow_size=7
 styles[key]=s
 return s

func text(value: String,rect: Rect2,size=20,color=PAPER,center=false,title=false) -> void:
 var font=game.title_font if title else game.body_font
 var y=rect.position.y
 for line in value.split('\n'):
  var width=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
  var x=rect.position.x+(maxf(0,(rect.size.x-width)/2) if center else 0)
  if color.get_luminance()>0.25:canvas.draw_string(font,Vector2(x+1,y+size+1),line,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,size,Color(0,0,0,color.a*0.65))
  canvas.draw_string(font,Vector2(x,y+size),line,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,size,color)
  y+=size*1.16

func wrapped(value: String,rect: Rect2,size: int,color: Color,center=false) -> void:
 var lines=[];var line=''
 for word in value.split(' '):
  var next=word if line.is_empty() else line+' '+word
  if game.body_font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x and not line.is_empty(): lines.append(line);line=word
  else:line=next
 if not line.is_empty(): lines.append(line)
 var y=rect.position.y
 for value_line in lines:
  if y+size>rect.end.y: break
  text(value_line,Rect2(rect.position.x,y,rect.size.x,size),size,color,center)
  y+=size*1.22

func paint_base(c: CanvasItem) -> void:
 canvas=c
 var bounds=Rect2(Vector2.ZERO,game.logical_size)
 if game.screen=='battle':
  canvas.draw_rect(bounds,Color('19132b'))
  canvas.draw_texture_rect(ROYAL_ARENA,bounds,false)
  for side in range(2):
   for column in range(SLOT_COLUMNS.size()):
    var slot: Rect2=layout.slots[side][column]
    canvas.draw_texture_rect_region(ROYAL_ARENA,slot,layout.slot_sources[side][column])
    canvas.draw_rect(slot.grow(-3),Color(0.95,0.83,0.69,0.32),false,2,true)
  if not game.reduced_motion:fx.environment()
 else:
  canvas.draw_texture_rect(portrait_board if game.portrait else board,bounds,false)
 if game.screen!='battle': canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size),Color(0.015,0.02,0.05,0.53))
 if game.screen=='home':
  var x=layout.w/2-285 if game.portrait else 110.0
  canvas.draw_style_box(style(Color(0.035,0.045,0.075,0.92),Color('a78654'),24),Rect2(x,layout.h*0.12,570,layout.h*0.78 if game.portrait else layout.h*0.75))
 if not game.inspect_id.is_empty(): canvas.draw_style_box(style(Color(0.02,0.025,0.04,0.95),Color('9e815a'),18),inspect_rect().grow(20))
 if game.screen=='collection': canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size),Color(0.025,0.02,0.05,0.69))
 if game.screen=='battle':
  for uid in unit_views:
   var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect)
   var unit=info.unit
   var ready=int(info.side)==0 and int(unit.attacks)>0 and not game.target_locked({'side':0,'uid':uid})
   var rim=Color('64b7ff') if info.side==0 else Color('ff8b57')
   canvas.draw_rect(rect,Color('30261f'))
   canvas.draw_rect(rect,rim,false,3,true)
   if ready:canvas.draw_rect(rect.grow(2),Color(rim,0.45+0.2*sin(clock*3)),false,3,true)


func paint_overlay(c: CanvasItem) -> void:
 canvas=c
 if game.screen=='home': paint_home()
 elif game.screen=='collection': paint_collection()
 else: paint_battle()
 for button_info in buttons: paint_button(button_info)
 if not game.inspect_id.is_empty():
  var card_rect=inspect_rect()
  paint_card(game.inspect_id,card_rect)
  var hint=element_hint(game.cards[game.inspect_id].element)
  if hint!='':
   var strip=Rect2(card_rect.position+Vector2(0,card_rect.size.y-26),Vector2(card_rect.size.x,24))
   canvas.draw_style_box(style(Color('312238'),GOLD,5,1),strip)
   text(hint,strip,15,PAPER,true)
  text('Toque fora para fechar',Rect2(card_rect.position+Vector2(-15,card_rect.size.y+15),Vector2(card_rect.size.x+30,25)),15,PAPER,true)
 if game.screen=='battle' and game.panel.is_empty() and not banners.is_empty():
  var strip=Rect2(layout.w/2-190,layout.h*0.443,380,42)
  canvas.draw_style_box(style(Color('33262b'),GOLD,8,2),strip)
  text(banners[0],strip,23,GOLD,true,true)
 if not game.panel.is_empty(): paint_panel()
 if game.toast_time>0:
  var width=minf(layout.w-70,650)
  canvas.draw_style_box(style(Color(0.025,0.03,0.055,0.94),Color('d8ba7a'),12),Rect2(layout.w/2-width/2,layout.h*0.19,width,56))
  var inset=5 if '\n' in game.toast_text else 15
  text(game.toast_text,Rect2(layout.w/2-width/2+14,layout.h*0.19+inset,width-28,50),18,PAPER,true)

 if game.qa_enabled and not game.qa_frame_label.is_empty():
  var meter=Rect2(8,layout.h-30,174,28)
  canvas.draw_rect(meter,Color(0.02,0.03,0.04,0.92))
  text(game.qa_frame_label,meter,18,Color.WHITE,true)

func paint_card(id: String,rect: Rect2,angle=0.0,tint=Color.WHITE) -> void:
 var card=game.cards[id]
 var transform=Transform2D(angle,rect.get_center())
 canvas.draw_set_transform_matrix(transform)
 var local=Rect2(-rect.size/2,rect.size)
 canvas.draw_texture_rect_region(frames,local,Rect2(Vector2(0 if card.kind=='minion' else frames.get_width()/2.0,0),Vector2(frames.get_width()/2.0,frames.get_height())),tint)
 var factor=rect.size.x/160.0
 text(str(int(card.cost)),Rect2(local.position+local.size*Vector2(0.025,0.024),local.size*Vector2(0.22,0.16)),int(23*factor),Color.WHITE,true,true)
 text(card.name,Rect2(local.position+local.size*Vector2(0.11,0.525),local.size*Vector2(0.79,0.10)),int((11 if card.name.length()>20 else 12)*factor),Color('3b281b'),true,true)
 wrapped(card.text,Rect2(local.position+local.size*Vector2(0.16,0.65),local.size*Vector2(0.69,0.20)),int(10*factor),Color('3b2d24'),true)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func element_hint(element: String) -> String:
 var source='storm' if element=='lightning' else element
 if not ELEMENT_NAMES.has(source):return ''
 var advantage: Dictionary=game.rules.ELEMENT_ADVANTAGE
 var hint='Raio' if element=='lightning' else ELEMENT_NAMES[source]
 if advantage.has(source):hint+='  ▲ '+ELEMENT_NAMES[advantage[source]]
 var weakness=advantage.find_key(source)
 if weakness!=null:hint+='  ▼ '+ELEMENT_NAMES[weakness]
 return hint

func armed_trap_rect(slot: Rect2) -> Rect2:
 var size=slot.size*Vector2(0.42,0.56)
 var center=slot.position+slot.size*Vector2(0.69,0.44)
 return Rect2(center-size/2,size)

func paint_trap_back(rect: Rect2) -> void:
 canvas.draw_style_box(style(Color('39274c'),Color('e9bbff'),4,2),rect)
 var center=rect.get_center()
 var radius=minf(rect.size.x,rect.size.y)*0.28
 var corners=PackedVector2Array([center-Vector2(0,radius),center+Vector2(radius,0),center+Vector2(0,radius),center-Vector2(radius,0),center-Vector2(0,radius)])
 canvas.draw_polyline(corners,Color('e9bbff'),2,true)

func paint_trap_reveal(reveal: Dictionary) -> void:
 var slot: Rect2=layout.supports[reveal.slot] if reveal.side==0 else layout.enemy_supports[reveal.slot]
 var progress=clampf(reveal.age/0.42,0,1)
 var center=slot.get_center()
 var size=slot.size*Vector2(0.66,0.86)
 if not game.reduced_motion:
  var back=armed_trap_rect(slot)
  center.y+=(-1 if reveal.side==0 else 1)*slot.size.y*0.38
  center=back.get_center().lerp(center,progress)
  size=back.size.lerp(size,progress)
  size.x*=maxf(0.05,absf(cos(progress*PI)))
 var rect=Rect2(center-size/2,size)
 if progress<0.5 and not game.reduced_motion:
  paint_trap_back(rect)
  return
 var card=game.cards[reveal.id]
 canvas.draw_style_box(style(Color('39274c'),Color('e9bbff'),4,2),rect)
 draw_card_picture(slice(spells,int(card.art),4,4),rect.grow(-minf(3,rect.size.x*0.15)))
 if game.reduced_motion or progress>=0.88:
  var label=Rect2(center+Vector2(-slot.size.x*0.85,size.y*0.48),Vector2(slot.size.x*1.7,24))
  canvas.draw_style_box(style(Color('39274c'),Color('e9bbff'),4,1),label)
  text(card.name,label,clampi(int(slot.size.x*0.14),12,17),PAPER,true,true)

func draw_card_picture(picture: AtlasTexture,window: Rect2,tint=Color.WHITE) -> void:
 var region=picture.region
 var scale=maxf(window.size.x/region.size.x,window.size.y/region.size.y)
 var crop=window.size/scale
 canvas.draw_texture_rect_region(picture.atlas,window,Rect2(region.get_center()-crop/2,crop),tint)

func paint_hand_card(hand: Dictionary,available: bool) -> void:
 var r: Rect2=hand.rect
 var card=game.cards[hand.id]
 var affordable=card.cost<=game.rules.players[0].mana
 var tint=Color('676271') if not affordable else Color.WHITE if available else Color('bbb4bf')
 var picture=slice(creatures if card.kind=='minion' else spells,int(card.art),5 if card.kind=='minion' else 4,5 if card.kind=='minion' else 4)
 var window=Rect2(r.position+r.size*Vector2(0.055,0.055),r.size*Vector2(0.90,0.62))
 draw_card_picture(picture,window,tint)
 canvas.draw_texture_rect(HAND_FRAME,r,false,tint)
 var label=Rect2(r.position+r.size*Vector2(0.115,0.565),r.size*Vector2(0.77,0.11))
 var font_size=maxi(9,int(r.size.x*0.10))
 while font_size>8 and game.title_font.get_string_size(card.name,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>label.size.x:
  font_size-=1
 canvas.draw_rect(label.grow(1),Color('362720'))
 text(card.name,label,font_size,PAPER,true,true)
 text(str(int(card.cost)),Rect2(r.position+r.size*Vector2(0.018,0.029),r.size*Vector2(0.207,0.15)),int(r.size.x*0.19),Color.WHITE if affordable else Color(1,0.34,0.32),true,true)

func radial_cooldown(center: Vector2,radius: float,remaining: float) -> void:
 var end_angle=-PI/2+TAU*(1-clampf(remaining/game.rules.REUSE_SECONDS,0,1))
 canvas.draw_circle(center,radius+3,Color('262036'))
 canvas.draw_arc(center,radius,-PI/2,3*PI/2,32,Color('5c5067'),2,true)
 if end_angle>-PI/2:canvas.draw_arc(center,radius,-PI/2,end_angle,32,Color('80e6ff'),4,true)
 canvas.draw_line(center,center+Vector2.from_angle(end_angle)*radius,Color.WHITE,2,true)

func drag_preview() -> Dictionary:
 var drag=game.drag
 if drag.is_empty() or game.screen!='battle' or game.done:return {}
 var target=game.target_at(game.pointer)
 if target.is_empty() or game.support_at(game.pointer)>=0:return {}
 if drag.kind=='power' and game.power_locked(0,'power'):return {}
 if drag.kind=='unit' and game.target_locked({'side':0,'uid':drag.uid}):return {}
 if drag.kind=='card' and game.card_locked(0,drag.index):return {}
 var area=drag.kind=='card' and game.cards[drag.id].get('effect','') in ['aoe','blizzard']
 if not area and game.target_locked(target):return {}
 var label=game.rules.health_preview(0,drag,target)
 return {} if label.is_empty() else {'text':label,'target':target}

func paint_next_card(player: Dictionary) -> void:
 var box=Rect2(layout.w*0.665,layout.h*0.006,layout.w*0.225,layout.h*0.13)
 canvas.draw_style_box(style(Color('28232b'),GOLD,8,1),box)
 var line=box.size.y/4
 var fs=int(minf(box.size.x/10,line*0.66))
 text('PRÓXIMA · %d'%player.deck.size(),Rect2(box.position,Vector2(box.size.x,line)),fs,GOLD,true)
 var name='Baralho vazio' if player.deck.is_empty() else str(game.cards[player.deck.back()].name)
 var width=game.title_font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
 var fitted=maxi(9,int(fs*minf(1,(box.size.x-6)/maxf(width,1))))
 text(name,Rect2(box.position+Vector2(0,line),Vector2(box.size.x,line)),fitted,PAPER,true,true)
 var cycle='Troca: 1 energia' if player.hand.size()==game.rules.MAX_HAND else 'Compra em %d s'%ceili(game.RIVAL_SECONDS-game.support_elapsed)
 if player.deck.is_empty():cycle='Sem cartas'
 text(cycle,Rect2(box.position+Vector2(0,line*2),Vector2(box.size.x,line)),fs,PAPER,true)
 text('Mão %d/%d · reuso %d s'%[player.hand.size(),game.rules.MAX_HAND,game.rules.REUSE_SECONDS],Rect2(box.position+Vector2(0,line*3),Vector2(box.size.x,line)),fs,PAPER,true)

func oval(rect: Rect2,fill: Color,edge: Color,width: float) -> void:
 var points=PackedVector2Array()
 for i in range(64):
  var angle=i*TAU/64
  points.append(rect.get_center()+Vector2(cos(angle)*rect.size.x/2,sin(angle)*rect.size.y/2))
 if fill.a>0:canvas.draw_colored_polygon(points,fill)
 points.append(points[0])
 canvas.draw_polyline(points,edge,width,true)

func badge(center: Vector2,value: String,color: Color,radius=21.0) -> void:
 canvas.draw_circle(center,radius+2,Color('312317'));canvas.draw_circle(center,radius,color);canvas.draw_arc(center,radius,0,TAU,36,Color('e8d7a6'),2)
 text(value,Rect2(center-Vector2(radius,radius*0.77),Vector2(radius*2,radius*1.6)),int(radius*1.3),Color.WHITE,true,true)

var heart=PackedVector2Array([Vector2(0,24),Vector2(-21,4),Vector2(-24,-6),Vector2(-21,-16),Vector2(-12,-20),Vector2(-5,-18),Vector2(0,-12),Vector2(5,-18),Vector2(12,-20),Vector2(21,-16),Vector2(24,-6),Vector2(21,4)])
var shield=PackedVector2Array([Vector2(-22,-18),Vector2(0,-23),Vector2(22,-18),Vector2(19,6),Vector2(12,17),Vector2(0,25),Vector2(-12,17),Vector2(-19,6)])

func hero_stat(at: Vector2,value: int,armor: bool) -> void:
 canvas.draw_set_transform(at)
 var shape=shield if armor else heart
 canvas.draw_colored_polygon(shape,Color('355177') if armor else Color('9c2036'))
 canvas.draw_polyline(shape,Color('f6dfb5'),2,true)
 canvas.draw_line(shape[-1],shape[0],Color('f6dfb5'),2,true)
 text(str(value),Rect2(-22,-16,44,32),23,Color.WHITE,true,true)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func paint_battle() -> void:
 var state=game.rules
 var plate=Rect2(layout.w*0.012,layout.h*0.01,layout.w*0.202,layout.h*0.078)
 var name_size=int(minf(plate.size.x*0.155,plate.size.y*0.34))
 paint_next_card(state.players[0])
 text('Jogador 2',plate,name_size,Color.WHITE,true,true)
 text('Clã das Sombras',Rect2(plate.position+Vector2(0,name_size*1.35),plate.size),int(name_size*0.65),PAPER,true,true)
 for side in range(2):
  for slot in range(state.players[side].supports.size()):
   var support=state.players[side].supports[slot]
   var rect: Rect2=layout.supports[slot] if side==0 else layout.enemy_supports[slot]
   var label='Defesa' if support.defense else 'Ataque'
   if support.id!='':
    var card=game.cards[support.id]
    var picture=slice(creatures if card.kind=='minion' else spells,int(card.art),5 if card.kind=='minion' else 4,5 if card.kind=='minion' else 4)
    var inset=Rect2(rect.position+rect.size*0.15,rect.size*0.70)
    draw_card_picture(picture,inset)
   if side==0 and slot==game.pending_support:
    canvas.draw_rect(rect,Color('ffdb65'),false,3,true)
   var icon=rect.position+rect.size*Vector2(0.18,0.19)
   canvas.draw_circle(icon,12,Color('292332'))
   if support.defense:
    canvas.draw_colored_polygon(PackedVector2Array([icon+Vector2(-7,-6),icon+Vector2(7,-6),icon+Vector2(6,3),icon+Vector2(0,9),icon+Vector2(-6,3)]),Color('91d9ff'))
   else:
    canvas.draw_line(icon+Vector2(-6,7),icon+Vector2(6,-7),Color('ffd398'),3,true)
    canvas.draw_line(icon+Vector2(-6,0),icon+Vector2(1,6),Color('ffd398'),3,true)
   if support.id!='':
    var timer=Rect2(rect.position+Vector2(rect.size.x*0.46,2),Vector2(rect.size.x*0.51,22))
    canvas.draw_rect(timer,Color('292332'))
    text('%d s'%ceili(game.RIVAL_SECONDS-game.support_elapsed),timer,15,PAPER,true)
   if support.get('trap','')!='':
    paint_trap_back(armed_trap_rect(rect))
    if support.id=='':label='Armadilha'
   var strip=Rect2(rect.position+rect.size*Vector2(0.06,0.72),rect.size*Vector2(0.88,0.23))
   canvas.draw_style_box(style(Color('312238'),GOLD,5,1),strip)
   text(label,strip,int(minf(strip.size.y*0.70,strip.size.x*0.16)),PAPER,true,true)
 for hero in hero_views:
  var p=state.players[int(hero.side)]
  hero_stat(hero.rect.position+hero.rect.size*Vector2(0.84,0.86),p.health,false)
  hero_stat(hero.rect.position+hero.rect.size*Vector2(0.16,0.86),p.armor,true)
 for uid in unit_views:
  var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect);var unit=info.unit
  canvas.draw_rect(rect.grow(-2),Color('e5bd70'),false,1,true)
  fx.status(unit,rect)
  if unit.attacks==0 and unit.delay>0:
   radial_cooldown(rect.position+rect.size*Vector2(0.78,0.2),rect.size.x*0.11,unit.delay)
  elif info.side==0 and unit.attacks>0 and state.effective_attack(info.side,unit)>0 and not game.target_locked({'side':0,'uid':uid}):
   var tag=Rect2(rect.position+Vector2(0,-2),Vector2(rect.size.x,19))
   canvas.draw_rect(tag,Color('234d3a'))
   text('ATACAR',tag,14,Color('b7ffce'),true,true)
  if unit.shield:
   oval(rect.grow(7),Color(1,0.9,0.4,0.08),Color(1,0.9,0.4,0.8),3)
   oval(rect.grow(11),Color.TRANSPARENT,Color(1,0.9,0.4,0.25),5)
  if unit.frozen>0 or unit.get('frozen_lock',false):
   canvas.draw_style_box(style(Color(0.2,0.75,1,0.15),Color('94e6ff'),30,3),rect.grow(4))
  if unit.sleeping and unit.attacks==0: text('Z',Rect2(rect.end-Vector2(14,rect.size.y-2),Vector2(30,30)),22,Color('c3dcec'),true,true)
  if 'windfury' in unit.keywords: text('↟',Rect2(rect.position-Vector2(7,20),Vector2(30,30)),20,GOLD,true)
  var radius=minf(rect.size.x*0.18,rect.size.y*0.15)
  var attack_value=state.effective_attack(info.side,unit)
  var attack_color=Color('287254') if attack_value>unit.attack else Color('845018')
  badge(Vector2(rect.position.x+radius+2,rect.end.y-radius-2),str(attack_value),attack_color,radius)
  badge(rect.end-Vector2.ONE*(radius+2),str(unit.health),Color('922a38'),radius)
 var opening=observed_match!=game.match_serial
 if opening:
  observed_match=game.match_serial
  ready_mask=0
  pulse_ends.fill(0)
  energy_pulse_end=0
 for hand in hand_views:
  if game.drag.get('kind','')=='card' and game.drag.index==hand.index: continue
  var remaining=float(state.players[0].cooldowns.get(hand.index,0))
  var card=game.cards[hand.id]
  var ready=hand.ready
  var bit=1<<int(hand.index)
  if ready:
   if not opening and (ready_mask & bit)==0:
    pulse_ends[hand.index]=clock+0.6
   ready_mask|=bit
  else:ready_mask &= ~bit
  if ready and pulse_ends[hand.index]>clock:
   canvas.draw_rect(hand.rect.grow(3),Color(0.65,1,0.82,(pulse_ends[hand.index]-clock)/0.6),false,5,true)
  if remaining>0:
   var center=hand.rect.position+hand.rect.size*Vector2(0.5,0.38)
   var radius=hand.rect.size.x*0.16
   radial_cooldown(center,radius,remaining)
  elif ready:canvas.draw_rect(hand.rect,Color('8be6ae'),false,2,true)
  elif card.cost<=state.players[0].mana:
   var reason='Campo cheio' if hand.full else 'Sem alvo'
   text(reason,Rect2(hand.rect.position+hand.rect.size*Vector2(0,0.72),hand.rect.size),maxi(9,int(hand.rect.size.x*0.12)),PAPER,true,true)
  if float(hand_lifts.get(hand.index,0))>0.05:fx.aura(hand.id,hand.rect,float(hand_lifts[hand.index]))
 if game.drag.is_empty():
  if game.selected_card>=0:
   paint_targets({'kind':'card','index':game.selected_card,'id':state.players[0].hand[game.selected_card]})
  elif game.selected_attacker>=0:paint_targets({'kind':'unit','uid':game.selected_attacker})
 if not game.reduced_motion:fx.trail()
 if not game.drag.is_empty():
  paint_targets(game.drag)
  if game.drag.kind=='card':paint_drop_preview()
  if game.drag.kind=='card':
   var held_rect=held_card_rect()
   paint_card(game.drag.id,held_rect)
   fx.aura(game.drag.id,held_rect,1.0)

  else: arrow(game.drag.origin,game.pointer,Color('ed694a'))
  var preview=drag_preview()
  if not preview.is_empty():
   var at=target_center(preview.target)
   var label_rect=Rect2(at-Vector2(83,40),Vector2(166,35))
   canvas.draw_style_box(style(Color('292332'),GOLD,8,2),label_rect)
   text(preview.text,label_rect,23,Color('a7f4bf') if preview.text.begins_with('+') else Color('ffb69c'),true,true)
 for anim in game.active_actions:
  var anim_time=anim.age
  if not game.reduced_motion and anim.kind=='card' and anim_time<0.62:
   var size=Vector2(170,255)
   var at=anim.origin.lerp(anim.destination,clampf(anim_time/0.6,0,1))
   paint_card(anim.id,Rect2(at-size/2,size),0,Color(1,1,1,clampf(1-anim_time/0.85,0,1)))
  if not game.reduced_motion:fx.action(anim,anim_time)
 for reveal in trap_reveals:paint_trap_reveal(reveal)
 var p=state.players[0]
 if p.health<=10:
  var strength=0.10+0.05*sin(clock*3.0)
  for band in range(10):
   canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size).grow(-band*3.0),Color(0.9,0.02,0.04,strength*(1-band/10.0)*3),false,3.1)
 if not opening and p.mana>previous_mana:energy_pulse_end=clock+0.6
 previous_mana=p.mana
 var bar=energy_bar()
 var bar_width=bar.size.x
 canvas.draw_style_box(style(Color('181027'),Color('bd904a'),8,2),bar)
 if energy_pulse_end>clock:
  canvas.draw_rect(bar.grow(2),Color(0.58,0.90,1,(energy_pulse_end-clock)/0.6),false,5,true)
 var cells=Rect2(bar.position+Vector2(bar_width*0.42,5),Vector2(bar_width*0.55,bar.size.y-10))
 var charge=float(p.mana)+game.energy_elapsed/game.ENERGY_SECONDS
 for i in range(int(p.max_mana)):
  var cell=Rect2(cells.position+Vector2(cells.size.x*i/p.max_mana,0),Vector2(cells.size.x/p.max_mana-2,cells.size.y))
  canvas.draw_rect(cell,Color('302c4b'))
  canvas.draw_rect(Rect2(cell.position,Vector2(cell.size.x*clampf(charge-i,0,1),cell.size.y)),Color('53b6ff'))
 text('Energia  %d/%d' % [p.mana,p.max_mana],Rect2(bar.position+Vector2(3,1),Vector2(bar_width*0.41,bar.size.y)),int(bar.size.y*0.57),PAPER,true,true)

func energy_bar() -> Rect2:
 var width=minf(layout.w*0.76,540.0)
 return Rect2((layout.w-width)/2,layout.h*0.954,width,clampf(layout.h*0.04,29,48))

func line_glow(a: Vector2,b: Vector2,color: Color,width=3.0) -> void:
 canvas.draw_line(a,b,Color(color,0.14),width*5)
 canvas.draw_line(a,b,Color(color,0.5),width*2)
 canvas.draw_line(a,b,color.lightened(0.5),width)

func paint_drop_preview() -> void:
 var player=game.rules.players[0]
 var index=int(game.drag.index)
 var card=game.cards[game.drag.id]
 if player.cooldowns.has(index) or card.cost>player.mana:return
 var rim=Color(0.55,1,0.76,0.8)
 var landing=Rect2()
 var support=game.support_at(game.pointer)
 for slot in range(layout.supports.size()):
  if game.rules.can_equip_support(slot,index).ok:canvas.draw_rect(layout.supports[slot],rim,false,3,true)
 if support>=0:
  if not game.rules.can_equip_support(support,index).ok:return
  landing=layout.supports[support]
 elif card.kind=='minion' and game.rules.can_play(0,index).ok:
  var count=player.board.size()
  var first=floori((game.rules.MAX_BOARD-count-1)/2.0)
  for offset in range(count+1):
   canvas.draw_rect(layout.slots[0][first+offset],rim,false,3,true)
  if layout.player_drop.has_point(game.pointer):
   landing=layout.slots[0][first+game.drop_position(game.pointer)]
 elif card.kind=='spell':
  var target=game.target_at(game.pointer)
  if game.rules.can_play(0,index,target).ok and (card.get('target','none')=='none' or not game.target_locked(target)):
   if card.get('target','none')=='none':
    canvas.draw_rect(layout.board_zone,rim,false,3,true)
   if not target.is_empty() or layout.board_zone.has_point(game.pointer):
    var center=target_center(target) if not target.is_empty() else game.pointer
    landing=Rect2(center-layout.slot_sizes[0]/2,layout.slot_sizes[0])
 if landing.has_area():
  canvas.draw_rect(landing,Color(0.04,0.09,0.11,0.68))
  canvas.draw_rect(landing,rim,false,4,true)
  var creature=card.kind=='minion'
  var picture=slice(creatures if creature else spells,int(card.art),5 if creature else 4,5 if creature else 4)
  draw_card_picture(picture,landing.grow(-4),Color(1,1,1,0.40))

func paint_targets(selection: Dictionary) -> void:
 var candidates=[]
 for uid in unit_views:candidates.append({'side':unit_views[uid].side,'uid':uid})
 for side in range(2):candidates.append({'side':side,'hero':true})
 for target in candidates:
  if game.target_locked(target):continue
  var valid=false
  if selection.kind=='card' and game.cards[selection.id].get('target','none')!='none':valid=game.rules.can_play(0,int(selection.index),target).ok
  elif selection.kind=='unit':valid=game.rules.can_attack(0,int(selection.uid),target).ok
  elif selection.kind=='power':valid=game.rules.can_power(0,target).ok
  if valid:
   var center=target_center(target)
   canvas.draw_arc(center,67 if game.portrait else 72,0,TAU,48,Color(1,0.87,0.45,0.65+sin(clock*7)*0.2),4)

func element_color(element: String) -> Color:
 return {'fire':Color('ff8a40'),'ice':Color('7edcff'),'lightning':Color('91bdff'),'storm':Color('c49aff'),'nature':Color('85db71'),'heal':Color('8be6ae'),'dark':Color('a085e8'),'shield':Color('ffe39b'),'bite':Color('ffb79c'),'steel':Color('ffdd8f'),'earth':Color('c4a16d')}.get(element,Color('b28bff'))

func arrow(a: Vector2,b: Vector2,color: Color) -> void:
 var last=a
 for i in range(20):
  var t=(i+1)/20.0
  var p=a.lerp(b,t)+Vector2(0,-sin(t*PI)*40)
  canvas.draw_line(last,p,Color(0.12,0.04,0.02,0.5),9);canvas.draw_line(last,p,color,5);last=p
 var direction=(b-a).normalized();var normal=direction.orthogonal()
 canvas.draw_colored_polygon(PackedVector2Array([b,b-direction*24+normal*13,b-direction*24-normal*13]),color)

func draw_float(f: Dictionary) -> void:
 var pos=f.position-Vector2(0,55+(0 if game.reduced_motion else f.age*47))
 text(f.text,Rect2(pos-Vector2(140,10),Vector2(280,50)),22 if f.text.length()>8 else 34,Color(f.color,clampf(1.6-f.age,0,1)),true,true)

func paint_home() -> void:
 var x=layout.w/2-245 if game.portrait else 150.0
 var top=layout.h*0.15 if game.portrait else layout.h*0.16
 text('D U N G E O N   C A R D S',Rect2(x,top,490,35),18,GOLD,true)
 text('Duelos da\nTaverna',Rect2(x,top+48,490,150),48,PAPER,true,true)
 wrapped('Invoque criaturas. Escolha seus alvos.\nCada carta muda o tabuleiro.'.replace('\n',' '),Rect2(x+30,top+190,430,75),20,PAPER,true)
 var positions=[Vector2(layout.w/2-185,layout.h*0.46),Vector2(layout.w/2,layout.h*0.43),Vector2(layout.w/2+185,layout.h*0.46)] if game.portrait else [Vector2(layout.w*0.65,layout.h*0.5),Vector2(layout.w*0.79,layout.h*0.43),Vector2(layout.w*0.91,layout.h*0.52)]
 for i in range(3): paint_card(['treant','dragon','fireball'][i],Rect2(positions[i]-Vector2(100,150),Vector2(200,300)),(i-1)*0.1)
 text('%d / 30 cartas no baralho' % game.profile.deck.size(),Rect2(x,layout.h*0.60 if game.portrait else layout.h*0.51,490,30),19,GOLD,true)
 text('%d moedas  ·  %d vitórias' % [game.profile.coins,game.profile.wins],Rect2(25,layout.h-50,layout.w-50,30),17,PAPER,true)

func paint_collection() -> void:
 text('Seu grimório',Rect2(layout.w/2-230,35,460,50),35,PAPER,true,true)
 text('%d / 30 cartas · até 2 cópias · lendárias únicas' % game.profile.deck.size(),Rect2(50,100,layout.w-100,35),19,GOLD,true)
 text('Segure para ler · toque para adicionar · use REMOVER para retirar',Rect2(50,133,layout.w-100,25),16,PAPER,true)
 for item in collection_views:
  paint_card(item.id,item.rect)
  var count=game.profile.deck.count(item.id)
  text(('− REMOVER ×'+str(count)) if count>0 else 'TOQUE PARA ADICIONAR',Rect2(item.rect.position+Vector2(-5,item.rect.size.y+4),Vector2(item.rect.size.x+10,26)),14,Color('a9e0b3') if count else PAPER,true)

func paint_button(info: Dictionary) -> void:
 if not game.panel.is_empty() and info.id not in ['mute','speed','motion','close','credits','home']: return
 var rect: Rect2=info.rect
 var enabled=info.enabled
 var primary=info.primary
 if info.id=='solar':
  var bar=energy_bar()
  canvas.draw_style_box(style(Color('703515'),Color('ffce60').lerp(Color.WHITE,0.25+0.2*sin(clock*4)),8,2),bar)
  var spacing=(bar.size.x-12)/game.rules.players[0].max_mana
  for i in range(game.rules.players[0].max_mana):
   canvas.draw_rect(Rect2(bar.position.x+6+i*spacing,bar.end.y-6,spacing-2,3),GOLD)
  if energy_pulse_end>clock:canvas.draw_rect(bar.grow(2),Color(1,0.85,0.5,(energy_pulse_end-clock)/0.6),false,4,true)
  text('10/10   ·   '+info.label,Rect2(bar.position+Vector2(0,1),bar.size),int(bar.size.y*0.58),Color('fff0ba'),true,true)
  return
 if info.id=='power':
  canvas.draw_texture_rect(slice(spells,0,4,4),rect,false)
  badge(rect.position+rect.size*Vector2(0.81,0.83),'2',Color('287cb2') if enabled else Color('414054'),12)
  return
 var fill=Color('c9a362') if primary else Color('382a25')
 if not enabled:fill=fill.darkened(0.35)
 canvas.draw_style_box(style(fill,Color('e0c185') if enabled else Color('7f7162'),12,3),rect)
 canvas.draw_line(rect.position+Vector2(12,5),rect.position+Vector2(rect.size.x-12,5),Color(1,0.92,0.65,0.35),2)
 var font_size=25 if primary else 19
 if info.id=='settings': font_size=28
 if info.id=='power': font_size=13
 var lines=info.label.split('\n').size()
 var y=rect.position.y+(rect.size.y-font_size*1.16*lines)/2
 text(info.label,Rect2(rect.position.x+6,y,rect.size.x-12,rect.size.y),font_size,Color('35251b') if primary else PAPER,true,true)

func paint_panel() -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size),Color(0.01,0.02,0.04,0.70))
 var rect=panel_rect()
 canvas.draw_style_box(style(Color('17202b'),Color('b49b6e'),20),rect)
 if game.panel=='settings':text('Configurações',Rect2(rect.position+Vector2(25,35),Vector2(rect.size.x-50,45)),30,PAPER,true,true)
 elif game.panel=='credits':
  text('Créditos de áudio',Rect2(rect.position+Vector2(25,35),Vector2(rect.size.x-50,45)),28,PAPER,true,true)
  wrapped('Dark Descent — Matthew Pablo, matthewpablo.com. CC BY 3.0. Música convertida e normalizada.\n\nEfeitos elementais — leohpaz, CC BY 4.0. Impactos e criaturas — rubberduck e artisticdude, CC0.\n\nFontes, links e alterações estão descritos no projeto.'.replace('\n',' '),Rect2(rect.position+Vector2(45,110),Vector2(rect.size.x-90,340)),21,PAPER)
 elif game.panel=='result':
  var result=game.rules.outcome
  var center=rect.position+Vector2(rect.size.x/2,85)
  var medal_color=GOLD if result=='win' else Color('92bdd7')
  var reveal=1.0 if game.reduced_motion else smoothstep(0,0.5,result_time)
  center.y+=(1-reveal)*(-32 if result=='win' else 28)
  fx.c=canvas;fx.ring(center,32+16*reveal,medal_color,0.8,0 if game.reduced_motion else result_time*0.3)
  if result=='lose':
   for side in [-1,1]:
    var start=center+Vector2(side*48,0)
    canvas.draw_polyline(PackedVector2Array([start,start+Vector2(side*18,10)*reveal,start+Vector2(side*28,4)*reveal,start+Vector2(side*49,22)*reveal]),medal_color,3,true)
  text('★' if result=='win' else '✦',Rect2(center-Vector2(30,36),Vector2(60,65)),49,medal_color,true,true)
  text('VITÓRIA!' if result=='win' else 'EMPATE' if result=='draw' else 'DERROTA',Rect2(rect.position+Vector2(35,160),Vector2(rect.size.x-70,65)),48,medal_color,true,true)
  text('A taverna celebra seu triunfo.' if result=='win' else 'Uma nova estratégia espera por você.',Rect2(rect.position+Vector2(25,242),Vector2(rect.size.x-50,35)),20,PAPER,true)
  var coins=50 if result=='win' else 10 if result=='draw' else 5
  var xp=35 if result=='win' else 12 if result=='draw' else 8
  for i in range(2):
   if not game.reduced_motion and result_time<0.32+i*0.12:continue
   var reward=Rect2(rect.position+Vector2(60+i*230,302),Vector2(210,77))
   canvas.draw_style_box(style(Color('24303a'),Color('6f654f'),12),reward)
   text(('+'+str(coins)+' MOEDAS') if i==0 else ('+'+str(xp)+' XP'),Rect2(reward.position+Vector2(5,23),reward.size-Vector2(10,20)),24,GOLD if i==0 else Color('a3daff'),true,true)
  if result=='win' and not game.reduced_motion:
   for i in range(12):
    var point=rect.position+Vector2(30+fposmod(i*43.0+sin(clock+i)*10,rect.size.x-60),fposmod(result_time*40+i*37,rect.size.y-130))
    canvas.draw_circle(point,2.5,Color(GOLD,0.6))
 for button_info in buttons:
  if button_info.id in ['mute','speed','motion','close','credits'] or game.panel=='result' and button_info.id=='home': paint_button(button_info)
