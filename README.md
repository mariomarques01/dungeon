# Dungeon Cards
Protótipo híbrido de jogo de cartas para Safari e Godot 4.

## Jogar no navegador
Abra `web/index.html` em um servidor estático. Para testar no iPhone, publique a pasta `web` em um serviço de hospedagem estática (por exemplo, Vercel).

## Godot
A versão Godot é exportada automaticamente pelo GitHub Actions e publicada em https://mariomarques01.github.io/dungeon/godot/. Também pode ser aberta pelo botão “JOGAR PROTÓTIPO GODOT” na tela inicial. É o protótipo textual, com visual e recursos diferentes da versão web. A exportação usa Godot 4.4.1 sem threads, dispensando cabeçalhos especiais no GitHub Pages.

Importe `godot/project.godot` no Godot 4. O protótipo Godot possui uma batalha textual funcional com botões.

## Regras do protótipo
100 HP, 3 energias por turno, 5 cartas na mão, 12 cartas no deck. O adversário é IA local, não jogador online. Sem ranking ou compras nesta fase.
