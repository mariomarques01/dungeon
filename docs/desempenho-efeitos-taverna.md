# Desempenho dos efeitos da taverna

## FPS antes e depois

Exports Web produzidos com Godot 4.4.1. A base é o commit `81be183`. O roteiro `tests/tavern_performance.cjs` abriu `?qa=1&seed=69`, iniciou uma partida por toque, fez a primeira invocação e registrou cerca de 12 s de intervalos de `requestAnimationFrame` após 1,5 s de espera. O ambiente foi Chromium 156 headless no Linux, com SwiftShader, viewport 390 × 844, DPR 1 e limitação de CPU de 4×. Cada execução abriu um navegador novo.

| Ambiente e versão | Execução | FPS médio | Menor FPS em janela de 1 s | Intervalo p95 |
| --- | ---: | ---: | ---: | ---: |
| Chromium · antes | 1 | 6,05 | 4,17 | 266,7 ms |
| Chromium · antes | 2 | 6,06 | 3,64 | 300,0 ms |
| Chromium · antes | 3 | 5,48 | 2,40 | 316,6 ms |
| Chromium · depois | 1 | 6,30 | 3,53 | 300,0 ms |
| Chromium · depois | 2 | 6,10 | 2,82 | 366,6 ms |
| Chromium · depois | 3 | 6,22 | 3,81 | 283,3 |
| Safari no iPhone · antes/depois | — | Pendente | Pendente | Pendente |

A mediana dos FPS médios foi de 6,05 para 6,22 (+2,8%). O p95 mediano passou de 300,0 ms para 300,0 ms, e o FPS mínimo mediano por janela caiu de 3,64 para 3,53. As amostras são curtas e variáveis.

O roteiro mede a cadência de callbacks do navegador. O contador visível de `?qa=1` mede chamadas de `_process` no Godot. O modo QA também publica um retrato JSON do jogo a cada frame nas duas versões, com custo próprio. A sequência cobre a partida após a invocação e pode incluir ações do rival. Uma sequência com arraste e feitiços simultâneos oferece uma carga diferente.

Para preencher a linha do iPhone, sirva os exports em URLs distintas, abra as duas com `?qa=1&seed=69` no mesmo iPhone e repita a sequência em retrato com a mesma orientação, velocidade e configuração de movimento. Registre modelo, versão do iOS, escala da tela e estado do modo de pouca energia. Use o contador QA para acompanhar o jogo e os intervalos de `requestAnimationFrame` para calcular as três métricas da tabela com o mesmo critério do roteiro.

## Cinco maiores custos de CPU observados

Perfil separado de uma cópia instrumentada da base `81be183`, no mesmo Chromium e com o mesmo roteiro. A tabela divide o tempo exclusivo medido por 60 chamadas de `paint_overlay()` na janela. Os temporizadores medem a execução dos métodos e o envio de comandos CanvasItem. O trabalho de GPU e a serialização do retrato QA ficam fora do ranking.

| Ordem | Trecho em `tavern_view.gd` | ms por frame |
| --- | --- | ---: |
| 1 | `paint_overlay()` chamado por `TopLayer._draw()`. Reconstrói HUD, cartas, indicadores e efeitos de ação a cada frame. O tempo de `text()` é contabilizado na linha 3. | 10,47 |
| 2 | `paint_base()` chamado pelo `_draw()` da cena. Reconstrói a arena e as casas junto aos efeitos do ambiente, heróis e bordas das criaturas. | 5,90 |
| 3 | `text()`. Divide e mede strings e envia comandos de texto e sombra. Foram 1.811 chamadas na janela. | 3,70 |
| 4 | `EffectSprite._draw()`. Os redraws dos efeitos ativos reconstroem a geometria dos eventos e restos, além dos números flutuantes na base. Foram 69 chamadas. | 1,91 |
| 5 | `prepare()`. Reconstrói geometria e dados do HUD e busca efeitos de invocação, impacto e reação para cada criatura. | 0,97 |

A criação e configuração de nós medida em `art()`, `acquire_effect()` e `emitter()` somou 0,26 ms por frame nessa janela, incluindo atualizações e reutilização de nós existentes. Esse recorte curto não isola o custo dos picos de alocação.

## Alterações

- A arena e as texturas das casas reaproveitam os comandos de desenho até mudar a tela ou o tamanho lógico. A camada de animação do tabuleiro e a interface continuam atualizando durante a partida.
- Números e avisos flutuantes usam um pool de `Label` e um `Tween` avançado pelo relógio da batalha. O relógio preserva duração, agrupamento por alvo, modificadores, hit-stop e velocidade da animação.
- Centelhas de fogo, bloqueio, escudo, armadura, cura e bênção usam um pool separado de até 12 emissores `CPUParticles2D` de disparo único. O pool anterior de seis emissores continua atendendo as explosões de morte e energia. Os contornos vetoriais distintivos dos feitiços e a destroçadura das criaturas continuam desenhados separadamente.
- Auras de seleção, arraste, ataque, conjuração e reação usam nós reaproveitados. O nó acompanha posição, rotação e opacidade e limita a atualização da geometria a cerca de 30 Hz com tamanho estável.
- O cache de texto guarda linhas e larguras medidas. As regiões de atlas usam chaves numéricas, e até 24 `TextureRect` inativos ficam disponíveis para reaproveitamento.

## Testes

Godot 4.4.1 headless, com importação dos recursos antes dos testes e validação final a 60 FPS de simulação (`--fixed-fps 60`).

| Script | Resultado |
| --- | --- |
| `tests/tavern_fx.gd` | 50 sequências de carta, 0 falhas |
| `tests/tavern_rules.gd` | 113 verificações, 0 falhas |
| `tests/tavern_actions.gd` | 0 falhas |
