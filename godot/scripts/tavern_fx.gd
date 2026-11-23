extends RefCounted
# Resolution-independent, antialiased effects. No additional texture downloads.
var view_ref: WeakRef
var v:
 get:return view_ref.get_ref()
var c: CanvasItem
var halo=GradientTexture2D.new()
func _init(view) -> void:
 view_ref=weakref(view)
 halo.width=32
 halo.height=32
 halo.fill=GradientTexture2D.FILL_RADIAL
 halo.fill_from=Vector2(0.5,0.5)
 halo.fill_to=Vector2(1,0.5)
 var gradient=Gradient.new()
 gradient.offsets=PackedFloat32Array([0,0.22,0.45,1])
 gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0.8),Color(1,1,1,0.15),Color.TRANSPARENT])
 halo.gradient=gradient
func glow(at: Vector2,radius: float,color: Color,alpha=1.0) -> void:
 if radius<0.1 or alpha<0.002:return
 c.draw_texture_rect(halo,Rect2(at-Vector2.ONE*radius*2,Vector2.ONE*radius*4),false,Color(color.lightened(0.22),alpha))
func beam(a: Vector2,b: Vector2,color: Color,width=3.0,alpha=1.0) -> void:
 c.draw_line(a,b,Color(color,alpha*0.1),width*6,true)
 c.draw_line(a,b,Color(color,alpha*0.4),width*2.4,true)
 c.draw_line(a,b,Color(color.lightened(0.7),alpha),width,true)
func ring(at: Vector2,radius: float,color: Color,alpha=1.0,rotation=0.0) -> void:
 if radius<0.1 or alpha<0.002:return
 c.draw_arc(at,radius,0,TAU,72,Color(color,alpha*0.22),9,true)
 c.draw_arc(at,radius,0,TAU,72,Color(color,alpha),1.6,true)
 for i in range(8):
  var a=rotation+i*TAU/8;var p=at+Vector2.from_angle(a)*radius
  beam(p-Vector2.from_angle(a+0.7)*5,p+Vector2.from_angle(a+0.7)*5,color,1,alpha)
func shard(at: Vector2,angle: float,length: float,color: Color,alpha=1.0) -> void:
 # Subpixel shards collapse at canvas coordinates; omit their invisible tail.
 if length<1.0 or alpha<0.002:return
 var direction=Vector2.from_angle(angle);var across=direction.orthogonal()
 var polygon=PackedVector2Array([at-direction*length*0.6,at+across*length*0.17,at+direction*length,at-across*length*0.17])
 c.draw_colored_polygon(polygon,Color(color,alpha*0.7))
 beam(at-direction*length*0.4,at+direction*length*0.8,color,1.1,alpha)
func lightning(a: Vector2,b: Vector2,t: float,color: Color,alpha=1.0) -> void:
 var last=a
 for i in range(1,13):
  var f=i/12.0;var p=a.lerp(b,f)+(b-a).normalized().orthogonal()*sin(i*17+floor(t*18)*2)*18*sin(f*PI)
  beam(last,p,color,2.5,alpha)
  if i%3==0:beam(p,p+Vector2(sin(i*7)*28,-24),color,1,alpha*0.55)
  last=p
func shield(at: Vector2,scale: float,color: Color,alpha=1.0) -> void:
 var p=PackedVector2Array([Vector2(-39,-44),Vector2(0,-53),Vector2(39,-44),Vector2(34,7),Vector2(0,49),Vector2(-34,7),Vector2(-39,-44)])
 for i in range(p.size()):p[i]=at+p[i]*scale
 var fill=p.duplicate();fill.resize(fill.size()-1)
 c.draw_colored_polygon(fill,Color(color,alpha*0.12));c.draw_polyline(p,Color(color,alpha),3,true)
 beam(at+Vector2(0,-31)*scale,at+Vector2(0,23)*scale,color,3,alpha)
 beam(at+Vector2(-20,-12)*scale,at+Vector2(20,-12)*scale,color,3,alpha)
func leaves(at: Vector2,t: float,color: Color,alpha=1.0) -> void:
 for i in range(12):
  var a=i*2.4+t*2;var p=at+Vector2(cos(a)*54,sin(a)*25-t*45)
  shard(p,a,10,color,alpha)
func roots(at: Vector2,t: float,alpha=1.0) -> void:
 for i in range(5):
  var points=PackedVector2Array()
  for j in range(17):
   var f=j/16.0;points.append(at+Vector2(sin(f*TAU+i*2)*float(18+i*5),46-f*125*t))
  c.draw_polyline(points,Color(0.23,0.43,0.12,alpha),6,true)
  c.draw_polyline(points,Color(0.68,0.87,0.25,alpha*0.7),1.5,true)
 leaves(at,t,Color('9ded6a'),alpha)
func ranged(id: String) -> bool:
 return id in ['apprentice','archmage','drake','dragon','demon','firelord','frostling','wyrm','necro','dryad','familiar','phoenix']

func aura(id: String,rect: Rect2,strength=1.0,phase=0.0) -> void:
 c=v.canvas
 var card=v.game.cards.get(id,{})
 if card.is_empty():return
 var element=str(card.element);var color=v.element_color(element)
 var center=rect.get_center();var top=rect.position.y
 var time=v.clock+phase
 # Effects extend beyond the frame, leaving the name/rules panel readable.
 for i in range(8):
  var cycle=fposmod(time*0.85+i*0.137,1.0)
  var edge=-1.0 if i%2==0 else 1.0
  var at=Vector2(center.x+edge*(rect.size.x*0.52+sin(time*3+i)*8),top+rect.size.y*(0.12+cycle*0.56))
  var alpha=sin(cycle*PI)*strength
  match element:
   'fire':
    at.y=top+rect.size.y*0.58-cycle*(rect.size.y*0.65+24)
    shard(at,-PI/2+sin(time*4+i)*0.2,15+cycle*13,Color('ffb347'),alpha)
    glow(at,9,Color('ff641d'),alpha*0.75)
   'ice':shard(at,time*0.3+i,16,Color('b8efff'),alpha)
   'lightning','storm':
    if i%2==0:lightning(at,at+Vector2(edge*26,-33),time,color,alpha*0.8)
   'nature','heal':
    shard(at,time+i*2.4,11,Color('c1ffae'),alpha)
    if element=='heal' and i%3==0:
     beam(at-Vector2(5,0),at+Vector2(5,0),color,1.5,alpha)
     beam(at-Vector2(0,5),at+Vector2(0,5),color,1.5,alpha)
   'earth':shard(at,i*1.7+time*0.3,13,Color('d1b98c'),alpha)
   'shield','steel':
    if i%2==0:beam(at,at+Vector2(edge*13,-16),Color('ffe7a6'),2,alpha)
   'bite':shard(at,-0.7,10,Color('e1e9f5'),alpha)
   _:
    glow(at,9,color,alpha)
    if i%2==0:shard(at,time+i,9,color,alpha)
 var crest=Vector2(center.x,top-18+sin(time*3)*5)
 match element:
  'fire':
   glow(crest,18,Color('ff712a'),strength*0.8)
   for i in range(3):shard(crest+Vector2((i-1)*12,sin(time*5+i)*5),-PI/2,28+i%2*9,Color('ffce68'),strength)
  'ice':
   glow(crest,16,Color('81dfff'),strength*0.7)
   for i in range(3):shard(crest+Vector2((i-1)*19,absf(i-1)*8),-PI/2+(i-1)*0.25,27,Color('cefbff'),strength)
  'earth':
   for i in range(3):shard(crest+Vector2((i-1)*25,sin(time*2+i)*10),time*0.4+i,20,Color('ddc9a0'),strength)
  'nature','heal':
   for i in range(4):shard(crest+Vector2.from_angle(time+i*TAU/4)*21,time+i,18,Color('adffb1'),strength)
  'shield':shield(crest,0.45,Color('ffe59d'),strength)
  'steel','bite':
   for i in range(3):shard(crest+Vector2((i-1)*17,0),-0.9,21,Color('fff0bb'),strength)
  _:
   glow(crest,16,color,strength)
   ring(crest,26,color,strength*0.7,time*2)
 c.draw_arc(center,rect.size.x*0.60,time*0.7,time*0.7+PI*0.7,36,Color(color,strength*0.35),2,true)

func trail() -> void:
 c=v.canvas
 var points=v.pointer_trail
 for i in range(1,points.size()):
  var a=points[i-1];var b=points[i]
  var alpha=clampf(1.0-float(b.age)/0.4,0,1)*0.65
  var color=v.element_color(v.game.cards[b.id].element)
  beam(a.position,b.position,color,2+alpha*3,alpha)
  if i%3==0:shard(b.position+Vector2(sin(i*3+v.clock)*14,0),-PI/2,8,color,alpha)

func action(a: Dictionary,time: float) -> void:
 c=v.canvas
 if a.is_empty():return
 var element=str(a.get('element','arcane'));var id=str(a.get('id',''))
 var color=v.element_color(element);var origin: Vector2=a.origin;var dest: Vector2=a.destination
 var card=v.game.cards.get(id,{})
 if a.kind=='power':
  var charge=clampf(time/0.52,0,1)
  var focus=origin.lerp(dest,smoothstep(0.12,0.52,time))
  for i in range(3):
   var twist=Vector2.from_angle(i*TAU/3+time*10)*(1-charge)*32
   beam(focus+twist,focus+twist.rotated(-0.55),color,3,1-charge)
  if time<0.52:glow(focus,9+12*charge,color)
  elif a.side==1:shield(dest,1.4,color,clampf(1-(time-0.52)*2,0,1))
 if a.kind=='attack':
  if not ranged(id) and time>0.10 and time<0.42:
   var travel=smoothstep(0.10,0.39,time)
   var direction=(dest-origin).normalized()
   var normal=direction.orthogonal()
   for i in range(3):
    var offset=normal*(i-1)*10
    var tip=origin.lerp(dest,travel)+offset
    beam(tip-direction*(18+32*sin(travel*PI)),tip,color,3-i*0.5,sin(travel*PI))
  if ranged(id) and time<0.38:
   projectile(origin,dest,clampf(time/0.38,0,1),element,color)
  return
 if a.get('card_kind','')=='minion':
  if time<0.52:
   ring(dest,60*clampf(time/0.3,0,1),color,0.75,time*2)
   glow(dest,30,color,0.4)
  return
 var t=clampf(time/0.52,0,1)
 var fade=clampf(1.0-(time-0.52)/0.62,0,1)
 if time<0.5:ring(origin,20+sin(t*PI)*24,color,0.8,time*4)
 match id:
  'solar':
   var corona=origin if time<0.52 else dest
   var radius=70-42*t if time<0.52 else 28+100*(1-fade)
   for ray in range(12):
    var angle=ray*TAU/12+0.5*t
    var radial=Vector2.from_angle(angle)
    shard(corona+radial*radius,angle,12+16*fade,Color('ffdb74'),fade)
   if time<0.52:
    ring(origin,24+42*t,Color('ffd65d'),1-t*0.4,time*3)
    projectile(origin,dest,t,'fire',Color('ffb33e'))
   else:
    impact(dest,'fire',clampf((time-0.52)/0.60,0,1),fade)
    shield(origin,1.25,Color('ffda70'),fade)
  'meteor':
   var row=v.layout.enemy_row if a.get('side',0)==0 else v.layout.player_row
   for i in range(5):
    var end=Vector2(v.layout.w*(0.22+i*0.14),row+sin(i*12)*28)
    projectile(end+Vector2(-170,-320),end,clampf((time-i*0.035)/0.42,0,1),'fire',color)
    if time>0.46:impact(end,'fire',clampf((time-0.46)/0.6,0,1),fade,'meteor')
  'thunderstorm','blizzard':
   var row=v.layout.enemy_row if a.get('side',0)==0 else v.layout.player_row
   for i in range(5):
    var end=Vector2(v.layout.w*(0.20+i*0.15),row)
    if id=='thunderstorm':lightning(end-Vector2(22,170),end,time,color,fade)
    else:
     for j in range(3):shard(end+Vector2(sin(i*17+j)*32,-120+fmod(time*230+j*53,170)),1.8,24,Color('c1f8ff'),fade)
    if time>0.48:impact(end,element,clampf((time-0.48)/0.6,0,1),fade)
  'missiles':
   for i in range(3):
    var end=dest
    var points=a.get('impact_points',[])
    if i<points.size():end=points[i]
    var flight=clampf((time-0.52)/0.3,0,1)
    var p=origin.lerp(end,flight)+Vector2(sin(flight*PI)*(i-1)*85,-sin(flight*PI)*80)
    if time<0.52:p=origin+Vector2.from_angle(i*TAU/3+time*5)*30
    if time<0.82:glow(p,14,color)
    elif time<1.3:impact(end,'arcane',clampf((time-0.82)/0.48,0,1),fade)
  'barrier':
   dest=v.layout.player_hero.get_center() if a.get('side',0)==0 else v.layout.enemy_hero.get_center()
   shield(dest,1.3+sin(t*PI)*0.25,Color('ffe69b'),fade)
   ring(dest,80,Color('ffd45e'),fade,time)
  'roots':roots(dest,t,fade)
  'healing','blessing':
   leaves(dest,t,Color('95ffc4') if id=='healing' else Color('ffdb79'),fade)
   for i in range(5):
    var p=dest+Vector2(sin(i*17)*45,40-fmod(time*110+i*29,135))
    beam(p-Vector2(6,0),p+Vector2(6,0),color,2,fade);beam(p-Vector2(0,6),p+Vector2(0,6),color,2,fade)
   if id=='blessing':ring(dest,65,Color('ffe8a1'),fade,time*2)
  'rune_blade':
   shard(dest, -0.95,75,Color('ffdd86'),fade)
   ring(dest,67,Color('ffe39a'),fade,time*2)
  'vortex':
   for i in range(4):
    var radius=(25+i*18)*(1.0-t*0.6)
    c.draw_arc(dest,radius,time*8+i,time*8+i+PI*1.6,64,Color(color,fade*(0.9-i*0.13)),6,true)
   glow(dest,28,Color('cda3ff'),fade)
  'pack':
   for i in range(2):
    var p=dest+Vector2((i-0.5)*125,0)
    ring(p,58*t,Color('91f1bd'),fade,time*(1 if i==0 else -1)*3)
    leaves(p,t,Color('91f1bd'),fade)
  'wisdom':
   for i in range(2):
    var p=origin.lerp(dest,t)+Vector2((i-0.5)*65,-sin(t*PI)*90)
    var rect=Rect2(p-Vector2(20,29),Vector2(40,58))
    c.draw_rect(rect,Color(0.91,0.76,0.45,fade*0.3));c.draw_rect(rect,Color(0.95,0.85,0.61,fade),false,2)
    for j in range(3):beam(p+Vector2(-12,-12+j*10),p+Vector2(12,-12+j*10),color,1,fade)
  'crystal':
   var p=dest.lerp(Vector2(v.layout.w*0.5,v.layout.h*0.966),t)
   shard(p,-PI/2,36,Color('81deff'),fade);ring(p,43,Color('7fcfff'),fade,time*3)
  _:
   if time<0.52:projectile(origin,dest,t,element,color)
   else:impact(dest,element,clampf((time-0.52)/0.65,0,1),fade,id)
func projectile(origin: Vector2,dest: Vector2,t: float,element: String,color: Color) -> void:
 # Sample the same arc as the projectile so the tail follows its trajectory.
 for i in range(4):
  var head=maxf(0,t-i*0.042)
  var tail=maxf(0,head-0.042)
  if head<=tail:break
  var start=origin.lerp(dest,tail)-Vector2.DOWN*sin(tail*PI)*55
  var end=origin.lerp(dest,head)-Vector2.DOWN*sin(head*PI)*55
  c.draw_line(start,end,Color(color,0.53-i*0.11),8-i*1.5,true)
 var at=origin.lerp(dest,t)+Vector2(0,-sin(t*PI)*55)
 var direction=(dest-origin).normalized()
 if element in ['storm','lightning']:
  lightning(origin,at,t,color);glow(at,20,color)
 elif element=='ice':
  for i in range(5):shard(at-direction*i*12,(dest-origin).angle(),30-i*3,Color('c4f4ff'),1.0-i*0.15)
 elif element in ['steel','bite']:
  for i in range(3):beam(at+Vector2(-30,-25+i*18),at+Vector2(25,15+i*18),color,3,0.8)
 else:
  for i in range(9):
   var p=at-direction*i*9+Vector2(0,sin(i*2+t*16)*i*1.5)
   glow(p,maxf(2,24-i*2),color,(1-i/10.0)*0.8)
  glow(at,34,color)
func impact(at: Vector2,element: String,t: float,alpha=1.0,id='') -> void:
 if t>=0.999 or alpha<0.002:return
 c.draw_set_transform(at,0,Vector2(1.4,1.4))
 impact_shape(Vector2.ZERO,element,t,alpha,id)
 c.draw_set_transform_matrix(Transform2D.IDENTITY)

func impact_shape(at: Vector2,element: String,t: float,alpha=1.0,id='') -> void:
 if t>=0.999 or alpha<0.002:return
 var color=v.element_color(element);var fade=(1-t)*alpha
 if element in ['steel','bite']:
  for i in range(3 if element=='bite' else 2):
   var offset=Vector2((i-1)*16,0) if element=='bite' else Vector2.ZERO
   var dir=Vector2.from_angle(-0.65+i*1.6 if element=='steel' else -0.75)
   beam(at+offset-dir*65*(1-t),at+offset+dir*65*t,Color('fff3bc'),5,fade)
 elif element=='ice':
  for i in range(8):shard(at+Vector2.from_angle(i*TAU/8)*(18+t*55),i*TAU/8,34*(1-t*0.5),color,fade)
 elif element in ['earth','nature']:
  if element=='nature':roots(at,1-t*0.3,fade)
  else:
   for i in range(7):
    var p=at+Vector2.from_angle(i*TAU/7)*t*75
    shard(p,i*2.4,18,Color('b6a07a'),fade)
   ring(at,25+t*70,color,fade)
 elif element in ['storm','lightning']:
  for i in range(5):lightning(at,at+Vector2.from_angle(i*TAU/5+t)*65,t,color,fade)
 elif element in ['shield','heal']:
  shield(at,1+t*0.2,color,fade)
 elif element=='dark':
  ring(at,70*(1-t),color,fade,t*8)
  for i in range(10):glow(at+Vector2.from_angle(i*2.4+t*5)*70*(1-t),6,color,fade)
 else:
  glow(at,45+t*50,color,fade*0.8)
  for i in range(14):
   var angle=i*2.4;var p=at+Vector2.from_angle(angle)*(15+t*(55+i%4*15))
   shard(p,angle,18*(1-t),color,fade)
  ring(at,20+t*80,color,fade*0.65)
func event(p: Dictionary) -> void:
 c=v.canvas
 var t=clampf(p.age/1.15,0,1);var fade=1-t;var at: Vector2=p.position
 var kind=str(p.kind);var element=str(p.get('element','arcane'));var color=v.element_color(element)
 if kind=='summon' and v.unit_views.has(int(p.uid)):at=v.unit_views[int(p.uid)].rect.get_center()
 match kind:
  'support':
   var travel=clampf(t/0.52,0,1)
   if travel<1:
    ring(p.origin,14+22*travel,color,1-travel,travel*PI)
    projectile(p.origin,at,travel,element,color)
   elif p.defense:shield(at,1+0.4*sin(PI*(t-0.52)/0.48),color,fade*2)
   else:impact(at,element,(t-0.52)/0.48,fade*2,p.id)
  'damage':
   var shock=clampf(p.age/0.32,0,1)
   if shock<1:
    var radius=(14+48*ease(shock,0.45))*clampf(0.65+0.09*p.amount,0.7,1.4)
    for i in range(4):
     var angle=i*PI/2+shock*0.3
     c.draw_arc(at,radius,angle,angle+1.1,12,Color(color.lightened(0.45),1-shock),3,true)
   if element=='fire':
    glow(at,63+t*70,color,fade*0.8)
    ring(at,28+t*112,color,fade*0.65)
   else:impact(at,element,t,1,str(p.get('id','')))
  'summon':
   var base=at+Vector2(0,35)
   ring(base,65*(0.6+t*0.6),color,fade,p.age*3)
   for i in range(6):
    var angle=i*TAU/6+p.age*2
    var start=base+Vector2(cos(angle)*44,sin(angle)*15)
    beam(start,start-Vector2(0,48*sin(PI*t)),color,1.6,fade*0.75)
   var id=str(p.get('id',''))
   if id in ['dragon','drake','firelord','demon']:
    for i in range(9):
     var point=at+Vector2((i-4)*14,42-t*110-absf(i-4)*7)
     shard(point,-PI/2,27,Color('ffad45'),fade)
    impact(at,'fire',t,0.45)
   elif id in ['wolf','token_wolf','panther','gryphon']:
    for i in range(3):
     var point=at+Vector2((i-1)*28,40-t*75)
     for j in range(3):beam(point+Vector2(j*6,-18),point+Vector2(j*6+8,10),color,2,fade)
   elif id in ['necro','skeleton','token_skeleton']:
    for i in range(6):glow(at+Vector2(sin(i*17+t*5)*44,40-t*100+i*5),9,Color('bb8cf7'),fade)
   elif element in ['nature','heal']:leaves(at,t,color,fade)
   elif element=='earth':impact(at,'earth',t,0.7)
   else:
    for i in range(8):glow(at+Vector2.from_angle(i*2.4+p.age)*float(65*(1-t)),6,color,fade)
  'armor','blocked':
   shield(at,1.3+sin(t*PI)*0.15,Color('ffe3a0'),fade)
  'shield_break':
   var corners=[Vector2(-38,-36),Vector2(0,-49),Vector2(38,-36),Vector2(30,13),Vector2(0,48),Vector2(-30,13)]
   for i in range(corners.size()):
    var edge: Vector2=corners[i]
    var next: Vector2=corners[(i+1)%corners.size()]
    var drift=(edge+next).normalized()*54*t+Vector2.DOWN*30*t*t
    var fragment=PackedVector2Array([at+drift,at+edge+drift,at+next+drift])
    c.draw_colored_polygon(fragment,Color(1,0.78,0.36,0.32*fade))
    c.draw_line(fragment[1],fragment[2],Color(1,0.91,0.64,fade),3,true)
  'heal','buff':
   ring(at,55,Color('b8ffd0') if kind=='heal' else Color('ffe197'),fade,p.age)
  'freeze':
   for i in range(7):shard(at+Vector2(-52+i*17,35),-PI/2,50+i%3*15,Color('b1edff'),fade)
  'debuff':roots(at,1-t*0.25,fade)
  'destroy':impact(at,'dark',t,0.9)
  'death':
   impact(at,element,t,1.15)
   for i in range(10):
    var point=at+Vector2.from_angle(i*2.4)*(20+t*90)+Vector2(0,-t*60 if element=='fire' else t*t*40)
    shard(point,i*1.4,18*(1-t),color,fade)
  'draw','mana':
   shard(at-Vector2(0,t*65),-PI/2,24,Color('92dfff'),fade)
func status(unit: Dictionary,rect: Rect2) -> void:
 c=v.canvas
 var at=rect.get_center()
 if unit.frozen>0 or unit.get('frozen_lock',false):
  for i in range(4):shard(at+Vector2(-35+i*23,35),-PI/2,35+i%2*15,Color('a9eaff'),0.55)
 if 'poison' in unit.keywords:
  for i in range(3):glow(at+Vector2(sin(i*2+v.clock)*rect.size.x*0.45,30+cos(i*3+v.clock*2)*8),3,Color('9fe342'),0.5)
 if unit.shield:ring(at,rect.size.x*0.6,Color('ffe8a2'),0.3+sin(v.clock*2)*0.1,v.clock*0.3)

func environment() -> void:
 c=v.canvas
 for effect in v.scenery:
  var t=float(effect.age)/2.4;var fade=1-t
  var element=str(effect.element);var color=v.element_color(element)
  var at: Vector2=effect.position
  c.draw_rect(Rect2(Vector2.ZERO,v.game.logical_size),Color(color,fade*0.045))
  # Reflections and elemental remnants on the board, underneath all cards.
  for i in range(3):
   var floor_point=at+Vector2((i-1)*75,35+absf(i-1)*12)
   glow(floor_point,52+sin(t*PI)*30,color,fade*0.13)
  match element:
   'fire':
    for i in range(18):
     var point=at+Vector2(sin(i*17)*130,60-fposmod(effect.age*70+i*19,210))
     shard(point,-PI/2,9,Color('ffbd6a'),fade*0.8)
    for side in [-1,1]:
     glow(Vector2(v.layout.w*(0.05 if side==-1 else 0.95),v.layout.h*0.28),100,color,fade*0.4)
    c.draw_arc(at,95,0,TAU,64,Color(0.22,0.07,0.03,fade*0.25),12,true)
   'ice':
    for i in range(12):
     var point=Vector2(v.layout.w*(0.06 if i%2==0 else 0.94),v.layout.h*(0.2+i*0.04))
     shard(point,-PI/2+(i%2-0.5),28,Color('c7f4ff'),fade*0.65)
    for i in range(15):
     var point=at+Vector2(sin(i*7)*130,-90+fposmod(effect.age*45+i*21,180))
     c.draw_circle(point,2,Color('c5f2ff')*Color(1,1,1,fade))
   'lightning','storm':
    for i in range(4):
     var end=at+Vector2.from_angle(i*TAU/4+0.3)*145
     lightning(at,end,t,color,fade*0.45)
   'earth','nature':
    for i in range(3):roots(at+Vector2((i-1)*75,45),0.5+sin(t*PI)*0.5,fade*0.35)
   'heal','shield':
    ring(at,100+t*45,color,fade*0.3,t)
   'dark','arcane':
    for i in range(3):
     c.draw_arc(at,70+i*30,effect.age*(i+1),effect.age*(i+1)+PI*1.5,64,Color(color,fade*0.3),3,true)
