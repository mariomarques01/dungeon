# Apoio no chão, combate, portais e muralhas

Correção dos quatro problemas relatados na versão `69dd9c9`.

- As figuras usam os limites opacos do atlas e o ponto do pé de apoio. A sombra está nesse ponto; não há oscilação vertical de repouso. Poses de caminhada, golpe e recuo giram em torno dos pés.
- Ataques têm preparação, impacto e recuperação. O dano ocorre no impacto, com reação do defensor, sinal de proteção para golem/ossada/muralha, faíscas e projéteis dos conjuradores. Mortes têm uma transição própria. Os tempos vêm do servidor no PvP e a apresentação interpola os temporizadores entre snapshots.
- Portal cria um vórtice, desmaterializa as criaturas adversárias e as rematerializa na área inicial da própria base. Preserva vida, aliados e muralhas; cancela ataques de/contra quem está sendo transportado e impede movimento/ataque até concluir a transição. Substitui a invocação antiga de duas ossadas.
- Muralhas próximas se encaixam automaticamente pelas extremidades numa linha isométrica. Mantêm conexões recíprocas, impedem sobreposição e bloqueiam a passagem. Destruir um trecho remove suas conexões.

## Evidências

Capturas de partidas reais no cliente Web exportado, comandadas por mouse, sem injetar estados no navegador:

- [Muralhas conectadas — jogador um](connected-walls.png).
- [A mesma conexão — jogador dois](connected-walls-opponent.png).
- [Portal em funcionamento](portal.jpg).
- [Sequência de golpe e reação de defesa](attack.mp4).
- [Sequência de transporte do portal](portal.mp4).

Os clipes são sequências de capturas do teste; a captura tem uma cadência inferior à taxa de quadros do jogo.

## Verificações

`tests/mutable_rules.gd`: 32 verificações, zero falhas. Inclui preparação antes do dano, impacto/recuo, projétil, portal em ambos os lados, preservação da vida, cancelamento de ataques em trânsito, pausa de movimento durante transporte, retomada na base, encaixe de três muralhas e desconexão do trecho destruído, além da partida inteira com IA.

`tests/mutable_actions_browser.cjs`: dois navegadores, golpes e dano reais, vórtice e retorno à base sincronizados, compra de cartas usando energia normal e colocação de duas muralhas adjacentes. Confere a mesma conexão nos dois clientes e salva as sequências acima.

`tests/mutable_browser.cjs`: desktop, celular DPR3, toque, rotação, ação inválida/válida, habilidade, pausa, ida/volta ao clássico, PvP e desconexão; zero erros de página/console.

`tests/mutable_rooms.cjs`: criação/código, sala inválida/cheia, validação autoritativa, dados inválidos, sincronização e desconexão.
