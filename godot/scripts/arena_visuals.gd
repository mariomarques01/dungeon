extends RefCounted
# All presentation is rendered by Godot; animation never mutates combat state.
const GOLD = Color("ffd666")
const WHITE = Color("fff3db")
var game
var backdrop: Texture2D
var actors: Texture2D
var card_atlas: Texture2D
var action: Dictionary = {}
var action_time = 0.0
var action_length = 1.85
var events: Array = []
var history: Array = []
var hero_hurt = 0.0
var enemy_hurt = 0.0
var shake = 0.0
var shown_hero = 100.0
var shown_enemy = 100.0
var hero_foot = Vector2(108,404)
var enemy_foot = Vector2(282,319)
const HERO_REGIONS = [Rect2(18,40,348,426),Rect2(378,0,390,474),Rect2(746,62,490,407),Rect2(1240,63,296,410)]
const ENEMY_REGIONS = [Rect2(0,561,380,455),Rect2(380,485,390,531),Rect2(760,600,480,416),Rect2(1235,571,301,445)]
const ART_INDEX = {"sword":0,"fire":1,"shield":2,"lightning":3,"heal":4,"ice":5,"water":6,"earth":7,"storm":8,"spark":2,"blade":9}

func _init(owner) -> void:
 game=owner
 backdrop=load("res://assets/v2/dungeon.png")
 actors=load("res://assets/v2/actors.png")
 card_atlas=load("res://assets/v2/cards.png")

func reset() -> void:
 action={}; events=[]; action_time=0; hero_hurt=0; enemy_hurt=0; shake=0
 shown_hero=game.hero; shown_enemy=game.enemy
 history=[]

func update(delta: float) -> void:
 var dt=delta*game.speed
 action_time+=dt
 hero_hurt=maxf(0,hero_hurt-dt)
 enemy_hurt=maxf(0,enemy_hurt-dt)
 shake=maxf(0,shake-dt)
 for event in events: event.age+=dt
 events=events.filter(func(event): return event.age<1.55)
 shown_hero=move_toward(shown_hero,float(game.hero),dt*80)
 shown_enemy=move_toward(shown_enemy,float(game.enemy),dt*80)

func begin(card: Dictionary, caster_enemy: bool, card_index = -1, kind = "card") -> void:
 action={"card":card.duplicate(),"enemy":caster_enemy,"index":card_index,"kind":kind}
 action_time=0
 action_length=0.7 if kind=="burn" or kind=="frozen" else 1.85
 history.append({"event":"begin","kind":kind,"art":card.get("art","sword"),"enemy":caster_enemy})

func complete() -> void:
 history.append({"event":"complete","art":action.get("card",{}).get("art","")})
 action={}

func emit_event(value: String, color: Color, target_enemy: bool, reaction = "buff") -> void:
 var overlap=0
 for event in events:
  if event.enemy==target_enemy and event.age<0.4: overlap+=1
 events.append({"value":value,"color":color,"enemy":target_enemy,"age":0.0,"offset":overlap*20,"reaction":reaction})
 if reaction=="hurt":
  if target_enemy: enemy_hurt=0.5
  else: hero_hurt=0.5
  shake=0.18
 history.append({"event":"impact","target_enemy":target_enemy,"reaction":reaction,"value":value})

func art(id: String, rect: Rect2, tint = Color.WHITE) -> void:
 var key="blade" if id=="blade" else game.cards[id].art if game.cards.has(id) else id
 var index=int(ART_INDEX.get(key,0))
 var cell=card_atlas.get_size()/Vector2(5,2)
 var source=Rect2(Vector2(index%5,index/5)*cell+Vector2(2,2),cell-Vector2(4,4))
 game.draw_texture_rect_region(card_atlas,rect,source,tint)

func actor(enemy_actor: bool, pose: int, foot: Vector2, height: float, tint = Color.WHITE) -> void:
 var region=(ENEMY_REGIONS if enemy_actor else HERO_REGIONS)[pose]
 var target_size=region.size*(height/region.size.y)
 var position=foot-Vector2(target_size.x/2,target_size.y)
 # The orc's strike frame points right in the atlas, so mirror it toward Elyra.
 if enemy_actor and pose==2:
  position.x+=target_size.x
  target_size.x=-target_size.x
 game.draw_texture_rect_region(actors,Rect2(position,target_size),region,tint)

func portrait(enemy_actor: bool, rect: Rect2) -> void:
 beveled(rect,Color("0b0a18"),GOLD,6)
 var source=Rect2(141,605,110,115) if enemy_actor else Rect2(137,64,106,116)
 game.draw_texture_rect_region(actors,rect.grow(-3),source)
 var title=game.stages[game.stage_index].name if enemy_actor else "ELYRA"
 game.draw_rect(Rect2(rect.position+Vector2(2,rect.size.y-14),Vector2(rect.size.x-4,13)),Color(0.02,0.01,0.05,0.88))
 game.text_at(title,Rect2(rect.position+Vector2(2,rect.size.y-13),Vector2(rect.size.x-4,12)),8,GOLD,true,true)
 var label=Rect2(rect.position+Vector2(rect.size.x-33,-2),Vector2(35,13))
 beveled(label,Color("14101a"),GOLD,3)
 game.text_at("NV %02d" % (12+game.stage_index*3 if enemy_actor else 8),Rect2(label.position+Vector2(1,2),label.size),7,GOLD,true,true)

func beveled(rect: Rect2, fill: Color, edge = GOLD, cut = 6) -> void:
 for layer in range(3):
  var r=rect.grow(-layer)
  var c=maxf(2,cut-layer)
  var points=PackedVector2Array([r.position+Vector2(c,0),r.position+Vector2(r.size.x-c,0),r.position+Vector2(r.size.x,c),r.end-Vector2(0,c),r.end-Vector2(c,0),r.position+Vector2(c,r.size.y),r.position+Vector2(0,r.size.y-c),r.position+Vector2(0,c)])
  var color=Color("6f3918") if layer==0 else edge if layer==1 else fill
  game.draw_colored_polygon(points,color)
 game.draw_line(rect.position+Vector2(cut+2,3),rect.position+Vector2(rect.size.x-cut-2,3),Color(edge,0.6),1)

func rule(y: float) -> void:
 game.draw_line(Vector2(0,y),Vector2(390,y),Color("a86117"),3)
 game.draw_line(Vector2(0,y),Vector2(390,y),GOLD,1)
 for x in [7,195,383]:
  game.draw_circle(Vector2(x,y),4,Color(1,0.55,0.06,0.15))
  game.draw_circle(Vector2(x,y),1.7,Color("fff4bd"))

func health(rect: Rect2, value: float, maximum: float, color: Color) -> void:
 beveled(rect,Color("080a16"),GOLD,5)
 var fraction=clampf(value/maximum,0,1)
 var inner=Rect2(rect.position+Vector2(3,3),Vector2((rect.size.x-6)*fraction,rect.size.y-6))
 if inner.size.x>0:
  game.draw_style_box(game.style_box(color,color,4),inner)
  game.draw_line(inner.position+Vector2(2,1),inner.position+Vector2(maxf(2,inner.size.x-2),1),color.lightened(0.6),1.5)

func draw_scene() -> void:
 var offset=Vector2(sin(game.clock*83),cos(game.clock*71))*shake*9
 game.draw_texture_rect(backdrop,Rect2(Vector2(0,65)+offset,Vector2(390,439)),false)
 game.draw_rect(Rect2(0,65,390,439),Color(0.02,0.01,0.06,0.08))
 # Small animated embers in the hall make the dungeon feel alive between turns.
 for i in range(12):
  var p=Vector2(24+(i*71)%345,420-fmod(game.clock*(12+i%4)+i*33,330))
  game.draw_circle(p,0.6+sin(game.clock+i)*0.3,Color(1,0.45,0.08,0.45))
 draw_fighters()
 draw_action()
 draw_events()
 draw_hud()

func draw_fighters() -> void:
 var hero_pos=hero_foot
 var enemy_pos=enemy_foot
 var hero_pose=0
 var enemy_pose=0
 var hero_tint=Color.WHITE
 var enemy_tint=Color.WHITE
 if not action.is_empty() and action.kind=="card":
  var enemy_cast=action.enemy
  var c=action.card
  var time=action_time
  var pose=1 if time<0.76 else 2 if time<1.35 and c.get("art","")=="sword" and c.has("damage") else 1 if time<1.5 else 0
  if enemy_cast: enemy_pose=pose
  else: hero_pose=pose
  if c.get("art","")=="sword" and time>0.7 and time<1.65:
   var approach=sin(clampf((time-0.7)/0.95,0,1)*PI)
   if enemy_cast: enemy_pos=enemy_pos.lerp(hero_pos+Vector2(70,-8),approach*0.75)
   else: hero_pos=hero_pos.lerp(enemy_pos+Vector2(-65,18),approach*0.75)
 if not action.is_empty() and action.kind=="frozen": enemy_pose=3
 if hero_hurt>0:
  hero_pose=3; hero_pos.x-=sin(hero_hurt*45)*5; hero_tint=Color(1,0.62,0.6) if int(hero_hurt*25)%2==0 else Color.WHITE
 if enemy_hurt>0:
  enemy_pose=3; enemy_pos.x+=sin(enemy_hurt*45)*5; enemy_tint=Color(1,0.62,0.6) if int(enemy_hurt*25)%2==0 else Color.WHITE
 hero_pos.y+=sin(game.clock*2)*1.3
 enemy_pos.y+=sin(game.clock*1.8+1)*1.2
 game.draw_style_box(game.style_box(Color(0,0,0,0.42),Color(0,0,0,0),20),Rect2(enemy_pos-Vector2(38,4),Vector2(76,9)))
 game.draw_style_box(game.style_box(Color(0,0,0,0.5),Color(0,0,0,0),20),Rect2(hero_pos-Vector2(43,3),Vector2(86,10)))
 actor(true,enemy_pose,enemy_pos,139,enemy_tint)
 actor(false,hero_pose,hero_pos,155,hero_tint)
 if game.hero_shield>0: barrier(hero_pos-Vector2(0,74),Color("65dcff"),61,game.clock,0.42)
 if game.enemy_shield>0: barrier(enemy_pos-Vector2(0,66),Color("fcaf58"),55,game.clock,0.42)
 if game.freeze>0:
  for i in range(5):
   var p=enemy_pos+Vector2(-36+i*16,-12)
   game.draw_colored_polygon(PackedVector2Array([p+Vector2(-10,7),p+Vector2(0,-35-i%2*14),p+Vector2(10,5)]),Color(0.3,0.8,1,0.55))

func noop() -> void:
 pass

func barrier(center: Vector2, color: Color, radius: float, time: float, strength = 1.0) -> void:
 for layer in range(3):
  game.draw_arc(center,radius+layer*3,0,TAU,64,Color(color,(0.4-layer*0.1)*strength),2)
 for i in range(8):
  var angle=i*TAU/8+time*0.4
  var p=center+Vector2(cos(angle),sin(angle))*radius
  game.draw_line(p-Vector2(2,0),p+Vector2(2,0),Color(color,strength),1)

func beam(a: Vector2, b: Vector2, color: Color, width: float) -> void:
 game.draw_line(a,b,Color(color,0.12),width*5)
 game.draw_line(a,b,Color(color,0.5),width*2)
 game.draw_line(a,b,color.lightened(0.4),width)

func burst(center: Vector2, color: Color, progress: float, amount = 16) -> void:
 for i in range(amount):
  var angle=i*TAU/amount+sin(i*7.0)*0.3
  var radius=15+progress*(32+i%4*11)
  var p=center+Vector2(cos(angle),sin(angle))*radius
  game.draw_line(p,p+Vector2(cos(angle),sin(angle))*(4+i%3*3),Color(color,clampf(1-progress,0,1)),2)
 game.draw_arc(center,12+progress*48,0,TAU,40,Color(color,clampf(1-progress,0,1)),2)

func draw_action() -> void:
 if action.is_empty(): return
 var time=action_time
 var c=action.card
 var color=Color(c.get("glow","#ffd889"))
 var caster=enemy_foot-Vector2(0,75) if action.enemy else hero_foot-Vector2(0,83)
 var target=hero_foot-Vector2(0,75) if action.enemy else enemy_foot-Vector2(0,70)
 if action.kind=="burn": burst(target,Color("ff6926"),clampf(time/0.7,0,1)); return
 if action.kind=="frozen": barrier(caster,Color("87e6ff"),55,time); return
 if time<0.42 and not action.enemy and action.index>=0:
  var origin=Vector2(43+int(action.index)*76,583)
  var t=clampf(time/0.42,0,1)
  var p=origin.lerp(caster,t)+Vector2(sin(t*PI)*-30,-sin(t*PI)*45)
  var extent=Vector2(46,54).lerp(Vector2(18,21),t)
  game.draw_line(origin,p,Color(color,0.55*(1-t)),3)
  art(c.get("id",c.art),Rect2(p-extent/2,extent),Color(1,1,1,1-t*0.7))
 if time>0.25 and time<0.9:
  var charge=sin(clampf((time-0.25)/0.65,0,1)*PI)
  barrier(caster,color,22+charge*29,time*4,charge)
  burst(caster,color,fmod(time*2,1),9)
  game.text_at("PODER INCORPORADO",Rect2(caster.x-80,caster.y-85,160,16),9,color,true,true)
 if c.has("damage") and time>=0.73 and time<1.12:
  var t=clampf((time-0.73)/0.39,0,1)
  var p=caster.lerp(target,t)+Vector2(0,-sin(t*PI)*24)
  match c.art:
   "sword":
    if time>0.98:
     beam(target+Vector2(-30,26),target+Vector2(30,-30),Color("fff0ba"),4)
     if c.get("id","")=="blade": beam(target+Vector2(-30,-30),target+Vector2(30,26),Color("fff0ba"),3)
   "lightning","storm":
    var start=Vector2(target.x-12,-10)
    var last=start
    for i in range(8):
     var next=start.lerp(target,(i+1)/8.0)+Vector2(sin(i*27+time*50)*14,0)
     beam(last,next,color,2)
     last=next
   _:
    for i in range(7):
     var trail=p.lerp(caster,i/11.0)
     game.draw_circle(trail,10-i,Color(color,0.11+i*0.02))
    game.draw_circle(p,12,Color(color,0.35))
    game.draw_circle(p,6,color.lightened(0.55))
    if c.art=="ice":
     game.draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-10),p+Vector2(9,0),p+Vector2(-6,10)]),Color("c9faff"))
 if time>=1.05 and time<1.75:
  var progress=clampf((time-1.05)/0.7,0,1)
  if c.has("damage"): burst(target,color,progress,24)
  if c.has("block"):
   var support=caster
   barrier(support,Color("72e6ff"),35+progress*24,time*3,1-progress*0.4)
   if c.art=="earth":
    for i in range(5):
     var r=Rect2(support+Vector2(-39+i*16,50-(1-progress)*26),Vector2(15,24+sin(i)*7))
     beveled(r,Color("554c4b"),Color("b8b7b5"),3)
  if c.has("heal"):
   for i in range(12):
    var p=caster+Vector2(sin(i*21+time*2)*38,55-fmod(i*13+progress*110,120))
    game.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color("91ffc4"),2)
    game.draw_line(p-Vector2(0,3),p+Vector2(0,3),Color("91ffc4"),2)

func draw_events() -> void:
 for event in events:
  var at=(enemy_foot if event.enemy else hero_foot)-Vector2(0,115+event.offset+event.age*27)
  var color=Color(event.color,clampf((1.55-event.age)*2,0,1))
  game.text_at(event.value,Rect2(at.x-92,at.y,184,25),14,Color(0,0,0,color.a),true,true)
  game.text_at(event.value,Rect2(at.x-93,at.y-1,184,25),14,color,true,true)

func draw_hud() -> void:
 game.draw_rect(Rect2(0,0,390,65),Color(0.015,0.01,0.035,0.97))
 portrait(true,Rect2(9,7,55,55))
 game.text_at("♥",Rect2(72,6,20,20),17,Color("ff294a"))
 game.text_at("VIDA",Rect2(94,9,110,20),13,WHITE,false,true)
 game.text_at("%d / %d" % [game.enemy,game.stages[game.stage_index].hp],Rect2(239,9,63,20),12,WHITE,true,true)
 health(Rect2(73,28,216,12),shown_enemy,float(game.stages[game.stage_index].hp),Color("ff2558"))
 game.text_at(game.intent(),Rect2(74,44,245,17),10,WHITE)
 rule(65)
 if game.enemy_shield>0: game.text_at("ESCUDO %d" % game.enemy_shield,Rect2(182,55,110,12),7,Color("80e4ff"),true)
 if game.burn>0: game.text_at("QUEIMA %d" % game.burn,Rect2(80,55,90,12),7,Color("ff9a49"))
 if game.freeze>0: game.text_at("CONGELADO",Rect2(80,55,140,12),7,Color("b3edff"))
 game.draw_rect(Rect2(0,438,390,68),Color(0.015,0.01,0.035,0.93))
 game.text_at("♥",Rect2(17,438,20,21),16,Color("ff294a"))
 game.text_at("VIDA",Rect2(38,442,130,20),13,WHITE,false,true)
 game.text_at("%d / 100" % game.hero,Rect2(235,442,68,18),12,WHITE,true,true)
 health(Rect2(17,462,285,12),shown_hero,100.0,Color("14ddff"))
 portrait(false,Rect2(313,422,62,70))
 if game.hero_shield>0: game.text_at("ESCUDO %d" % game.hero_shield,Rect2(120,479,140,15),10,Color("8eeeff"),true)
 else: game.text_at("RODADA %d/10 · FASE %d/5" % [mini(10,game.round_number),game.stage_index+1],Rect2(118,482,185,15),8,GOLD,true)
 rule(505)
 game.draw_rect(Rect2(0,507,390,22),Color("090915"))
 game.text_at("✦ SUA MÃO",Rect2(12,508,150,20),14,GOLD,false,true)
 for i in range(3): game.image_at("gem",Rect2(159+i*17,510,17,17),Color.WHITE if i<game.energy else Color(0.25,0.3,0.4,0.5))
 var playable=false
 for id in game.hand:
  if game.cards[id].cost<=game.energy: playable=true
 game.text_at("Executando ação" if game.busy else "Ataque disponível" if playable else "Encerre o turno",Rect2(257,512,123,15),8,WHITE,true)
 game.draw_rect(Rect2(0,530,390,170),Color(0.015,0.01,0.035,0.94))
 for i in range(game.hand.size()): draw_card(game.hand[i],Rect2(8+i*76,532,70,110),game.busy or game.cards[game.hand[i]].cost>game.energy)
 var button_rect=Rect2(9,656,372,39)
 beveled(button_rect,Color("a75a08"),GOLD,10)
 for i in range(30):
  var t=i/29.0
  var color=Color("ffe96f").lerp(Color("ffa300"),t)
  if game.busy or game.done: color=color.darkened(0.45)
  var inset=maxf(0,7-minf(i,29-i))
  game.draw_line(Vector2(14+inset,660+i),Vector2(376-inset,660+i),color,1.2)
 game.text_at("ENCERRAR TURNO →",Rect2(16,663,358,26),18,Color("160c07"),true,true)
 if game.hero<=30 and not game.done: game.text_at("VIDA CRÍTICA — PROTEJA ELYRA",Rect2(80,413,230,18),10,Color("ff826c"),true)
 if game.busy:
  var title="CONJURAÇÃO" if action_time<0.73 else game.phase
  game.text_at(title,Rect2(75,124,240,20),11,GOLD,true,true)

func draw_card(id: String, rect: Rect2, unavailable = false) -> void:
 var c=game.cards[id]
 var edge=Color("ffbd42") if c.art in ["fire","sword"] else Color("73d7ff") if c.has("block") else Color(c.glow)
 var glow=game.style_box(Color("090a12"),edge,5)
 glow.shadow_color=Color(edge,0.34)
 glow.shadow_size=5
 game.draw_style_box(glow,rect)
 beveled(rect,Color("0a0b14"),edge,7)
 beveled(rect.grow(-3),Color("070a14"),Color("c3bca7"),5)
 art(id,Rect2(rect.position+Vector2(5,5),Vector2(rect.size.x-10,rect.size.y*0.59)))
 var y=rect.position.y+rect.size.y*0.60
 game.draw_rect(Rect2(rect.position+Vector2(5,rect.size.y*0.60),Vector2(rect.size.x-10,rect.size.y*0.33)),Color(0.015,0.02,0.035,0.95))
 var title=c.name
 if game.title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x>rect.size.x-8:
  var words=title.split(" ")
  var last=words[words.size()-1]
  title=title.trim_suffix(last).strip_edges()+"\n"+last
 for line_index in range(title.split("\n").size()):
  game.text_at(title.split("\n")[line_index],Rect2(rect.position.x+4,y+line_index*10,rect.size.x-8,10),9,WHITE,true,true)
 game.text_at(game.info(id),Rect2(rect.position.x+3,rect.end.y-24,rect.size.x-6,12),7,WHITE,true)
 var kind="DEFESA" if c.has("block") else "CURA" if c.has("heal") else "ATAQUE" if c.art=="sword" else "MAGIA"
 beveled(Rect2(rect.position+Vector2(6,rect.size.y-14),Vector2(rect.size.x-12,11)),Color("122136"),edge,4)
 game.text_at(kind,Rect2(rect.position+Vector2(6,rect.size.y-13),Vector2(rect.size.x-12,11)),7,WHITE,true,true)
 var center=rect.position+Vector2(10,10)
 game.draw_circle(center,10,Color("083d78"))
 game.draw_circle(center-Vector2(1,1),8,Color("168fe1"))
 game.draw_arc(center,10,0,TAU,30,Color("c0f8ff"),1.7)
 game.text_at(str(int(c.cost)),Rect2(center-Vector2(9,8),Vector2(18,16)),12,Color.WHITE,true,true)
 if unavailable: game.draw_rect(rect,Color(0.02,0.02,0.04,0.48))
