# Duelos da Taverna — QA

final result: passed

## Reference

The user's Hearthstone references establish a tactile painted tabletop, two rows of creature portraits, heroes above/below the field, a fanned hand, mana and targeted card interactions. This revision changes the game rules and presentation accordingly. It uses original board, frame, creature and spell artwork rather than franchise assets.

## Evidence and viewports

`docs/qa/tavern/home.png`, `collection.png`, `opening.png`, `summoning-drag.png`, `summoned.png`, `attack-arrow.png`, `combat.png`, `populated-board.png`, `spell-target.png`, `spell-impact.png`, `result.png`, `mobile-touch-drag.png` and `mobile-board.png` are actual Chromium/WebGL2 captures. Desktop viewport: 1280×800 CSS pixels; mobile: 390×844, touch enabled, density 1. No device chrome is recreated in the game.

## Findings resolved

- Replaced the unwanted two-character dungeon duel with a creature-and-spell tabletop game.
- Rebuilt the game around drag-to-summon, targeted spells and drag-to-attack between persistent minions; invalid drops spend no mana or card.
- Added original painted board variants, a 25-creature art atlas, a 16-spell atlas and separate physical creature/spell frames.
- Added summoning, attack travel, recoil, death/fade, elemental projectiles and bursts, shield breaks, freeze, stat changes, ready glows and legal-target guidance.
- Fixed desktop card hover hit testing so lifted cards remain draggable from their original hand positions.
- Fixed responsive viewport configuration, portrait hero/hand/mana spacing and collection removal for single-copy cards in a full deck.
- Replaced heavy body text with a regular reading font and improved stat badge spacing and oval unit frames.
- Collection cards support press-and-hold reading and explicit removal controls.

## Required visual surfaces

Typography uses readable serif titles and regular body text. The palette is warm parchment, walnut, brass, jewel blue mana, gold attack and red health. Portrait and landscape layouts use separate board art. Native text remains independent of the painted frames. Cards show cost, name, rules, attack and health; tokens show live combat stats. Creature health, armor, mana, hand size and deck size update from the rules model.

## Functional verification

The native rule suite passes 57 checks, including four differently shuffled full duels. Coverage includes 30-card deck validation, mana consumption and growth, seven-unit board limits, hand limits, fatigue, summoning sickness, simultaneous combat, Provocar, Escudo Divino, Investida, Ímpeto, Fúria dos Ventos, Veneno, Roubo de Vida, spellpower, freeze duration, buffs, targeted spells, area damage, deathrattle tokens/healing, hero power limits, lethal damage and legal AI choices.

The browser integration passed a complete match driven only through real pointer gestures: invalid drag, valid summoning, inability to attack immediately, AI turn, creature combat, targeted spells, reward/persistence and touch-only mobile drag via CDP touch events. One completed run played six creatures, performed nine attacks and resolved spells; console and JavaScript errors were zero. A final smoke check covers collection removal/addition and the final presentation.

## Remaining notes

Small decorative differences from the inspiration are expected: this is an original game rather than a pixel-identical recreation. Mobile Safari on physical hardware was not available; native touch behavior was verified in Chromium's touch-capable mobile mode.

Resultado, combate e rotação: painel numa camada acima de toda a arte; vitória por ação letal testada com criaturas sobreviventes. Resultado revisado em `docs/qa/tavern/result-fixed.png`. Morte por fogo, gelo, raio e sombra preserva o elemento causador nos fragmentos. Perfis de som por criatura/material e contra-ataque exercitados nas 44 sequências. Partida completa com oito criaturas, cinco ataques, feitiços e toque terminou sem erros no navegador. Rotação em tela móvel com densidade 3 preservou saúde/mão, preencheu o canvas, manteve as cartas visíveis e permitiu abrir/fechar configurações por toque; evidência em `docs/qa/tavern/landscape-fill.png`.
