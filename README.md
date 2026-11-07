# Dungeon Cards
Jogo de cartas com interface e combate nativos em Godot 4.4.1, exportado para Web sem threads.

## Jogar
- Godot (endereço principal): https://mariomarques01.github.io/dungeon/
- Godot (link compatível, redireciona ao endereço principal): https://mariomarques01.github.io/dungeon/godot/
- Versão web original: https://mariomarques01.github.io/dungeon/classic/

## Layout e combate da versão 2
Arena de masmorra em roxo e fogo, personagens pintados com quatro poses, retratos novos e cartas ilustradas conforme a referência enviada. Ao jogar, a carta transfere poder ao personagem; a conjuração, o golpe ou a defesa, o impacto e a recuperação acontecem em etapas sincronizadas. A vida e o escudo só mudam no ponto de impacto. Cliques repetidos e encerramento de turno ficam bloqueados durante a ação.

Os efeitos de espada, armadura, escudo, fogo, gelo, trovão, tempestade, terra, água e cura usam gravações distintas. A trilha orquestral **Dark Descent**, de Matthew Pablo, toca em loop com redução de volume durante os efeitos. Créditos e licenças estão disponíveis em Configurações → Créditos de áudio e em `godot/assets/v2/audio/CREDITS.txt`.

## Recursos
24 habilidades, baralho editável de 12 cartas, mão de 5 cartas, 3 de mana por turno, escudos, cura, queimadura, congelamento, ressonância e tríade arcana. Cinco chefes com ações especiais, progressão, moedas e XP. Música, efeitos de combate, detalhes das cartas e personagens, controle de som e velocidade. O progresso e o deck da versão original são reaproveitados no mesmo navegador por meio da chave `dungeon_cards_v15`.

## Desenvolvimento
Importe `godot/project.godot` no Godot 4.4.1. As novas artes de arena, personagens e cartas estão em `godot/assets/v2`, geradas para este projeto a partir da referência visual. A interface mantém suporte a toque e janelas de tamanhos diferentes. As definições de cartas e chefes foram portadas de `web/game.js`. A interface e as regras rodam em GDScript; a página HTML apenas carrega o motor.

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script "$PWD/tests/godot_port.gd"
godot --headless --path godot --script "$PWD/tests/godot_v2.gd"
godot --headless --path godot --export-release Web ../web/godot/index.html
python3 -m http.server 8765 --directory web
```

O GitHub Actions testa o combate, exporta o Godot e publica as versões no Pages. A pasta `web` mantém a implementação original e pode ser hospedada separadamente.

As fontes Noto e DejaVu têm suas licenças incluídas em `godot/assets`.

## Teste no navegador
Com Chromium instalado e um servidor local na porta 8765:

```sh
npm install --prefix /tmp/dungeon-browser playwright-core
NODE_PATH=/tmp/dungeon-browser/node_modules node tests/godot_browser.cjs
```

O teste cobre edição do deck, configurações, animação de atribuição, momento de impacto, bloqueio de cliques repetidos, defesa, reprodução e mute da música, uma batalha completa e persistência após recarga. Usa uma consulta `?qa=1` somente de leitura para inspecionar o estado real do motor; essa consulta não altera as regras. `DUNGEON_URL` permite testar outro endereço; `CHROMIUM_PATH` permite selecionar o navegador. As capturas são salvas em `artifacts/browser`.

A publicação usa um nome de pacote exclusivo por tentativa e compartilha os arquivos do motor pelo endereço principal, evitando duplicações ao reexecutar o deploy.
