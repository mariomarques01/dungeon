# Dungeon Cards v2 — layout, animation, combat and sound QA

final result: passed

## Reference and implementation

Reference: the user's supplied 720 × 1280 image of the purple stone dungeon, flaming braziers, enemy health at the top, player health at the bottom, five illustrated cards and the large gold end-turn button.

The new Godot battle uses a 390 × 700 portrait composition. The reference is approximately 390 × 693 after density normalization; browser/device chrome is not part of the scene. The dungeon, character poses and card illustrations were created as separate game assets from this reference. They are rendered and animated by Godot, not a flattened screenshot.

Evidence: `docs/qa/v2/battle.png`, `charge.png`, `projectile.png`, `impact.png`, `defense.png`, `result.png`, `credits.png`, `home.png`, `deck.png`, `desktop.png` and `tall.png`. Battle captures are content-only, 390 × 700 pixels at deviceScaleFactor 1; full browser viewport was 390 × 740. Additional windows tested: 390 × 844 and 1024 × 768.

## Findings and fixes

- [P1, fixed] The previous arena and flat illustrations did not match the new target. Added the painted gothic dungeon, fire lighting, character portraits, four poses per fighter, and an elemental card-art atlas. Removed the large old header/resource blocks from the battle layout to match the supplied hierarchy.
- [P1, fixed] Card use lacked a distinct attribution/attack/reaction sequence. Added card-to-character transfer, power absorption, casting or sword poses, projectiles or slashes, impact recoil, independent floating damage/block/heal events, and recovery. Ice stops the enemy action; shield effects remain visible until consumed/expired.
- [P1, fixed] Presentation and damage timing were not synchronized. Absolute animation timestamps now control charge, release, impact and recovery. Combat state changes at impact; new cards and end-turn input remain locked through recovery. A battle serial prevents old pending actions from damaging a restarted match.
- [P1, fixed] The prior sound bank reused generic magic recordings. Elemental effects now use distinct professionally recorded fire, ice, thunder, water, earth and wind samples, plus sword, armor, shield, healing and creature reaction recordings. A complete orchestral fantasy score replaces the synthesized note loop. Music ducks beneath effects, loops and obeys mute. Master limiting prevents stacked effects from clipping. Source credits and licenses are available in settings and the repository.
- [P2, fixed] The hero portrait intercepted the speed button. Reduced the portrait input region to leave the speed control reachable; the browser test now verifies transitions through ×1, ×1.5 and ×2.
- [P2, fixed] Two-line card titles overlapped their effect text. Tightened the title line height and recaptured the final battle view, including two-line names.

## Fidelity review

- Typography: high-contrast serif headings and card titles, compact body labels, readable card costs and HP. Card text is native text and remains separate from illustration assets.
- Layout: top enemy HUD, large illuminated arena, bottom player HUD, a narrow hand/mana strip, five cards, gold primary action. The characters now occupy the arena so their casts, impacts and defensive reactions are visible.
- Colors: near-black UI, purple stone, orange fire, gold frames, crimson enemy HP, cyan player HP and elemental colors.
- Assets: painted scenery, silver-haired hooded guardian, green armored orc and matching elemental card art. Sprites use transparent atlases and individual poses. Decorative frame geometry and particles are native Godot drawing.
- Content: existing 24 abilities, five bosses, 12-card deck, card costs, rewards and saved progress remain functional. Additional audio credits are in settings.

The supplied reference is a visual target, not a promise of pixel-identical painted imagery. The new scene follows its composition and art direction while adding the requested visible fighters and live effects.

## Functional validation

- Existing rule suite: all checks passed, including mana, damage, shields, burn, freeze, healing, elemental combinations, boss behavior, deck recycling, rewards, progression and ten-round finish.
- New regression suite: all 24 cards complete their native animation and resolution path. Tests verify no damage during initial charge, damage at impact, recovery lock, duplicate-click protection, partial/full/excess defense, actual HP removal on overkill, negative-damage rejection and cancellation of pending attacks after a restart.
- Browser integration: passed with an actual native attack and defense, repeated-click attempts, unchanged HP before impact, typed sound events, real music pause/resume, speed controls, full battle, victory, rewards, progression and persisted edited deck after reload. No JavaScript or console errors.
- Read-only `?qa=1` snapshots expose the native engine state for assertions; they do not inject actions or change rules.
- Final sound-enabled and visual smoke capture passed after the last text and mix adjustments.
- GDScript import/export, JavaScript syntax, workflow YAML and git whitespace checks passed.

## Audio attribution

Full attribution and modifications: `godot/assets/v2/audio/CREDITS.txt` and in-game Settings → Audio credits. Music: Matthew Pablo, CC BY 3.0. Elemental samples: leohpaz, CC BY 4.0. Other recordings: rubberduck and artisticdude, CC0.

## Remaining notes

Real-device Safari was not available for this pass; browser testing used Chromium/WebGL2. Small font and decorative frame differences from the reference are cosmetic. No blocking functional or visual findings remain.
