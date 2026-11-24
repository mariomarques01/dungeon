extends Node2D

const THEMES=[
 {'name':'Taverna','id':'tavern','wide':"res://tavern_assets/environments/tavern_wide.webp",'portrait':"res://tavern_assets/environments/tavern_portrait.webp",'tray':Color('ffe3bb'),'torch':Color('ffb76b'),'motes':Color('ffd692')},
 {'name':'Masmorra','id':'dungeon','wide':"res://tavern_assets/environments/dungeon_wide.webp",'portrait':"res://tavern_assets/environments/dungeon_portrait.webp",'tray':Color('a5a8dd'),'torch':Color('ff8d51'),'motes':Color('c9b4ed')},
 {'name':'Floresta','id':'forest','wide':"res://tavern_assets/environments/forest_wide.webp",'portrait':"res://tavern_assets/environments/forest_portrait.webp",'tray':Color('94c5a7'),'torch':Color('e5dc8a'),'motes':Color('c6ee9e')},
]
const ELEMENT_LIGHT={
 'fire':Color(1.42,1.15,0.83),
 'water':Color(0.63,0.84,1.12),
 'wind':Color(0.85,0.88,1.28),
 'nature':Color(0.84,1.21,0.80),
 'earth':Color(0.82,0.68,0.50),
}

var back: Sprite2D
var middle: Sprite2D
var front: Sprite2D
var lights: Array[PointLight2D]=[]
var smoke: Array[CPUParticles2D]=[]
var motes: CPUParticles2D
var board_size=Vector2.ZERO
var theme_index=-1
var portrait_mode=false
var battle=false
var offset=Vector2.ZERO
var room_light=Color.WHITE
var spell_light=Color.WHITE
var spell_left=0.0

func _ready() -> void:
 back=layer("Fundo")
 middle=layer("Meio")
 middle.light_mask=2
 front=layer("Frente")
 middle.texture=preload("res://tavern_assets/royal/arena.webp")
 middle.material=material("""
 void fragment() {
  vec2 p=UV;
  float sides=1.0-smoothstep(0.035,0.11,min(p.x,1.0-p.x));
  float rim=max(sides,1.0-smoothstep(0.04,0.11,min(p.y,1.0-p.y)));
  float floor_mix=smoothstep(0.11,0.20,p.y)*(1.0-smoothstep(0.69,0.81,p.y));
  float crest=smoothstep(0.25,0.39,p.x)*(1.0-smoothstep(0.60,0.75,p.x));
  float heroes=crest*max(1.0-smoothstep(0.13,0.17,p.y),smoothstep(0.59,0.63,p.y)*(1.0-smoothstep(0.75,0.79,p.y)));
  COLOR.a *= max(heroes,max(0.91-rim*0.55-floor_mix*0.20,rim*0.35));
 }
 """)
 front.material=material("""
 void fragment() {
  vec2 p=UV;
  float border=min(p.x,1.0-p.x);
  if (border >= 0.16) discard;
  float edge=1.0-smoothstep(0.025,0.16,border);
  float corners=smoothstep(0.46,0.83,p.y);
  COLOR.a *= edge*(0.32+corners*0.60);
 }
 """)
 var haze=radial(Color.WHITE,Color.TRANSPARENT)
 for i in range(2):
  var lamp=PointLight2D.new()
  lamp.name="LuzTocha%d"%i
  lamp.texture=haze
  lamp.range_item_cull_mask=2
  lamp.texture_scale=3.0
  lamp.energy=0.55
  add_child(lamp)
  lights.append(lamp)
  var plume=particles(6,2.5,haze)
  plume.spread=20
  plume.gravity=Vector2(4,-5)
  plume.initial_velocity_min=8
  plume.initial_velocity_max=18
  plume.scale_amount_min=0.18
  plume.scale_amount_max=0.50
  plume.color=Color(0.65,0.61,0.64,0.20)
  smoke.append(plume)
 motes=particles(18,5.0,haze)
 motes.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
 motes.spread=150
 motes.gravity=Vector2(2,-1)
 motes.initial_velocity_min=4
 motes.initial_velocity_max=12
 motes.scale_amount_min=0.025
 motes.scale_amount_max=0.07

func layer(label: String) -> Sprite2D:
 var sprite=Sprite2D.new()
 sprite.name=label
 add_child(sprite)
 return sprite

func material(fragment: String) -> ShaderMaterial:
 var shader=Shader.new()
 shader.code="shader_type canvas_item;\n"+fragment
 var result=ShaderMaterial.new()
 result.shader=shader
 return result

func radial(center: Color,edge: Color) -> GradientTexture2D:
 var gradient=Gradient.new()
 gradient.offsets=PackedFloat32Array([0.0,0.28,1.0])
 gradient.colors=PackedColorArray([center,Color(center,0.45),edge])
 var texture=GradientTexture2D.new()
 texture.width=128
 texture.height=128
 texture.fill=GradientTexture2D.FILL_RADIAL
 texture.fill_from=Vector2(0.5,0.5)
 texture.fill_to=Vector2(1,0.5)
 texture.gradient=gradient
 return texture

func particles(count: int,duration: float,texture: Texture2D) -> CPUParticles2D:
 var node=CPUParticles2D.new()
 node.emitting=false
 node.texture=texture
 node.amount=count
 node.lifetime=duration
 node.fixed_fps=20
 node.direction=Vector2.UP
 var fade=Gradient.new()
 fade.offsets=PackedFloat32Array([0.0,0.24,0.68,1.0])
 fade.colors=PackedColorArray([Color.TRANSPARENT,Color.WHITE,Color(1,1,1,0.50),Color.TRANSPARENT])
 node.color_ramp=fade
 add_child(node)
 return node

func configure(area: Vector2,theme: int,is_portrait: bool,in_battle: bool) -> void:
 if area==board_size and theme==theme_index and is_portrait==portrait_mode and battle==in_battle:return
 board_size=area
 theme_index=theme
 portrait_mode=is_portrait
 battle=in_battle
 var config: Dictionary=THEMES[theme]
 var path: String=config.portrait if is_portrait else config.wide
 if not back.texture or back.texture.resource_path!=path:
  back.texture=load(path)
  front.texture=back.texture
 var texture: Texture2D=back.texture
 var fill=Vector2.ONE*maxf(area.x/texture.get_width(),area.y/texture.get_height())
 back.scale=fill*1.075
 front.scale=fill*1.12
 middle.scale=area/middle.texture.get_size()
 middle.visible=battle
 motes.position=area/2
 motes.emission_rect_extents=area*0.49
 motes.color=Color(config.motes,0.62)
 for i in range(lights.size()):
  lights[i].position=torch_position(i)
  smoke[i].position=lights[i].position
  lights[i].color=config.torch
  lights[i].texture_scale=clampf(area.x*0.29/128,1.8,4.0)
 apply_layers()

func torch_position(index: int) -> Vector2:
 return board_size*Vector2(0.285 if index==0 else 0.715,0.069)

func illuminate(element: String) -> void:
 spell_light=ELEMENT_LIGHT.get(element,Color(1.10,0.93,1.23))
 spell_left=1.35

func reset_motion() -> void:
 offset=Vector2.ZERO
 spell_left=0.0
 room_light=Color.WHITE
 apply_layers()
 set_particles(false)

func set_particles(enabled: bool) -> void:
 motes.visible=enabled
 motes.emitting=enabled
 for plume in smoke:
  plume.visible=enabled and battle
  plume.emitting=plume.visible

func advance(delta: float,lean: Vector2,reduced: bool,clock: float) -> void:
 set_particles(not reduced and battle)
 if reduced:
  offset=Vector2.ZERO
  room_light=Color.WHITE
  spell_left=0.0
 else:
  var target=lean.limit_length()*minf(16.0,board_size.x*0.016) if battle else Vector2.ZERO
  var blend=1.0-exp(-delta*7.0)
  offset=offset.lerp(target,blend)
  spell_left=maxf(0,spell_left-delta)
  var desired=Color.WHITE.lerp(spell_light,smoothstep(0.0,1.15,spell_left)) if battle else Color.WHITE
  room_light=room_light.lerp(desired,1.0-exp(-delta*11.0))
 for i in range(lights.size()):
  var lamp=lights[i]
  lamp.enabled=battle
  var flicker=1.0 if reduced else 1.0+0.13*sin(clock*8.0+i*2.1)+0.07*sin(clock*17.0+i)
  lamp.energy=0.57*flicker*clampf((room_light.r+room_light.g+room_light.b)/3.0,0.45,1.45)
 apply_layers()

func apply_layers() -> void:
 if theme_index<0:return
 var center=board_size/2
 back.position=center-offset*0.54
 middle.position=center
 front.position=center+offset
 back.modulate=room_light
 middle.modulate=room_light*THEMES[theme_index].tray
 front.modulate=room_light
