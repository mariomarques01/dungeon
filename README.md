# Dungeon Cards — Duelos da Taverna

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
