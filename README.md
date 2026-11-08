# Dungeon — Masmorra Mutável

Duelo de invocadores em **Godot 4.4.1 / GDScript**, com arena vertical baseada na referência aprovada “Duelo arcano na masmorra mutável”. O modo anterior de taverna continua disponível no menu e permite retornar à masmorra.

- Jogar: https://mariomarques01.github.io/dungeon/
- Taverna diretamente: https://mariomarques01.github.io/dungeon/?mode=classic
- Implementação web histórica: https://mariomarques01.github.io/dungeon/classic/

## Duelo da masmorra

Partidas em tempo real de até quatro minutos. Escolha uma das quatro cartas na mão e toque no seu lado da arena, ou arraste a carta até lá. Cada carta gasta energia e é substituída pela próxima de um baralho circular de dez cartas. A energia regenera até dez, mais rápido no minuto final. Invocações marcham e lutam automaticamente; muralhas protegem, portais invocam duas ossadas e feitiços causam dano ou curam na área escolhida. O botão de fogo ativa a habilidade do invocador com recarga de 22 segundos.

A cada 30 segundos, a arena alterna entre rotas abertas, aceleração na rota esquerda e dano na rota direita. Destrua o núcleo rival; ao fim do tempo, vence o núcleo com mais vida. Empates são possíveis. O treino tem IA. Pausar interrompe somente o treino; abrir o menu online mantém a partida em andamento.

O cliente preserva a proporção 720 × 1280 inteira em telas móveis, desktop e ao girar o dispositivo; usa margens quando a tela tem outra proporção. Retratos, molduras e as quatro cartas iniciais usam a arte aprovada. O piso sem personagens e as peças independentes foram reconstruídos a partir da referência: os combatentes são objetos vivos e os valores do HUD refletem a simulação. A arte de fundo reconstruída não é uma reprodução pixel a pixel da referência.

Vitórias, derrotas, moedas, XP e contagem de invocações para maestria são salvos neste navegador, separados do perfil clássico. A coleção mostra todas as dez cartas e uma insígnia de liga baseada nas vitórias locais. Não há vantagem comprada, desbloqueios pagos, ranking global ou temporadas nesta versão.

## PvP disponível

Há salas privadas com código, servidor autoritativo em GDScript, sincronização e resultado por desconexão. **O cliente web publicado precisa de um servidor WSS acessível para jogar pela internet. Nenhum servidor público é fornecido pelo GitHub Pages.** O formulário de Salas solicita esse endereço e trata falhas de conexão. Consulte [server/README.md](server/README.md) para executar ou hospedar o servidor.

## Desenvolvimento e validação da masmorra

- `godot/scripts/mutable_rules.gd`: simulação compartilhada, sem interface ou rede.
- `godot/scripts/mutable_game.gd`: interface, entrada, treino, persistência e cliente WebSocket.
- `server/rooms.gd`: salas, validação das intenções, simulação e snapshots.
- `godot/mutable_assets/`: referência aprovada, cenário limpo e atlas de peças transparentes.
- `godot/scenes/tavern.tscn`: modo anterior preservado.

```sh
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script "$PWD/tests/mutable_rules.gd"
godot --headless --path godot --script "$PWD/tests/tavern_rules.gd"
godot --headless --path godot --script "$PWD/tests/tavern_fx.gd"
godot --headless --path godot --export-release Web ../web/godot/index.html
python3 -m http.server 8766 --directory web
# Em outro terminal, execute o servidor conforme server/README.md.
npm install --prefix /tmp/dungeon-browser playwright-core ws
NODE_PATH=/tmp/dungeon-browser/node_modules node tests/mutable_rooms.cjs
NODE_PATH=/tmp/dungeon-browser/node_modules node tests/mutable_browser.cjs
```

Os testes de navegador usam gestos reais e `?qa=1` para observar o estado sem injetar jogadas. Capturam desktop, retrato, celular com densidade 3 e paisagem; verificam invocação inválida/válida, habilidade, pausa, rotação, ida/volta ao clássico, dois navegadores em PvP e desconexão. O CI executa regras dos dois modos, efeitos clássicos, teste de salas com dois clientes e exportação antes do Pages.

## Histórico da recuperação

Em 08/11/2026, o GitHub tinha apenas `main` em `9bb1635`, sem PRs encontrados; a consulta ao commit `0ce60bd` retornou “No commit found”. Não havia checkout anterior em `/workspace`, `/tmp` ou `/home/agent` na busca inicial. A arena e as salas desta versão foram reconstruídas; testes alegados no histórico anterior não foram contabilizados.

---

# Modo clássico — Duelos da Taverna

Jogo de cartas tático em **Godot 4.4.1**, com criaturas no tabuleiro, feitiços com alvos e controles de arrastar com mouse ou toque.

- Jogo: https://mariomarques01.github.io/dungeon/
- Link compatível: https://mariomarques01.github.io/dungeon/godot/
- Implementação web original: https://mariomarques01.github.io/dungeon/classic/

## Como jogar

Arraste uma criatura da mão para o seu lado do tabuleiro. Arraste uma criatura pronta até um inimigo para atacar. Arraste um feitiço até seu alvo; feitiços sem alvo podem ser soltos sobre o tabuleiro. Jogadas inválidas devolvem a carta sem gastar mana. Segure uma carta ou criatura para ler seus detalhes.

Cada herói começa com 30 de vida. O baralho tem 30 cartas e o campo aceita até sete criaturas de cada lado. A mana começa em 1 e aumenta até 10. Criaturas normalmente aguardam o próximo turno para atacar. O botão de encerrar turno entrega a vez à IA, que usa sua própria mão e mana.

O conjunto tem **41 cartas colecionáveis**: 25 criaturas e 16 feitiços, além de três fichas de invocação. Há Provocar, Escudo Divino, Investida, Ímpeto, Fúria dos Ventos, Veneno, Roubo de Vida, efeitos ao entrar e efeitos ao morrer. Ataques entre criaturas causam dano simultâneo. Feitiços de alvo, dano em área, cura, armadura, congelamento, compra e fortalecimento têm regras próprias.

A coleção permite adicionar cartas, remover pelo contador e restaurar o baralho inicial. O limite é de duas cópias por carta e uma cópia por lendária. Todas as cartas estão disponíveis, sem compras.

## Visual e animações

Tabuleiro pintado de taverna, versões horizontal e vertical, cartas físicas com molduras e ilustrações próprias, retratos de criaturas no campo, setas de ataque, alvos válidos destacados, invocações, investidas, partículas elementais, efeitos de dano/cura, escudos e animações de morte. A mão é apresentada em leque; passar o mouse ou selecionar eleva a carta.

As referências de Hearthstone orientaram a composição e o gênero. As artes, nomes e regras do projeto são próprios. Não são usados assets, logos ou personagens dessa franquia.

## Progresso e áudio

Vitórias, derrotas, moedas, XP e baralho são salvos neste navegador. O novo perfil usa `dungeon_tavern_v3`; moedas e estatísticas do perfil anterior são importadas, mas o baralho é reconstruído porque o conjunto de cartas mudou.

Efeitos gravados por elemento e trilha orquestral em loop, com mute e controle de velocidade. Créditos em Configurações → Créditos de áudio e `godot/assets/v2/audio/CREDITS.txt`.

## Desenvolvimento

Importe `godot/project.godot` no Godot 4.4.1. O jogo ativo usa:

- `godot/scripts/tavern_rules.gd`: regras, recursos, combate e decisões da IA.
- `godot/scripts/tavern_game.gd`: entrada por mouse/toque, arraste, turnos e persistência.
- `godot/scripts/tavern_view.gd`: composição responsiva, cartas, tabuleiro e animações.
- `godot/tavern_assets/cards.json`: definições das cartas.
- `godot/tavern_assets`: ilustrações e molduras.

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script "$PWD/tests/tavern_rules.gd"
godot --headless --path godot --export-release Web ../web/godot/index.html
python3 -m http.server 8766 --directory web
```

As cenas e testes antigos permanecem como referência em `godot/scenes/legacy_v2.tscn`; não são a mecânica atual.

## Verificação no navegador

Com Chromium disponível:

```sh
npm install --prefix /tmp/dungeon-browser playwright-core
NODE_PATH=/tmp/dungeon-browser/node_modules node tests/tavern_browser.cjs
```

O teste joga por gestos reais: arraste inválido, invocação, espera da criatura, ataque entre criaturas, feitiços com alvo, partida completa, recompensa, persistência e arraste por toque no celular. `DUNGEON_URL`, `SCREENSHOT_DIR` e `CHROMIUM_PATH` podem ser definidos. `?qa=1` expõe um retrato somente de leitura do estado do motor para as verificações; não injeta jogadas.

O GitHub Actions executa os testes de regras e publica o Godot no Pages com pacotes exclusivos por tentativa e arquivos com versão, mantendo o endereço `/classic/` como referência.

As texturas usam compressão com qualidade 0,78. `scripts/optimize_web.py` separa o motor do pacote de cartas usando nomes derivados do conteúdo: atualizar o jogo não invalida o download do motor. Os arquivos grandes são guardados no Cache Storage quando disponível; a abertura continua normalmente se o navegador negar armazenamento. A primeira visita ainda precisa baixar e inicializar o motor WebAssembly.

`tests/loading_browser.cjs` verifica primeira abertura, reabertura sem downloads grandes, armazenamento indisponível e toques/arraste em uma tela móvel com densidade 3. O controle web por toque usa coordenadas relativas ao canvas para compensar resolução e posição da tela, incluindo cancelamento do gesto.

As animações em `godot/scripts/tavern_fx.gd` usam desenho vetorial com contornos suavizados, preservando nitidez em telas de alta densidade sem acrescentar atlas pesados. Cada feitiço tem sua sequência: meteoros em área, raios ramificados, nevasca, projéteis de gelo, mísseis, raízes, cura, bênção, lâmina, vórtice, invocação de lobos, compra e cristal de mana. Criaturas possuem entradas por família, avanço/recuo, reação ao dano e morte; escudos, bloqueios, armadura e congelamento têm efeitos próprios. O áudio de manuseio é uma gravação curta e discreta de papel, com eventos separados para invocação e impacto.

`godot --headless --path godot --script "$PWD/tests/tavern_fx.gd"` exercita as 44 sequências de carta com alvos legais e confirma que cada ação conclui e libera a interação. O teste do navegador também verifica o som de papel e a ausência do antigo som genérico de carga.

Ao escolher uma carta, a elevação é suave e o elemento aparece fora da moldura, incluindo uma manifestação acima dela. Ao arrastar, a carta mantém sua aura e deixa um rastro da mesma cor; criaturas exibem um círculo no ponto de chegada. A aura acompanha quem ataca e reaparece no defensor ao receber dano ou bloquear. Conjuradores permanecem em posição enquanto lançam o ataque; criaturas corpo a corpo avançam até o alvo. O teste das 44 cartas também exercita os ataques das criaturas.

O painel de resultado fica numa camada acima de todas as imagens e efeitos, com medalha e recompensas em espaços próprios. A rotação preserva o duelo, recalcula a proporção para preencher o canvas e mantém a mão visível no horizontal. Os controles laterais têm margem extra para telas com recorte.

Impactos ampliados iluminam o cenário e deixam reflexos/brasas, gelo nas bordas, raízes ou energia residual. Durante o combate, uma projeção da criatura ultrapassa a moldura. A derrota usa fragmentos do próprio retrato, com queima, estilhaçamento ou desintegração conforme o elemento recebido, incluindo o contra-ataque. O áudio diferencia golpes leves/pesados, mordidas, madeira, pedra, armadura e ruptura de escudo; ataques em área não empilham o mesmo som para cada alvo.
