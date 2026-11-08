# Verificação da masmorra mutável — 08/11/2026

As correções posteriores de apoio no chão, combate, portal e encaixe de muralhas estão em [mutable-actions](../mutable-actions/README.md).

Versão reconstruída a partir da `main` `9bb1635`. O commit histórico `0ce60bd` não estava disponível no GitHub nem num checkout anterior deste ambiente.

## Referência e resultado

A [imagem aprovada](../../../godot/mutable_assets/reference.jpg) é a referência principal desta versão. [Retrato 720 × 1280](portrait.png), [celular 390 × 844 com densidade 3](mobile.png) e [paisagem 844 × 390](landscape.png) foram capturados do jogo Godot exportado e executado no Chromium, sem montar telas estáticas.

A interface preserva os retratos, posição do relógio, núcleo vermelho acima/ciano abaixo, ponte esquerda, runa central, armadilha direita, habilidade, quatro cartas e barra de energia da referência. As molduras e cartas iniciais reutilizam regiões da arte aprovada. O cenário vazio e o atlas de peças foram gerados a partir dela para permitir combate independente, portanto o cenário reconstruído tem diferenças e não é idêntico pixel a pixel. O jogo cabe por inteiro em cada tela; margens preservam a composição em proporções diferentes.

Os números de vida, energia, tempo, mão e recarga são valores vivos da simulação. Posições das criaturas mudam conforme as jogadas; a cena da imagem de referência não foi fingida com personagens colados ao fundo.

## Validação executada

- Godot 4.4.1: importação e exportação Web sem erros de scripts.
- `tests/mutable_rules.gd`: 19 verificações, incluindo custo/rotação da mão, alvo inválido, combate, núcleo, portal, habilidade/recarga, transformação, armadilha e término de partida completa com IA.
- `tests/tavern_rules.gd`: 57 verificações, zero falhas.
- `tests/tavern_fx.gd`: 44 sequências de carta completas, zero falhas.
- `tests/tavern_browser.cjs`: partida clássica completa por gestos reais, feitiços, ataques, recompensa, salvamento após recarga e arraste por toque; zero erros de console/página.
- `tests/mutable_rooms.cjs`: dois clientes WebSocket reais, criação/código, sala inexistente/cheia, validação de lado, dados inválidos, snapshots iguais, desconexão e remoção de sala.
- `tests/mutable_browser.cjs`: gestos de mouse/toque reais, desktop, celular com densidade 3, rotação, ação inválida/válida, habilidade, pausa, ida/volta à taverna, dois navegadores em PvP e recompensa por desconexão. Zero erros de console ou página na execução aprovada.

Veja [jogador um](pvp-one.png) e [jogador dois](pvp-two.png). As capturas mostram a mesma partida vista de lados opostos, com o núcleo do próprio jogador sempre embaixo. O servidor roda o mesmo GDScript das regras de treino.

## Limites da entrega

Os testes PvP usaram um servidor local real. Não comprovam hospedagem pública nem passagem por proxy TLS. O Pages publica o cliente; o endereço WSS precisa de uma implantação separada, descrita em [server/README.md](../../../server/README.md). Sem esse endereço, o treino funciona e o menu de salas informa a necessidade do servidor.

A progressão é local: moedas, XP, vitórias/derrotas e contador de maestria. Todas as dez cartas estão disponíveis. A insígnia de liga representa vitórias locais; não existe ranking global, autenticação, matchmaking, temporada competitiva ou retomada de uma partida desconectada.
