extends SceneTree
var game
var failures=0
func check(condition: bool, label: String) -> void:
 if condition: print("PASS: "+label)
 else: failures+=1; push_error(label)
func _initialize() -> void:
 call_deferred("run")
func fresh(speed = 30.0) -> void:
 game.audio_engine.set_enabled(false)
 game.sound_on=false
 game.profile={"deck":game.DEFAULT_DECK.duplicate(),"coins":0,"xp":0,"wins":0,"losses":0,"stage":0}
 game.start_battle()
 game.speed=speed
func wait_idle() -> void:
 while game.busy: await process_frame
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 fresh(1.0)
 game.hand=["sword","shield"]
 game.play(0)
 check(game.busy and game.energy==2 and game.hand.size()==1,"Carta é consumida uma vez ao iniciar a animação")
 game.play(0)
 game.end_turn()
 check(game.round_number==1 and game.hand.size()==1 and game.energy==2,"Cliques repetidos e fim de turno são bloqueados durante a ação")
 await create_timer(0.25).timeout
 check(game.enemy==100 and game.hero_shield==0,"Carga inicial não aplica dano ou defesa prematuramente")
 await create_timer(0.95).timeout
 check(game.enemy==90 and game.busy,"Dano é aplicado no impacto e a recuperação ainda bloqueia ações")
 await wait_idle()
 check(game.presentation.action.is_empty(),"Animação termina antes de liberar a próxima carta")
 var reactions=game.presentation.history.filter(func(e): return e.get("reaction","")=="hurt")
 check(reactions.size()==1,"Um impacto produz uma reação de dano, sem duplicação")
 fresh()
 game.hand=["shield"]
 await game.play(0)
 check(game.hero_shield==12,"Escudo concede exatamente o valor da carta")
 await game.end_turn()
 check(game.hero==100 and game.hero_shield==0,"Escudo absorve o golpe inteiro e expira ao fim da reação inimiga")
 var blocks=game.presentation.history.filter(func(e): return e.get("reaction","")=="block")
 check(blocks.size()==1,"Bloqueio tem evento de defesa independente da perda de vida")
 fresh()
 game.hero_shield=5
 check(game.hit(false,12)==7 and game.hero==93,"Defesa parcial só deixa passar o dano excedente")
 game.hero=3
 check(game.hit(false,20)==3 and game.hero==0,"Dano exibido nunca ultrapassa a vida realmente removida")
 check(game.hit(true,-20)==0 and game.enemy==100,"Valor de ataque negativo não cura o alvo")
 fresh()
 game.hero_shield=20
 game.hit(false,12)
 check(game.hero==100 and game.hero_shield==8,"Defesa excedente permanece até o encerramento do turno")
 fresh(1.0)
 game.hand=["sword"]
 game.play(0)
 fresh(30.0)
 await create_timer(0.4).timeout
 check(game.hero==100 and game.enemy==100 and not game.busy,"Reiniciar a batalha cancela impactos pendentes da partida anterior")
 for id in game.cards:
  fresh()
  game.hero=70
  game.hand=[id]
  var c=game.cards[id]
  await game.play(0)
  check(game.enemy==100-int(c.get("damage",0)) and game.hero_shield==int(c.get("block",0)) and game.hero==mini(100,70+int(c.get("heal",0))),"Resolução completa de "+c.name)
  check(game.presentation.history.any(func(e): return e.event=="begin" and e.art==c.art),"Animação elemental de "+c.name)
 check(game.audio_engine.clip_for("shield")!=game.audio_engine.clip_for("ice"),"Defesa metálica e gelo usam gravações diferentes")
 check(game.audio_engine.clip_for("water")!=game.audio_engine.clip_for("heal"),"Água e cura usam gravações diferentes")
 check(game.audio_engine.clip_for("lightning")!=game.audio_engine.clip_for("storm"),"Raio e tempestade têm camadas sonoras distintas")
 check(game.audio_engine.music.stream.loop,"A trilha orquestral tem repetição ativada")
 print("RESULT: %d failures" % failures)
 quit(1 if failures else 0)
