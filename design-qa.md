# Godot port — design and interaction QA

final result: passed

## Visual truth and evidence

The supplied mobile battle screenshot and the existing `web/index.html`, `web/style.css`, `web/game.js`, and `web/assets` are the reference. The source was rendered from the original implementation at 390 × 740 CSS pixels, deviceScaleFactor 1, without browser chrome. Godot was exported to Web and rendered in Chromium/WebGL2 at the same size and density.

- Source: `docs/qa/source-home.png`, `docs/qa/source-battle.png`.
- Godot: `docs/qa/godot-home.png`, `docs/qa/godot-battle.png`.
- Same-input full-view comparisons: `docs/qa/compare-home.png`, `docs/qa/compare-battle.png` (source left, Godot right).
- Focused cards, labels, costs, resource strip, and primary action: `docs/qa/compare-cards.png`.
- Additional states: `docs/qa/godot-deck.png`, `godot-card-detail.png`, `godot-hero.png`, `godot-tower.png`, and `godot-result.png`.
- Responsive evidence: `docs/qa/godot-tall.png` at 390 × 844 and `docs/qa/godot-desktop.png` at 1024 × 768.

The battle comparison uses Vorak, phase 2/5, round 1, 115 enemy HP, 100 player HP, 3 mana, 7 cards remaining, coins 50, one win, and the same five card IDs. The source card entrance animation was allowed to finish before capture. No density resizing was needed. Device and Safari chrome in the user-provided image are excluded from the implementation.

## Comparison history

1. [P1, fixed] The prior Godot scene was a gray text-only prototype. Replaced it with a native Control interface, original illustrated environment, portraits, original card illustrations, gold frames, health bars, resources, and original combat rules.
2. [P1, fixed] Initial overlay captures showed home buttons over the collection. Underlying controls are now hidden while a modal consumes pointer input. Verified collection, settings, tower, character, card, and result captures.
3. [P2, fixed] The arena originally stretched the entire background. It now uses the original centered cover crop, and the arena, hand, resource strip, and end-turn control follow the source's mobile proportions.
4. [P2, fixed] Missing font glyphs, decimal mana labels, and small deck-button type. Added a licensed symbol fallback, integer formatting, and matching display-font sizing. Recaptured home and battle.
5. [P2, fixed] Cairo SVG rasterization omitted source glow filters. Re-rendered original SVGs in Chromium to preserve them, and reused the original button, lobby background, sword icon, and gem artwork. Latest full-view and focused comparisons show the corrected assets.
6. [P1, fixed] The browser flow exposed preference-loading errors from JavaScript value conversion. Settings now load as strings and are parsed in GDScript. Both on/off toggling and persisted speed 2 were verified in the browser.

## Required fidelity surfaces

- Typography: native Noto Serif/Noto Sans with symbol fallbacks preserve display/body hierarchy and readable costs, card names, and combat stats. Minor differences in letter spacing and embossed text styling remain cosmetic.
- Layout: lobby measurements were taken from the source DOM. Battle positions and major-region proportions match the mobile reference. All persistent controls remain inside the viewport. Larger windows preserve the portrait composition with side margins.
- Colors/tokens: dark navy/purple background, gold frames, red enemy health, cyan player health, and element colors follow the source.
- Image quality: source assets are reused, rasterized at sufficient resolution with SVG filters preserved. No substitute illustrations. Source gradients and button backgrounds are reused as textures; gameplay and UI controls are native Godot.
- Content: same 24 cards, names, costs, effects, 12-card deck, five bosses, HP, intent, rounds, rewards, and progression. Original localStorage profile is imported. Minor decorative emoji icons are omitted from several labels; corresponding labels and actions remain present.

## Interaction and functional validation

- 23 assertions passed in `tests/godot_port.gd`: deck/hand sizes, mana, shields, zero-cost consumption, damage, healing, burn, freeze, resonance, triad, discard recycling, all five boss attacks, Drakor defense, rewards, progression, duplicate-result protection, and ten-round finish.
- `tests/godot_browser.cjs` passed in Chromium with a touch-capable mobile viewport: settings toggles, tower, deck replacement while retaining 12 cards, long-press card details, character details, complete battle, rewards, advancement, reload persistence, tall-mobile layout, and desktop layout.
- The browser battle advanced from Vorak to Skael, from 50 to 100 coins, from 35 to 70 XP, and from one to two wins. The edited deck remained saved after reload.
- Browser JavaScript and console errors: zero. A separate sound-enabled combat smoke check passed after importing the same eight CC0 recordings used by the original web game.
- Export, GDScript import, JavaScript syntax checks, workflow YAML validation, and git whitespace checks passed.

## Open questions

None blocking. Real-device Safari has not been exercised in this environment; browser verification used Chromium/WebGL2.

## Follow-up polish

[P3] The native font rendering, embossed lettering, some tiny decorative icons, and frame glow falloff are not pixel-identical to browser CSS. They do not change the game layout, assets, information, or controls.

## Implementation checklist

- [x] Preserve the selected game's imagery and mobile composition.
- [x] Port the complete existing card and boss rules into Godot.
- [x] Verify the complete game flow and saved profile.
- [x] Inspect full-view and focused source/implementation comparisons.
- [x] Keep the original web game available at `/classic/`.
- [x] Publish fingerprinted Godot resources to prevent stale prototype assets.
