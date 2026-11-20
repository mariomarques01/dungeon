extends RefCounted
const GOLD=Color('eac67e')
const PAPER=Color('f1dfb6')
const INK=Color('30251e')
var game
var fx
var effect_history=[]
var pointer_trail=[]
var hand_lifts={}
var frame_delta=0.016
var result_time=0.0
var scenery=[]
var fragment_cache={}
var board: Texture2D
var portrait_board: Texture2D
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
var ghosts=[]
var particles=[]
var floats=[]
var anim={}
var anim_time=0.0
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
  node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; node.stretch_mode=TextureRect.STRETCH_SCALE
  var material=ShaderMaterial.new(); material.shader=shader; node.material=material
  game.art_layer.add_child(node); nodes[key]=node
 var node=nodes[key]
 node.texture=texture; node.position=rect.position; node.size=rect.size; node.pivot_offset=rect.size/2; node.rotation=angle; node.modulate=tint; node.z_index=z
 node.material.set_shader_parameter('ellipse',ellipse)
 if texture is AtlasTexture:
  var region=texture.region;var size=texture.atlas.get_size()
  node.material.set_shader_parameter('uv_rect',Vector4(region.position.x/size.x,region.position.y/size.y,region.size.x/size.x,region.size.y/size.y))

func tick(delta: float) -> void:
 result_time+=delta
 for effect in scenery:effect.age+=delta*game.speed
 scenery=scenery.filter(func(effect):return effect.age<2.4)
 frame_delta=delta
 clock+=delta; anim_time+=delta*game.speed
 for point in pointer_trail:point.age+=delta
 pointer_trail=pointer_trail.filter(func(point):return point.age<0.4)
 if game.drag.get('kind','')=='card':
  if pointer_trail.is_empty() or pointer_trail[-1].position.distance_to(game.pointer)>8:
   pointer_trail.append({'position':game.pointer,'id':game.drag.id,'age':0.0})
   if pointer_trail.size()>18:pointer_trail.pop_front()
 for p in particles: p.age+=delta*game.speed
 for f in floats: f.age+=delta*game.speed
 for g in ghosts: g.age+=delta*game.speed
 particles=particles.filter(func(p): return p.age<1.15)
 floats=floats.filter(func(f): return f.age<1.25)
 ghosts=ghosts.filter(func(g): return g.age<1.4)

func geometry() -> void:
 var w=game.logical_size.x; var h=game.logical_size.y; var mobile=game.portrait
 layout={'w':w,'h':h,'mobile':mobile}
 layout.enemy_hero=Rect2(Vector2(w/2-58,38 if mobile else 17),Vector2(116,147))
 layout.player_hero=Rect2(Vector2(w/2-(58 if mobile else 48),h-495 if mobile else h-350),Vector2(116,147) if mobile else Vector2(96,120))
 layout.enemy_row=h*0.34 if mobile else h*0.31
 layout.player_row=h*0.57 if mobile else h*0.46
 layout.unit_size=Vector2(88,114) if mobile else Vector2(105,133)
 layout.player_drop=Rect2(65,h*0.46,w-130,h*0.27) if mobile else Rect2(155,h*0.43,w-310,h*0.28)
 layout.board_zone=Rect2(50,175,w-100,h-480) if mobile else Rect2(150,145,w-300,h-330)
 layout.end=Rect2(w-190,h*0.465,163,86) if mobile else Rect2(w-260,h*0.445,164,66)
 layout.power=Rect2(w/2+85,h-425 if mobile else h-245,69,69)
 layout.settings=Rect2(w-118,25,86,86) if mobile else Rect2(w-148,25,48,48)
 layout.mana=Vector2(w/2-150,h-52)
 hand_views=[]; unit_views={}; hero_views=[]; buttons=[]; collection_views=[]
 if game.screen!='battle': return
 var state=game.rules
 for side in range(2):
  hero_views.append({'side':side,'hero':true,'rect':layout.player_hero if side==0 else layout.enemy_hero})
  var list: Array=state.players[side].board
  var gap=minf(145.0,(w-140)/maxf(1,list.size())) if mobile else 114.0
  var row=float(layout.player_row if side==0 else layout.enemy_row)
  for i in range(list.size()):
   var center=Vector2(w/2+(i-(list.size()-1)/2.0)*gap,row)
   var uid=int(list[i].uid)
   var size=Vector2(minf(132,gap-10),minf(165,(gap-10)*1.25)) if mobile else layout.unit_size
   unit_views[uid]={'side':side,'uid':uid,'rect':Rect2(center-size/2,size),'unit':list[i]}
 var hand: Array=state.players[0].hand
 var size=Vector2(158,237) if mobile else Vector2(146,219)
 var spacing=minf(95.0 if mobile else 82.0,((w-170) if mobile else w*0.60)-size.x if hand.size()<=1 else (((w-170) if mobile else w*0.60)-size.x)/maxf(1,hand.size()-1))
 for i in range(hand.size()):
  var f=i-(hand.size()-1)/2.0
  var center=Vector2(w/2-(0 if mobile else 50)+f*spacing,h-(185 if mobile else 115)+absf(f)*3)
  var angle=f*0.045
  var base_rect=Rect2(center-size/2,size)
  var lifted=game.selected_card==i or game.hover_card==i or (game.press.get('kind','')=='card' and int(game.press.get('index',-1))==i)
  var lift=move_toward(float(hand_lifts.get(i,0)),1.0 if lifted and game.drag.is_empty() else 0.0,frame_delta*9)
  hand_lifts[i]=lift
  center.y-=(70 if mobile else 110)*lift
  angle*=1-lift*0.8
  hand_views.append({'index':i,'id':hand[i],'rect':Rect2(center-size/2,size),'base_rect':base_rect,'angle':angle})

func button(id: String,rect: Rect2,label: String,enabled=true,primary=false) -> void:
 buttons.append({'id':id,'rect':rect,'label':label,'enabled':enabled,'primary':primary})

func prepare() -> void:
 used={}; geometry()
 if game.screen=='battle':
  var state=game.rules
  art('hero0',slice(creatures,3,5,5),layout.player_hero.grow(-7),true)
  art('hero1',slice(creatures,9,5,5),layout.enemy_hero.grow(-7),true)
  art('power',slice(spells,0,4,4),layout.power.grow(-5),true)
  for uid in unit_views:
   var info=unit_views[uid]; var rect: Rect2=info.rect
   var opacity=1.0
   if not anim.is_empty() and anim.get('kind','')=='attack' and int(anim.get('uid',-1))==uid:
    var target=target_center(anim.target)
    var t=clampf((anim_time-0.1)/0.28,0,1) if anim_time<0.38 else 1.0-clampf((anim_time-0.38)/0.47,0,1)
    if fx.ranged(str(info.unit.id)):rect.position.y-=sin(t*PI)*12
    else:rect.position=rect.position.lerp(target-rect.size/2,t*0.9)
   var spawn=particles.filter(func(p): return p.get('uid',-1)==uid and p.kind=='summon')
   if not spawn.is_empty():
    var factor=clampf(spawn[0].age/0.35,0.08,1.0)
    rect=Rect2(rect.get_center()-rect.size*factor/2,rect.size*factor)
   var hits=particles.filter(func(p): return p.kind=='damage' and int(p.get('target',{}).get('uid',-1))==uid and p.age<0.28)
   if not hits.is_empty():rect.position.x+=sin(hits[0].age*70)*8
   rect.position.y+=sin(clock*1.8+uid)*1.4
   info.draw_rect=rect
   var resonating=(anim.get('kind','')=='attack' and int(anim.get('uid',-1))==uid) or particles.any(func(p):return p.get('response_id','')==info.unit.id and p.get('target',{}).get('uid',-1)==uid and p.age<0.65)
   if resonating:
    var spirit=rect.grow(14);spirit.position.y-=20+sin(clock*7)*5
    art('spirit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),spirit,true,0,Color(element_color(game.cards[info.unit.id].element).lightened(0.5),0.35),0)
   art('unit'+str(uid),slice(creatures,int(game.cards[info.unit.id].art),5,5),rect.grow(-7),true,sin(anim_time*12)*0.09 if anim.get('kind','')=='attack' and int(anim.get('uid',-1))==uid else 0,Color(1,0.6,0.5,opacity) if not hits.is_empty() else Color(1,1,1,opacity),1)
  for hand in hand_views:
   if game.drag.get('kind','')=='card' and int(game.drag.get('index',-1))==int(hand.index): continue
   if not anim.is_empty() and anim.get('kind','')=='card' and anim.get('side',0)==0 and int(anim.get('index',-1))==int(hand.index) and not anim.get('resolved',false): continue
   prepare_card('hand'+str(hand.index),hand.id,hand.rect,hand.angle,10+int(hand.index))
  if not game.drag.is_empty() and game.drag.kind=='card':
   var size=Vector2(178,267) if game.portrait else Vector2(175,262)
   var rect=Rect2(game.pointer-size*Vector2(0.5,0.68),size)
   prepare_card('drag',game.drag.id,rect,0,50)
  if not anim.is_empty() and anim.kind=='card' and anim_time<0.62:
   var size=Vector2(170,255)
   var p=anim.origin.lerp(anim.destination,clampf(anim_time/0.6,0,1))
   prepare_card('cast',anim.id,Rect2(p-size/2,size),0,45,Color(1,1,1,clampf(1-anim_time/0.85,0,1)))
  for g in ghosts:
   prepare_remains(g)
  button('end',layout.end,'ENCERRAR\nTURNO' if state.active==0 else 'TURNO DO\nRIVAL',state.active==0 and not game.busy)
  button('settings',layout.settings,'⚙')
  button('power',layout.power,'1 DANO\n2 MANA',state.active==0 and not game.busy and not state.players[0].power_used and state.players[0].mana>=2)
 elif game.screen=='home': prepare_home()
 elif game.screen=='collection': prepare_collection()
 if not game.inspect_id.is_empty():
  var rect=inspect_rect()
  prepare_card('inspect',game.inspect_id,rect,0,70)
 if game.panel=='settings':
  var rect=panel_rect()
  button('mute',Rect2(rect.position+Vector2(45,105),Vector2(rect.size.x-90,55)),'SOM LIGADO' if game.sound_on else 'SOM DESLIGADO')
  button('speed',Rect2(rect.position+Vector2(45,177),Vector2(rect.size.x-90,55)),'ANIMAÇÕES ×'+str(game.speed))
  button('credits',Rect2(rect.position+Vector2(45,249),Vector2(rect.size.x-90,55)),'CRÉDITOS DE ÁUDIO')
  button('close',Rect2(rect.position+Vector2(rect.size.x-58,14),Vector2(42,42)),'×')
 if game.panel=='credits': button('close',Rect2(panel_rect().position+Vector2(panel_rect().size.x-58,14),Vector2(42,42)),'×')
 if game.panel=='result':
  var r=panel_rect()
  button('home',Rect2(r.position+Vector2(55,r.size.y-105),Vector2(r.size.x-110,60)),'VOLTAR À TAVERNA',true,true)
 for key in nodes.keys():
  if not used.has(key): nodes[key].queue_free(); nodes.erase(key)

func prepare_remains(g: Dictionary) -> void:
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
  var key='dead'+str(g.uid)+'-'+str(part)
  art(key,fragment_cache[cache_key],rect,true,t*(part-4)*0.12,tint,2)
  # Every fragment shares the original oval mask, so no rectangular background leaks.
  var texture_size=creatures.get_size()
  nodes[key].material.set_shader_parameter('uv_rect',Vector4(base.region.position.x/texture_size.x,base.region.position.y/texture_size.y,base.region.size.x/texture_size.x,base.region.size.y/texture_size.y))

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
 button('filter',Rect2(layout.w-260,30,225,50),['TODAS','CRIATURAS','FEITIÇOS'][game.collection_filter])
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
 if anim.has('target_position'): return anim.target_position
 return Vector2(layout.w/2,layout.player_row)

func begin(action: Dictionary) -> void:
 anim=action.duplicate(true); anim_time=0
 effect_history.append({'phase':'cast','id':action.get('id','power'),'kind':action.kind,'element':action.get('element','arcane')})
 if effect_history.size()>60:effect_history.pop_front()
func finish() -> void:
 anim={}

func ingest(events: Array,before: Array) -> void:
 var elemental=events.filter(func(event):return event.kind in ['damage','freeze','armor','heal','destroy'])
 if not elemental.is_empty():
  var element=str(anim.get('element',elemental[0].get('element','arcane')))
  scenery.append({'element':element,'age':0.0,'position':target_center(elemental[0].get('target',{}))})
  if scenery.size()>4:scenery.pop_front()
 var causes={}
 for event in events:
  var kind=event.kind
  if kind in ['damage','destroy'] and event.get('target',{}).has('uid'):causes[int(event.target.uid)]=event.get('element',anim.get('element','dark'))
  if kind in ['damage','heal','buff','debuff','blocked','shield_break','freeze','destroy','armor','draw','mana']:
   var at=target_center(event.get('target',{'side':event.get('side',0),'hero':true}))
   var label='+'+str(event.get('amount',0))+' ARMADURA' if kind=='armor' else 'DESTRUÍDO' if kind=='destroy' else '+ MANA' if kind=='mana' else 'COMPRA' if kind=='draw' else '−'+str(event.get('amount',0)) if kind=='damage' else '+'+str(event.get('amount',0)) if kind in ['heal','buff'] else 'ESCUDO ROMPIDO' if kind=='shield_break' else 'GELO' if kind=='freeze' else '−'+str(event.get('amount',0)) if kind=='debuff' else 'BLOQUEOU '+str(event.get('amount',0))
   var color=Color('ffe29b') if kind in ['armor','blocked','shield_break'] else Color('ff615d') if kind=='damage' else Color('8cffbe') if kind in ['heal','buff'] else Color('96dfff')
   floats.append({'position':at,'text':label,'color':color,'age':0.0,'element':event.get('element',anim.get('element','arcane')),'id':anim.get('id','')})
   particles.append({'kind':kind,'position':at,'target':event.get('target',{}).duplicate(),'color':color,'age':0.0,'element':event.get('element',anim.get('element','arcane')),'id':anim.get('id','')})
   if kind in ['damage','blocked','shield_break'] and event.get('target',{}).has('uid'):
    for unit in before[int(event.target.side)].board:
     if int(unit.uid)==int(event.target.uid):particles[-1].response_id=unit.id;break
  elif kind=='summon':
   particles.append({'kind':'summon','uid':event.uid,'side':event.side,'position':Vector2(layout.w/2,layout.player_row if int(event.side)==0 else layout.enemy_row),'color':Color('b9a0ff'),'age':0.0,'element':game.cards[event.id].element,'id':event.id})
  elif kind=='death':
   for unit in before[int(event.side)].board:
    if int(unit.uid)==int(event.uid):
     var rect=unit_views[event.uid].get('draw_rect',unit_views[event.uid].rect) if unit_views.has(event.uid) else Rect2(Vector2(layout.w/2,layout.player_row if int(event.side)==0 else layout.enemy_row)-layout.unit_size/2,layout.unit_size)
     var cause=str(causes.get(int(event.uid),anim.get('element','dark')))
     ghosts.append({'uid':event.uid,'id':event.id,'rect':rect,'age':0.0,'element':cause})
     particles.append({'kind':'death','position':rect.get_center(),'color':element_color(cause),'element':cause,'age':0.0})

func style(fill: Color,border: Color,radius=12,width=2) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius);s.shadow_color=Color(0,0,0,0.45);s.shadow_size=7;return s

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
 canvas.draw_texture_rect(portrait_board if game.portrait else board,Rect2(Vector2.ZERO,game.logical_size),false)
 fx.environment()
 if game.screen!='battle': canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size),Color(0.015,0.02,0.05,0.53))
 if game.screen=='home':
  var x=layout.w/2-285 if game.portrait else 110.0
  canvas.draw_style_box(style(Color(0.035,0.045,0.075,0.92),Color('a78654'),24),Rect2(x,layout.h*0.12,570,layout.h*0.78 if game.portrait else layout.h*0.75))
 if not game.inspect_id.is_empty(): canvas.draw_style_box(style(Color(0.02,0.025,0.04,0.95),Color('9e815a'),18),inspect_rect().grow(20))
 if game.screen=='collection': canvas.draw_rect(Rect2(Vector2.ZERO,game.logical_size),Color(0.025,0.02,0.05,0.69))
 if game.screen=='battle':
  var tint=Color(0.3,0.8,0.48,0.08+sin(clock*4)*0.025)
  if game.drag.get('kind','')=='card' and game.cards[game.drag.id].kind=='minion': canvas.draw_style_box(style(tint,Color(0.45,1,0.65,0.6),25),layout.player_drop)
  for uid in unit_views:
   var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect)
   var unit=info.unit
   var ready=int(info.side)==0 and game.rules.active==0 and int(unit.attacks)>0 and not game.busy
   if ready: oval(rect.grow(7),Color(0.2,1,0.45,0.08),Color(0.35,1,0.52,0.65+sin(clock*4)*0.15),3)
   oval(rect,Color('30261f'),Color('b7b2a2') if 'taunt' in unit.keywords else Color('ab8150'),6 if 'taunt' in unit.keywords else 4)
  for hero in hero_views: canvas.draw_style_box(style(Color('30261f'),Color('bc995c'),35,6),hero.rect)

func paint_overlay(c: CanvasItem) -> void:
 canvas=c
 if game.screen=='home': paint_home()
 elif game.screen=='collection': paint_collection()
 else: paint_battle()
 for button_info in buttons: paint_button(button_info)
 if not game.inspect_id.is_empty():
  paint_card(game.inspect_id,inspect_rect())
  text('Toque fora para fechar',Rect2(inspect_rect().position+Vector2(-15,inspect_rect().size.y+15),Vector2(inspect_rect().size.x+30,25)),15,PAPER,true)
 if not game.panel.is_empty(): paint_panel()
 if game.toast_time>0:
  var width=minf(layout.w-70,650)
  canvas.draw_style_box(style(Color(0.025,0.03,0.055,0.94),Color('d8ba7a'),12),Rect2(layout.w/2-width/2,layout.h*0.19,width,56))
  text(game.toast_text,Rect2(layout.w/2-width/2+14,layout.h*0.19+15,width-28,30),18,PAPER,true)

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
 if card.kind=='minion':
  text(str(int(card.attack)),Rect2(local.position+local.size*Vector2(0.05,0.815),local.size*Vector2(0.23,0.14)),int(24*factor),Color.WHITE,true,true)
  text(str(int(card.health)),Rect2(local.position+local.size*Vector2(0.75,0.815),local.size*Vector2(0.23,0.14)),int(24*factor),Color.WHITE,true,true)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

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

func paint_battle() -> void:
 var state=game.rules
 for hero in hero_views:
  var p=state.players[int(hero.side)]
  var center=hero.rect.get_center()
  badge(hero.rect.position+Vector2(hero.rect.size.x-8,hero.rect.size.y-8),str(p.health),Color('a51e2c'),22)
  if p.armor>0:badge(hero.rect.position+Vector2(10,hero.rect.size.y-8),str(p.armor),Color('667e9a'),18)
  text('ELYRA' if hero.side==0 else 'MALGRUK',Rect2(hero.rect.position+Vector2(-26,hero.rect.size.y+17),Vector2(hero.rect.size.x+52,25)),17,PAPER,true,true)
 for uid in unit_views:
  var info=unit_views[uid];var rect: Rect2=info.get('draw_rect',info.rect);var unit=info.unit
  oval(rect.grow(-2),Color.TRANSPARENT,Color('d6b56f'),2)
  if rect.size.x>35:
   badge(rect.position+Vector2(14,rect.size.y-6),str(unit.attack),Color('ac853b'),15)
   badge(rect.position+Vector2(rect.size.x-14,rect.size.y-6),str(unit.health),Color('ac2833'),15)
  fx.status(unit,rect)
  if unit.shield:
   oval(rect.grow(7),Color(1,0.9,0.4,0.08),Color(1,0.9,0.4,0.8),3)
   oval(rect.grow(11),Color.TRANSPARENT,Color(1,0.9,0.4,0.25),5)
  if unit.frozen>0 or unit.get('frozen_lock',false):
   canvas.draw_style_box(style(Color(0.2,0.75,1,0.15),Color('94e6ff'),30,3),rect.grow(4))
  if unit.sleeping and unit.attacks==0: text('Z',Rect2(rect.end-Vector2(14,rect.size.y-2),Vector2(30,30)),22,Color('c3dcec'),true,true)
  if 'windfury' in unit.keywords: text('↟',Rect2(rect.position-Vector2(7,20),Vector2(30,30)),20,GOLD,true)
 for hand in hand_views:
  if game.drag.get('kind','')=='card' and game.drag.index==hand.index: continue
  if not anim.is_empty() and anim.get('kind','')=='card' and anim.get('side',0)==0 and anim.index==hand.index and not anim.get('resolved',false): continue
  paint_card(hand.id,hand.rect,hand.angle)
  if float(hand_lifts.get(hand.index,0))>0.05:fx.aura(hand.id,hand.rect,float(hand_lifts[hand.index]))
  if game.cards[hand.id].cost<=state.players[0].mana and state.active==0 and not game.busy:
   # A light accent under the physical card makes playable cards readable without neon frames.
   canvas.draw_arc(hand.rect.get_center()+Vector2(0,hand.rect.size.y*0.40),hand.rect.size.x*0.45,0,PI,24,Color(0.4,0.95,0.65,0.65),2)
 fx.trail()
 if not game.drag.is_empty():
  paint_targets()
  if game.drag.kind=='card':
   var size=Vector2(178,267) if game.portrait else Vector2(175,262)
   var held_rect=Rect2(game.pointer-size*Vector2(0.5,0.68),size)
   paint_card(game.drag.id,held_rect)
   fx.aura(game.drag.id,held_rect,1.0)
   if game.cards[game.drag.id].kind=='minion' and layout.player_drop.has_point(game.pointer):
    fx.ring(Vector2(game.pointer.x,layout.player_row),108+sin(clock*4)*5,element_color(game.cards[game.drag.id].element),0.8,clock*2)
  else: arrow(game.drag.origin,game.pointer,Color('ed694a'))
 if not anim.is_empty():
  if anim.kind=='card' and anim_time<0.62:
   var size=Vector2(170,255)
   var at=anim.origin.lerp(anim.destination,clampf(anim_time/0.6,0,1))
   paint_card(anim.id,Rect2(at-size/2,size),0,Color(1,1,1,clampf(1-anim_time/0.85,0,1)))
  fx.action()
 paint_particles()
 var p=state.players[0]
 var mana_start=Vector2(layout.w-230,layout.h-47) if not game.portrait else Vector2(layout.w/2-128,layout.h-46)
 for i in range(10):
  var at=mana_start+Vector2(i*(23 if game.portrait else 18),0)
  var color=Color('48aaf4') if i<int(p.mana) else Color('274364') if i<int(p.max_mana) else Color('3b353c')
  canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-9),at+Vector2(8,0),at+Vector2(0,9),at+Vector2(-8,0)]),color)
 text('%d / %d' % [p.mana,p.max_mana],Rect2(mana_start+Vector2(-75,-17),Vector2(65,30)),20,Color('d7ebff'),true)
 text('TURNO %d' % ((state.turn+1)/2),Rect2(25,25,180,25),18,PAPER,false,true)
 text('Você' if state.active==0 else 'Rival jogando…',Rect2(25,54,220,25),16,PAPER)
 text('BARALHO\n%d' % p.deck.size(),Rect2(layout.w-150,layout.h*0.71,130,60),17,PAPER,true,true)
 text('RIVAL\n%d cartas' % state.players[1].hand.size(),Rect2(26,layout.h*0.15,150,50),15,PAPER)
 if state.turn<4 and state.players[0].board.is_empty() and not game.busy and game.drag.is_empty():
  text('Solte suas criaturas aqui',Rect2(layout.w/2-250,layout.player_row-18,500,40),20,Color('7e5a36'),true)

func line_glow(a: Vector2,b: Vector2,color: Color,width=3.0) -> void:
 canvas.draw_line(a,b,Color(color,0.14),width*5)
 canvas.draw_line(a,b,Color(color,0.5),width*2)
 canvas.draw_line(a,b,color.lightened(0.5),width)

func paint_targets() -> void:
 var candidates=[]
 for uid in unit_views:candidates.append({'side':unit_views[uid].side,'uid':uid})
 for side in range(2):candidates.append({'side':side,'hero':true})
 for target in candidates:
  var valid=false
  if game.drag.kind=='card' and game.cards[game.drag.id].get('target','none')!='none':valid=game.rules.can_play(0,int(game.drag.index),target).ok
  elif game.drag.kind=='unit':valid=game.rules.can_attack(0,int(game.drag.uid),target).ok
  elif game.drag.kind=='power':valid=game.rules.can_power(0,target).ok
  if valid:
   var center=target_center(target)
   canvas.draw_arc(center,67 if game.portrait else 72,0,TAU,48,Color(1,0.87,0.45,0.65+sin(clock*7)*0.2),4)

func element_color(element: String) -> Color:
 return {'fire':Color('ff8a40'),'ice':Color('7edcff'),'lightning':Color('91bdff'),'storm':Color('c49aff'),'nature':Color('85db71'),'heal':Color('8be6ae'),'dark':Color('a085e8'),'steel':Color('ffdd8f'),'earth':Color('c4a16d')}.get(element,Color('b28bff'))

func arrow(a: Vector2,b: Vector2,color: Color) -> void:
 var last=a
 for i in range(20):
  var t=(i+1)/20.0
  var p=a.lerp(b,t)+Vector2(0,-sin(t*PI)*40)
  canvas.draw_line(last,p,Color(0.12,0.04,0.02,0.5),9);canvas.draw_line(last,p,color,5);last=p
 var direction=(b-a).normalized();var normal=direction.orthogonal()
 canvas.draw_colored_polygon(PackedVector2Array([b,b-direction*24+normal*13,b-direction*24-normal*13]),color)

func paint_particles() -> void:
 for p in particles:
  var t=clampf(p.age/0.85,0,1)
  var at=p.position
  if p.kind=='summon' and unit_views.has(int(p.uid)): at=unit_views[int(p.uid)].rect.get_center()
  fx.event(p)
 for f in floats:
  var pos=f.position-Vector2(0,55+f.age*47)
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
 if not game.panel.is_empty() and info.id not in ['mute','speed','close','credits','home']: return
 var rect: Rect2=info.rect
 var enabled=info.enabled
 var primary=info.primary
 if info.id=='power':
  canvas.draw_arc(rect.get_center(),rect.size.x/2,0,TAU,48,Color('e5c271') if enabled else Color('706653'),5)
  badge(rect.position+Vector2(10,rect.size.y-6),'2',Color('287cb2'),15)
  return
 var fill=Color('c9a362') if primary else Color('382a25')
 if not enabled:fill=fill.darkened(0.35)
 canvas.draw_style_box(style(fill,Color('e0c185') if enabled else Color('7f7162'),12,3),rect)
 canvas.draw_line(rect.position+Vector2(12,5),rect.position+Vector2(rect.size.x-12,5),Color(1,0.92,0.65,0.35),2)
 var font_size=25 if primary else 19
 if info.id=='settings': font_size=40 if game.portrait else 26
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
  fx.c=canvas;fx.ring(center,48,medal_color,0.8,clock*0.3)
  text('★' if result=='win' else '✦',Rect2(center-Vector2(30,36),Vector2(60,65)),49,medal_color,true,true)
  text('VITÓRIA!' if result=='win' else 'EMPATE' if result=='draw' else 'DERROTA',Rect2(rect.position+Vector2(35,160),Vector2(rect.size.x-70,65)),48,medal_color,true,true)
  text('A taverna celebra seu triunfo.' if result=='win' else 'Uma nova estratégia espera por você.',Rect2(rect.position+Vector2(25,242),Vector2(rect.size.x-50,35)),20,PAPER,true)
  var coins=50 if result=='win' else 10 if result=='draw' else 5
  var xp=35 if result=='win' else 12 if result=='draw' else 8
  for i in range(2):
   var reward=Rect2(rect.position+Vector2(60+i*230,302),Vector2(210,77))
   canvas.draw_style_box(style(Color('24303a'),Color('6f654f'),12),reward)
   text(('+'+str(coins)+' MOEDAS') if i==0 else ('+'+str(xp)+' XP'),Rect2(reward.position+Vector2(5,23),reward.size-Vector2(10,20)),24,GOLD if i==0 else Color('a3daff'),true,true)
  if result=='win':
   for i in range(12):
    var point=rect.position+Vector2(30+fposmod(i*43.0+sin(clock+i)*10,rect.size.x-60),fposmod(result_time*40+i*37,rect.size.y-130))
    canvas.draw_circle(point,2.5,Color(GOLD,0.6))
 for button_info in buttons:
  if button_info.id in ['mute','speed','close','credits'] or game.panel=='result' and button_info.id=='home': paint_button(button_info)
