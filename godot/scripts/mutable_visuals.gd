extends RefCounted
# Sprite bounds exclude transparent atlas padding. Every pose pivots at its feet.
const BOUNDS = [Rect2(79,53,398,423),Rect2(607,103,417,314),Rect2(1024,53,457,424),Rect2(82,525,354,465),Rect2(604,608,301,298),Rect2(1038,576,435,363)]
# Supporting foot measured in the opaque bounds, including asymmetric stances.
const FOOT_X = [0.2287,0.3841,0.7519,0.3925,0.5198,0.5]
const WIDTHS = {'golem':124.0,'orc':118.0,'goblin':105.0,'mage':85.0,'skeleton':82.0,'wall':96.0,'wisp':40.0}
var g
func _init(game) -> void:g = game
func screen(pos: Vector2) -> Vector2:
 return Vector2(720-pos.x,985-pos.y) if g.side == 1 else pos
func direction(vec: Vector2) -> Vector2:return -vec if g.side == 1 else vec
func remaining(value: float) -> float:return maxf(0,value-g.visual_age)
func reset_transform() -> void:g.draw_set_transform(g.origin,0,Vector2.ONE*g.factor)
func sprite(index: int, destination: Rect2, tint: Color = Color.WHITE) -> void:
 if g.sprites == null:return
 var src: Rect2 = BOUNDS[index]
 var extent = src.size*minf(destination.size.x/src.size.x,destination.size.y/src.size.y)
 var position = destination.position+Vector2((destination.size.x-extent.x)/2,destination.size.y-extent.y)
 g.draw_texture_rect_region(g.sprites,Rect2(position,extent),src,tint)
func shadow(p: Vector2, width: float, alpha: float = 0.34) -> void:
 g.draw_set_transform(g.origin+p*g.factor,0,Vector2(g.factor,g.factor*0.28))
 g.draw_circle(Vector2.ZERO,width,Color(0.01,0.01,0.02,alpha))
 reset_transform()
func paint() -> void:
 for fx in g.rules.state.effects:
  if fx.kind in ['portal','banish']:portal(fx)
 var units: Array = g.rules.state.units.duplicate()
 units.sort_custom(func(a,b):return screen(Vector2(a.x,a.y)).y < screen(Vector2(b.x,b.y)).y)
 for u in units:unit(u)
 for hit in g.rules.state.get('strikes',[]):strike(hit)
 for fx in g.rules.state.effects:
  if fx.kind not in ['portal','banish']:impact(fx)
func unit(u: Dictionary) -> void:
 var p = screen(Vector2(u.x,u.y))
 var c: Dictionary = g.Rules.CARDS[u.id]
 var width = float(WIDTHS[u.id])
 var index = int(c.get('sprite',-1))
 var height = width*(BOUNDS[index].size.y/BOUNDS[index].size.x) if index >= 0 else 45.0
 var facing = direction(Vector2(u.get('facing_x',0),u.get('facing_y',-1)))
 var rotation = 0.0
 var scale_x = 1.0
 var scale_y = 1.0
 var alpha = 1.0
 var spawn = remaining(float(u.get('spawn_time',0)))
 var warp = remaining(float(u.get('warp_time',0)))
 var attack = remaining(float(u.get('strike_time',0)))
 var hurt = remaining(float(u.get('hurt_time',0)))
 if bool(u.get('moving',false)):
  rotation = sin(g.elapsed*11+float(u.uid))*0.035
  scale_x = 1+sin(g.elapsed*11+float(u.uid))*0.02
  # Feet remain on the ground; a grounded body sway replaces vertical hovering.
  if int(g.elapsed*12+u.uid)%5 == 0:g.draw_circle(p-facing*15,3,Color(0.6,0.51,0.42,0.16))
 if spawn > 0:
  var progress = 1-spawn/0.45
  scale_y = 0.7+0.3*sin(progress*PI/2);alpha = clampf(progress*3,0,1)
  g.draw_arc(p,18+(1-progress)*30,0,TAU,48,Color(0.18,0.91,1,1-progress),2,true)
 if attack > 0:
  var progress = 1-attack/0.6
  var swing = sin(clampf(progress/0.6,0,1)*PI)
  rotation += facing.x*swing*0.16
  scale_y *= 1+swing*0.05
  if float(c.range) < 90:p += facing*swing*13
  else:
   g.draw_arc(p+Vector2(facing.x*18,-height*0.65),12+8*swing,0,TAU,32,Color(0.5,0.7,1,swing),2,true)
 if hurt > 0:
  var recoil = direction(Vector2(u.get('recoil_x',0),u.get('recoil_y',0)))
  rotation -= recoil.x*sin(hurt/0.32*PI)*0.18
  scale_y *= 1-sin(hurt/0.32*PI)*0.08
 if warp > 0:
  var progress = 1-warp/0.9
  if progress < 0.5:
   p = screen(Vector2(u.get('warp_from_x',u.x),u.get('warp_from_y',u.y)))
   scale_x *= maxf(0.02,1-progress*2);scale_y *= 1+progress*0.5;alpha = 1-progress*2
  else:
   scale_x *= maxf(0.02,(progress-0.5)*2);alpha = (progress-0.5)*2
 shadow(p,29 if u.id == 'golem' else (36 if u.id == 'wall' else 20),0.34*alpha)
 if u.id == 'wall':
  # Wall texture endpoints and WALL_STEP share the same isometric baseline.
  height = 80
 var anchor_x = width*FOOT_X[index] if index >= 0 else width/2
 var body_offset = width/2-anchor_x
 var anchor_y = height*0.78 if u.id == 'wall' else height
 g.draw_set_transform(g.origin+p*g.factor,rotation,Vector2(scale_x,scale_y)*g.factor)
 if index >= 0:
  var color = Color(1.2,0.83,0.76,alpha) if hurt > 0.15 else Color(1,1,1,alpha)
  g.draw_texture_rect_region(g.sprites,Rect2(-anchor_x,-anchor_y,width,height),BOUNDS[index],color)
 else:
  g.draw_circle(Vector2(0,-18),15,Color(0.3,0.9,1,alpha))
  g.draw_arc(Vector2(0,-18),20,g.elapsed,g.elapsed+4,24,Color(0.65,0.4,1,alpha),3,true)
 reset_transform()
 if hurt > 0 and u.id in ['golem','skeleton','wall']:
  var shield_pos = p+Vector2(body_offset,-height*0.45)
  var shield = PackedVector2Array([shield_pos+Vector2(-20,-16),shield_pos+Vector2(20,-16),shield_pos+Vector2(16,12),shield_pos+Vector2(0,26),shield_pos+Vector2(-16,12),shield_pos+Vector2(-20,-16)])
  g.draw_polyline(shield,Color(1,0.8,0.3,hurt/0.32),3,true)
 var bar = p+Vector2(body_offset-28,-height-12)
 g.draw_rect(Rect2(bar,Vector2(56,8)),Color('#101526'))
 g.draw_rect(Rect2(bar+Vector2(2,2),Vector2(52*maxf(0,float(u.hp)/float(u.max_hp)),4)),Color('#37dfef') if int(u.side) == g.side else Color('#ee454e'))
func strike(hit: Dictionary) -> void:
 var a = screen(Vector2(hit.x,hit.y))-Vector2(0,40)
 var b = screen(Vector2(hit.to_x,hit.to_y))-Vector2(0,36)
 var progress = clampf(1-remaining(float(hit.life))/float(hit.duration),0,1)
 var color = Color('#c476ff') if hit.id == 'mage' else Color('#ffc35e')
 if hit.ranged:
  var travel = clampf((progress-0.25)/0.75,0,1)
  var p = a.lerp(b,travel)
  g.draw_line(p-(b-a).normalized()*22,p,Color(color,0.5),5,true)
  g.draw_circle(p,9,Color(color,0.2));g.draw_circle(p,4,color);g.draw_circle(p,2,Color.WHITE)
 elif progress > 0.35:
  var center = a.lerp(b,0.7)
  var angle = (b-a).angle()
  g.draw_arc(center,27,angle-1.5+progress,angle+0.8+progress,24,Color(1,0.87,0.65,0.9),4,true)
func portal(fx: Dictionary) -> void:
 var duration = float(fx.get('duration',0.9))
 var t = clampf(1-remaining(float(fx.life))/duration,0,1)
 var p = screen(Vector2(fx.x,fx.y))
 vortex(p,t,fx.kind == 'portal')
 if fx.kind == 'banish':
  var destination = screen(Vector2(fx.to_x,fx.to_y))
  vortex(destination,1-t,false)
  for i in range(5):
   var k = clampf(t*1.8-float(i)*0.06,0,1)
   var point = p.lerp(destination,k)+Vector2(sin(k*PI)*30,-sin(k*PI)*60)
   g.draw_circle(point,4-float(i)*0.5,Color(0.64,0.4,1,sin(k*PI)*0.7))
func vortex(p: Vector2, t: float, main: bool) -> void:
 var strength = sin(t*PI)
 var radius = (54 if main else 32)*strength
 g.draw_set_transform(g.origin+p*g.factor,0,Vector2(1,0.48)*g.factor)
 g.draw_circle(Vector2.ZERO,radius,Color(0.28,0.04,0.48,0.75*strength))
 for ring in range(3):
  var angle = t*TAU*3+ring*TAU/3
  g.draw_arc(Vector2.ZERO,radius+ring*4,angle,angle+4.5,48,Color(0.7,0.35+ring*0.15,1,strength),3,true)
 reset_transform()
 for i in range(8):
  var angle = t*TAU*2+i*TAU/8
  g.draw_circle(p+Vector2(cos(angle)*radius,sin(angle)*radius*0.45-12*strength),2.5,Color(0.8,0.65,1,strength))
func impact(fx: Dictionary) -> void:
 var p = screen(Vector2(fx.x,fx.y))
 var duration = float(fx.get('duration',0.6))
 var progress = clampf(1-remaining(float(fx.life))/duration,0,1)
 if remaining(float(fx.life)) <= 0:return
 if fx.kind == 'death':
  var index = int(g.Rules.CARDS[fx.id].get('sprite',-1))
  if index >= 0:
   var width = float(WIDTHS[fx.id]);var height = width*BOUNDS[index].size.y/BOUNDS[index].size.x
   g.draw_set_transform(g.origin+p*g.factor,progress*0.5,Vector2.ONE*g.factor*(1-progress*0.35))
   g.draw_texture_rect_region(g.sprites,Rect2(-width*FOOT_X[index],-height*(0.78 if fx.id == 'wall' else 1),width,height),BOUNDS[index],Color(0.65,0.6,0.7,1-progress))
   reset_transform()
  return
 var color = Color('#65ffb7') if fx.kind == 'heal' else (Color('#c7a783') if fx.get('id','') == 'wall' else Color('#ffcd76'))
 var center = p-Vector2(0,30)
 for i in range(8):
  var angle = i*TAU/8+0.4
  var end = center+Vector2.from_angle(angle)*(8+progress*32)
  g.draw_line(end-Vector2.from_angle(angle)*6,end,Color(color,1-progress),2,true)
 if fx.kind in ['heal','fire']:
  g.draw_arc(p,20+progress*100,0,TAU,64,Color(color,(1-progress)*0.8),3,true)
 else:g.draw_line(center+Vector2(-13,10)*(1-progress),center+Vector2(13,-10)*(1-progress),Color(1,1,0.9,1-progress),4,true)
