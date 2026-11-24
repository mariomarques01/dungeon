extends RefCounted
const GOLD=Color('eac67e')
const PAPER=Color('f1dfb6')
const INK=Color('30251e')
const HEAVY_DAMAGE=5
const CRITICAL_DAMAGE=8
const HIT_FLASH_SECONDS=0.055
const HIT_RECOIL_SECONDS=0.28
const COLLECTION_LIBRARY=preload("res://tavern_assets/collection/library.jpg")
# The upper arch and floor absorb extra height while the frame reaches both edges.
const COLLECTION_STRETCH_BANDS=[Vector2(50,300),Vector2(740,1190)]
const COLLECTION_CONTROLS=preload("res://tavern_assets/collection/controls.jpg")
const COLLECTION_SPRITES={
 'heading':Rect2(22,13,597,196),
 'home':Rect2(643,83,297,91),
 'filter':Rect2(955,83,299,91),
 'add':Rect2(64,405,553,100),
 'remove':Rect2(662,404,555,101),
 'previous':Rect2(25,545,317,87),
 'reset_deck':Rect2(355,539,573,106),
 'next':Rect2(941,546,315,87),
 'instructions':Rect2(29,314,860,54),
}
const COLLECTION_BUTTON_EDGE=[
 Vector2(0.07,0.02),Vector2(0.93,0.02),Vector2(0.98,0.13),Vector2(0.998,0.31),
 Vector2(0.998,0.70),Vector2(0.98,0.89),Vector2(0.93,0.98),Vector2(0.07,0.98),
 Vector2(0.02,0.89),Vector2(0.002,0.70),Vector2(0.002,0.31),Vector2(0.02,0.13),
]
# Outline of the crest on the supplied control sheet, in normalized coordinates.
const COLLECTION_HEADING_EDGE=[
 Vector2(0.01,0.42),Vector2(0.061,0.17),Vector2(0.106,0.16),Vector2(0.156,0.125),
 Vector2(0.191,0.173),Vector2(0.385,0.16),Vector2(0.47,0.077),Vector2(0.5,0.009),
 Vector2(0.554,0.111),Vector2(0.631,0.17),Vector2(0.816,0.174),Vector2(0.861,0.124),
 Vector2(0.885,0.16),Vector2(0.943,0.17),Vector2(0.988,0.42),Vector2(0.952,0.75),
 Vector2(0.9,0.881),Vector2(0.84,0.864),Vector2(0.625,0.88),Vector2(0.543,0.925),
 Vector2(0.5,0.987),Vector2(0.45,0.925),Vector2(0.387,0.88),Vector2(0.184,0.856),
 Vector2(0.102,0.879),Vector2(0.053,0.758),
]
const HOME_ART=preload("res://tavern_assets/menu/home.jpg")
const HOME_PORTAL=preload("res://tavern_assets/menu/portal.jpg")
const HOME_ASSETS=preload("res://tavern_assets/menu/menu_assets.jpg")
const HOME_BUTTONS=[
 ['start','Jogar Duelo',Rect2(227,485,505,131)],
 ['collection','Coleção de Cartas',Rect2(254,629,452,96)],
 ['rewards','Recompensas',Rect2(255,736,450,80)],
 ['missions','Missões',Rect2(256,829,448,81)],
 ['shop','Loja',Rect2(254,920,453,82)],
 ['settings','Configurações',Rect2(255,1011,451,83)],
]
# Only the sky, the gap above the menu and the floor absorb extra height.
const HOME_STRETCH_BANDS=[Vector2(32,98),Vector2(436,481),Vector2(1101,1239)]
const HOME_PANELS={'rewards':'Recompensas','missions':'Missões','shop':'Loja'}
const ArenaRoom=preload("res://scripts/tavern_environment.gd")
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

var bursts: Array[CPUParticles2D]=[]
var torches: Array[CPUParticles2D]=[]
var next_burst=0
var impact_bursts: Array[CPUParticles2D]=[]
var next_impact_burst=0
var hit_until=[0.0,0.0]
var hero_hit_atlas: Array[AtlasTexture]=[]
var hero_hit_materials: Array[ShaderMaterial]=[]
var river_until=0.0
var river_x=0.5
var crowd_until=0.0
var sun_until=0.0
var reflow: Tween
var reflow_from=[]
var reflow_progress=1.0

func emitter(count: int,continuous: bool) -> CPUParticles2D:
 var node=CPUParticles2D.new()
 node.emitting=false
 node.amount=count
 node.one_shot=not continuous
 node.lifetime=0.65 if continuous else 0.42
 node.explosiveness=0.0 if continuous else 1.0
 node.direction=Vector2.UP
 node.spread=22 if continuous else 100
 node.gravity=Vector2(0,-12 if continuous else 120)
 node.initial_velocity_min=25 if continuous else 65
 node.initial_velocity_max=55 if continuous else 145
 node.scale_amount_min=2
 node.scale_amount_max=5
 node.fixed_fps=30
 node.z_index=1 if continuous else 89
 node.visible=false
 if not continuous:node.finished.connect(node.hide)
 game.art_layer.add_child(node)
 return node

func play_burst(node: CPUParticles2D,at: Vector2,color: Color) -> void:
 node.position=at
 node.color=color
 node.speed_scale=game.speed
 node.show()
 node.restart()

func impact_burst(at: Vector2,color: Color) -> void:
 if game.reduced_motion:return
 if impact_bursts.size()<12:impact_bursts.append(emitter(12,false))
 play_burst(impact_bursts[next_impact_burst],at,color)
 next_impact_burst=(next_impact_burst+1)%12

func burst(at: Vector2,color: Color) -> void:
 if game.reduced_motion:return
 if bursts.size()<6:bursts.append(emitter(9,false))
 var node=bursts[next_burst]
 next_burst=(next_burst+1)%6
 play_burst(node,at,color)

func update_burst_speed() -> void:
 for group in [bursts,impact_bursts]:
  for node in group:node.speed_scale=game.speed

func stop_motion() -> void:
 room.reset_motion()
 if reflow:reflow.kill()
 reflow_progress=1.0
 reflow_from.clear()
 hand_lifts.clear()
 pointer_trail.clear()
 energy_pulse_end=0
 pulse_ends.fill(0)
 hit_until.fill(0)
 river_until=0
 crowd_until=0
 sun_until=0
 for group in [bursts,impact_bursts,torches]:
  for node in group:
   node.emitting=false
   node.hide()
 freeze_left=0
 shake_left=0
 shake_strength=0
 deal_started.clear()
 for node in auras:node.hide()

func set_match_paused(paused: bool) -> void:
 if paused:frame_delta=0.0
 if reflow and reflow.is_valid():
  if paused:reflow.pause()
  else:reflow.play()

func battle_delta(delta: float) -> float:
 if game.reduced_motion:
  freeze_left=0.0
  return delta
 var held=minf(freeze_left,delta)
 freeze_left-=held
 return delta-held

func camera_offset() -> Vector2:
 if shake_left<=0 or game.reduced_motion:return Vector2.ZERO
 return Vector2(sin(shake_left*126),sin(shake_left*93))*shake_strength*(shake_left/0.17)

func banner(message: String) -> void:
 if banners.is_empty():banner_left=1.3
 if message not in banners:banners.append(message)

func impact_stretch(rect: Rect2,progress: float) -> Rect2:
 # Start compressed, stretch on the rebound, then settle.
 return stretch(rect,-0.18*cos(progress*TAU)*(1-progress))

func stretch(rect: Rect2,amount: float) -> Rect2:
 var size=rect.size*Vector2(1.0-amount,1.0+amount)
 return Rect2(Vector2(rect.get_center().x-size.x/2,rect.end.y-size.y),size)

var scenery=[]
var fragment_cache={}
var styles={}
var text_layouts={}
var room: ArenaRoom
var arena_layer: Node2D
var base_layer: Node2D
var arena_size=Vector2.ZERO
var arena_screen=''
const SLOT_ZOOM=1.22
const SLOT_COLUMNS=[89,141,192,243,295]
const ROYAL_ARENA = preload("res://tavern_assets/royal/arena.webp")
const HAND_FRAME = preload("res://tavern_assets/royal/hand-frame.webp")
var creatures: Texture2D
var spells: Texture2D
var frames: Texture2D
var atlas_cache={}
var nodes={}
var free_art: Array[TextureRect]=[]
var used={}
var hand_shader=Shader.new()
var shader: Shader
var hit_flash: ShaderMaterial
var frozen_portrait: ShaderMaterial
var layout={}
var hand_views=[]
var unit_views={}
var hero_views=[]
var buttons=[]
var collection_views=[]
# The scene owns these CanvasItems. Only active effects request redraws.
class BaseLayer extends Node2D:
 var owner_view: WeakRef
 var terrain=false

 func _draw() -> void:
  var view=owner_view.get_ref()
  if view==null:return
  if terrain:view.paint_terrain(self)
  else:view.paint_base(self)

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
   &"remains":
    if not view.game.reduced_motion:view.draw_remains(record)
  view.canvas=previous

class AuraSprite extends Node2D:
 var owner_view: WeakRef
 var card_id=''
 var bounds=Rect2()
 var phase=0.0
 var next_draw=0.0

 func _draw() -> void:
  var view=owner_view.get_ref()
  if view==null:return
  var previous=view.canvas
  view.canvas=self
  view.fx.aura(card_id,bounds,1.0,phase)
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
  rotation=hand.angle
  position=hand.rect.get_center()-(hand.rect.size/2).rotated(rotation)
  if card_id==hand.id and card_size==hand.rect.size and ready==available and affordable==can_pay:return
  card_id=hand.id
  card_size=hand.rect.size
  available=ready
  affordable=can_pay
  material.set_shader_parameter('muted',not affordable)
  queue_redraw()

 func _draw() -> void:
  var view=owner_view.get_ref()
  if view==null:return
  var previous=view.canvas
  view.canvas=self
  view.paint_hand_card({'id':card_id,'rect':Rect2(Vector2.ZERO,card_size)},available)
  view.canvas=previous

const HAND_EFFECTS={
 "scout": "Goblin",
 "stoneguard": "Provocar",
 "wolf": "Alcateia",
 "apprentice": "Feitiços +1",
 "drake": "Entrada · 1 dano",
 "shieldbearer": "Provocar",
 "dryad": "Cura 3 PV",
 "beetle": "Escudo Divino",
 "orc": "Orc",
 "firelord": "Área · 2 dano",
 "frostling": "Congela 1",
 "treant": "Provocar",
 "knight": "Guarda e escudo",
 "necro": "Invoca esqueletos",
 "skeleton": "Mortos-vivos",
 "golem": "Provocar",
 "familiar": "Dois ataques",
 "serpent": "Veneno",
 "dragon": "Área · 2 dano",
 "archmage": "Feitiços +2",
 "demon": "Área · 3 dano",
 "phoenix": "Roubo de vida",
 "wyrm": "Congela todos",
 "fireball": "6 de dano",
 "bolt": "2 de dano",
 "healing": "Cura 5 PV",
 "frost": "2 dano + gelo",
 "meteor": "Área · 4 dano",
 "barrier": "6 de armadura",
 "missiles": "3 mísseis",
 "wisdom": "Compra 2",
 "roots": "−2 ATQ · compra 1",
 "blessing": "+2 ATQ / +2 PV",
 "vortex": "Destrói 1",
 "pack": "Invoca 2 lobos",
 "thunderstorm": "Área · 3 dano",
 "blizzard": "Área · 2 + gelo",
 "rune_blade": "+3 ATQ",
 "crystal": "+1 energia",
 "token_skeleton": "Mortos-vivos",
 "token_wolf": "Provocar",
 "token_guard": "Recruta",
 "trap_bulwark": "Ataque · +3 ARM",
 "trap_spikes": "Ataque · 2 dano",
 "trap_runes": "Feitiço · +3 ARM",
 "trap_spring": "Feitiço · cura 2",
 "trap_embers": "PV < 10 · cura 4",
 "trap_last_stand": "PV < 7 · +5 ARM"
}

var hand_faces: Array[HandFace]=[]

func prepare_hand_faces() -> void:
 for hand in hand_views:
  if hand.index>=hand_faces.size():
   var face=HandFace.new()
   face.material=ShaderMaterial.new()
   face.material.shader=hand_shader
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

var free_effects={&"particle":[],&"remains":[]}
var free_numbers: Array[Label]=[]
var auras: Array[AuraSprite]=[]
var aura_count=0

func prepare_aura(id: String,rect: Rect2,strength: float,phase=0.0,angle=0.0) -> void:
 if aura_count==auras.size():
  var new_aura=AuraSprite.new()
  new_aura.owner_view=weakref(self)
  new_aura.z_index=99
  game.art_layer.add_child(new_aura)
  auras.append(new_aura)
 var aura=auras[aura_count]
 aura_count+=1
 var bounds=Rect2(-rect.size/2,rect.size)
 aura.position=rect.get_center()
 aura.rotation=angle
 aura.modulate.a=strength
 if not aura.visible or id!=aura.card_id or bounds!=aura.bounds or clock>=aura.next_draw:
  aura.card_id=id
  aura.bounds=bounds
  aura.phase=phase
  aura.next_draw=clock+1.0/30
  aura.queue_redraw()
 aura.show()

func prepare_auras() -> void:
 aura_count=0
 if game.screen=='battle' and not game.reduced_motion:
  for hand in hand_views:
   if game.drag.get('kind','')=='card' and game.drag.index==hand.index:continue
   var lift=float(hand_lifts.get(hand.index,0))
   if lift>0.05:prepare_aura(hand.id,hand.rect,lift,0,hand.angle)
  if game.drag.get('kind','')=='card':
   prepare_aura(game.drag.id,held_card_rect(),1.0)
  for action in game.active_actions:
   var age: float=action.age
   if action.kind=='attack':
    var frame=Rect2(action.origin-Vector2(53,65),Vector2(106,130))
    var uid=int(action.get('uid',-1))
    if unit_views.has(uid):frame=unit_views[uid].draw_rect
    prepare_aura(action.id,frame,0.9,age)
   elif action.kind=='card' and age<0.62:
    var at: Vector2=action.origin.lerp(action.destination,clampf(age/0.6,0,1))
    prepare_aura(action.id,Rect2(at-Vector2(85,127),Vector2(170,255)),1.0,age)
  for particle in particles:
   if not particle.has('response_id'):continue
   var strength=0.0
   if particle.kind=='damage':strength=(1-particle.age/0.65)*0.85
   elif particle.kind in ['blocked','shield_break']:strength=1-particle.age/1.15
   if strength>0:
    prepare_aura(particle.response_id,Rect2(particle.position-Vector2(50,62),Vector2(100,124)),strength,particle.age)
 for i in range(aura_count,auras.size()):auras[i].hide()

func add_number(record: Dictionary) -> void:
 var label: Label
 if free_numbers.is_empty():
  label=Label.new()
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_override('font',game.title_font)
  label.add_theme_constant_override('shadow_offset_x',1)
  label.add_theme_constant_override('shadow_offset_y',1)
  label.z_index=90
  game.art_layer.add_child(label)
 else:label=free_numbers.pop_back()
 record.sprite=label
 floats.append(record)
 animate_number(record)
 label.show()

func animate_number(record: Dictionary) -> void:
 if record.has('tween'):record.tween.kill()
 var label: Label=record.sprite
 var font_size=22 if record.text.length()>8 else 34
 var color: Color=record.color
 if record.get('kind','')=='damage':
  var amount: int=record.amount
  if amount>=CRITICAL_DAMAGE:
   font_size=51
   color=Color('ffd369')
  elif amount>=HEAVY_DAMAGE:
   font_size=42
   color=Color('ff936a')
  elif amount>=3:
   font_size=36
  else:
   font_size=29
 label.text=record.text
 label.add_theme_font_size_override('font_size',font_size)
 label.add_theme_color_override('font_color',color)
 label.add_theme_color_override('font_shadow_color',Color(0,0,0,0.65) if color.get_luminance()>0.25 else Color.TRANSPARENT)
 label.size=Vector2(280,0)
 label.position=record.position-Vector2(140,65-font_size+game.title_font.get_ascent(font_size))
 label.modulate.a=1.0
 # Step with battle time so hit-stop, animation speed and effect expiry agree.
 var tween=label.create_tween().set_parallel()
 tween.pause()
 tween.tween_property(label,'modulate:a',0.35,0.65).set_delay(0.6)
 if not game.reduced_motion:tween.tween_property(label,'position:y',label.position.y-47*1.25,1.25)
 record.tween=tween
 if record.age>0:tween.custom_step(record.age)

func advance_numbers(elapsed: float) -> void:
 for i in range(floats.size()-1,-1,-1):
  var record=floats[i]
  record.age+=elapsed
  if record.age<1.25:
   if elapsed>0:record.tween.custom_step(elapsed)
   continue
  record.tween.kill()
  record.sprite.hide()
  free_numbers.append(record.sprite)
  floats.remove_at(i)


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
 sprite.material=hit_flash if record.get('hit',false) and not game.reduced_motion else null
 record.sprite=sprite
 active.append(record)
 sprite.visible=not game.reduced_motion
 if sprite.visible:sprite.queue_redraw()

func advance_effects(active: Array,elapsed: float,lifetime: float) -> void:
 for i in range(active.size()-1,-1,-1):
  var record=active[i]
  var sprite: EffectSprite=record.sprite
  record.age+=elapsed
  if sprite.material==hit_flash and (record.age>=HIT_FLASH_SECONDS or game.reduced_motion):
   sprite.material=null
  if record.age>=lifetime:
   active.remove_at(i)
   sprite.hide()
   sprite.record={}
   free_effects[sprite.category].append(sprite)
  else:
   var was_visible=sprite.visible
   sprite.visible=not game.reduced_motion
   if sprite.visible and (elapsed>0 or not was_visible):sprite.queue_redraw()

func reset_effects() -> void:
 stop_motion()
 first_blood=false
 trap_reveals.clear()
 banners.clear()
 known_hand_size=0
 advance_effects(particles,INF,1.15)
 advance_numbers(INF)
 advance_effects(ghosts,INF,1.4)

var ghosts=[]
var particles=[]
var trap_reveals=[]
var floats=[]

var canvas
var clock=0.0

func _init(owner) -> void:
 hand_shader.code="shader_type canvas_item; uniform bool muted=false; void fragment(){ if(muted){COLOR.rgb=mix(COLOR.rgb,vec3(dot(COLOR.rgb,vec3(0.299,0.587,0.114))),0.85);} }"
 game=owner
 room=ArenaRoom.new()
 game.art_layer.add_child(room)
 arena_layer=BaseLayer.new()
 arena_layer.owner_view=weakref(self)
 arena_layer.terrain=true
 game.art_layer.add_child(arena_layer)
 base_layer=BaseLayer.new()
 base_layer.owner_view=weakref(self)
 game.art_layer.add_child(base_layer)
 fx=preload("res://scripts/tavern_fx.gd").new(self)
 creatures=load('res://tavern_assets/creatures.png'); spells=load('res://tavern_assets/spells.png'); frames=load('res://tavern_assets/frames.png')
 var white_shader=Shader.new()
 white_shader.code="shader_type canvas_item; void fragment(){ COLOR.rgb=vec3(1.0); }"
 hit_flash=ShaderMaterial.new()
 hit_flash.shader=white_shader
 var ice_shader=Shader.new()
 ice_shader.code="shader_type canvas_item; void fragment(){ float gray=dot(COLOR.rgb,vec3(0.299,0.587,0.114)); COLOR.rgb=mix(COLOR.rgb,gray*vec3(0.82,0.96,1.13),0.93); }"
 frozen_portrait=ShaderMaterial.new()
 frozen_portrait.shader=ice_shader
 var portrait_flash_shader=Shader.new()
 portrait_flash_shader.code="shader_type canvas_item; uniform vec4 uv_rect; void fragment(){ vec2 p=(UV-uv_rect.xy)/uv_rect.zw; COLOR=vec4(1.0,1.0,1.0,0.85*(1.0-smoothstep(0.72,1.0,length((p-vec2(0.5))*2.0)))); }"
 for side in range(2):
  var material=ShaderMaterial.new()
  material.shader=portrait_flash_shader
  hero_hit_materials.append(material)
  var atlas=AtlasTexture.new()
  atlas.atlas=ROYAL_ARENA
  hero_hit_atlas.append(atlas)
 shader=Shader.new()
 shader.code='shader_type canvas_item; uniform bool ellipse=false; uniform vec4 uv_rect=vec4(0.0,0.0,1.0,1.0); void fragment(){ if(ellipse){vec2 p=(UV-uv_rect.xy)/uv_rect.zw;float d=length((p-vec2(0.5))*2.0);COLOR.a*=1.0-smoothstep(0.97,1.0,d);} }'

func slice(texture: Texture2D,index: int,columns: int,rows: int) -> AtlasTexture:
 if not atlas_cache.has(texture):atlas_cache[texture]={}
 var cache: Dictionary=atlas_cache[texture]
 var key=Vector3i(index,columns,rows)
 if not cache.has(key):
  var at=AtlasTexture.new(); at.atlas=texture
  var cell=texture.get_size()/Vector2(columns,rows)
  at.region=Rect2(Vector2(index%columns,index/columns)*cell+Vector2(1,1),cell-Vector2(2,2))
  cache[key]=at
 return cache[key]

func art(key: String,texture: Texture2D,rect: Rect2,ellipse=false,angle=0.0,tint=Color.WHITE,z=0,flash: ShaderMaterial=null) -> void:
 used[key]=true
 if not nodes.has(key):
  var fresh: TextureRect
  if free_art.is_empty():
   fresh=TextureRect.new()
   fresh.mouse_filter=Control.MOUSE_FILTER_IGNORE
   fresh.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   fresh.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
   game.art_layer.add_child(fresh)
  else:
   fresh=free_art.pop_back()
   game.art_layer.move_child(fresh,-1)
   fresh.show()
  nodes[key]=fresh
 var node=nodes[key]
 node.texture=texture; node.position=rect.position; node.size=rect.size; node.pivot_offset=rect.size/2; node.rotation=angle; node.modulate=tint; node.z_index=z
 if not ellipse:
  node.material=flash
  return
 if not node.material or node.material.shader!=shader:
  node.material=ShaderMaterial.new()
  node.material.shader=shader
  node.material.set_shader_parameter('ellipse',true)
 if texture is AtlasTexture:
  var region=texture.region;var size=texture.atlas.get_size()
  node.material.set_shader_parameter('uv_rect',Vector4(region.position.x/size.x,region.position.y/size.y,region.size.x/size.x,region.size.y/size.y))

func tick(delta: float) -> void:
 room.configure(game.logical_size,game.arena_theme,game.portrait,game.screen=='battle')
 room.advance(delta,game.environment_lean(),game.reduced_motion,clock)
 var lit=game.screen=='battle' and not game.reduced_motion
 if lit and torches.is_empty():
  for i in range(2):torches.append(emitter(5,true))
 for i in range(torches.size()):
  var torch=torches[i]
  torch.position=room.torch_position(i)
  torch.color=ArenaRoom.THEMES[game.arena_theme].torch
  torch.visible=lit
  torch.emitting=lit
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
 advance_numbers(delta*game.speed)
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
 layout.player_row=282*arena_scale.y
 layout.enemy_row=170.5*arena_scale.y
 for side in range(2):
  var original_size=Vector2(40,54 if side==0 else 57)
  var size=original_size*arena_scale*SLOT_ZOOM
  layout.slot_sizes.append(size)
  for x in SLOT_COLUMNS:
   var center=Vector2(x*arena_scale.x,layout.player_row if side==0 else layout.enemy_row)
   layout.slots[side].append(Rect2(center-size/2,size))
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
 var previous_hand=hand_views
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
 if hand.size()!=known_hand_size and known_hand_size>0 and not game.reduced_motion:
  reflow_from=previous_hand.map(func(h):return h.base_rect.get_center().x)
  if reflow:reflow.kill()
  reflow_progress=0
  reflow=game.create_tween()
  reflow.tween_property(self,"reflow_progress",1.0,0.24).set_trans(Tween.TRANS_SINE)
  if game.panel=='pause':reflow.pause()
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
  if i<reflow_from.size():center.x=lerpf(reflow_from[i],center.x,reflow_progress)
  var angle=0.0 if game.reduced_motion else f*0.035
  var base_rect=Rect2(center-size/2,size)
  var lifted=game.selected_card==i or game.hover_card==i or (game.press.get('kind','')=='card' and int(game.press.get('index',-1))==i)
  var lift=move_toward(float(hand_lifts.get(i,0)),1.0 if lifted and game.drag.is_empty() else 0.0,frame_delta*9)
  if game.reduced_motion:lift=0
  hand_lifts[i]=lift
  center.y-=(70 if mobile else 110)*lift
  if not game.reduced_motion and i<deal_started.size() and deal_started[i]!=null:
   var travel=smoothstep(0,0.24,clock-float(deal_started[i]))
   center=Vector2(w*0.72,h*0.05).lerp(center,travel)
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
 room.configure(game.logical_size,game.arena_theme,game.portrait,game.screen=='battle')
 room.visible=game.screen=='battle'
 if arena_size!=game.logical_size or arena_screen!=game.screen:
  arena_size=game.logical_size
  arena_screen=game.screen
  arena_layer.queue_redraw()
 base_layer.queue_redraw()
 prepare_hand_faces()
 if game.screen=='battle':
  var state=game.rules
  var mana: int=state.players[0].mana
  if observed_match==game.match_serial and mana>previous_mana and not game.reduced_motion:
   energy_pulse_end=clock+0.6
   burst(energy_bar().get_center(),GOLD)
  previous_mana=mana
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
    rect=stretch(rect,advance*0.20-windup*0.17)
    if fx.ranged(str(info.unit.id)):
     rect.position-=direction*(windup*6+advance*10)
    else:
     rect.position-=direction*windup*16
     rect.position=rect.position.lerp(action.destination-rect.size/2,advance*0.9)
   var spawn={}
   var hit={}
   var ice_age=INF
   var resonating=attacking
   for effect in particles:
    if spawn.is_empty() and effect.kind=='summon' and effect.uid==uid:spawn=effect
    if int(effect.get('target',{}).get('uid',-1))!=uid:continue
    if effect.kind=='damage' and effect.age<HIT_RECOIL_SECONDS:hit=effect
    if effect.kind=='freeze':ice_age=effect.age
    if effect.get('response_id','')==info.unit.id and effect.age<0.65:resonating=true
   if not spawn.is_empty() and not game.reduced_motion:
    var arrival=clampf(spawn.age/0.46,0,1)
    var factor=lerpf(0.12,1.0,ease(arrival,0.35))+0.12*sin(PI*arrival)
    rect=Rect2(rect.get_center()-rect.size*factor/2,rect.size*factor)
    rect.position.y-=45*pow(1-arrival,2)
    rect=stretch(rect,-sin(arrival*TAU)*0.13*(1-arrival))
   elif not attacking and not game.reduced_motion:
    rect=stretch(rect,0.013*sin(clock*2.1+uid*1.7))
   var showing_hit=not hit.is_empty() and not game.reduced_motion
   if showing_hit:
    var recovery=clampf(hit.age/HIT_RECOIL_SECONDS,0,1)
    var recoil=clampf(hit.amount*2.0,4,16)*sin(recovery*TAU)*(1-recovery)
    rect=impact_stretch(rect,recovery)
    rect.position.y+=recoil*(1 if info.side==0 else -1)
   info.draw_rect=rect
   info.ice_growth=smoothstep(0.0,0.34,ice_age)
   if resonating and not game.reduced_motion:
    var spirit=rect.grow(14);spirit.position.y-=20+sin(clock*7)*5
    art('spirit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),spirit,false,0,Color(element_color(game.cards[info.unit.id].element).lightened(0.5),0.35),0)
   var tint=Color(1,0.6,0.5,opacity) if showing_hit else Color(1,1,1,opacity)
   var material=frozen_portrait if fx.frozen(info.unit) else null
   if showing_hit and hit.age<HIT_FLASH_SECONDS:material=hit_flash
   art('unit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),rect.grow(-3),false,0,tint,1,material)
  if not game.reduced_motion:
   for hero in hero_views:
    var age=hero_hit_age(hero.side)
    if age>=HIT_FLASH_SECONDS:continue
    var atlas=hero_hit_atlas[hero.side]
    atlas.region=hero_source(hero.rect)
    var uv=Rect2(atlas.region.position/ROYAL_ARENA.get_size(),atlas.region.size/ROYAL_ARENA.get_size())
    var material=hero_hit_materials[hero.side]
    material.set_shader_parameter('uv_rect',Vector4(uv.position.x,uv.position.y,uv.size.x,uv.size.y))
    art('hero_flash%d'%hero.side,atlas,hero_hit_rect(hero,age),false,0,Color.WHITE,0,material)
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
  button('help',Rect2(layout.settings.position+Vector2(0,layout.settings.size.y+24),layout.settings.size),'?')
  if not state.done and game.panel.is_empty():
   var x: float=layout.w-121
   var y: float=layout.settings.end.y+layout.settings.size.y+32
   button('pause',Rect2(x,y,111,50),'Pausa')
   button('emotes',Rect2(x,y+56,111,50),'Emotes')
   if game.emotes_open:
    for i in range(game.EMOTES.size()):
     button('emote_%d'%i,Rect2(layout.w-202,y+112+i*52,192,48),game.EMOTES[i])
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
  button('speed',Rect2(rect.position+Vector2(45,169),Vector2(rect.size.x-90,55)),'ANIMAÇÕES ×'+str(game.speed))
  button('motion',Rect2(rect.position+Vector2(45,297),Vector2(rect.size.x-90,55)),'REDUZIR MOVIMENTO · '+('SIM' if game.reduced_motion else 'NÃO'))
  button('credits',Rect2(rect.position+Vector2(45,233),Vector2(rect.size.x-90,55)),'CRÉDITOS DE ÁUDIO')
  button('theme',Rect2(rect.position+Vector2(45,361),Vector2(rect.size.x-90,55)),'TEMA · '+ArenaRoom.THEMES[game.arena_theme].name.to_upper())
  if game.screen=='home':
   button('difficulty',Rect2(rect.position+Vector2(45,425),Vector2(rect.size.x-90,55)),'IA · '+game.rules.AI_LEVELS[game.difficulty].name)
  if game.tilt_available:
   var label='INCLINAÇÃO · '+('SIM' if game.tilt_enabled else 'NÃO')
   var tilt_y=489 if game.screen=='home' else 425
   button('tilt',Rect2(rect.position+Vector2(45,tilt_y),Vector2(rect.size.x-90,55)),label,not game.reduced_motion)
  button('close',Rect2(rect.position+Vector2(rect.size.x-58,14),Vector2(42,42)),'×')
 if game.panel in HOME_PANELS:
  var rect=panel_rect()
  button('close',Rect2(rect.position+Vector2(rect.size.x-58,14),Vector2(42,42)),'×')
  if game.panel=='shop':
   button('collection',Rect2(rect.position+Vector2(45,215),Vector2(rect.size.x-90,55)),'VER COLEÇÃO',true,true)
 if game.panel=='credits': button('close',Rect2(panel_rect().position+Vector2(panel_rect().size.x-58,14),Vector2(42,42)),'×')
 if game.panel=='pause':
  var r=panel_rect()
  button('resume',Rect2(r.position+Vector2(55,105),Vector2(r.size.x-110,60)),'CONTINUAR',true,true)
 if game.panel=='result':
  var r=panel_rect()
  button('home',Rect2(r.position+Vector2(55,r.size.y-105),Vector2(r.size.x-110,60)),'VOLTAR À TAVERNA',true,true)
 prepare_auras()
 for key in nodes.keys():
  if used.has(key):continue
  var stale: TextureRect=nodes[key]
  nodes.erase(key)
  if free_art.size()>=24:stale.queue_free()
  else:
   stale.hide()
   stale.texture=null
   free_art.append(stale)

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

func home_art_rect() -> Rect2:
 var source_size=HOME_ART.get_size()
 var viewport: Vector2=game.size
 if viewport.y>=viewport.x*source_size.y/source_size.x:
  return Rect2(Vector2.ZERO,viewport)
 var usable: Vector2=viewport-game.safe_origin-game.safe_margin
 var factor=minf(usable.x/source_size.x,usable.y/source_size.y)
 var display=source_size*maxf(0,factor)
 return Rect2(game.safe_origin+(usable-display)/2.0,display)

func vertical_art_stretch(extra_height: float,bands: Array) -> float:
 var total=0.0
 for band in bands:total+=band.y-band.x
 return maxf(0,extra_height)/total

func vertical_art_y(y: float,scale_factor: float,stretch: float,bands: Array) -> float:
 var result=y*scale_factor
 for band in bands:result+=clampf(y-band.x,0,band.y-band.x)*stretch
 return result

func prepare_home() -> void:
 if not game.panel.is_empty():return
 var artwork=home_art_rect()
 var factor=artwork.size.x/HOME_ART.get_width()
 var stretch=vertical_art_stretch(artwork.size.y-HOME_ART.get_height()*factor,HOME_STRETCH_BANDS)
 for item in HOME_BUTTONS:
  var source: Rect2=item[2]
  var top=vertical_art_y(source.position.y,factor,stretch,HOME_STRETCH_BANDS)
  var bottom=vertical_art_y(source.end.y,factor,stretch,HOME_STRETCH_BANDS)
  var rect=Rect2(artwork.position+Vector2(source.position.x*factor,top),Vector2(source.size.x*factor,bottom-top))
  button(item[0],game.board_transform.affine_inverse()*rect,item[1])

func paint_home_background(layer: CanvasItem) -> void:
 var artwork=home_art_rect()
 if artwork.size.x<=0 or artwork.size.y<=0:return
 var viewport: Vector2=game.size
 if artwork.size!=viewport:
  var fill=maxf(viewport.x/HOME_PORTAL.get_width(),viewport.y/HOME_PORTAL.get_height())
  var background=HOME_PORTAL.get_size()*fill
  layer.draw_texture_rect(HOME_PORTAL,Rect2((viewport-background)/2,background),false,Color(0.29,0.31,0.42))
 paint_vertical_art(layer,HOME_ART,artwork,HOME_STRETCH_BANDS)

func paint_vertical_art(layer: CanvasItem,texture: Texture2D,artwork: Rect2,bands: Array) -> void:
 var factor=artwork.size.x/texture.get_width()
 var stretch=vertical_art_stretch(artwork.size.y-texture.get_height()*factor,bands)
 if is_zero_approx(stretch):
  layer.draw_texture_rect(texture,artwork,false)
  return
 var edges=[0.0]
 for band in bands:edges.append_array([band.x,band.y])
 edges.append(float(texture.get_height()))
 for i in range(edges.size()-1):
  var top=vertical_art_y(edges[i],factor,stretch,bands)
  var bottom=vertical_art_y(edges[i+1],factor,stretch,bands)
  var source=Rect2(0,edges[i],texture.get_width(),edges[i+1]-edges[i])
  var destination=Rect2(artwork.position+Vector2(0,top),Vector2(artwork.size.x,bottom-top))
  layer.draw_texture_rect_region(texture,destination,source,Color.WHITE,false,false)

func prepare_collection() -> void:
 var ids: Array=game.collectible_ids()
 var columns=4 if game.portrait else 6
 var page_size=columns*2
 var last_page=maxi(0,ceili(float(ids.size())/page_size)-1)
 game.collection_page=clampi(game.collection_page,0,last_page)
 var w: float=layout.w
 var h: float=layout.h
 var wide=minf(w,1390.0)
 var offset=(w-wide)/2
 var header_height=minf(116.0,h*0.114)
 var nav_width=minf(182.0,wide*0.194)
 var nav_height=header_height*0.48
 var nav_y=h*0.024+(header_height-nav_height)/2
 var labels=['TODAS','CRIATURAS','FEITIÇOS','ARMADILHAS']
 button('home',Rect2(offset+wide*0.042,nav_y,nav_width,nav_height),'VOLTAR')
 button('filter',Rect2(offset+wide*0.958-nav_width,nav_y,nav_width,nav_height),labels[game.collection_filter])
 var footer_y=h*0.906
 var footer_height=minf(62.0,h*0.055)
 button('previous',Rect2(offset+wide*0.041,footer_y,wide*0.223,footer_height),'ANTERIOR',game.collection_page>0)
 button('next',Rect2(offset+wide*0.736,footer_y,wide*0.223,footer_height),'PRÓXIMA',game.collection_page<last_page)
 button('reset_deck',Rect2(w/2-wide*0.21,footer_y-footer_height*0.08,wide*0.42,footer_height*1.16),'BARALHO INICIAL')

 var gap=minf(16.0,wide*0.017)
 var grid_top=h*(0.24 if game.portrait else 0.234)
 var grid_bottom=h*0.866 if game.portrait else h*0.867
 var row_gap=minf(21.0,h*0.016)
 var action_height=minf(44.0,h*0.036)
 var row_height=(grid_bottom-grid_top-row_gap)/2
 var card_width=minf((wide*0.89-gap*(columns-1))/columns,(row_height-action_height-3)*HAND_FRAME.get_width()/HAND_FRAME.get_height())
 var card_height=card_width*HAND_FRAME.get_height()/HAND_FRAME.get_width()
 var left=(w-columns*card_width-(columns-1)*gap)/2
 var extra=maxf(0,grid_bottom-grid_top-2*(card_height+action_height+3)-row_gap)
 var top=grid_top+extra*(0.12 if game.portrait else 0.5)
 if game.portrait:row_gap+=extra*0.72
 for slot in range(page_size):
  var index=game.collection_page*page_size+slot
  if index>=ids.size():break
  var x=left+(slot%columns)*(card_width+gap)
  var y=top+(slot/columns)*(card_height+action_height+3+row_gap)
  var rect=Rect2(x,y,card_width,card_height)
  var action=Rect2(x+4,rect.end.y+3,card_width-8,action_height)
  collection_views.append({'id':ids[index],'rect':rect,'action':action,'count':game.profile.deck.count(ids[index])})

func paint_collection_background(layer: CanvasItem) -> void:
 var size: Vector2=game.size
 var native=COLLECTION_LIBRARY.get_size()
 if game.portrait:
  paint_vertical_art(layer,COLLECTION_LIBRARY,Rect2(Vector2.ZERO,size),COLLECTION_STRETCH_BANDS)
 else:
  var scale_factor=size.x/native.x
  var shown=size.y/scale_factor
  var source=Rect2(0,clampf(native.y*0.40-shown/2,0,maxf(0,native.y-shown)),native.x,minf(native.y,shown))
  layer.draw_texture_rect_region(COLLECTION_LIBRARY,Rect2(Vector2.ZERO,size),source)
  layer.draw_rect(Rect2(Vector2.ZERO,size),Color(0.05,0.025,0.06,0.40))

func panel_rect() -> Rect2:
 if game.panel=='pause':return Rect2(Vector2(layout.w/2-240,layout.h/2-110),Vector2(480,220))
 var height=568.0 if game.panel=='settings' and game.screen=='home' else 520.0
 if game.panel in HOME_PANELS:height=320.0
 return Rect2(Vector2(layout.w/2-280,layout.h/2-height/2),Vector2(560,height))
func inspect_rect() -> Rect2:
 var size=Vector2(440,660) if game.portrait else Vector2(260,390)
 return Rect2(Vector2(layout.w/2-size.x/2,layout.h/2-size.y/2-25),size)

func target_center(target: Dictionary) -> Vector2:
 if target.get('hero',false): return (layout.player_hero if int(target.side)==0 else layout.enemy_hero).get_center()
 if unit_views.has(int(target.get('uid',-1))): return unit_views[int(target.uid)].rect.get_center()
 return Vector2(layout.w/2,layout.player_row)

func begin(action: Dictionary) -> void:
 if not game.reduced_motion and action.get('card_kind','')=='spell':
  room.illuminate(action.get('element','arcane'))
 effect_history.append({'phase':'cast','id':action.get('id','power'),'kind':action.kind,'element':action.get('element','arcane')})
 if effect_history.size()>60:effect_history.pop_front()

func ingest(events: Array,before: Array,action: Dictionary={}) -> void:
 if not game.reduced_motion and action.get('kind','')=='card':
  river_until=clock+0.55
  river_x=clampf(action.destination.x/layout.w,0.1,0.9) if action.has('destination') else 0.5
 var elemental=events.filter(func(event):return event.kind in ['damage','freeze','armor','heal','destroy'])
 if not elemental.is_empty():
  var element=str(action.get('element',elemental[0].get('element','arcane')))
  scenery.append({'element':element,'age':0.0,'position':target_center(elemental[0].get('target',{}))})
  if scenery.size()>4:scenery.pop_front()
 var defeated=events.filter(func(event):return event.kind=='death' and event.side!=action.get('side',-1))
 if defeated.size()>=2 and action.has('side'):
  var banner_at=Vector2(layout.w*0.5,(layout.enemy_row+layout.player_row)*0.5)
  add_number({'position':banner_at+Vector2(0,55),'text':'QUEDA DUPLA' if defeated.size()==2 else 'QUEDA MÚLTIPLA','color':GOLD,'age':0.0})
 for side in range(2):
  var health=game.rules.players[side].health
  if before[side].health>=10 and health>0 and health<10:
   banner('SEU HERÓI EM PERIGO' if side==0 else 'HERÓI RIVAL EM PERIGO')
 var causes={}
 var hit_units={}
 for event in events:
  var kind=event.kind
  if kind=='death' and not game.reduced_motion:
   burst(target_center({'side':event.side,'uid':event.uid}),element_color(game.cards[event.id].element))
   crowd_until=clock+0.45
  if kind=='damage':
   if not game.reduced_motion:
    sun_until=clock+0.28
    if event.target.get('hero',false):hit_until[event.target.side]=clock+HIT_RECOIL_SECONDS
    else:hit_units[int(event.target.uid)]=true
   if not first_blood:
    first_blood=true
    banners.push_front('PRIMEIRO SANGUE')
    banner_left=1.3
   if not game.reduced_motion:
    if event.amount>=HEAVY_DAMAGE:
     var hold=lerpf(0.060,0.090,inverse_lerp(HEAVY_DAMAGE,CRITICAL_DAMAGE,clampi(event.amount,HEAVY_DAMAGE,CRITICAL_DAMAGE)))
     freeze_left=maxf(freeze_left,hold)
    shake_strength=maxf(shake_strength if shake_left>0 else 0,minf(8,1.4*event.amount))
    shake_left=0.17
  if kind in ['damage','destroy'] and event.get('target',{}).has('uid'):causes[int(event.target.uid)]=event.get('element',action.get('element','dark'))
  if kind in ['damage','heal','buff','debuff','blocked','shield_break','freeze','destroy','armor','draw','mana']:
   var at=target_center(event.get('target',{'side':event.get('side',0),'hero':true}))
   var color=Color('ffe29b') if kind in ['armor','blocked','shield_break'] else Color('ff615d') if kind=='damage' else Color('8cffbe') if kind in ['heal','buff'] else Color('96dfff')
   if kind in ['damage','heal']:
    accumulate(event,at,color)
   elif not event.get('target',{}).has('uid'):
    var label='+'+str(event.get('amount',0))+' ARMADURA' if kind=='armor' else 'DESTRUÍDO' if kind=='destroy' else '+ ENERGIA' if kind=='mana' else 'COMPRA' if kind=='draw' else '+'+str(event.get('amount',0)) if kind=='buff' else 'ESCUDO ROMPIDO' if kind=='shield_break' else 'GELO' if kind=='freeze' else '−'+str(event.get('amount',0)) if kind=='debuff' else 'BLOQUEOU '+str(event.get('amount',0))
    add_number({'position':at,'text':label,'color':color,'age':0.0,'element':event.get('element',action.get('element','arcane')),'id':action.get('id','')})
   var particle={'kind':kind,'amount':event.get('amount',0),'position':at,'target':event.get('target',{}).duplicate(),'color':color,'age':0.0,'element':event.get('element',action.get('element','arcane')),'id':action.get('id','')}
   if kind=='shield_break':
    var bubble=Rect2(at-Vector2(50,60),Vector2(100,120))
    var uid=int(event.target.get('uid',-1))
    if unit_views.has(uid):bubble=unit_views[uid].get('draw_rect',unit_views[uid].rect)
    particle.position=bubble.get_center()
    particle.bubble_radius=bubble.size/2+Vector2.ONE*7
   if event.has('drained_from'):particle.drain_origin=target_center(event.drained_from)
   acquire_effect(particles,&"particle",particle)
   var element: String=particles[-1].element
   if kind in ['armor','blocked','heal','buff'] or (kind=='damage' and element=='fire'):
    impact_burst(at,element_color(element) if kind=='damage' else color)
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
     acquire_effect(ghosts,&"remains",{'uid':event.uid,'id':event.id,'rect':rect,'age':0.0,'element':cause,'hit':hit_units.has(int(event.uid))})
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
   number.age=0.0
   animate_number(number)
   return
  if event.kind in ['damage','element_resist'] and number.kind in ['damage','element_resist']:stack_depth+=1
 add_number({'position':at+Vector2(0,stack_depth*35),'kind':event.kind,'target':event.target,'amount':event.amount,'modifier':modifier,'text':prefix+str(event.amount)+marker,'color':color,'age':0.0})

func style(fill: Color,border: Color,radius=12,width=2) -> StyleBoxFlat:
 var key=[fill.to_rgba32(),border.to_rgba32(),radius,width]
 if styles.has(key):return styles[key]
 var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius);s.shadow_color=Color(0,0,0,0.45);s.shadow_size=7
 styles[key]=s
 return s

func text(value: String,rect: Rect2,size=20,color=PAPER,center=false,title=false) -> void:
 var font=game.title_font if title else game.body_font
 var key=[value,size,title]
 if not text_layouts.has(key):
  if text_layouts.size()>=512:text_layouts.clear()
  var lines=value.split('\n')
  var widths=PackedFloat32Array()
  for line in lines:widths.append(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
  text_layouts[key]=[lines,widths]
 var layout_text: Array=text_layouts[key]
 var y=rect.position.y
 var shadow=color.get_luminance()>0.25
 for i in range(layout_text[0].size()):
  var line: String=layout_text[0][i]
  var x=rect.position.x+(maxf(0,(rect.size.x-layout_text[1][i])/2) if center else 0)
  if shadow:canvas.draw_string(font,Vector2(x+1,y+size+1),line,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,size,Color(0,0,0,color.a*0.65))
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

func paint_terrain(c: CanvasItem) -> void:
 canvas=c
 if game.screen!='battle':return
 for side in range(2):
  for column in range(SLOT_COLUMNS.size()):
   var slot: Rect2=layout.slots[side][column]
   canvas.draw_rect(slot,Color(0.07,0.06,0.10,0.17))
   canvas.draw_rect(slot.grow(-3),Color(0.95,0.83,0.69,0.32),false,2,true)

func hero_hit_age(side: int) -> float:
 return clampf(clock+HIT_RECOIL_SECONDS-hit_until[side],0,HIT_RECOIL_SECONDS)

func hero_source(rect: Rect2) -> Rect2:
 var scale_factor: Vector2=ROYAL_ARENA.get_size()/game.logical_size
 return Rect2(rect.position*scale_factor,rect.size*scale_factor)

func hero_hit_rect(hero: Dictionary,age: float) -> Rect2:
 var rect: Rect2=hero.rect
 var idle=1+0.008*(1+sin(clock*2+hero.side))
 var dest=Rect2(rect.get_center()-rect.size*idle/2,rect.size*idle)
 var progress=age/HIT_RECOIL_SECONDS
 dest.position.x+=(1-progress)*sin(clock*90)*5
 return impact_stretch(dest,progress)

func paint_base(c: CanvasItem) -> void:
 canvas=c
 if game.screen=='battle':
  if not game.reduced_motion:
   fx.environment()
   for hero in hero_views:
    var age=hero_hit_age(hero.side)
    var hit=1-age/HIT_RECOIL_SECONDS
    if hit>0:canvas.draw_texture_rect_region(ROYAL_ARENA,hero_hit_rect(hero,age),hero_source(hero.rect),room.room_light*Color(1,1-hit*0.55,1-hit*0.55))
   if river_until>clock:
    var t=1-(river_until-clock)/0.55
    canvas.draw_set_transform_matrix(Transform2D(0,Vector2(1,0.12),0,Vector2(layout.w*river_x,layout.h*0.452)))
    canvas.draw_arc(Vector2.ZERO,6+t*78,0,TAU,32,Color(0.6,0.94,1,1-t),3)
    canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
   if sun_until>clock:
    canvas.draw_circle(Vector2(layout.w*0.5,layout.h*0.452),12+18*(sun_until-clock),Color(1,0.76,0.28,(sun_until-clock)*1.6))
   if crowd_until>clock and game.arena_theme==0:
    for side in [0.07,0.93]:
     var r=Rect2(layout.w*(side-0.045),layout.h*0.085,layout.w*0.09,layout.h*0.04)
     var shifted=r
     shifted.position.y-=4*absf(sin((crowd_until-clock)*18))
     canvas.draw_texture_rect_region(ROYAL_ARENA,shifted,Rect2(r.position/game.logical_size*ROYAL_ARENA.get_size(),r.size/game.logical_size*ROYAL_ARENA.get_size()))
 if not game.inspect_id.is_empty(): canvas.draw_style_box(style(Color(0.02,0.025,0.04,0.95),Color('9e815a'),18),inspect_rect().grow(20))
 if game.screen=='battle':
  for uid in unit_views:
   var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect)
   var unit=info.unit
   var ready=int(info.side)==0 and int(unit.attacks)>0 and not game.target_locked({'side':0,'uid':uid})
   var rim=Color('64b7ff') if info.side==0 else Color('ff8b57')
   canvas.draw_rect(rect,Color('30261f'))
   canvas.draw_rect(rect,rim,false,3,true)
   if ready:canvas.draw_rect(rect.grow(2),Color(rim,0.45 if game.reduced_motion else 0.45+0.2*sin(clock*3)),false,3,true)


func paint_overlay(c: CanvasItem) -> void:
 canvas=c
 if game.screen=='collection':paint_collection()
 elif game.screen=='battle':paint_battle()
 if game.screen=='battle' and game.panel.is_empty() and game.emote_time>0:
  var bubble=Rect2(layout.player_hero.position+Vector2(0,-49),Vector2(layout.player_hero.size.x,38))
  canvas.draw_style_box(style(Color('33262b'),GOLD,8,2),bubble)
  text(game.emote_text,bubble,20,GOLD,true)
 if game.panel.is_empty() and game.screen!='home':
  for button_info in buttons:paint_button(button_info)
 if not game.inspect_id.is_empty():
  var card_rect=inspect_rect()
  paint_card(game.inspect_id,card_rect)
  var hint=element_hint(game.cards[game.inspect_id].element)
  if hint!='':
   var strip=Rect2(card_rect.position+Vector2(0,card_rect.size.y-26),Vector2(card_rect.size.x,24))
   canvas.draw_style_box(style(Color('312238'),GOLD,5,1),strip)
   text(hint,strip,15,PAPER,true)
  text('Toque fora para fechar',Rect2(card_rect.position+Vector2(-15,card_rect.size.y+15),Vector2(card_rect.size.x+30,25)),15,PAPER,true)
 if game.screen=='battle' and game.panel.is_empty() and not game.tutorial_visible and game.toast_time<=0 and not banners.is_empty():
  var strip=Rect2(layout.w/2-190,layout.h*0.443,380,42)
  canvas.draw_style_box(style(Color('33262b'),GOLD,8,2),strip)
  text(banners[0],strip,23,GOLD,true,true)
 if not game.panel.is_empty(): paint_panel()
 if game.panel!='pause' and game.toast_time>0 and not (game.screen=='battle' and game.tutorial_visible and game.selected_card<0):
  var toast_y=layout.h*0.409 if game.screen=='battle' else layout.h*0.19
  var width=minf(layout.w-70,650)
  canvas.draw_style_box(style(Color(0.025,0.03,0.055,0.94),Color('d8ba7a'),12),Rect2(layout.w/2-width/2,toast_y,width,48))
  var inset=5 if '\n' in game.toast_text else 15
  text(game.toast_text,Rect2(layout.w/2-width/2+14,toast_y+inset,width-28,50),18,PAPER,true)

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

 var inset=r.position+r.size*Vector2(0.12,0.70)
 if not affordable:
  canvas.draw_rect(Rect2(inset-Vector2(1,1),r.size*Vector2(0.77,0.24)),Color('bba584'))
 var width=r.size.x*0.76
 var fs=maxi(10,int(r.size.x*0.12))
 if card.kind=='minion':
  text('%d ATQ · %d PV'%[card.attack,card.health],Rect2(inset,Vector2(width,fs*1.4)),fs,INK,true,true)
  inset.y+=fs*1.35
 var summary=HAND_EFFECTS.get(card.id,'')
 var fit=mini(fs,int(width*fs/maxf(1,game.body_font.get_string_size(summary,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x)))
 text(summary,Rect2(inset,Vector2(width,fs*2)),fit,INK,true)

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
 var next_id: String=game.rules.next_card(0)
 var width=minf(layout.w*0.085,layout.h*0.068)
 var rect=Rect2(Vector2(layout.w*0.68,layout.h*0.012),Vector2(width,width*1.38))
 canvas.draw_style_box(style(INK,GOLD,4,2),rect)
 if not next_id.is_empty():
  var card=game.cards[next_id]
  var creature=card.kind=='minion'
  draw_card_picture(slice(creatures if creature else spells,int(card.art),5 if creature else 4,5 if creature else 4),rect.grow(-3))
  badge(rect.position+Vector2(5,7),str(int(card.cost)),INK,9)
 var label=Rect2(rect.position.x-16,rect.end.y+4,layout.w*0.20,22)
 text('Próxima carta' if not next_id.is_empty() else 'Baralho vazio',label,16,GOLD,true,true)
 if not next_id.is_empty():
  var name: String=game.cards[next_id].name
  var name_rect=Rect2(label.position+Vector2(0,19),label.size)
  text(name,name_rect,mini(15,int(name_rect.size.x*1.7/(name.length()+1))),PAPER,true)
 var at=rect.end+Vector2(20,-rect.size.y*0.65)
 canvas.draw_circle(at,15,INK)
 canvas.draw_arc(at,15,0,TAU,32,Color('705d42'),3,true)
 var progress=game.support_elapsed/game.SUPPORT_SECONDS
 if player.hand.size()<game.rules.MAX_HAND and not next_id.is_empty():
  canvas.draw_arc(at,15,-PI/2,-PI/2+TAU*progress,32,GOLD,3,true)
  text(str(ceili(game.SUPPORT_SECONDS-game.support_elapsed)),Rect2(at-Vector2(13,9),Vector2(26,18)),14,PAPER,true)
 else:text('Ⅱ',Rect2(at-Vector2(12,9),Vector2(24,18)),14,GOLD,true)
 var pile=Rect2(at+Vector2(-16,24),Vector2(13,17))
 canvas.draw_rect(pile,GOLD,false,2)
 canvas.draw_rect(Rect2(pile.position+Vector2(3,-3),pile.size),INK)
 canvas.draw_rect(Rect2(pile.position+Vector2(3,-3),pile.size),GOLD,false,2)
 text(str(player.deck.size()),Rect2(pile.position+Vector2(20,-4),Vector2(38,25)),17,PAPER)

func badge(center: Vector2,value: String,color: Color,radius=21.0) -> void:
 canvas.draw_circle(center,radius+2,Color('312317'));canvas.draw_circle(center,radius,color);canvas.draw_arc(center,radius,0,TAU,36,Color('e8d7a6'),2)
 text(value,Rect2(center-Vector2(radius,radius*0.77),Vector2(radius*2,radius*1.6)),int(radius*1.3),Color.WHITE,true,true)

var heart=PackedVector2Array([Vector2(0,24),Vector2(-21,4),Vector2(-24,-6),Vector2(-21,-16),Vector2(-12,-20),Vector2(-5,-18),Vector2(0,-12),Vector2(5,-18),Vector2(12,-20),Vector2(21,-16),Vector2(24,-6),Vector2(21,4)])
var shield=PackedVector2Array([Vector2(-22,-18),Vector2(0,-23),Vector2(22,-18),Vector2(19,6),Vector2(12,17),Vector2(0,25),Vector2(-12,17),Vector2(-19,6)])

func hero_stat(at: Vector2,value: int,armor: bool) -> void:
 var pulse=1.0
 if not armor and value<=10 and not game.reduced_motion:pulse+=0.12*pow(maxf(0,sin(clock*5)),2)
 canvas.draw_set_transform(at,0,Vector2.ONE*pulse)
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
 var gem_label=Rect2(1,layout.h*0.485,layout.w*0.08,19)
 canvas.draw_style_box(style(INK,GOLD,3,1),gem_label)
 text('Gemas',gem_label,14,PAPER,true,true)
 text('Poder',Rect2(layout.power.position+Vector2(-6,layout.power.size.y+1),layout.power.size+Vector2(12,0)),15,GOLD,true,true)
 text('Ajustes',Rect2(layout.settings.position+Vector2(-7,layout.settings.size.y),layout.settings.size+Vector2(14,0)),15,GOLD,true,true)
 if game.tutorial_visible and game.selected_card<0 and game.drag.is_empty() and game.panel.is_empty():
  var guide=Rect2(layout.w*0.09,layout.h*0.414,layout.w*0.82,minf(42,layout.h*0.052))
  canvas.draw_style_box(style(INK,GOLD,6,1),guide)
  text('Arraste cartas ao campo e criaturas até um inimigo.',guide,int(minf(guide.size.x/27,guide.size.y*0.63)),PAPER,true)
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
    text('%d s'%ceili(game.SUPPORT_SECONDS-game.support_elapsed),timer,15,PAPER,true)
   if support.get('trap','')!='':
    paint_trap_back(armed_trap_rect(rect))
    if support.id=='':label='Armadilha'
   var strip=Rect2(rect.position+rect.size*Vector2(0.06,0.72),rect.size*Vector2(0.88,0.23))
   canvas.draw_style_box(style(Color('312238'),GOLD,5,1),strip)
   text(label,strip,int(minf(strip.size.y*0.70,strip.size.x*0.16)),PAPER,true,true)
 for hero in hero_views:
  var p=state.players[int(hero.side)]
  hero_stat(hero.rect.position+hero.rect.size*Vector2(0.84,0.86),p.health,false)
  var armor_at: Vector2=hero.rect.position+hero.rect.size*Vector2(0.16,0.86)
  fx.armor_plates(armor_at,p.armor)
  hero_stat(armor_at,p.armor,true)
 for uid in unit_views:
  var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect);var unit=info.unit
  canvas.draw_rect(rect.grow(-2),Color('e5bd70'),false,1,true)
  if unit.attacks==0 and unit.delay>0:
   radial_cooldown(rect.position+rect.size*Vector2(0.78,0.2),rect.size.x*0.11,unit.delay)
  elif info.side==0 and unit.attacks>0 and state.effective_attack(info.side,unit)>0 and not game.target_locked({'side':0,'uid':uid}):
   var tag=Rect2(rect.position+Vector2(0,-2),Vector2(rect.size.x,19))
   canvas.draw_rect(tag,Color('234d3a'))
   text('ATACAR',tag,14,Color('b7ffce'),true,true)
  fx.status(unit,rect,info.ice_growth)
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
  canvas.draw_set_transform_matrix(Transform2D(hand.angle,hand.rect.get_center())*Transform2D(0,-hand.rect.get_center()))
  var remaining=float(state.players[0].cooldowns.get(hand.index,0))
  var card=game.cards[hand.id]
  var ready=hand.ready
  var bit=1<<int(hand.index)
  if ready:
   if not opening and (ready_mask & bit)==0:
    pulse_ends[hand.index]=clock+0.6
   ready_mask|=bit
  else:ready_mask &= ~bit
  if not game.reduced_motion and ready and pulse_ends[hand.index]>clock:
   canvas.draw_rect(hand.rect.grow(3),Color(GOLD,(pulse_ends[hand.index]-clock)/0.6),false,5,true)
  if remaining>0:
   var center=hand.rect.position+hand.rect.size*Vector2(0.5,0.38)
   var radius=hand.rect.size.x*0.16
   radial_cooldown(center,radius,remaining)
  elif ready:
   canvas.draw_rect(hand.rect.grow(2),Color(GOLD,0.30),false,5,true)
   canvas.draw_rect(hand.rect,GOLD,false,2,true)
  elif card.cost<=state.players[0].mana:
   var reason='Campo cheio' if hand.full else 'Sem alvo'
   text(reason,Rect2(hand.rect.position+hand.rect.size*Vector2(0,0.38),hand.rect.size),maxi(9,int(hand.rect.size.x*0.12)),PAPER,true,true)
  if card.cost>state.players[0].mana:
   var tag=Rect2(hand.rect.position+hand.rect.size*Vector2(0.12,0.39),hand.rect.size*Vector2(0.76,0.14))
   canvas.draw_rect(tag,INK)
   text('Falta %d'%int(card.cost-state.players[0].mana),tag,int(tag.size.y*0.76),PAPER,true,true)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
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

  else:
   var guard=taunt_pull_target(game.drag,game.target_at(game.pointer))
   if guard.is_empty():arrow(game.drag.origin,game.pointer,Color('ed694a'))
   else:fx.taunt_pull(game.drag.origin,game.pointer,target_center(guard))
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
 if p.health<=10 and not game.reduced_motion:
  var strength=0.10+0.05*sin(clock*3.0)
  for band in range(10):
   canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size).grow(-band*3.0),Color(0.9,0.02,0.04,strength*(1-band/10.0)*3),false,3.1)
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

func taunt_pull_target(selection: Dictionary,hovered: Dictionary) -> Dictionary:
 if selection.kind!='unit' or hovered.get('side',-1)!=1:return {}
 var uid=int(selection.uid)
 if game.rules.can_attack(0,uid,hovered).ok:return {}
 var nearest={}
 var shortest=INF
 var at=target_center(hovered)
 for unit in game.rules.players[1].board:
  if 'taunt' not in unit.keywords:continue
  var candidate={'side':1,'uid':unit.uid}
  if game.target_locked(candidate) or not game.rules.can_attack(0,uid,candidate).ok:continue
  var distance=at.distance_squared_to(target_center(candidate))
  if distance<shortest:
   shortest=distance
   nearest=candidate
 return nearest

func paint_targets(selection: Dictionary) -> void:
 var candidates=[]
 for uid in unit_views:candidates.append({'side':unit_views[uid].side,'uid':uid})
 for side in range(2):candidates.append({'side':side,'hero':true})
 for target in candidates:
  if game.target_locked(target):continue
  var valid=false
  if selection.kind=='card' and game.cards[selection.id].get('target','none')!='none':valid=game.rules.can_play(0,int(selection.index),target).ok
  elif selection.kind=='unit':
   valid=game.rules.can_attack(0,int(selection.uid),target).ok
  elif selection.kind=='power':valid=game.rules.can_power(0,target).ok
  if valid:
   var center=target_center(target)
   canvas.draw_arc(center,67 if game.portrait else 72,0,TAU,48,Color(1,0.87,0.45,0.65 if game.reduced_motion else 0.65+sin(clock*7)*0.2),4)

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

func collection_sprite(key: String,rect: Rect2,tint=Color.WHITE) -> void:
 var source: Rect2=COLLECTION_SPRITES[key]
 var edge=COLLECTION_HEADING_EDGE if key=='heading' else COLLECTION_BUTTON_EDGE
 var points=PackedVector2Array()
 var uvs=PackedVector2Array()
 var texture_size=COLLECTION_CONTROLS.get_size()
 for point in edge:
  points.append(rect.position+point*rect.size)
  uvs.append((source.position+point*source.size)/texture_size)
 canvas.draw_polygon(points,PackedColorArray([tint]),uvs,COLLECTION_CONTROLS)

func collection_card(info: Dictionary) -> void:
 var rect: Rect2=info.rect
 var size=rect.size
 var card=game.cards[info.id]
 var minion=card.kind=='minion'
 var picture=slice(creatures if minion else spells,int(card.art),5 if minion else 4,5 if minion else 4)
 draw_card_picture(picture,Rect2(rect.position+size*Vector2(0.068,0.055),size*Vector2(0.864,0.58)))
 canvas.draw_texture_rect(HAND_FRAME,rect,false)
 var label=Rect2(rect.position+size*Vector2(0.085,0.545),size*Vector2(0.83,0.091))
 canvas.draw_style_box(style(Color('e8b75b'),Color('ffdb81'),6,1),label)
 var font_size=maxi(9,int(size.x*0.096))
 while font_size>8 and game.title_font.get_string_size(card.name,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>label.size.x-4:
  font_size-=1
 text(card.name,Rect2(label.position+Vector2(2,1),label.size-Vector2(4,1)),font_size,INK,true,true)
 text(str(int(card.cost)),Rect2(rect.position+size*Vector2(0.018,0.029),size*Vector2(0.207,0.15)),int(size.x*0.19),Color.WHITE,true,true)
 var description=Rect2(rect.position+size*Vector2(0.135,0.674),size*Vector2(0.73,0.22 if minion else 0.24))
 canvas.draw_style_box(style(Color('f0cc8a'),Color.TRANSPARENT,5,0),description.grow(2))
 wrapped(card.text,description,maxi(9,int(size.x*0.079)),INK,true)
 if minion:
  var stat_size=size.x*0.19
  badge(rect.position+size*Vector2(0.14,0.906),str(int(card.attack)),Color('935416'),stat_size/2)
  badge(rect.position+size*Vector2(0.86,0.906),str(int(card.health)),Color('982a37'),stat_size/2)
 if info.count>0:
  var copies=Rect2(rect.position+size*Vector2(0.81,0.06),size*Vector2(0.13,0.088))
  canvas.draw_style_box(style(Color('153354'),Color('bd9b50'),5,1),copies)
  text(str(info.count),copies,maxi(9,int(size.x*0.087)),Color.WHITE,true,true)

func paint_collection() -> void:
 var w: float=layout.w
 var h: float=layout.h
 var header_height=minf(116.0,h*0.114)
 var heading_width=minf(460.0,w*0.49)
 collection_sprite('heading',Rect2((w-heading_width)/2,h*0.024,heading_width,header_height))
 var banner_width=minf(620.0,w*0.83)
 var banner=Rect2((w-banner_width)/2,h*0.136,banner_width,minf(41.0,h*0.038))
 canvas.draw_style_box(style(Color('2b180f'),Color('da9a39'),16,2),banner)
 var summary='%d / 30 cartas · até 2 cópias · lendárias únicas'%game.profile.deck.size()
 text(summary,Rect2(banner.position+Vector2(0,banner.size.y*0.13),banner.size),clampi(int(banner.size.y*0.57),14,23),Color('f9d781'),true,true)
 var guidance=Rect2(banner.position+Vector2(0,banner.size.y+4),Vector2(banner.size.x,minf(36.0,h*0.030)))
 collection_sprite('instructions',guidance)
 for item in collection_views:
  collection_card(item)
  collection_sprite('remove' if item.count>0 else 'add',item.action)

func paint_collection_button(info: Dictionary) -> void:
 var rect: Rect2=info.rect
 var tint=Color.WHITE if info.enabled else Color(0.68,0.65,0.65,0.82)
 collection_sprite(info.id,rect,tint)
 if info.id=='filter' and game.collection_filter!=0:
  var label=Rect2(rect.position+rect.size*Vector2(0.32,0.19),rect.size*Vector2(0.63,0.58))
  canvas.draw_rect(label,Color('342117'))
  var font_size=mini(int(label.size.x*0.14),int(label.size.y*0.76))
  text(info.label,Rect2(label.position+Vector2(0,(label.size.y-font_size)/2),label.size),font_size,PAPER,true,true)

func paint_button(info: Dictionary) -> void:
 if game.screen=='collection' and COLLECTION_SPRITES.has(info.id):
  paint_collection_button(info)
  return
 var rect: Rect2=info.rect
 var enabled=info.enabled
 var primary=info.primary
 if info.id=='solar':
  var bar=energy_bar()
  canvas.draw_style_box(style(Color('703515'),Color('ffce60').lerp(Color.WHITE,0.25 if game.reduced_motion else 0.25+0.2*sin(clock*4)),8,2),bar)
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
 if game.panel=='pause':text('Partida pausada',Rect2(rect.position+Vector2(25,35),Vector2(rect.size.x-50,45)),30,PAPER,true,true)
 elif game.panel=='settings':text('Configurações',Rect2(rect.position+Vector2(25,35),Vector2(rect.size.x-50,45)),30,PAPER,true,true)
 elif game.panel in HOME_PANELS:
  var heading=Rect2(rect.position+Vector2(35,35),Vector2(rect.size.x-100,52))
  canvas.draw_texture_rect_region(HOME_ASSETS,heading,Rect2(835,739,330,52))
  text(HOME_PANELS[game.panel],heading,30,GOLD,true,true)
  var area=Rect2(rect.position+Vector2(45,104),Vector2(rect.size.x-90,104))
  match game.panel:
   'rewards':
    text('%d moedas   ·   %d XP' % [game.profile.coins,game.profile.xp],area,27,GOLD,true,true)
    text('%d vitórias   ·   %d derrotas' % [game.profile.wins,game.profile.losses],Rect2(area.position+Vector2(0,48),area.size),21,PAPER,true)
   'missions':wrapped('Ainda não há missões disponíveis.',area,23,PAPER,true)
   'shop':wrapped('Todas as cartas do jogo estão disponíveis na Coleção.',area,23,PAPER,true)
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
  if button_info.id in game.PANEL_BUTTONS[game.panel]:paint_button(button_info)
