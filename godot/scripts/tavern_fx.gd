extends RefCounted

const STATUS_COLORS={
 &"shield":Color('ffe49a'),
 &"taunt":Color('ffac76'),
 &"frozen":Color('aeedff'),
 &"poison":Color('b5e86c'),
 &"lifesteal":Color('ffa3c0'),
}
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
 var card=v.game.cards.get(id,{})
 c=v.canvas
 if card.is_empty():return
 var element=str(card.get('fx',card.element));var color=v.element_color(card.element)
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
 var element=str(a.get('fx',a.get('element','wind')));var id=str(a.get('id',''))
 var color=v.element_color(element);var origin: Vector2=a.origin;var dest: Vector2=a.destination
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
  'fireball','meteor','bolt','missiles','thunderstorm','frost','blizzard','healing','blessing','roots','pack','barrier','vortex','rune_blade','crystal','wisdom':
   spell(a,time,element,color)
  _:
   if time<0.52:projectile(origin,dest,t,element,color)
   else:impact(dest,element,clampf((time-0.52)/0.65,0,1),fade,id)
# The impact clock comes from the scheduled action. Random missiles acquire
# their real endpoints only once the rules have resolved their hits.
func spell(a: Dictionary,time: float,element: String,color: Color) -> void:
 var id: String=a.id
 var origin: Vector2=a.origin
 var dest: Vector2=a.destination
 var row: float=v.layout.enemy_row if a.side==0 else v.layout.player_row
 if id in ['meteor','thunderstorm','blizzard']:dest.y=row
 if id=='barrier':dest=(v.layout.player_hero if a.side==0 else v.layout.enemy_hero).get_center()
 var hit: float=a.impact
 var t=smoothstep(hit*0.24,hit,time)
 var age=clampf((time-hit)/(a.duration-hit),0,1)
 var fade=1.0-smoothstep(0.24,1.0,age)
 if time<hit:
  if id in ['fireball','meteor']:
   var count=3 if id=='meteor' else 1
   for i in range(count):
    var end=dest+Vector2((i-(count-1)*0.5)*v.layout.w*0.23,0)
    var apex=end+Vector2(-85,-215)
    var head=origin.lerp(apex,smoothstep(0,0.42,t)).lerp(end,smoothstep(0.42,1,t))
    c.draw_circle(end,11+18*t,Color(0.12,0.055,0.02,t*0.38),true,-1,true)
    glow(head,12+14*t,color)
    shard(head-Vector2(7,17)*t,1.2,28*t,Color('ffd78c'))
  elif id=='missiles':
   for i in range(3):glow(origin+Vector2.from_angle(i*TAU/3+t*2)*24,10,color)
  elif id in ['roots','healing','blessing','pack']:
   var bud=origin.lerp(dest,t)-Vector2.DOWN*sin(t*PI)*38
   glow(bud,14,color)
   for i in range(3):
    var direction=(dest-origin).angle()+sin(i*2+t*5)*0.6
    shard(bud-Vector2.from_angle(direction)*i*11,direction,11-i,color)
  else:projectile(origin,dest,t,element,color)
  return
 if id in ['fireball','meteor']:
  var count=3 if id=='meteor' else 1
  for i in range(count):
   var end=dest+Vector2((i-(count-1)*0.5)*v.layout.w*0.23,0)
   var radius=18+28*smoothstep(0,0.3,age)
   c.draw_set_transform(end,0,Vector2(1,0.38))
   c.draw_circle(Vector2.ZERO,radius,Color(0.16,0.06,0.03,0.62*fade))
   c.draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(color,fade),3,true)
   c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
   impact(end,'fire',clampf(age*2,0,1),fade,id)
  return
 if id in ['bolt','missiles','thunderstorm']:
  var points: Array=a.get('impact_points',[])
  var last=origin
  var count=maxi(1,points.size())
  for i in range(count):
   var end: Vector2=points[i] if i<points.size() else dest
   var strike=age-i*0.055
   if strike>=0 and strike<0.32:
    var start=last if id!='missiles' else origin+Vector2((i-1)*25,-16)
    lightning(start,end,strike,color,1-strike/0.32)
   if strike>=0:glow(end,23,color,fade)
   last=end
  if age<0.12:c.draw_rect(Rect2(Vector2.ZERO,v.game.logical_size),Color(color,0.09*(1-age/0.12)))
  return
 if id in ['frost','blizzard']:
  var spread=1.0 if id=='frost' else 4.0
  for i in range(9):
   var foot=dest+Vector2((i-4)*15*spread,20+sin(i*7)*14)
   shard(foot,-PI/2+sin(i)*0.4,(12+8*(i%3))*smoothstep(0,0.28,age),Color('b8edff'),fade)
  for unit in v.unit_views.values():
   if (id=='blizzard' and unit.side!=a.side) or unit.uid==a.target.get('uid',-1):
    c.draw_rect(unit.rect,Color(0.66,0.90,1.0,0.18*fade))
  return
 var growth=smoothstep(0,0.42,age)
 match id:
  'barrier':
   shield(dest,0.85+growth*0.5,Color('ffe69b'),fade)
   for i in range(6):shard(dest+Vector2((i-2.5)*25,35),-PI/2,30*growth,color,fade)
   ring(dest,80,Color('ffd45e'),fade,time)
  'roots':roots(dest,growth,fade)
  'healing','blessing':
   leaves(dest,growth,Color('95ffc4') if id=='healing' else Color('ffdb79'),fade)
   for i in range(5):
    var p=dest+Vector2(sin(i*17)*45,40-fmod(time*110+i*29,135))
    beam(p-Vector2(6,0),p+Vector2(6,0),color,2,fade);beam(p-Vector2(0,6),p+Vector2(0,6),color,2,fade)
   if id=='blessing':ring(dest,65,Color('ffe8a1'),fade,time*2)
  'rune_blade':
   shard(dest, -0.95,75,Color('ffdd86'),fade)
   ring(dest,67,Color('ffe39a'),fade,time*2)
  'vortex':
   for i in range(4):
    var radius=(25+i*18)*(1.0-growth*0.6)
    c.draw_arc(dest,radius,time*8+i,time*8+i+PI*1.6,64,Color(color,fade*(0.9-i*0.13)),6,true)
   glow(dest,28,Color('cda3ff'),fade)
  'pack':
   for i in range(2):
    var p=dest+Vector2((i-0.5)*125,0)
    ring(p,58*growth,Color('91f1bd'),fade,time*(1 if i==0 else -1)*3)
    leaves(p,growth,Color('91f1bd'),fade)
  'wisdom':
   for i in range(2):
    var p=dest+Vector2((i-0.5)*65,-growth*24)
    var rect=Rect2(p-Vector2(20,29),Vector2(40,58))
    c.draw_rect(rect,Color(0.91,0.76,0.45,fade*0.3));c.draw_rect(rect,Color(0.95,0.85,0.61,fade),false,2)
    for j in range(3):beam(p+Vector2(-12,-12+j*10),p+Vector2(12,-12+j*10),color,1,fade)
  'crystal':
   var p=dest-Vector2.DOWN*24*growth
   shard(p,-PI/2,36,Color('81deff'),fade);ring(p,43,Color('7fcfff'),fade,time*3)
 if id in ['rune_blade','wisdom','crystal']:
  for i in range(4):
   var angle=i*TAU/4+growth*0.35
   var radial=Vector2.from_angle(angle)
   var tip=dest+radial*62
   beam(tip-radial*12,tip,color,2,fade)
   beam(tip,tip-radial.rotated(0.8)*9,color,2,fade)

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
 var kind=str(p.kind);var element=str(p.get('fx',p.get('element','wind')));var color=v.element_color(element)
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
   elif id in ['necro','token_skeleton']:
    for i in range(6):glow(at+Vector2(sin(i*17+t*5)*44,40-t*100+i*5),9,Color('bb8cf7'),fade)
   elif element in ['nature','heal']:leaves(at,t,color,fade)
   elif element=='earth':impact(at,'earth',t,0.7)
   else:
    for i in range(8):glow(at+Vector2.from_angle(i*2.4+p.age)*float(65*(1-t)),6,color,fade)
  'armor','blocked':
   shield(at,1.3+sin(t*PI)*0.15,Color('ffe3a0'),fade)
  'shield_break':
   shield_crack(at,p.bubble_radius,p.age)
  'heal','buff':
   ring(at,55,Color('b8ffd0') if kind=='heal' else Color('ffe197'),fade,p.age)
   if p.has('drain_origin'):life_thread(p.drain_origin,at,p.age)
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
func frozen(unit: Dictionary) -> bool:
 return unit.frozen>0 or unit.get('frozen_lock',false)

func unit_statuses(unit: Dictionary) -> Array[StringName]:
 var icons: Array[StringName]=[]
 if unit.shield:icons.append(&"shield")
 if 'taunt' in unit.keywords:icons.append(&"taunt")
 if frozen(unit):icons.append(&"frozen")
 if 'poison' in unit.keywords:icons.append(&"poison")
 if 'lifesteal' in unit.keywords:icons.append(&"lifesteal")
 return icons

func status(unit: Dictionary,rect: Rect2,ice_growth: float) -> void:
 c=v.canvas
 var icons=unit_statuses(unit)
 if icons.is_empty():return
 var motion=not v.game.reduced_motion
 if unit.shield:
  divine_bubble(rect.get_center(),rect.size/2+Vector2.ONE*7,1.0)
 if 'taunt' in unit.keywords:
  var intensity=0.55+0.14*sin(v.clock*4) if motion else 0.55
  var at=rect.get_center()
  glow(at,rect.size.x*0.44,STATUS_COLORS[&"taunt"],intensity*0.33)
  c.draw_rect(rect.grow(5),Color(STATUS_COLORS[&"taunt"],intensity),false,2,true)
 if frozen(unit):grow_ice(rect,ice_growth if motion else 1.0)
 if motion and 'poison' in unit.keywords:poison_drops(rect,int(unit.uid))
 # The icons stay visible in reduced motion and follow the creature's pose.
 var radius=clampf(rect.size.x/(icons.size()*2.25),5.0,12.0)
 var at=rect.position+Vector2(rect.size.x/2-(icons.size()-1)*radius*1.1,rect.size.y*0.31)
 for icon in icons:
  status_icon(at,radius,icon)
  at.x+=radius*2.2

func status_icon(at: Vector2,radius: float,icon: StringName) -> void:
 var ink=STATUS_COLORS[icon]
 c.draw_circle(at,radius,Color('26202d'),true,-1,true)
 c.draw_arc(at,radius,0,TAU,20,ink,1.4,true)
 c.draw_set_transform(at,0,Vector2.ONE*radius/10)
 match icon:
  &"shield":
   c.draw_colored_polygon(PackedVector2Array([Vector2(-5,-5),Vector2(5,-5),Vector2(4,2),Vector2(0,6),Vector2(-4,2)]),ink)
  &"taunt":
   c.draw_polyline(PackedVector2Array([Vector2(-6,3),Vector2(0,-4),Vector2(6,3)]),ink,2,true)
   c.draw_line(Vector2(0,-4),Vector2(0,6),ink,2,true)
  &"frozen":
   for i in range(3):
    var ray=Vector2.from_angle(i*PI/3)*6
    c.draw_line(-ray,ray,ink,2,true)
  &"poison":
   c.draw_colored_polygon(PackedVector2Array([Vector2(0,-6),Vector2(5,1),Vector2(4,5),Vector2(0,7),Vector2(-4,5),Vector2(-5,1)]),ink)
  &"lifesteal":
   c.draw_circle(Vector2(-2.6,-1.5),3.3,ink,true,-1,true)
   c.draw_circle(Vector2(2.6,-1.5),3.3,ink,true,-1,true)
   c.draw_colored_polygon(PackedVector2Array([Vector2(-5.4,0),Vector2(5.4,0),Vector2(0,6)]),ink)
 c.draw_set_transform_matrix(Transform2D.IDENTITY)

func divine_bubble(at: Vector2,radii: Vector2,alpha: float) -> void:
 var color: Color=STATUS_COLORS[&"shield"]
 var outline=PackedVector2Array()
 for i in range(40):outline.append(at+Vector2.from_angle(i*TAU/40)*radii)
 c.draw_colored_polygon(outline,Color(color,0.09*alpha))
 outline.append(outline[0])
 c.draw_polyline(outline,Color(color,0.78*alpha),2,true)
 var shine=PackedVector2Array()
 for i in range(9):shine.append(at+Vector2.from_angle(-2.75+i*0.11)*radii*0.9)
 c.draw_polyline(shine,Color('fff4cf',0.86*alpha),3,true)

func shield_crack(at: Vector2,radii: Vector2,age: float) -> void:
 var t=clampf(age/0.58,0,1)
 if t>=1:return
 if t<0.27:
  divine_bubble(at,radii,1-t)
  var crack=PackedVector2Array()
  for point in [Vector2(-0.86,-0.53),Vector2(-0.35,-0.38),Vector2(-0.46,-0.06),Vector2(0.08,0.08),Vector2(0.23,0.54),Vector2(0.60,0.8)]:
   crack.append(at+point*radii)
  c.draw_polyline(crack,Color('4b3327'),4,true)
  c.draw_polyline(crack,Color('fff5ce'),1.5,true)
  c.draw_line(crack[3],at+radii*Vector2(0.63,-0.35),Color('fff5ce'),2,true)
  return
 var drift=smoothstep(0.27,1.0,t)
 for i in range(8):
  var angle=i*TAU/8
  var middle=Vector2.from_angle(angle+0.28)
  var offset=middle*drift*45+Vector2.DOWN*drift*drift*22
  var end_a=at+offset+Vector2.from_angle(angle)*radii
  var end_b=at+offset+Vector2.from_angle(angle+0.56)*radii
  var tip=at+offset+middle*radii*0.67
  var alpha=1-drift
  c.draw_colored_polygon(PackedVector2Array([end_a,tip,end_b]),Color(1,0.84,0.48,alpha*0.33))
  c.draw_polyline(PackedVector2Array([end_a,tip,end_b]),Color(1,0.94,0.70,alpha),2,true)

func grow_ice(rect: Rect2,amount: float) -> void:
 var color: Color=STATUS_COLORS[&"frozen"]
 var ice=Rect2(rect.position+Vector2(0,rect.size.y*(1-amount)*0.92),Vector2(rect.size.x,rect.size.y*(0.08+0.92*amount)))
 c.draw_rect(ice,Color(color,0.14))
 var bottom=rect.position.y+rect.size.y*0.84
 for i in range(5):
  var at=Vector2(rect.position.x+rect.size.x*(0.12+i*0.19),bottom)
  shard(at,-PI/2+(i-2)*0.09,rect.size.y*(0.19+i%3*0.065)*amount,color,0.8)

func poison_drops(rect: Rect2,uid: int) -> void:
 for i in range(3):
  var phase=fposmod(v.clock*1.14+i/3.0+uid*0.17,1.0)
  var side=1 if i==1 else -1
  var at=rect.get_center()+Vector2(rect.size.x*(0.5+0.08*phase)*side,rect.size.y*(phase*0.70-0.33))
  var alpha=sin(phase*PI)
  var tint=Color(STATUS_COLORS[&"poison"],alpha)
  c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-8),at+Vector2(3,1),at+Vector2(-3,1)]),tint)
  c.draw_circle(at,3,tint,true,-1,true)

func armor_plates(at: Vector2,armor: int) -> void:
 c=v.canvas
 var count=mini(armor,6)
 for i in range(count):
  var offset=i-(count-1)/2.0
  var center=at+Vector2(offset*14,-30+absf(offset)*2)
  var plate=PackedVector2Array([center+Vector2(-8,-6),center+Vector2(8,-6),center+Vector2(6,4),center+Vector2(0,8),center+Vector2(-6,4),center+Vector2(-8,-6)])
  c.draw_colored_polygon(plate.slice(0,5),Color('5c7992'))
  c.draw_polyline(plate,Color('e3edf2'),1.5,true)
  c.draw_circle(center,1.5,Color('d0ac67'))

func taunt_pull(from: Vector2,via: Vector2,to: Vector2) -> void:
 c=v.canvas
 var line=PackedVector2Array()
 for i in range(21):
  var time=i/20.0
  line.append(from.lerp(via,time).lerp(via.lerp(to,time),time))
 var ink: Color=STATUS_COLORS[&"taunt"]
 c.draw_polyline(line,Color(ink,0.24),9,true)
 c.draw_polyline(line,ink,3,true)
 var shift=0.0 if v.game.reduced_motion else fposmod(v.clock*22,5.0)
 for index in [5,10,15]:
  var step=index+int(shift)
  var direction=(line[step+1]-line[step]).normalized()
  var at=line[step]
  var back=at-direction*10
  c.draw_polyline(PackedVector2Array([back+direction.orthogonal()*5,at,back-direction.orthogonal()*5]),ink,3,true)

func life_thread(origin: Vector2,destination: Vector2,age: float) -> void:
 var progress=clampf(age/0.80,0,1)
 if progress>=1:return
 var bend=(destination-origin).normalized().orthogonal()*38
 var head=clampf(progress*1.7,0,1)
 var tail=smoothstep(0.32,1.0,progress)
 var alpha=1-smoothstep(0.67,1.0,progress)
 var points=PackedVector2Array()
 for i in range(17):
  var t=lerpf(tail,head,i/16.0)
  points.append(origin.lerp(destination,t)+bend*sin(t*PI))
 if head-tail>0.01:
  c.draw_polyline(points,Color(0.85,0.24,0.48,alpha*0.45),12,true)
  c.draw_polyline(points,Color(1,0.72,0.82,alpha),3,true)
 glow(points[-1],10,STATUS_COLORS[&"lifesteal"],alpha)

func environment() -> void:
 c=v.canvas
 for effect in v.scenery:
  var t=float(effect.age)/2.4;var fade=1-t
  var element=str(effect.get('fx',effect.element));var color=v.element_color(effect.element)
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
