extends SceneTree
var game
var failures = 0
func check(condition: bool, label: String) -> void:
 if not condition:
  failures+=1
  push_error(label)
 else: print("PASS: "+label)
func _initialize() -> void:
 call_deferred("run")
func fresh() -> void:
 game.profile={"deck":game.DEFAULT_DECK.duplicate(),"coins":0,"xp":0,"wins":0,"losses":0,"stage":0}
 game.start_battle()
 game.speed=20.0
 game.sound_on=false
 game.audio_engine.set_enabled(false)
func run() -> void:
 game=load("res://scenes/legacy_v2.tscn").instantiate()
 root.add_child(game)
 game.sound_on=false
 game.audio_engine.set_enabled(false)
 fresh()
 check(game.cards.size()==24 and game.stages.size()==5,"24 habilidades e 5 chefes")
 check(game.hand.size()==5 and game.deck.size()==7,"Baralho de 12 com compra de 5 cartas")
 game.hand=["sword"]
 game.enemy_shield=6
 await game.play(0)
 check(game.enemy==96 and game.enemy_shield==0 and game.energy==2,"Dano absorvido pelo escudo e consumo de mana")
 fresh()
 game.hand=["spark"]
 await game.play(0)
 check(game.energy==3 and game.hero_shield==8 and game.hand.is_empty(),"Carta gratuita é consumida e concede defesa")
 fresh()
 game.hand=["fire","sword"]
 await game.play(0)
 check(game.burn==2 and game.enemy==86,"Fogo aplica dano e queimadura")
 game.freeze=1
 await game.end_turn()
 check(game.hero==100 and game.enemy==83 and game.burn==1 and game.freeze==0,"Queimadura ocorre e gelo impede a ação inimiga")
 check(game.round_number==2 and game.energy==3 and game.hand.size()==5,"Fim do turno descarta mão e compra nova mão")
 fresh()
 game.hero=90
 game.hand=["water"]
 await game.play(0)
 check(game.hero==98 and game.hero_shield==4,"Maré aplica cura e defesa juntas")
 fresh()
 game.hand=["sword","sword"]
 await game.play(0)
 await game.play(0)
 check(game.enemy==76,"Ressonância de elementos aplica +4 dano")
 fresh()
 game.hand=["sword","spark","water"]
 await game.play(0)
 await game.play(0)
 await game.play(0)
 check(game.triad_used and game.triad_charge and game.energy==2,"Tríade distinta devolve mana e carrega próximo ataque")
 fresh()
 game.energy=0
 game.hand=["fire"]
 await game.play(0)
 check(game.enemy==100 and game.hand.size()==1,"Carta sem mana não pode ser jogada")
 game.deck=[]
 game.hand=[]
 game.discard=["sword","shield","fire","water","spark"]
 game.draw_hand()
 check(game.hand.size()==5 and game.discard.is_empty(),"Descarte é embaralhado quando acaba o deck")
 for i in range(5):
  game.profile.stage=i
  game.start_battle()
  game.round_number=3
  var expected=[16,23,19,21,23][i]
  check(game.boss_damage()==expected,"Dano especial do chefe %d" % (i+1))
  if i==3: check(game.boss_defends(),"Drakor usa defesa especial")
 fresh()
 game.enemy=1
 game.hand=["sword"]
 await game.play(0)
 check(game.done and game.outcome=="win" and game.profile.stage==1,"Vitória desbloqueia próxima fase")
 check(game.profile.coins==50 and game.profile.xp==35 and game.profile.wins==1,"Recompensas são concedidas uma vez")
 game.finish("win")
 check(game.profile.coins==50,"Resultado repetido não duplica recompensa")
 game.profile.stage=4
 game.start_battle()
 game.finish("win")
 check(game.profile.stage==4,"Último chefe mantém progresso válido")
 fresh()
 game.round_number=10
 game.hero=100
 game.enemy=99
 game.freeze=1
 game.speed=20.0
 await game.end_turn()
 check(game.done and game.outcome=="win","Limite de 10 rodadas compara vida restante")
 print("RESULT: %d failures" % failures)
 quit(1 if failures else 0)
