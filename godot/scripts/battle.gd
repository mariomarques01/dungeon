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
var presentation
var audio_engine
var qa_enabled = false
var last_hit: Dictionary = {}
var turn_serial = 0

func _ready() -> void:
 title_font.fallbacks = [preload("res://assets/symbols.ttf")]
 body_font.fallbacks = [preload("res://assets/symbols.ttf")]
 cards = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards.json"))
 stages = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages.json"))
 for art in ["gem","lobby","lobby-panel","lobby-background","swords","sword","citadel","elyra-elite","malgruk-elite","elyra-battle","malgruk-battle","card-sword","card-fire","card-shield","card-lightning","card-heal","card-spark","card-ice","card-water","card-earth","card-storm"]:
  textures[art] = load("res://assets/" + art + ".png")
 load_profile()
 presentation=preload("res://scripts/arena_visuals.gd").new(self)
 audio_engine=preload("res://scripts/combat_audio.gd").new(self)
 audio_engine.set_enabled(sound_on)
 if OS.has_feature("web"):
  qa_enabled=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''"))=="1"
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
 clock+=delta
 if presentation: presentation.update(delta)
 if audio_engine: audio_engine.update(delta)
 if qa_enabled:
  var snapshot={"screen":screen,"panel":panel,"hero":hero,"enemy":enemy,"heroShield":hero_shield,"enemyShield":enemy_shield,"energy":energy,"round":round_number,"hand":hand,"deck":deck.size(),"busy":busy,"done":done,"burn":burn,"freeze":freeze,"stage":stage_index,"phase":phase,"sound":sound_on,"speed":speed,"profile":profile,"animation":presentation.action,"animationTime":presentation.action_time,"visualEvents":presentation.events,"audio":audio_engine.history,"musicPlaying":audio_engine.music.playing and not audio_engine.music.stream_paused}
  JavaScriptBridge.eval("window.__dungeonState="+JSON.stringify(snapshot))
 queue_redraw()

func layout_transform() -> Transform2D:
 var height=700.0 if screen=="battle" else 740.0
 var factor=minf(size.x/390.0,size.y/height)
 return Transform2D(0,Vector2(factor,factor),0,(size-Vector2(390,height)*factor)/2)

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
  button(Rect2(17,480,90,21),"SOM" if sound_on else "MUDO",toggle_sound)
  button(Rect2(320,479,55,21),"× " + str(speed),toggle_speed)
  button(Rect2(9,7,55,55),"",func(): panel = "enemy"; rebuild(),false,busy,true)
  button(Rect2(313,422,62,56),"",func(): panel = "hero"; rebuild(),false,busy,true)
  for i in range(hand.size()):
   var id = hand[i]
   var card_button = button(Rect2(8+i*76,532,70,110),"",play.bind(i),false,busy or done or cards[id].cost>energy,true)
   var hold = Timer.new()
   hold.one_shot = true
   hold.wait_time = 0.55
   card_button.add_child(hold)
   card_button.button_down.connect(hold.start)
   card_button.button_up.connect(hold.stop)
   hold.timeout.connect(func(): panel="card:"+id; rebuild())
  var end_button=button(Rect2(9,656,372,39),"",end_turn,false,busy or done,true)
  end_button.tooltip_text="Encerrar turno"
  var gear=button(Rect2(326,15,48,34),"⚙",func(): panel="settings"; rebuild())
  gear.add_theme_font_size_override("font_size",25)
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
 draw_texture_rect(presentation.backdrop,Rect2(0,0,390,740),false,Color(0.35,0.28,0.38))
 image_at("lobby-panel",Rect2(16,89,358,558))
 text_at("✦  T O R R E   I N F I N I T A  ✦",Rect2(33,105,324,20),10,GOLD,true)
 image_at("swords",Rect2(33,127,26,30))
 text_at("DUNGEON CARDS",Rect2(59,126,298,40),25,GOLD,true,true)
 draw_texture_rect_region(presentation.backdrop,Rect2(33,166,324,100),Rect2(0,200,presentation.backdrop.get_width(),650))
 presentation.actor(false,0,Vector2(101,263),94)
 presentation.actor(true,0,Vector2(298,263),91)
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
 presentation.draw_scene()

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
 presentation.draw_card(id,rect,unavailable)

func build_panel() -> void:
 # Full-screen input shield keeps touches from reaching the battle underneath.
 var shield = button(Rect2(0,0,390,740),"",func(): pass,false,false,true)
 shield.mouse_default_cursor_shape = Control.CURSOR_ARROW
 if panel == "result":
  button(Rect2(55,478,280,48),"VOLTAR À TORRE",func(): screen="home"; panel=""; audio_engine.stop_music(); rebuild(),true)
 else:
  button(Rect2(316,61,42,30),"FECHAR",func(): panel=""; rebuild())
 if panel == "settings":
  button(Rect2(65,258,260,44),"SOM: LIGADO" if sound_on else "SOM: DESLIGADO",toggle_sound)
  button(Rect2(65,326,260,44),"VELOCIDADE: ×"+str(speed),toggle_speed)
  button(Rect2(65,394,260,44),"CRÉDITOS DE ÁUDIO",func(): panel="credits"; rebuild())
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
  text_at("Progresso salvo automaticamente neste navegador.",Rect2(30,464,330,35),10,WHITE,true)
 elif panel in ["hero","enemy"]:
  var is_hero = panel=="hero"
  presentation.actor(not is_hero,0,Vector2(195,393),235)
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
 elif panel=="credits":
  text_at("MÚSICA E EFEITOS",Rect2(30,133,330,30),20,GOLD,true,true)
  text_wrapped("Dark Descent — Matthew Pablo. www.matthewpablo.com. CC BY 3.0. Música convertida e normalizada para uso no jogo.",Rect2(45,199,300,85),11,WHITE)
  text_wrapped("8 RPG Battle Magic SFX — leohpaz. CC BY 4.0. Gravações de fogo, gelo, trovão, água, vento, terra e carga mágica; convertidas e normalizadas.",Rect2(45,305,300,100),11,WHITE)
  text_wrapped("80 RPG SFX — rubberduck. Freeze Spell — artisticdude. CC0. Impactos de espada e armadura, escudo, cura e reação do orc.",Rect2(45,426,300,90),11,WHITE)
  text_wrapped("Licenças: creativecommons.org/licenses/by/3.0/ e creativecommons.org/licenses/by/4.0/. Fontes e links completos constam no projeto.",Rect2(45,551,300,90),10,GOLD)
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
 sound_on=not sound_on
 if OS.has_feature("web"): JavaScriptBridge.eval("localStorage.setItem('dungeon_sound','"+("on" if sound_on else "off")+"')")
 audio_engine.set_enabled(sound_on)
 rebuild()

func toggle_speed() -> void:
 speed = 1.5 if speed==1.0 else 2.0 if speed==1.5 else 1.0
 if OS.has_feature("web"): JavaScriptBridge.eval("localStorage.setItem('dungeon_battle_speed','"+str(speed)+"')")
 rebuild()

func effect(art: String) -> void:
 audio_engine.play(audio_engine.clip_for(art))

func tone(_frequency: float, _duration = 0.2, _volume = 0.15) -> void:
 if audio_engine: audio_engine.play("ui",-11.0)

func start_battle() -> void:
 turn_serial+=1
 stage_index=int(profile.stage)
 hero=100; enemy=int(stages[stage_index].hp); hero_shield=0; enemy_shield=0
 energy=3; round_number=1; combo=0; burn=0; freeze=0
 chain=[]; last_element=""; triad_used=false; triad_charge=false
 hand=[]; discard=[]; deck=profile.deck.duplicate(); deck.shuffle()
 done=false; busy=false; screen="battle"; panel=""; phase="SUA VEZ"
 message="Prepare seu primeiro ataque!"
 presentation.reset()
 audio_engine.history.clear()
 audio_engine.start_music()
 draw_hand(); rebuild()

func draw_hand() -> void:
 while hand.size()<5:
  if deck.is_empty():
   if discard.is_empty(): break
   deck=discard.duplicate(); deck.shuffle(); discard.clear()
  hand.append(deck.pop_back())

func element(c: Dictionary) -> String:
 return "steel" if c.art=="sword" else "ice" if c.art=="shield" else "water" if c.art=="heal" else "lightning" if c.art=="spark" else c.art

func hit(target_enemy: bool, amount: int) -> int:
 amount=maxi(0,amount)
 var current_shield=maxi(0,enemy_shield if target_enemy else hero_shield)
 var absorbed=mini(current_shield,amount)
 var hp=enemy if target_enemy else hero
 var actual=mini(hp,amount-absorbed)
 if target_enemy: enemy_shield=current_shield-absorbed; enemy=maxi(0,enemy-actual)
 else: hero_shield=current_shield-absorbed; hero=maxi(0,hero-actual)
 last_hit={"damage":actual,"blocked":absorbed,"enemy":target_enemy}
 return actual

func feedback(value: String, color: Color, target_enemy: bool) -> void:
 presentation.emit_event(value,color,target_enemy)

func animation_at(seconds: float) -> void:
 while not presentation.action.is_empty() and presentation.action_time<seconds:
  await get_tree().process_frame

func play(index: int) -> void:
 if busy or done or panel!="" or index<0 or index>=hand.size(): return
 var id=hand[index]
 var c: Dictionary=cards[id].duplicate()
 c.id=id
 if int(c.cost)>energy: return
 busy=true
 var serial=turn_serial
 energy-=int(c.cost); hand.remove_at(index); discard.append(id); combo+=1
 var el=element(c)
 chain.append(el)
 if chain.size()>3: chain.pop_front()
 var unique={}
 for item in chain: unique[item]=true
 if chain.size()==3 and unique.size()==3 and not triad_used:
  triad_used=true; triad_charge=true; energy=mini(3,energy+1)
  feedback("TRÍADE · +1 MANA",Color("cdb0ff"),false)
 var resonance=last_element==el and combo>1
 last_element=el
 phase="PODER INCORPORADO"
 presentation.begin(c,false,index)
 rebuild()
 await animation_at(0.36)
 if serial!=turn_serial: return
 audio_engine.charge(c.art)
 await animation_at(0.73)
 if serial!=turn_serial: return
 phase="ATAQUE" if c.has("damage") else "DEFESA" if c.has("block") else "CURA"
 await animation_at(1.05)
 if serial!=turn_serial: return
 var details=[]
 if c.has("damage"):
  var bonus=(mini(6,(combo-2)*2) if combo>=3 else 0)+(4 if resonance else 0)+(6 if triad_charge else 0)
  triad_charge=false
  var amount=hit(true,int(c.damage)+bonus)
  var blocked=int(last_hit.blocked)
  if blocked>0: presentation.emit_event("%d BLOQUEADO" % blocked,Color("8deaff"),true,"block")
  if amount>0: presentation.emit_event("−%d%s" % [amount," COMBO" if bonus>0 else ""],Color(c.glow),true,"hurt")
  audio_engine.impact(c.art,amount,blocked,true)
  details.append("%d dano" % amount)
 if c.has("block"):
  hero_shield+=int(c.block)
  feedback("+%d ESCUDO" % int(c.block),Color("72e7ff"),false)
  if not c.has("damage"):
   audio_engine.play("earth" if c.art=="earth" else "ice" if c.art=="ice" else "water" if c.art=="water" else "shield",-4.0)
  details.append("+%d defesa" % int(c.block))
 if c.has("heal"):
  var amount=mini(int(c.heal),100-hero)
  hero+=amount
  feedback("+%d VIDA" % amount,Color("8effb4"),false)
  audio_engine.play("heal",-8.0 if c.has("block") else -4.0)
  details.append("+%d cura" % amount)
 if c.has("burn"): burn=maxi(burn,int(c.burn)); feedback("QUEIMADURA",Color("ffb364"),true)
 if c.has("freeze"): freeze=maxi(freeze,int(c.freeze)); feedback("CONGELADO",Color("b3efff"),true); audio_engine.play("freeze",-11.0)
 message=c.name+": "+" · ".join(details)
 await animation_at(1.85)
 if serial!=turn_serial: return
 presentation.complete()
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
 if busy or done or panel!="": return
 busy=true
 var serial=turn_serial
 phase="TURNO INIMIGO"
 rebuild()
 await get_tree().create_timer(0.22/speed).timeout
 if serial!=turn_serial: return
 if burn>0:
  var amount=hit(true,3)
  burn-=1
  presentation.begin({"art":"fire","glow":"#ff853f"},false,-1,"burn")
  presentation.emit_event("QUEIMA −%d" % amount,Color("ff995c"),true,"hurt")
  audio_engine.play("fire",-9.0)
  await animation_at(0.7)
  if serial!=turn_serial: return
  presentation.complete()
 if enemy<=0: finish("win"); return
 if freeze>0:
  freeze-=1
  phase="INIMIGO CONGELADO"
  presentation.begin({"art":"ice"},true,-1,"frozen")
  feedback("AÇÃO IMPEDIDA",Color("b6efff"),true)
  audio_engine.play("freeze",-8.0)
  message=stages[stage_index].name+" perdeu a ação: congelado."
  await animation_at(0.7)
 elif boss_defends():
  var c={"art":"earth" if stage_index==3 else "shield","block":int(stages[stage_index].guard),"glow":"#fac58b"}
  presentation.begin(c,true)
  audio_engine.charge(c.art)
  await animation_at(1.05)
  if serial!=turn_serial: return
  enemy_shield+=int(stages[stage_index].guard)
  feedback("+%d ESCUDO" % int(stages[stage_index].guard),Color("9de7ff"),true)
  audio_engine.play(c.art,-4.0)
  message=stages[stage_index].name+" ergueu escudo."
  await animation_at(1.85)
 else:
  var art=stages[stage_index].element if boss_special() else "sword"
  var c={"art":art,"damage":boss_damage(),"glow":"#ff8f4f"}
  phase=stages[stage_index].ability if boss_special() else "ATAQUE INIMIGO"
  presentation.begin(c,true)
  await animation_at(0.36)
  if serial!=turn_serial: return
  audio_engine.charge(art)
  await animation_at(1.05)
  if serial!=turn_serial: return
  var amount=hit(false,boss_damage())
  var blocked=int(last_hit.blocked)
  if blocked>0: presentation.emit_event("%d BLOQUEADO" % blocked,Color("91eaff"),false,"block")
  if amount>0: presentation.emit_event("−%d VIDA" % amount,Color("ff7f66"),false,"hurt")
  audio_engine.impact(art,amount,blocked,false)
  message=stages[stage_index].name+" atacou: %d dano; %d bloqueado." % [amount,blocked]
  await animation_at(1.85)
 if serial!=turn_serial: return
 presentation.complete()
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
 save_profile(); panel="result"; audio_engine.finish_music(); audio_engine.play("heal" if result=="win" else "armor",-8.0); rebuild()
