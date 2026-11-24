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
 return rules.spawn(side,id)
func _initialize() -> void:
 cards=JSON.parse_string(FileAccess.get_file_as_string('res://tavern_assets/cards.json'))
 fresh()
 check(cards.values().filter(func(c):return not c.get('token',false)).size()==47,'47 cartas colecionáveis')
 check(rules.valid_deck(Rules.DEFAULT_DECK),'Baralho inicial de 30 cartas válido')
 check(rules.players[0].mana==1 and rules.players[0].hand.size()==4,'Primeiro turno tem 1 mana e quatro cartas')
 rules.players[0].hand=['scout'];var result=rules.play(0,0)
 check(result.ok and rules.players[0].mana==0 and rules.players[0].hand.is_empty(),'Invocar consome mana e carta exatamente uma vez')
 var unit=rules.players[0].board[0]
 check(unit.attack==1 and unit.health==2 and unit.attacks==1 and unit.delay==0 and not unit.sleeping,'Criatura entra pronta e sem recarga')
 check(rules.can_attack(0,unit.uid,{'side':1,'hero':true}).ok,'Herói pode ser atacado imediatamente após a invocação')
 rules.end_turn();rules.end_turn()
 check(unit.attacks==1 and rules.players[0].mana==0,'Próximo turno renova criatura e preserva energia gasta')
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
 check(rules.can_attack(0,a.uid,{'side':1,'uid':b.uid}).ok and rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok,'Pantera entra pronta para atacar qualquer inimigo legal')
 fresh();a=rules.spawn(0,'gryphon')
 check(rules.can_attack(0,a.uid,{'side':1,'hero':true}).ok,'Grifo entra pronto para atacar o herói')
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
 for i in range(5):ready(0,'scout')
 result=rules.play(0,0)
 check(not result.ok and rules.players[0].board.size()==5 and rules.players[0].mana==10,'Limite de cinco criaturas não consome a carta rejeitada')
 fresh();rules.players[0].mana=10;rules.players[0].hand=['pack']
 for i in range(4):ready(0,'scout')
 rules.play(0,0)
 check(rules.players[0].board.size()==5,'Invocação múltipla respeita os espaços disponíveis')
 fresh();rules.players[0].deck=[];rules.draw(0,3)
 check(rules.players[0].health==24 and rules.players[0].fatigue==3,'Fadiga cresce quando acaba o baralho')
 fresh();rules.players[0].hand=Rules.DEFAULT_DECK.slice(0,5);var deck_count=rules.players[0].deck.size();rules.events=[];rules.draw(0)
 check(rules.players[0].hand.size()==5 and rules.players[0].deck.size()==deck_count-1 and rules.events.any(func(e):return e.kind=='burn'),'Mão cheia queima a compra excedente')
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
   rules.advance_cooldowns(0.25)
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
   check(rules.players.all(func(p):return p.mana>=0 and p.mana<=10 and p.board.size()<=5 and p.hand.size()<=5),'Recursos válidos na simulação %d' % match_index) if action_count%30==0 else false
  check(rules.done,'Duelo completo sem travamento %d' % match_index)
 fresh()
 rules.players[0].hand=['scout','fireball']
 check(not rules.equip_support(1,1).ok and rules.players[0].hand.size()==2,'Energia insuficiente preserva a mão')
 check(rules.equip_support(0,0).ok and rules.players[0].mana==0,'Equipar cobra energia uma vez')
 rules.players[0].mana=4
 check(rules.equip_support(1,0).ok and rules.players[0].hand.is_empty(),'Dois apoios independentes aceitam criatura e feitiço')
 rules.end_turn()
 check(rules.players[1].health==29 and rules.players[0].armor==2,'Ataque e defesa dos apoios antes da ação rival')
 rules.players[1].hand=['scout','fireball'];rules.players[1].mana=5
 ready(1,'wolf')
 rules.choose_rival_support()
 check(rules.players[1].supports.all(func(s):return s.id!='') and rules.players[1].mana==0,'A IA equipa os dois apoios com cartas e energia próprias')
 var armor_before=rules.players[0].armor
 rules.end_turn()
 check(rules.players[0].armor==armor_before-2 and rules.players[1].armor==1,'Os apoios rivais atacam e defendem o lado correto')
 fresh()
 rules.players[0].mana=9
 check(not rules.solar_flare().ok and rules.players[0].mana==9,'Especial bloqueado antes da carga completa')
 rules.players[0].mana=10
 check(rules.solar_flare().ok and rules.players[1].health==24 and rules.players[0].armor==4,'Erupção Solar causa dano e concede armadura')
 check(rules.players[0].mana==0 and not rules.solar_flare().ok,'Especial consome a carga uma única vez')
 rules.start(Rules.DEFAULT_DECK,[],37,true)
 for side in range(2):
  rules.players[side].mana=10
  rules.players[side].hand=['scout','scout']
 check(rules.play(1,0).ok and rules.play(0,0).ok,'Ambos jogam sem alternar turnos')
 check(rules.players[0].hand.size()==2 and rules.can_play(0,1).ok,'A mão permanece e cópias recarregam separadamente')
 check(not rules.equip_support(0,0).ok and rules.equip_support(0,1).ok,'Apoio respeita e inicia recarga')
 rules.advance_cooldowns(4.9)
 check(not rules.can_play(0,0).ok,'Carta indisponível antes de cinco segundos')
 rules.advance_cooldowns(0.11)
 check(rules.can_play(0,0).ok and rules.players[1].board[0].attacks==1,'Carta e criatura prontas após cinco segundos')
 var player=rules.players[0]
 player.hand=['wolf','scout'];player.deck=['orc','dragon'];player.mana=1
 player.cooldowns[1]=3.0
 check(not rules.exchange_card(0,1).ok and player.mana==1,'Recarga bloqueia troca sem cobrar energia')
 check(rules.exchange_card(0,0).ok and player.hand==['dragon','scout'] and player.deck==['wolf','orc'] and player.cooldowns[1]==3.0,'Troca preserva as posições e coloca a carta no fundo')
 check(not rules.exchange_card(0,0).ok and player.deck==['wolf','orc'] and player.mana==0,'Troca sem energia preserva o baralho')
 fresh()
 var cast_preview={'kind':'card','index':0}
 var enemy_hero={'side':1,'hero':true}
 rules.players[0].mana=10
 rules.players[0].hand=['fireball']
 rules.players[1].armor=2
 var expected=mini(30,int(cards.fireball.amount)-2)
 check(rules.health_preview(0,cast_preview,enemy_hero)=='−2 ARM · −%d PV'%expected,'Preview separa armadura e dano real')
 check(rules.players[0].mana==10 and rules.players[1].health==30 and rules.events.is_empty(),'Preview não resolve a ação')
 var guard=ready(1,'beetle')
 check(rules.health_preview(0,cast_preview,{'side':1,'uid':guard.uid})=='ESCUDO' and guard.shield,'Preview preserva escudo')
 rules.players[0].hand=['healing']
 rules.players[0].health=29
 check(rules.health_preview(0,cast_preview,{'side':0,'hero':true})=='+1','Preview limita a cura à vida faltante')
 check(rules.health_preview(0,cast_preview,enemy_hero)=='','Alvo inválido não mostra cura')
 fresh()
 rules.players[0].cooldowns[0]=0.25
 rules.players[0].power_delay=0.25
 check(not rules.advance_cooldowns(0.1) and rules.advance_cooldowns(0.15) and not rules.advance_cooldowns(1),'Recargas simultâneas produzem um único aviso de prontidão')
 rules.players[1].cooldowns[0]=0.1
 check(not rules.advance_cooldowns(1),'Recarga rival não produz ping do jogador')
 test_attack_readiness()
 test_ai_levels()
 test_next_card_and_costs()
 test_elements()
 test_traps()
 test_families()
 print('RESULT: %d passed, %d failures' % [passed,failed]);quit(1 if failed else 0)

func test_attack_readiness() -> void:
 rules.start(Rules.DEFAULT_DECK,[],42,true)
 var attacker=rules.spawn(0,'scout')
 var hero={'side':1,'hero':true}
 check(Rules.ENTRY_LOCK_SECONDS==0 and attacker.entry_lock==0 and attacker.delay==0,'Criatura começa sem bloqueio nem recarga')
 check(rules.attack(0,attacker.uid,hero).ok and attacker.delay==Rules.REUSE_SECONDS,'Ataque imediato ao herói inicia recarga')
 rules.advance_cooldowns(4.9)
 check(not rules.can_attack(0,attacker.uid,hero).ok,'Ataque segue indisponível durante a recarga')
 rules.advance_cooldowns(0.11)
 check(rules.can_attack(0,attacker.uid,hero).ok,'Fim da recarga libera novo ataque')
 var familiar=rules.spawn(0,'familiar')
 var enemy=rules.spawn(1,'scout')
 var creature={'side':1,'uid':enemy.uid}
 check(familiar.attacks==2 and familiar.delay==0 and rules.attack(0,familiar.uid,creature).ok,'Fúria dos Ventos entra com dois ataques e pode atacar outra criatura imediatamente')
 check(familiar.attacks==1 and familiar.delay==0,'Primeiro ataque de Fúria dos Ventos preserva o segundo sem recarga')
 var second_enemy=rules.spawn(1,'scout')
 check(rules.attack(0,familiar.uid,{'side':1,'uid':second_enemy.uid}).ok and familiar.delay==Rules.REUSE_SECONDS,'Último ataque inicia a recarga')
 var recruit=rules.spawn(0,'stoneguard')
 rules.freeze_unit(0,recruit.uid)
 check(recruit.delay>0 and recruit.attacks==0,'Congelamento continua impedindo ações')
 rules.advance_cooldowns(Rules.REUSE_SECONDS)
 check(recruit.delay==0 and recruit.attacks==1 and recruit.frozen==0,'Fim do congelamento libera ataque')

 rules.start(Rules.DEFAULT_DECK,[],42,true)
 var rival=rules.spawn(1,'scout')
 var plan=rules.ai_attack()
 check(plan.get('uid',-1)==rival.uid and plan.get('target',{}).get('hero',false),'IA pode atacar o herói com uma criatura recém-invocada')

func test_ai_levels() -> void:
 for level in range(Rules.AI_LEVELS.size()):
  fresh()
  rules.ai_level=level
  var deck: Array=rules.rival_deck()
  var trap_count=deck.filter(func(id):return cards[id].kind=='trap').size()
  check(rules.valid_deck(deck) and trap_count==level*2,'Baralho válido e quantidade de armadilhas esperada no nível %d'%level)
  rules.start(Rules.DEFAULT_DECK,deck,42,true)
  var ally=rules.spawn(0,'scout')
  rules.spawn(1,'wolf')
  var target: Dictionary=rules.ai_attack().target
  check(target.get('hero',false) if level==2 else target.get('uid',-1)==ally.uid,'Agressividade muda o alvo no nível %d'%level)
  ally.health=10
  var pressure_target: Dictionary=rules.ai_attack().target
  check(pressure_target.get('hero',false)==(level>0),'Níveis mais agressivos evitam uma troca sem abate')
  rules.players[0].health=1
  check(rules.ai_attack().target.get('hero',false),'IA reconhece ataque letal no nível %d'%level)
  var rival=rules.players[1]
  rival.hand=['trap_spring','trap_spikes','trap_embers']
  rival.mana=10
  rules.choose_rival_support()
  var armed=rival.supports.filter(func(slot):return slot.trap!='')
  check(armed.size()==level,'IA respeita o limite de armadilhas no nível %d'%level)
  if level>0:check(armed[0].trap=='trap_spikes','IA avalia o gatilho ao escolher qual armadilha armar')
  rules.choose_rival_support()
  check(rival.supports.filter(func(slot):return slot.trap!='').size()==level,'Nova decisão respeita armadilhas já armadas no nível %d'%level)

func test_next_card_and_costs() -> void:
 fresh()
 var player=rules.players[0]
 player.deck=['orc','wolf']
 var previous: Array=player.deck.duplicate()
 check(rules.next_card(0)=='wolf' and player.deck==previous,'Prévia lê o topo sem alterar o baralho')
 rules.draw(0)
 check(player.hand.back()=='wolf' and rules.next_card(0)=='orc','Prévia acompanha a ordem de compra')
 player.deck.clear()
 check(rules.next_card(0)=='','Baralho vazio limpa a prévia')
 player.hand=['wolf']
 player.mana=2
 check(not rules.can_play(0,0).ok,'Lobo custa mais energia após o rebalanceamento')
 player.mana=3
 check(rules.play(0,0).ok and player.mana==0,'Lobo custa exatamente 3')
 player.hand=['barrier']
 player.mana=1
 check(rules.play(0,0).ok and player.mana==0,'Barreira custa exatamente 1')

func test_elements() -> void:
 fresh()
 var ice=ready(1,'frostling')
 var storm=ready(1,'gryphon')
 var steel=ready(1,'orc')
 var targets=[{'side':1,'uid':ice.uid},{'side':1,'uid':storm.uid},{'side':1,'uid':steel.uid}]
 check(rules.elemental_modifier(targets[0],'fire')==1 and rules.elemental_modifier(targets[1],'ice')==1 and rules.elemental_modifier(targets[2],'lightning')==1,'Fogo vence gelo, gelo vence tempestade e raio vence aço')
 check(rules.elemental_modifier(targets[1],'steel')==-1 and rules.elemental_modifier(targets[0],'storm')==-1 and rules.elemental_modifier(targets[2],'fire')==0,'O inverso perde 1 e pares sem relação são neutros')
 rules.players[0].mana=10
 rules.players[0].hand=['frost']
 var fire=ready(1,'drake')
 var fire_target={'side':1,'uid':fire.uid}
 var preview=rules.health_preview(0,{'kind':'card','index':0},fire_target)
 var cast=rules.play(0,0,fire_target)
 check(preview=='−1 ▼' and fire.health==2 and cast.events.any(func(e):return e.kind=='damage' and e.modifier==-1),'Prévia, evento e dano de feitiço registram a fraqueza')
 rules.events=[]
 storm.shield=true
 check(rules.damage(targets[1],1,'steel',true)==0 and storm.shield and storm.health==4 and rules.events[-1].kind=='element_resist','Resistência total preserva escudo e impede veneno')
 check(rules.damage(targets[1],0,'ice')==0 and storm.shield,'Vantagem mantém um golpe de base zero em zero')
 check(rules.damage(targets[1],1,'ice')==0 and not storm.shield,'Escudo absorve dano com vantagem')
 check(rules.damage({'side':1,'hero':true},2,'lightning')==2,'Heróis são neutros')
 fresh()
 var attacker=ready(0,'drake')
 ice=ready(1,'frostling')
 var fight=rules.attack(0,attacker.uid,{'side':1,'uid':ice.uid})
 var hits=fight.events.filter(func(e):return e.kind=='damage')
 check(ice.health==1 and attacker.health==1 and hits.map(func(e):return e.modifier)==[1,-1],'Ataque e contra-ataque aplicam o elemento separadamente')

func test_traps() -> void:
 fresh()
 var deck=Rules.DEFAULT_DECK.duplicate()
 deck[0]='trap_bulwark'
 check(rules.valid_deck(deck) and cards.values().filter(func(c):return c.kind=='trap').size()==6,'As seis armadilhas são colecionáveis e aceitas em baralhos')
 var player=rules.players[0]
 player.hand=['scout','trap_bulwark','trap_spikes'];player.mana=10
 check(not rules.play(0,1).ok and player.mana==10,'Armadilha exige uma casa de apoio')
 check(rules.equip_support(0,0).ok and rules.equip_support(0,0).ok and player.supports[0].id=='scout' and player.supports[0].trap=='trap_bulwark','Apoio regular e armadilha ocupam a mesma casa')
 check(not rules.equip_support(0,0).ok and player.mana==7 and player.hand==['trap_spikes'],'Armadilha ocupada bloqueia a segunda sem custo')
 rules.end_turn()
 check(player.supports[0].trap=='trap_bulwark' and rules.players[1].health==29,'Pulso do apoio não dispara nem remove sua armadilha')
 var attacker=ready(1,'wolf')
 var hero={'side':0,'hero':true}
 var result=rules.attack(1,attacker.uid,hero)
 check(result.events[0].kind=='trap_reveal' and player.health==30 and player.armor==0 and player.supports[0].trap=='','Baluarte revela antes do ataque, protege e é descartado')
 attacker=ready(1,'scout')
 result=rules.attack(1,attacker.uid,hero)
 check(player.health==29 and not result.events.any(func(e):return e.kind=='trap_reveal'),'Armadilha disparada não se repete')

 rules.start(Rules.DEFAULT_DECK,[],42,true)
 player=rules.players[0]
 player.mana=10;player.hand=['trap_spikes','trap_runes','trap_spring','trap_embers','trap_last_stand']
 var rival=rules.players[1]
 rival.mana=10;rival.hand=['scout','fireball','crystal']
 check(rules.equip_support(0,0).ok and player.hand.size()==5 and player.cooldowns.has(0),'Armar em tempo real inicia a recarga')
 var ally=ready(0,'wolf')
 attacker=ready(1,'scout')
 result=rules.attack(1,attacker.uid,{'side':0,'uid':ally.uid})
 check(result.events[0].id=='trap_spikes' and ally.health==2 and rules.find_unit(1,attacker.uid)==null,'Espinhos também protegem criaturas e cancelam o ataque letal ao agressor')
 rules.equip_support(0,1)
 rules.equip_support(1,2)
 player.health=20
 check(not rules.play(1,1,{'side':1,'hero':true}).ok and player.supports[0].trap=='trap_runes','Feitiço inválido não revela armadilha')
 rules.play(1,0)
 check(player.supports[1].trap=='trap_spring','Invocar criatura não dispara armadilha de feitiço')
 result=rules.play(1,1,hero)
 var reveals=result.events.filter(func(e):return e.kind=='trap_reveal')
 check(reveals.map(func(e):return e.id)==['trap_runes','trap_spring'] and player.health==19 and player.armor==0,'Armadilhas de feitiço resolvem em ordem antes dos efeitos do feitiço')
 rules.equip_support(0,3)
 rules.equip_support(1,4)
 player.health=11
 rules.damage(hero,1)
 check(player.supports[0].trap=='trap_embers','Atingir exatamente o limite não dispara armadilha de vida')
 rules.damage(hero,5)
 check(player.health==9 and player.armor==5 and player.supports.all(func(s):return s.trap==''),'Cruzar ambos os limites no mesmo golpe resolve cura e armadura')
 rules.advance_cooldowns(5)
 player.mana=10
 rules.equip_support(0,3)
 player.health=5
 rules.damage(hero,6)
 check(player.health==4 and player.supports[0].trap=='trap_embers','Armar abaixo do limite aguarda um novo cruzamento')
 player.health=10
 rules.damage(hero,10)
 check(player.health==0 and player.supports[0].trap=='trap_embers','Dano letal não é revertido pela armadilha de vida')
 fresh()
 rules.end_turn()
 rules.players[1].hand=['trap_bulwark','trap_spring']
 rules.players[1].mana=5
 ready(1,'wolf')
 rules.choose_rival_support(func(side,index):return side==1 and index==0)
 check(rules.players[1].supports[0].trap=='trap_spring' and rules.players[1].hand==['trap_bulwark'],'Rival arma cartas disponíveis e respeita ações pendentes')

func test_families() -> void:
 fresh()
 var wolf=ready(0,'wolf')
 var opposing_wolf=ready(1,'wolf')
 check(rules.effective_attack(0,wolf)==3 and rules.effective_attack(1,opposing_wolf)==3,'Um membro em cada lado não forma família')
 var token=ready(0,'token_wolf')
 ready(0,'wolf')
 check(rules.effective_attack(0,wolf)==4 and rules.family_bonus(0,token)==1 and wolf.attack==3,'Fichas contam e três aliados não acumulam o bônus')
 var target={'side':1,'hero':true}
 check(rules.health_preview(0,{'kind':'unit','uid':wolf.uid},target)=='−4','Prévia usa o ataque de família')
 rules.attack(0,wolf.uid,target)
 check(rules.players[1].health==26,'Ataque usa o bônus de família')
 for ally in rules.players[0].board:
  if ally.uid!=wolf.uid:ally.health=0
 check(rules.family_bonus(0,wolf)==0,'Aliados sem vida deixam de contar imediatamente')
 rules.resolve_deaths()
 check(rules.effective_attack(0,wolf)==3,'Remoção dos aliados restaura o ataque base')
 fresh()
 var scout=ready(0,'stoneguard')
 var skeleton=ready(1,'skeleton')
 var necro=ready(1,'necro')
 rules.attack(0,scout.uid,{'side':1,'uid':skeleton.uid})
 check(scout.health==3-int(cards.skeleton.attack)-1,'Contra-ataque usa a sinergia de mortos-vivos')
 necro.health=0
 rules.resolve_deaths()
 check(rules.players[1].board.filter(func(u):return u.id=='token_skeleton' and rules.family_bonus(1,u)==1).size()==2,'Esqueletos de Último Suspiro ativam a família')
 fresh()
 var drake=ready(0,'drake')
 var wyrm=ready(0,'wyrm')
 check(rules.family_bonus(0,drake)==1 and rules.family_bonus(0,wyrm)==1,'Criaturas diferentes da família Dragões compartilham o bônus')
