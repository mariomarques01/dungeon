# Dungeon Cards
Jogo de cartas com interface e combate nativos em Godot 4.4.1, exportado para Web sem threads.

## Jogar
- Godot (endereço principal): https://mariomarques01.github.io/dungeon/
- Godot (link compatível): https://mariomarques01.github.io/dungeon/godot/
- Versão web original: https://mariomarques01.github.io/dungeon/classic/

## Recursos
24 habilidades, baralho editável de 12 cartas, mão de 5 cartas, 3 de mana por turno, escudos, cura, queimadura, congelamento, ressonância e tríade arcana. Cinco chefes com ações especiais, progressão, moedas e XP. Música, efeitos de combate, detalhes das cartas e personagens, controle de som e velocidade. O progresso e o deck da versão original são reaproveitados no mesmo navegador por meio da chave `dungeon_cards_v15`.

## Desenvolvimento
Importe `godot/project.godot` no Godot 4.4.1. As artes em `godot/assets` são rasterizações das artes originais de `web/assets`, preservando os filtros dos SVGs. As definições de cartas e chefes foram portadas de `web/game.js`. A interface e as regras rodam em GDScript; a página HTML apenas carrega o motor.

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script "$PWD/tests/godot_port.gd"
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

O teste cobre edição do deck, configurações, detalhes, uma batalha completa e persistência após recarga. `DUNGEON_URL` permite testar outro endereço; `CHROMIUM_PATH` permite selecionar o navegador. As capturas são salvas em `artifacts/browser`.
