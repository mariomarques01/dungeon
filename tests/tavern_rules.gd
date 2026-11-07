extends SceneTree
const Rules=preload('res://scripts/tavern_rules.gd')
var cards: Dictionary
var rules
var failed=0
var passed=0
func check(ok: bool,label: String) -> void:
 if ok:passed+=1;print('PASS: '+label)
 else:failed+=1;push_error(label)
func fresh() -> void:
 rules=Rules.new(cards);rules.start(Rules.DEFAULT_DECK,[],42);rules.events=[]
func ready(side: int,id: String):
 var unit=rules.spawn(side,id);unit.sleeping=false;unit.attacks=2 if 'windfury' in unit.keywords else 1;return unit
func _initialize() -> void:
 cards=JSON.parse_string(FileAccess.get_file_as_string('res://tavern_assets/cards.json'))
 fresh()
 check(cards.values().filter(func(c):return not c.get('token',false)).size()==41,'41 cartas colecionáveis')
 check(rules.valid_deck(Rules.DEFAULT_DECK),'Baralho inicial de 30 cartas válido')
 check(rules.players[0].mana==1 and rules.players[0].hand.size()==4,'Primeiro turno tem 1 mana e quatro cartas')
 rules.players[0].hand=['scout'];var result=rules.play(0,0)
 check(result.ok and rules.players[0].mana==0 and rules.players[0].hand.is_empty(),'Invocar consome mana e carta exatamente uma vez')
 var unit=rules.players[0].board[0]
 check(unit.attack==1 and unit.health==2 and unit.attacks==0,'Criatura entra com atributos e precisa esperar')
 check(not rules.can_attack(0,unit.uid,{'side':1,'hero':true}).ok,'Não ataca no turno de invocação')
 rules.end_turn();rules.end_turn()
 check(unit.attacks==1 and rules.players[0].max_mana==2,'Próximo turno renova criatura e aumenta mana')
 var hp=rules.players[1].health
 check(rules.attack(0,unit.uid,{'side':1,'hero':true}).ok and rules.players[1].health==hp-1,'Criatura ataca o herói escolhido')
 check(not rules.can_attack(0,unit.uid,{'side':1,'hero':true}).ok,'Criatura não repete ataque no mesmo turno')
 fresh();var a=ready(0,'wolf');var b=ready(1,'wolf')
 rules.attack(0,a.uid,{'side':1,'uid':b.uid})
 check(rules.players[0].board.is_empty() and rules.players[1].board.is_empty(),'Combate simultâneo remove as duas criaturas mortas')
 fresh();a=ready(0,'golem');b=ready(1,'beetle');var before=b.health
 rules.attack(0,a.uid,{'side':1,'uid':b.uid})
 check(not b.shield and b.health==before and a.health==4,'Escudo Divino evita dano e ainda há contra-ataque')
 fresh();a=ready(0,'orc');b=ready(1,'stoneguard');var other=ready(1,'scout')
 check(not rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok and not rules.can_attack(0,a.uid,{'side':1,'uid':other.uid}).ok,'Provocar protege o herói e as outras criaturas')
 check(rules.can_attack(0,a.uid,{'side':1,'uid':b.uid}).ok,'Provocar permite atacar o protetor')
 fresh();a=rules.spawn(0,'panther');b=ready(1,'orc')
 check(rules.can_attack(0,a.uid,{'side':1,'uid':b.uid}).ok and not rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok,'Investida permite atacar criaturas, mas não o herói')
 fresh();a=rules.spawn(0,'gryphon')
 check(rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok,'Ímpeto permite ataque imediato ao herói')
 fresh();a=ready(0,'familiar');rules.attack(0,a.uid,{'side':1,'hero':true});rules.attack(0,a.uid,{'side':1,'hero':true})
 check(rules.players[1].health==26 and not rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok,'Fúria dos Ventos concede exatamente dois ataques')
 fresh();a=ready(0,'serpent');b=ready(1,'golem');rules.attack(0,a.uid,{'side':1,'uid':b.uid})
 check(rules.find_unit(1,b.uid)==null,'Veneno destrói a criatura que sofreu dano')
 fresh();a=ready(0,'serpent');b=ready(1,'beetle');rules.attack(0,a.uid,{'side':1,'uid':b.uid})
 check(rules.find_unit(1,b.uid)!=null and not b.shield,'Escudo Divino impede o Veneno no primeiro golpe')
 fresh();a=ready(0,'phoenix');rules.players[0].health=20;rules.attack(0,a.uid,{'side':1,'hero':true})
 check(rules.players[0].health==25,'Roubo de Vida cura pelo dano realmente causado')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['fireball'];hp=rules.players[0].health
 result=rules.play(0,0,{'side':0,'hero':true})
 check(not result.ok and rules.players[0].mana==10 and rules.players[0].hand.size()==1 and rules.players[0].health==hp,'Alvo inválido não gasta carta ou mana')
 result=rules.play(0,0,{'side':1,'hero':true})
 check(result.ok and rules.players[1].health==24 and rules.players[0].mana==6,'Feitiço causa o dano e cobra seu custo')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['fireball'];ready(0,'apprentice');ready(0,'archmage');rules.play(0,0,{'side':1,'hero':true})
 check(rules.players[1].health==21,'Poder de feitiço soma os bônus das criaturas')
 fresh();rules.players[1].armor=4
 check(rules.damage({'side':1,'hero':true},6)==2 and rules.players[1].health==28 and rules.players[1].armor==0,'Armadura absorve o dano antes da vida')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['frost'];b=ready(1,'golem');rules.play(0,0,{'side':1,'uid':b.uid});rules.end_turn()
 check(b.attacks==0 and b.frozen_lock,'Congelamento impede o próximo turno de ataques')
 rules.end_turn();rules.end_turn()
 check(b.attacks==1 and not b.frozen_lock,'Criatura volta a atacar após descongelar')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['blessing'];a=ready(0,'wolf');rules.play(0,0,{'side':0,'uid':a.uid})
 check(a.attack==5 and a.health==4 and a.max_health==4,'Fortalecimento aumenta ataque, vida atual e máxima')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['meteor'];a=ready(0,'wolf');b=ready(1,'orc');other=ready(1,'beetle');rules.play(0,0)
 check(rules.find_unit(1,b.uid)==null and other.health==4 and not other.shield and a.health==2 and rules.players[1].health==30,'Dano em área atinge só criaturas inimigas e respeita escudos')
 fresh();a=ready(0,'necro');a.health=0;rules.resolve_deaths()
 check(rules.players[0].board.size()==2 and rules.players[0].board.all(func(u):return u.id=='token_skeleton'),'Último Suspiro invoca duas fichas após a morte')
 fresh();a=ready(0,'phoenix');rules.players[0].health=21;a.health=0;rules.resolve_deaths()
 check(rules.players[0].health==26,'Último Suspiro da Fênix restaura vida')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['scout']
 for i in range(7):ready(0,'scout')
 result=rules.play(0,0)
 check(not result.ok and rules.players[0].board.size()==7 and rules.players[0].mana==10,'Limite de sete criaturas não consome a carta rejeitada')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['pack']
 for i in range(6):ready(0,'scout')
 rules.play(0,0)
 check(rules.players[0].board.size()==7,'Invocação múltipla respeita os espaços disponíveis')
 fresh();rules.players[0].deck=[];rules.draw(0,3)
 check(rules.players[0].health==24 and rules.players[0].fatigue==3,'Fadiga cresce quando acaba o baralho')
 fresh();rules.players[0].hand=Rules.DEFAULT_DECK.slice(0,10);var deck_count=rules.players[0].deck.size();rules.events=[];rules.draw(0)
 check(rules.players[0].hand.size()==10 and rules.players[0].deck.size()==deck_count-1 and rules.events.any(func(e):return e.kind=='burn'),'Mão cheia queima a compra excedente')
 fresh();rules.players[0].mana=2;rules.power(0,{'side':1,'hero':true})
 check(rules.players[1].health==29 and not rules.can_power(0,{'side':1,'hero':true}).ok,'Poder heroico custa mana e só pode ser usado uma vez')
 fresh();rules.players[0].health=0;rules.players[1].health=0;rules.check_end()
 check(rules.done and rules.outcome=='draw','Morte simultânea dos heróis resulta em empate')
 fresh();rules.players[1].health=1;rules.players[0].mana=1;rules.players[0].hand=['bolt'];rules.play(0,0,{'side':1,'hero':true})
 check(rules.done and rules.outcome=='win','Dano letal encerra a partida')
 fresh();rules.end_turn();rules.players[1].mana=10
 var plan=rules.ai_play()
 check(not plan.is_empty() and rules.can_play(1,plan.index,plan.target).ok,'IA escolhe uma jogada legal com sua própria mana')
 # Exercise complete AI-driven duels to detect deadlocks, resource drift and invalid targets.
 for match_index in range(4):
  fresh();rules.start(Rules.DEFAULT_DECK,[],match_index*23+7)
  for action_count in range(450):
   if rules.done:break
   if rules.active==0:
    var played=false
    for index in range(rules.players[0].hand.size()):
     var c=cards[rules.players[0].hand[index]]
     var targets=rules.enemy_targets(0) if c.get('target','none').begins_with('enemy') else [{'side':0,'hero':true}] if c.get('target','none')=='friendly' else []
     if c.get('target','none')=='friendly_minion':
      for u in rules.players[0].board:targets.append({'side':0,'uid':u.uid})
     if c.get('target','none')=='none':targets=[{}]
     for target in targets:
      if rules.can_play(0,index,target).ok:rules.play(0,index,target);played=true;break
     if played:break
    if played:continue
    for u in rules.players[0].board.duplicate():
     for target in rules.enemy_targets(0):
      if rules.can_attack(0,u.uid,target).ok:rules.attack(0,u.uid,target);played=true;break
     if played:break
    if not played:rules.end_turn()
   else:
    plan=rules.ai_play()
    if not plan.is_empty():rules.play(1,plan.index,plan.target)
    else:
     plan=rules.ai_attack()
     if not plan.is_empty():rules.attack(1,plan.uid,plan.target)
     elif rules.can_power(1).ok:rules.power(1)
     else:rules.end_turn()
   check(rules.players.all(func(p):return p.mana>=0 and p.mana<=10 and p.board.size()<=7 and p.hand.size()<=10),'Recursos válidos na simulação %d' % match_index) if action_count%30==0 else false
  check(rules.done,'Duelo completo sem travamento %d' % match_index)
 print('RESULT: %d passed, %d failures' % [passed,failed]);quit(1 if failed else 0)
