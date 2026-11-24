# Equilíbrio de elementos, armadilhas e famílias

## Elementos

| Ataque | Defesa | Ajuste |
| --- | --- | --- |
| Fogo | Natureza | +1 |
| Natureza | Terra | +1 |
| Terra | Vento | +1 |
| Vento | Água | +1 |
| Água | Fogo | +1 |

Cada confronto invertido dá −1. Os outros pares, os ataques a heróis e o dano de fadiga são neutros. O ajuste vale para qualquer efeito de dano com elemento, inclusive feitiços, efeitos em área e cada lado de um combate. Ele incide antes do escudo e do veneno. Um golpe de base zero continua em zero, e a resistência pode reduzir um golpe a zero sem romper o escudo. A inspeção da carta mostra os confrontos do elemento. A prévia e os números de dano mostram ▲ para vantagem e ▼ para fraqueza. A prévia preserva o segredo de armadilhas e estima o golpe direto.

Em `cards.json`, os elementos são `fire`, `water`, `earth`, `wind` e `nature`. Gelo virou Água. Tempestade, raio e arcano viraram Vento. Aço, sombra e escudo viraram Terra. Mordida e cura viraram Natureza. O campo `fx` preserva o estilo de animação e áudio das cartas migradas.

O ajuste de um ponto interfere mais nas trocas entre criaturas pequenas. A neutralidade dos heróis mantém os valores de dano direto e de ataque dos apoios.

## Armadilhas

As seis cartas ficam no filtro **Armadilhas** do grimório. Para usá-las, monte um baralho de 30 cartas e solte uma armadilha numa casa dourada. Cada casa aceita uma armadilha além do apoio regular. Armar cobra energia e inicia a mesma recarga de 5 s do modo em tempo real. A carta fica virada para baixo até disparar, o que libera a casa para outra armadilha. O apoio regular continua pulsando.

| Carta | Energia | Gatilho | Efeito |
| --- | ---: | --- | --- |
| Baluarte Oculto | 2 | Ataque inimigo ao herói ou a uma criatura aliada | Ganha 3 de armadura antes do ataque |
| Espinhos Ocultos | 2 | Ataque inimigo ao herói ou a uma criatura aliada | Causa 2 de dano sombrio ao atacante antes do ataque. Se ele morrer, o ataque é cancelado |
| Runas de Guarda | 2 | Feitiço inimigo válido | Ganha 3 de armadura antes do feitiço |
| Fonte Selada | 1 | Feitiço inimigo válido | Cura 2 PV antes do feitiço |
| Brasas de Retorno | 2 | Dano reduz a vida de 10 PV ou mais para 1–9 PV | Cura 4 PV após o golpe |
| Último Bastião | 2 | Dano reduz a vida de 7 PV ou mais para 1–6 PV | Ganha 5 de armadura após o golpe |

Os gatilhos de ataque e feitiço aceitam qualquer alvo indicado na tabela. Um feitiço inimigo de cura ou de compra também pode disparar as Runas ou a Fonte. Poderes heroicos, gritos de batalha e pulsos de apoio não contam como feitiços. Dano absorvido pela armadura e dano letal não disparam armadilhas de vida. Se um golpe cruza dois limites, ambos são avaliados com os PV registrados antes e depois do mesmo golpe. Armadilhas do mesmo gatilho disparam da esquerda para a direita.

Comparadas aos apoios recorrentes, as armadilhas oferecem proteção imediata ou um efeito de recuperação maior, condicionado a uma ação do rival ou a um limiar de vida. Para preservar as partidas de abertura, os baralhos iniciais continuam com a composição anterior. A IA consegue armar armadilhas quando elas fazem parte do baralho que recebe. A revelação vira a carta na casa do apoio. No modo de movimento reduzido, a face aparece sem a virada.

## Famílias

| Família | Membros |
| --- | --- |
| Lobos | Lobo Prateado e Lobo Espectral |
| Mortos-vivos | Tecelão de Ossos, Soldado Esquecido e Esqueleto |
| Dragões | Draco de Brasa, Dragão Âmbar e Serpe do Inverno |

Com dois ou mais membros vivos da mesma família no mesmo campo, cada membro recebe +1 de ataque e a insígnia de ataque fica verde. Fichas contam. O bônus vale em ataques e contra-ataques, soma-se a outros efeitos de ataque e desaparece assim que sobrar um único membro vivo. Ter um terceiro membro amplia o número de criaturas beneficiadas. O bônus individual continua em +1, o que limita o crescimento da sinergia em campos cheios.
