extends Control
# Native Godot port of web/game.js. The browser only hosts the exported canvas.
const DEFAULT_DECK = ["sword","fire","shield","lightning","heal","spark","ice","water","earth","storm","ember","blade"]
const GOLD = Color("e7c477")
const INK = Color("090c20")
const WHITE = Color("fff4da")
var cards: Dictionary
var stages: Array
var profile: Dictionary = {"deck":DEFAULT_DECK.duplicate(),"coins":0,"xp":0,"wins":0,"losses":0,"stage":0}
var textures: Dictionary = {}
var title_font = preload("res://assets/title.ttf")
var body_font = preload("res://assets/body.ttf")
var screen = "home"
var panel = ""
var collection_page = 0
var selected_detail = ""
var sound_on = true
var speed = 1.0
var hero = 100
var enemy = 100
var hero_shield = 0
var enemy_shield = 0
var energy = 3
var round_number = 1
var combo = 0
var burn = 0
var freeze = 0
var stage_index = 0
var hand: Array = []
var deck: Array = []
var discard: Array = []
var chain: Array = []
var last_element = ""
var triad_used = false
var triad_charge = false
var busy = false
var done = false
var outcome = ""
var message = "Prepare seu primeiro ataque!"
var phase = "SUA VEZ"
var fx_amount = ""
var fx_color = Color.WHITE
var fx_enemy = true
var fx_time = 0.0
var motion = 0.0
var motion_enemy = false
var pulse = 0.0
var clock = 0.0
var music_clock = 0.0
var music_step = 0
var controls: Control
var voices: Array = []
var sfx: Dictionary = {}
var save_error = false

func _ready() -> void:
 title_font.fallbacks = [preload("res://assets/symbols.ttf")]
 body_font.fallbacks = [preload("res://assets/symbols.ttf")]
 cards = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards.json"))
 stages = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages.json"))
 for art in ["gem","lobby","lobby-panel","lobby-background","swords","sword","citadel","elyra-elite","malgruk-elite","elyra-battle","malgruk-battle","card-sword","card-fire","card-shield","card-lightning","card-heal","card-spark","card-ice","card-water","card-earth","card-storm"]:
  textures[art] = load("res://assets/" + art + ".png")
 for kind in ["steel","fire","ice","lightning","earth","water","heal","ui"]:
  var path = "res://assets/sfx/"+kind+".ogg"
  if ResourceLoader.exists(path): sfx[kind]=load(path)
 load_profile()
 controls = Control.new()
 add_child(controls)
 resized.connect(rebuild)
 rebuild()

func load_profile() -> void:
 var raw = ""
 if OS.has_feature("web"):
  var stored = JavaScriptBridge.eval("localStorage.getItem('dungeon_cards_v15') || ''")
  if stored != null: raw = str(stored)
 elif FileAccess.file_exists("user://profile.json"):
  raw = FileAccess.get_file_as_string("user://profile.json")
 var data = JSON.parse_string(raw) if not raw.is_empty() else null
 if data is Dictionary:
  var valid = data.get("deck",[]) is Array and data.get("deck",[]).size() == 12
  for id in data.get("deck",[]):
   if not cards.has(id): valid = false
  if valid:
   profile.deck = data.deck
   for key in ["coins","xp","wins","losses","stage"]:
    profile[key] = maxi(0,int(data.get(key,0)))
   profile.stage = mini(4,profile.stage)
 if OS.has_feature("web"):
  sound_on = str(JavaScriptBridge.eval("localStorage.getItem('dungeon_sound') || 'on'")) != "off"
  var saved_speed = str(JavaScriptBridge.eval("localStorage.getItem('dungeon_battle_speed') || '1'")).to_float()
  if saved_speed==1.0 or saved_speed==1.5 or saved_speed==2.0: speed = saved_speed

func save_profile() -> void:
 var encoded = JSON.stringify(profile)
 if OS.has_feature("web"):
  JavaScriptBridge.eval("localStorage.setItem('dungeon_cards_v15'," + JSON.stringify(encoded) + ")")
 else:
  var file = FileAccess.open("user://profile.json",FileAccess.WRITE)
  if file: file.store_string(encoded)
  else: save_error = true

func _process(delta: float) -> void:
 clock += delta
 fx_time = maxf(0,fx_time-delta*speed)
 motion = maxf(0,motion-delta*speed)
 pulse = maxf(0,pulse-delta*speed)
 if screen == "battle" and sound_on and not done:
  music_clock += delta
  if music_clock > 0.49:
   music_clock = 0
   var notes = [220.0,261.63,293.66,329.63,293.66,261.63,196.0,246.94,220.0,261.63,329.63,392.0,329.63,293.66,261.63,196.0]
   tone(notes[music_step%notes.size()],0.32,0.025)
   if music_step%4==0: tone(110.0,0.9,0.035)
   music_step += 1
 queue_redraw()

func layout_transform() -> Transform2D:
 var factor = minf(size.x/390.0,size.y/740.0)
 return Transform2D(0,Vector2(factor,factor),0,(size-Vector2(390,740)*factor)/2)

func rebuild() -> void:
 if not is_instance_valid(controls): return
 for node in controls.get_children():
  controls.remove_child(node)
  node.queue_free()
 var tx = layout_transform()
 controls.position = tx.origin
 controls.scale = tx.get_scale()
 if screen == "home":
  var deck_button = button(Rect2(33,416,324,49),"MONTAR DECK",open_collection)
  deck_button.add_theme_font_override("font",title_font)
  deck_button.add_theme_font_size_override("font_size",16)
  button(Rect2(33,477,157,45),"PROGRESSO DA TORRE",func(): panel = "tower"; rebuild())
  button(Rect2(200,477,157,45),"CONFIGURAÇÕES",func(): panel = "settings"; rebuild())
  button(Rect2(33,534,324,49),"INICIAR BATALHA",start_battle,true)
 elif screen == "battle":
  button(Rect2(14,465,83,26),"SOM" if sound_on else "MUDO",toggle_sound)
  button(Rect2(319,465,57,26),"× " + str(speed),toggle_speed)
  button(Rect2(12,125,58,75),"",func(): panel = "enemy"; rebuild(),false,busy,true)
  button(Rect2(320,410,58,80),"",func(): panel = "hero"; rebuild(),false,busy,true)
  for i in range(hand.size()):
   var id = hand[i]
   var card_button = button(Rect2(7+i*76,569,72,113),"",play.bind(i),false,busy or done or cards[id].cost>energy,true)
   var hold = Timer.new()
   hold.one_shot = true
   hold.wait_time = 0.55
   card_button.add_child(hold)
   card_button.button_down.connect(hold.start)
   card_button.button_up.connect(hold.stop)
   hold.timeout.connect(func(): panel="card:"+id; rebuild())
  button(Rect2(9,696,372,38),"ENCERRAR TURNO  →",end_turn,true,busy or done)
 if panel != "":
  for node in controls.get_children(): node.hide()
  build_panel()
 queue_redraw()

func style_box(fill: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = fill
 s.border_color = border
 s.set_border_width_all(2)
 s.set_corner_radius_all(radius)
 s.shadow_color = Color(0,0,0,0.6)
 s.shadow_size = 4
 return s

func button(rect: Rect2, value: String, action: Callable, primary = false, disabled = false, invisible = false) -> Button:
 var b = Button.new()
 b.position = rect.position
 b.size = rect.size
 b.text = value
 b.disabled = disabled
 b.focus_mode = Control.FOCUS_NONE
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_font_override("font",title_font if primary else body_font)
 b.add_theme_font_size_override("font_size",16 if primary else 10)
 b.add_theme_color_override("font_color",Color("211322") if primary else GOLD)
 b.add_theme_color_override("font_hover_color",Color("211322") if primary else WHITE)
 b.add_theme_color_override("font_disabled_color",Color("807768"))
 for state in ["normal","hover","pressed","disabled","focus"]:
  if invisible: b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
  else:
   var fill = Color("f3c265") if primary else INK
   if state == "hover": fill = Color("ffe2a2") if primary else Color("30243c")
   if state == "pressed": fill = Color("bf8b40") if primary else Color("4c3650")
   if state == "disabled": fill = Color("302d34")
   b.add_theme_stylebox_override(state,style_box(fill,GOLD))
 if primary:
  var gold_texture = load("res://assets/lobby-button.png" if screen=="home" else "res://assets/gold-button.png")
  for state in ["normal","hover","pressed"]:
   var gold_style = StyleBoxTexture.new()
   gold_style.texture = gold_texture
   gold_style.texture_margin_left = 12
   gold_style.texture_margin_right = 12
   gold_style.texture_margin_top = 12
   gold_style.texture_margin_bottom = 12
   b.add_theme_stylebox_override(state,gold_style)
 b.pressed.connect(action)
 controls.add_child(b)
 return b

func frame(rect: Rect2, fill = INK, border = GOLD, radius = 5) -> void:
 draw_style_box(style_box(fill,border,radius),rect)

func text_at(value: String, rect: Rect2, font_size = 12, color = WHITE, centered = false, serif = false) -> void:
 var font = title_font if serif else body_font
 var lines = value.split("\n")
 var y = rect.position.y
 for line in lines:
  var width = font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  var x = rect.position.x + (maxf(0,(rect.size.x-width)/2) if centered else 0)
  draw_string(font,Vector2(x,y+font_size),line,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,font_size,color)
  y += font_size*1.45

func text_wrapped(value: String, rect: Rect2, font_size = 10, color = WHITE) -> void:
 var line = ""
 var y = rect.position.y
 for word in value.split(" "):
  var next = word if line.is_empty() else line+" "+word
  if body_font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x and not line.is_empty():
   text_at(line,Rect2(rect.position.x,y,rect.size.x,font_size),font_size,color)
   y+=font_size*1.3
   line=word
   if y+font_size>rect.end.y: return
  else: line=next
 text_at(line,Rect2(rect.position.x,y,rect.size.x,font_size),font_size,color)

func image_at(art: String, rect: Rect2, tint = Color.WHITE) -> void:
 if textures.has(art): draw_texture_rect(textures[art],rect,false,tint)

func image_cover(art: String, rect: Rect2) -> void:
 var texture: Texture2D = textures[art]
 var original = texture.get_size()
 var factor = maxf(rect.size.x/original.x,rect.size.y/original.y)
 var crop = rect.size/factor
 draw_texture_rect_region(texture,rect,Rect2((original-crop)/2,crop))

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("070a18"))
 draw_set_transform_matrix(layout_transform())
 if screen == "home": draw_home()
 else: draw_battle()
 if panel != "": draw_panel()
 draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_home() -> void:
 image_at("lobby-background",Rect2(0,0,390,740))
 image_at("lobby-panel",Rect2(16,89,358,558))
 text_at("✦  T O R R E   I N F I N I T A  ✦",Rect2(33,105,324,20),10,GOLD,true)
 image_at("swords",Rect2(33,127,26,30))
 text_at("DUNGEON CARDS",Rect2(59,126,298,40),25,GOLD,true,true)
 image_at("lobby",Rect2(33,166,324,100))
 text_at("A JORNADA COMEÇA AQUI",Rect2(33,244,324,20),10,GOLD,true)
 text_at("FASE %d / 5" % (int(profile.stage)+1),Rect2(33,274,324,20),12,GOLD,true)
 var boss = stages[int(profile.stage)]
 text_at(boss.name + " — " + boss.title,Rect2(33,300,324,25),18,WHITE,true,true)
 text_at(boss.zone,Rect2(33,329,324,20),11,Color("c7c7df"),true)
 frame(Rect2(33,363,324,41),Color("11172b"),Color("796446"),9)
 text_at("BARALHO PREPARADO",Rect2(46,376,185,20),11,WHITE)
 text_at("12 / 12 cartas",Rect2(238,376,105,20),11,GOLD,true)
 text_at("Monte seu baralho antes de iniciar. Durante a batalha,
ele fica bloqueado.",Rect2(33,596,324,35),10,Color("bdb5c9"),true)

func draw_battle() -> void:
 image_at("citadel",Rect2(0,0,390,740),Color(0.7,0.65,0.85))
 image_at("swords",Rect2(7,20,23,28))
 draw_rect(Rect2(0,0,390,740),Color(0.02,0.02,0.09,0.5))
 text_at("✦  T O R R E   I N F I N I T A",Rect2(12,5,250,15),10,GOLD)
 text_at("DUNGEON CARDS",Rect2(30,20,265,30),20,GOLD,false,true)
 frame(Rect2(292,4,86,45),INK,GOLD,12)
 text_at("500",Rect2(297,14,76,22),21,GOLD,true,true)
 text_at("BRONZE III",Rect2(297,37,76,15),8,WHITE,true)
 frame(Rect2(329,2,53,14),Color("16152b"),GOLD,2)
 text_at("FASE %d/5" % (stage_index+1),Rect2(331,4,49,11),7,GOLD,true)
 draw_line(Vector2(9,56),Vector2(381,56),GOLD,1)
 text_at("NV %d  ·  %d MOEDAS  ·  %d VITÓRIAS  ·  FASE %d/5" % [1+int(profile.xp)/100,profile.coins,profile.wins,stage_index+1],Rect2(7,60,376,15),10,GOLD,true)
 frame(Rect2(4,76,382,44),Color(0.03,0.03,0.1,0.94),GOLD,0)
 text_at("DERROTE " + stages[stage_index].name,Rect2(42,78,230,20),15,GOLD,false,true)
 text_wrapped(stages[stage_index].description+" Vença antes da 10ª rodada!",Rect2(42,98,260,20),8,WHITE)
 image_at("malgruk-elite",Rect2(9,82,27,32))
 frame(Rect2(310,85,69,26),Color("342235"),GOLD,0)
 text_at("RODADA %d/10" % mini(10,round_number),Rect2(312,92,65,15),9,GOLD,true,true)
 image_cover("citadel",Rect2(8,123,374,370))
 draw_rect(Rect2(8,123,374,370),Color(0.04,0.02,0.1,0.18))
 portrait(false,Rect2(12,125,58,75))
 text_at("VIDA",Rect2(82,138,150,18),12,WHITE)
 text_at("%d / %d" % [enemy,stages[stage_index].hp],Rect2(291,138,87,18),12,WHITE,true)
 health_bar(Rect2(82,161,294,12),float(enemy)/float(stages[stage_index].hp),Color("ff665e"))
 text_at(intent(),Rect2(82,181,290,18),10,GOLD)
 var enemy_status = []
 if enemy_shield>0: enemy_status.append("ESCUDO %d" % enemy_shield)
 if burn>0: enemy_status.append("QUEIMA %d" % burn)
 if freeze>0: enemy_status.append("CONGELADO")
 text_at(" · ".join(enemy_status),Rect2(82,201,290,18),9,Color("a5dcff"))
 # Native tweened combatants emerge only during attacks, as in the source.
 if motion>0:
  var progress = sin((1.0-motion)*PI)
  var from = Vector2(294,332) if motion_enemy else Vector2(34,322)
  var to = Vector2(50,244) if motion_enemy else Vector2(280,205)
  var at = from.lerp(to,progress)
  image_at("malgruk-battle" if motion_enemy else "elyra-battle",Rect2(at,Vector2(75,105)))
 frame(Rect2(148,296,94,29),Color(0.04,0.04,0.1,0.86),GOLD,16)
 text_at(phase,Rect2(151,305,88,15),10,GOLD,true,true)
 text_at("VIDA",Rect2(15,432,120,20),12,WHITE)
 text_at("%d / 100" % hero,Rect2(234,432,73,20),12,WHITE,true)
 health_bar(Rect2(15,453,292,12),hero/100.0,Color("42dfee"))
 portrait(true,Rect2(320,410,58,80))
 if hero_shield>0: text_at("ESCUDO %d" % hero_shield,Rect2(108,474,190,18),10,Color("9ce9ff"),true)
 if hero<=30: text_at("VIDA CRÍTICA — PROTEJA ELYRA",Rect2(65,405,250,16),10,Color("ff8677"),true)
 for i in range(3): frame(Rect2(8+i*128,497,119,38),Color(0.03,0.04,0.1,0.95),Color("ad905e"),0)
 text_at("MANA %d / 3" % energy,Rect2(9,499,117,15),9,WHITE,true,true)
 text_at("SEQUÊNCIA",Rect2(137,499,117,15),9,WHITE,true,true)
 text_at("BARALHO",Rect2(265,499,117,15),9,WHITE,true,true)
 for i in range(3):
  image_at("gem",Rect2(24+i*27,509,24,24),Color.WHITE if i<energy else Color(0.25,0.3,0.4,0.6))
 text_at("×%d" % maxi(1,combo),Rect2(137,513,117,20),19,GOLD,true,true)
 text_at(str(deck.size()),Rect2(265,513,117,20),19,GOLD,true,true)
 draw_line(Vector2(0,541),Vector2(390,541),GOLD,1)
 text_at("✦ SUA MÃO",Rect2(9,546,170,20),13,GOLD,false,true)
 var playable = false
 for id in hand:
  if cards[id].cost<=energy: playable=true
 text_at("Executando ação..." if busy else "Toque para jogar" if playable else "Encerre o turno",Rect2(250,549,130,16),9,WHITE,true)
 if hero_shield>0: draw_arc(Vector2(348,448),39,0,TAU,48,Color(0.4,0.85,1,0.8),3)
 if enemy_shield>0: draw_arc(Vector2(41,161),39,0,TAU,48,Color(0.4,0.85,1,0.8),3)
 for i in range(hand.size()): draw_card(hand[i],Rect2(7+i*76,569,72,113),busy or cards[hand[i]].cost>energy)
 if fx_time>0:
  var at = Vector2(190,240 if fx_enemy else 405)
  var col = fx_color
  col.a = minf(1,fx_time*2)
  draw_arc(at,18+(1-fx_time)*65,0,TAU,40,col,3)
  for i in range(12):
   var angle = i*TAU/12+clock
   var particle = at+Vector2(cos(angle),sin(angle))*(15+(1-fx_time)*80)
   draw_circle(particle,2.5*fx_time,col)
  text_at(fx_amount,Rect2(at.x-110,at.y-45-(1-fx_time)*25,220,30),26,col,true,true)
 if pulse>0: draw_rect(Rect2(8,123,374,370),Color(fx_color,0.13*pulse))


func portrait(is_hero: bool, rect: Rect2) -> void:
 var rim = style_box(INK,GOLD,9)
 rim.shadow_color = Color(0.3,0.8,1,0.4) if is_hero else Color(1,0.6,0.2,0.5)
 rim.shadow_size = 7
 draw_style_box(rim,rect)
 frame(rect.grow(-3),Color.TRANSPARENT,GOLD,6)
 image_at("elyra-elite" if is_hero else "malgruk-elite",Rect2(rect.position+Vector2(3,3),rect.size-Vector2(6,6)))
 frame(Rect2(rect.position+Vector2(18,1),Vector2(38,14)),Color("2a1930"),GOLD,3)
 text_at("LV %02d" % (8 if is_hero else 12+stage_index*3),Rect2(rect.position+Vector2(19,3),Vector2(35,12)),8,GOLD,true,true)
 text_at("ELYRA" if is_hero else stages[stage_index].name,Rect2(rect.position+Vector2(2,rect.size.y-18),Vector2(rect.size.x-4,16)),10,GOLD,true,true)

func health_bar(rect: Rect2, fraction: float, color: Color) -> void:
 frame(rect,Color("05091b"),GOLD,7)
 var inner = Rect2(rect.position+Vector2(2,2),Vector2(maxf(0,(rect.size.x-4)*fraction),rect.size.y-4))
 draw_style_box(style_box(color,color,5),inner)
 draw_line(inner.position+Vector2(1,1),inner.position+Vector2(maxf(1,inner.size.x-1),1),color.lightened(0.4),2)

func card_flavor(c: Dictionary) -> String:
 if c.has("freeze"): return "Aprisiona o inimigo em cristais glaciais e impede a próxima ação."
 if c.has("burn"): return "As chamas continuam causando dano no início do turno inimigo."
 if c.has("block") and c.has("heal"): return "Restaura vida e fortalece sua proteção."
 if c.has("block"): return "Cria uma barreira mágica que absorve dano recebido."
 if c.has("heal"): return "Canaliza energia vital para recuperar pontos de vida."
 if c.art=="storm": return "Invoca relâmpagos devastadores contra o adversário."
 return "Concentra poder arcano em um golpe direto contra o inimigo."

func info(id: String) -> String:
 var c = cards[id]
 var parts = []
 for pair in [["damage","dano"],["block","defesa"],["heal","cura"]]:
  if c.has(pair[0]): parts.append(str(int(c[pair[0]]))+" "+pair[1])
 if c.has("burn"): parts.append("queima")
 if c.has("freeze"): parts.append("congela")
 return " · ".join(parts)

func draw_card(id: String, rect: Rect2, unavailable = false) -> void:
 var c = cards[id]
 var rim = style_box(Color("0a1026"),GOLD,7)
 rim.shadow_color = Color(Color(c.glow),0.5)
 rim.shadow_size = 5
 draw_style_box(rim,rect)
 frame(rect.grow(-3),Color.TRANSPARENT,Color("a47b4c"),4)
 var texrect = Rect2(rect.position+Vector2(3,3),Vector2(rect.size.x-6,rect.size.y*0.64))
 image_at("card-"+c.art,texrect)
 draw_rect(Rect2(rect.position+Vector2(3,rect.size.y*0.64),Vector2(rect.size.x-6,rect.size.y*0.34)),Color(0.02,0.03,0.07,0.95))
 text_at(c.name,Rect2(rect.position+Vector2(2,rect.size.y*0.66),Vector2(rect.size.x-4,15)),7,WHITE,true)
 text_at(info(id),Rect2(rect.position+Vector2(2,rect.size.y*0.78),Vector2(rect.size.x-4,15)),7,GOLD,true)
 var type = "DEFESA" if c.has("block") else "CURA" if c.has("heal") else "ATAQUE" if c.art=="sword" else "MAGIA"
 frame(Rect2(rect.position+Vector2(5,rect.size.y-15),Vector2(rect.size.x-10,12)),Color("17233d"),Color(c.glow),5)
 text_at(type,Rect2(rect.position+Vector2(5,rect.size.y-14),Vector2(rect.size.x-10,12)),7,WHITE,true)
 var center = rect.position+Vector2(8,9)
 draw_circle(center,11,Color("166c9b"))
 draw_arc(center,11,0,TAU,24,Color("adf5ff"),2)
 text_at(str(int(c.cost)),Rect2(center-Vector2(10,8),Vector2(20,17)),12,Color.WHITE,true)
 if unavailable: draw_rect(rect,Color(0.02,0.02,0.08,0.53))

func build_panel() -> void:
 # Full-screen input shield keeps touches from reaching the battle underneath.
 var shield = button(Rect2(0,0,390,740),"",func(): pass,false,false,true)
 shield.mouse_default_cursor_shape = Control.CURSOR_ARROW
 if panel == "result":
  button(Rect2(55,478,280,48),"VOLTAR À TORRE",func(): screen="home"; panel=""; rebuild(),true)
 else:
  button(Rect2(316,61,42,30),"FECHAR",func(): panel=""; rebuild())
 if panel == "settings":
  button(Rect2(65,258,260,44),"SOM: LIGADO" if sound_on else "SOM: DESLIGADO",toggle_sound)
  button(Rect2(65,326,260,44),"VELOCIDADE: ×"+str(speed),toggle_speed)
 elif panel == "collection":
  var ids = cards.keys()
  var start = collection_page*8
  for i in range(start,mini(start+8,ids.size())):
   var local_i = i-start
   var rect = Rect2(30+(local_i%4)*85,215+(local_i/4)*160,75,132)
   button(rect,"",select_card.bind(ids[i]),false,screen=="battle",true)
  button(Rect2(35,575,94,34),"ANTERIOR",func(): collection_page=maxi(0,collection_page-1); rebuild(),false,collection_page==0)
  button(Rect2(261,575,94,34),"PRÓXIMA",func(): collection_page=mini(2,collection_page+1); rebuild(),false,collection_page==2)

func draw_panel() -> void:
 draw_rect(Rect2(0,0,390,740),Color(0.01,0.01,0.04,0.85))
 frame(Rect2(18,46,354,649),Color("0b1025"),GOLD,14)
 if panel == "collection":
  text_at("GRIMÓRIO DE ELYRA",Rect2(35,106,320,30),20,GOLD,true,true)
  text_at("BARALHO 12 / 12   ·   %d / 3" % (collection_page+1),Rect2(30,143,330,20),11,WHITE,true)
  text_at("Baralho bloqueado durante a batalha." if screen=="battle" else "Toque para trocar a carta mais antiga do deck.",Rect2(30,171,330,20),10,GOLD,true)
  var ids = cards.keys()
  for i in range(collection_page*8,mini(collection_page*8+8,ids.size())):
   var local_i = i-collection_page*8
   var rect = Rect2(30+(local_i%4)*85,215+(local_i/4)*160,75,132)
   draw_card(ids[i],rect)
   if ids[i] in profile.deck: text_at("NO DECK",Rect2(rect.position+Vector2(0,137),Vector2(75,16)),8,Color("8ceaca"),true)
  text_at(message if selected_detail!="" else "24 habilidades · 12 cartas por baralho",Rect2(30,637,330,30),9,WHITE,true)
 elif panel == "tower":
  text_at("GUARDIÕES DA TORRE",Rect2(30,125,330,35),20,GOLD,true,true)
  for i in range(5):
   frame(Rect2(38,195+i*82,314,65),Color("131a30"),GOLD if i<=int(profile.stage) else Color("514959"))
   text_at("%d. %s" % [i+1,stages[i].name],Rect2(53,205+i*82,282,20),15,GOLD,false,true)
   text_at("CONCLUÍDA" if i<int(profile.stage) else "PRÓXIMA BATALHA" if i==int(profile.stage) else "BLOQUEADA",Rect2(53,232+i*82,280,16),9,WHITE)
 elif panel == "settings":
  text_at("CONFIGURAÇÕES",Rect2(30,156,330,30),22,GOLD,true,true)
  text_at("Progresso salvo automaticamente neste navegador.",Rect2(30,423,330,35),10,WHITE,true)
 elif panel in ["hero","enemy"]:
  var is_hero = panel=="hero"
  image_at("elyra-elite" if is_hero else "malgruk-elite",Rect2(112,150,166,230))
  text_at("ELYRA" if is_hero else stages[stage_index].name,Rect2(30,408,330,35),25,GOLD,true,true)
  text_at("GUARDIÃ ARCANA" if is_hero else stages[stage_index].title,Rect2(30,453,330,24),12,WHITE,true)
  text_at("ESSÊNCIA ARCANA" if is_hero else stages[stage_index].ability,Rect2(30,512,330,24),15,GOLD,true,true)
  text_at("Canaliza a magia elemental para proteger a Torre." if is_hero else "O guardião anuncia sua próxima ação antes de atacar.",Rect2(30,559,330,35),10,WHITE,true)
 elif panel.begins_with("card:"):
  var id = panel.trim_prefix("card:")
  draw_card(id,Rect2(107,164,176,286))
  text_at(cards[id].name,Rect2(30,482,330,30),22,GOLD,true,true)
  text_at(info(id),Rect2(30,532,330,24),13,WHITE,true)
  text_wrapped(card_flavor(cards[id]),Rect2(45,581,300,62),11,GOLD)
 elif panel == "result":
  text_at("TORRE INFINITA",Rect2(30,180,330,24),12,WHITE,true)
  text_at("VITÓRIA!" if outcome=="win" else "EMPATE" if outcome=="draw" else "DERROTA",Rect2(30,244,330,55),38,GOLD,true,true)
  text_at("Os cinco guardiões foram conquistados!" if outcome=="win" and stage_index==4 else "Nova fase desbloqueada!" if outcome=="win" else "Ajuste seu deck e tente novamente.",Rect2(30,333,330,30),12,WHITE,true)
  text_at("+50 MOEDAS  ·  +35 XP" if outcome=="win" else "+10 MOEDAS  ·  +12 XP" if outcome=="draw" else "+5 MOEDAS  ·  +8 XP",Rect2(30,395,330,25),14,GOLD,true,true)

func open_collection() -> void:
 panel = "collection"
 selected_detail = ""
 rebuild()

func select_card(id: String) -> void:
 if screen == "battle": return
 selected_detail = id
 if id in profile.deck:
  message = "Já está no baralho. Escolha outra habilidade."
 else:
  var removed = profile.deck.pop_front()
  profile.deck.append(id)
  message = cards[removed].name + " → " + cards[id].name
  save_profile()
 tone(620,0.12)
 rebuild()

func toggle_sound() -> void:
 sound_on = not sound_on
 if OS.has_feature("web"): JavaScriptBridge.eval("localStorage.setItem('dungeon_sound','"+("on" if sound_on else "off")+"')")
 if not sound_on:
  for voice in voices:
   if is_instance_valid(voice): voice.stop(); voice.queue_free()
  voices.clear()
 rebuild()

func toggle_speed() -> void:
 speed = 1.5 if speed==1.0 else 2.0 if speed==1.5 else 1.0
 if OS.has_feature("web"): JavaScriptBridge.eval("localStorage.setItem('dungeon_battle_speed','"+str(speed)+"')")
 rebuild()

func effect(art: String) -> void:
 if not sound_on: return
 var kind = "steel" if art=="sword" else "lightning" if art=="storm" else art
 if not sfx.has(kind): tone(160.0 if art=="fire" else 740.0,0.35); return
 var voice = AudioStreamPlayer.new()
 voice.stream = sfx[kind]
 voice.volume_db = -3
 add_child(voice)
 voices.append(voice)
 voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
 voice.play()

func tone(frequency: float, duration = 0.2, volume = 0.15) -> void:
 if not sound_on: return
 var wav = AudioStreamWAV.new()
 wav.format = AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate = 22050
 var count = int(duration*22050)
 var data = PackedByteArray()
 data.resize(count*2)
 for i in range(count):
  var t = float(i)/22050.0
  var envelope = sin(PI*float(i)/count)*exp(-t*7)
  var wave = sin(TAU*frequency*t)+0.25*sin(TAU*frequency*2*t)
  data.encode_s16(i*2,int(clampf(wave*envelope*volume,-1,1)*32767))
 wav.data = data
 var voice = AudioStreamPlayer.new()
 voice.stream = wav
 add_child(voice)
 voices.append(voice)
 voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
 voice.play()

func start_battle() -> void:
 stage_index = int(profile.stage)
 hero=100; enemy=int(stages[stage_index].hp); hero_shield=0; enemy_shield=0
 energy=3; round_number=1; combo=0; burn=0; freeze=0
 chain=[]; last_element=""; triad_used=false; triad_charge=false
 hand=[]; discard=[]; deck=profile.deck.duplicate(); deck.shuffle()
 done=false; busy=false; screen="battle"; panel=""; phase="SUA VEZ"
 message="Prepare seu primeiro ataque!"; draw_hand(); tone(440,0.3); rebuild()

func draw_hand() -> void:
 while hand.size()<5:
  if deck.is_empty():
   if discard.is_empty(): break
   deck=discard.duplicate(); deck.shuffle(); discard.clear()
  hand.append(deck.pop_back())

func element(c: Dictionary) -> String:
 return "steel" if c.art=="sword" else "ice" if c.art=="shield" else "water" if c.art=="heal" else "lightning" if c.art=="spark" else c.art

func hit(target_enemy: bool, amount: int) -> int:
 var absorbed = mini(enemy_shield if target_enemy else hero_shield,amount)
 amount -= absorbed
 if target_enemy: enemy_shield-=absorbed; enemy=maxi(0,enemy-amount)
 else: hero_shield-=absorbed; hero=maxi(0,hero-amount)
 return amount

func feedback(value: String, color: Color, target_enemy: bool) -> void:
 fx_amount=value; fx_color=color; fx_enemy=target_enemy; fx_time=1.0; pulse=1.0

func play(index: int) -> void:
 if busy or done or index<0 or index>=hand.size(): return
 var id = hand[index]
 var c: Dictionary = cards[id]
 if c.cost>energy: return
 busy=true; energy-=int(c.cost); hand.remove_at(index); discard.append(id); combo+=1
 var el = element(c)
 chain.append(el)
 if chain.size()>3: chain.pop_front()
 var unique = {}
 for item in chain: unique[item]=true
 if chain.size()==3 and unique.size()==3 and not triad_used:
  triad_used=true; triad_charge=true; energy=mini(3,energy+1)
 var resonance = last_element==el and combo>1
 last_element=el; phase="CONJURAÇÃO" if c.art!="sword" else "INVESTIDA"
 motion=1.0; motion_enemy=false; effect(c.art)
 rebuild()
 await get_tree().create_timer(0.35/speed).timeout
 var details = []
 if c.has("damage"):
  var bonus = (mini(6,(combo-2)*2) if combo>=3 else 0)+(4 if resonance else 0)+(6 if triad_charge else 0)
  triad_charge=false
  var amount = hit(true,int(c.damage)+bonus)
  feedback("−%d%s" % [amount,"  COMBO +%d" % bonus if bonus>0 else ""],Color(c.glow),true)
  details.append("%d dano" % amount)
 if c.has("block"):
  hero_shield+=int(c.block); feedback("+%d ESCUDO" % int(c.block),Color("72d9ff"),false)
  details.append("+%d defesa" % int(c.block))
 if c.has("heal"):
  var amount = mini(int(c.heal),100-hero)
  hero+=amount; feedback("+%d VIDA" % amount,Color("88ffb4"),false)
  details.append("+%d cura" % amount)
 if c.has("burn"): burn=maxi(burn,int(c.burn)); details.append("Queimadura")
 if c.has("freeze"): freeze=maxi(freeze,int(c.freeze)); details.append("Congelado")
 message=c.name+": "+" · ".join(details)
 await get_tree().create_timer(0.35/speed).timeout
 if enemy<=0: finish("win"); return
 busy=false; phase="SUA VEZ"; rebuild()

func boss_special() -> bool:
 return round_number%3==0 and stage_index>0

func boss_damage() -> int:
 return int(stages[stage_index].attack)+(4 if round_number%3==0 else 0)+(5 if boss_special() and stage_index==1 else 0)

func boss_defends() -> bool:
 return (boss_special() and stage_index==3) or (not boss_special() and enemy<ceil(float(stages[stage_index].hp)*0.3) and round_number%2==0)

func intent() -> String:
 if freeze>0: return "CONGELADO · PERDE A AÇÃO"
 if boss_defends(): return "Defesa: +%d escudo" % int(stages[stage_index].guard)
 if boss_special(): return stages[stage_index].ability+": %d" % boss_damage()
 return "Ataque: %d dano" % boss_damage()

func end_turn() -> void:
 if busy or done: return
 busy=true; phase="TURNO INIMIGO"; rebuild()
 await get_tree().create_timer(0.35/speed).timeout
 if burn>0:
  var amount=hit(true,3); burn-=1
  feedback("QUEIMA −%d" % amount,Color("ff995c"),true)
  await get_tree().create_timer(0.3/speed).timeout
 if enemy<=0: finish("win"); return
 if freeze>0:
  freeze-=1; message=stages[stage_index].name+" perdeu a ação: congelado."
  feedback("CONGELADO",Color("a4e9ff"),true)
 elif boss_defends():
  enemy_shield+=int(stages[stage_index].guard)
  message=stages[stage_index].name+" ergueu escudo."
  feedback("+%d ESCUDO" % int(stages[stage_index].guard),Color("a4e9ff"),true)
 else:
  motion=1.0; motion_enemy=true; effect(stages[stage_index].element if boss_special() else "sword")
  await get_tree().create_timer(0.35/speed).timeout
  var amount=hit(false,boss_damage())
  message=stages[stage_index].name+" atacou: %d dano." % amount
  feedback("−%d" % amount,Color("ff7f66"),false)
 await get_tree().create_timer(0.45/speed).timeout
 hero_shield=0; discard.append_array(hand); hand.clear(); round_number+=1; energy=3
 combo=0; last_element=""; chain=[]; triad_used=false; triad_charge=false; draw_hand()
 if hero<=0: finish("lose"); return
 if round_number>10: finish("win" if hero>enemy else "lose" if hero<enemy else "draw"); return
 busy=false; phase="SUA VEZ"; rebuild()

func finish(result: String) -> void:
 if done: return
 done=true; busy=false; outcome=result
 profile.coins+=50 if result=="win" else 10 if result=="draw" else 5
 profile.xp+=35 if result=="win" else 12 if result=="draw" else 8
 if result=="win": profile.wins+=1; profile.stage=mini(4,int(profile.stage)+1)
 if result=="lose": profile.losses+=1
 save_profile(); panel="result"; tone(660 if result=="win" else 160,0.5); rebuild()
