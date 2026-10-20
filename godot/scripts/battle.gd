extends Control

const CARDS = [
 {"name":"Espada","cost":1,"damage":10,"block":0},
 {"name":"Fogo","cost":2,"damage":14,"block":0},
 {"name":"Escudo","cost":1,"damage":0,"block":12},
 {"name":"Raio","cost":2,"damage":16,"block":0},
 {"name":"Faisca","cost":0,"damage":4,"block":0}
]
var hero_hp := 100
var enemy_hp := 100
var energy := 3
var shield := 0
var round_number := 1
var finished := false

func _ready() -> void:
 $Layout/EndTurn.pressed.connect(end_turn)
 $Layout/Restart.pressed.connect(restart)
 restart()

func restart() -> void:
 hero_hp = 100
 enemy_hp = 100
 energy = 3
 shield = 0
 round_number = 1
 finished = false
 $Layout/Log.text = "Sua vez!"
 render()

func render() -> void:
 $Layout/Status.text = "Goblin: %d HP | Heroi: %d HP | Escudo: %d | Energia: %d | Rodada: %d" % [enemy_hp,hero_hp,shield,energy,round_number]
 for child in $Layout/Cards.get_children():
  child.queue_free()
 for i in range(CARDS.size()):
  var card = CARDS[i]
  var button := Button.new()
  button.text = "%s | %d energia | %d dano | %d escudo" % [card.name,card.cost,card.damage,card.block]
  button.disabled = finished or card.cost > energy
  button.pressed.connect(play.bind(i))
  $Layout/Cards.add_child(button)
 $Layout/EndTurn.disabled = finished

func play(i:int) -> void:
 if finished:
  return
 var card = CARDS[i]
 if energy < card.cost:
  return
 energy -= card.cost
 enemy_hp = max(0,enemy_hp-card.damage)
 shield += card.block
 $Layout/Log.text = "Voce usou %s!" % card.name
 if enemy_hp == 0:
  finished = true
  $Layout/Log.text = "VITORIA!"
 render()

func end_turn() -> void:
 if finished:
  return
 var damage:int = max(0,12-shield)
 hero_hp = max(0,hero_hp-damage)
 shield = 0
 energy = 3
 round_number += 1
 $Layout/Log.text = "Goblin causou %d de dano." % damage
 if hero_hp == 0:
  finished = true
  $Layout/Log.text = "DERROTA!"
 elif round_number > 10:
  finished = true
  $Layout/Log.text = "VITORIA!" if hero_hp > enemy_hp else "DERROTA!"
 render()
