# Mutation Farm — Godot build

Mobile portrait casual game built with Godot 4.7.2 and GDScript. Open
`project.godot` and run `scenes/Game.tscn`. The HTML project at
`../mutation-farm/` is a historical prototype, not the current runtime.

## Current scope (2026-10-05)

- 10 chicken lineages × 10 tiers, normal/shiny variants, bounce/attack/hit sprites.
- Five farms: Earth, Mars, Volcano, Ice and Saturn; each owns two full lineages.
- Per-planet egg quality, UFO delivery level/timer, egg slots and displayed roster.
- Shared wallet/collection; egg shop, merge, risky fusion and enemy UFO raids.
- Collection and offline AI Arena: 100 character skills, difficulty selection,
  seeded matches, skill previews, cooldowns, x1/x2/x4, safe exit and rematch.
  Chapter bosses are out of scope by product decision. Bluetooth duels between
  two phones are planned, NOT implemented. Onboarding device acceptance, quests,
  achievements and release readiness remain backlog work. Initial offline music/SFX
  and an upper-right audio Settings modal are now integrated; see `AUDIO.md` for
  tested scope and remaining device/listening acceptance.
- Simple cartoon art, wooden/cream UI and Baloo 2 typography. Egg Upgrade and
  Fusion share title styling.
- Daily planet-specific shop stock and ad-refilled battle Energy are
  implemented with persisted state; provisional costs and exact rules are in
  `PLAY_ECONOMY.md`. Battle presentation now interpolates motion/health bars.

See [BUSINESS.md](BUSINESS.md) for priorities, evidence and unresolved product
decisions; [GAMEPLAY.md](GAMEPLAY.md) for current rules. Historical BA values
such as 3 species / 6 tiers do not override later user-approved requirements.

## Project structure

- `scenes/Game.tscn`: application scene; farm/map/UI scenes live below `scenes/`.
- `scripts/App.gd`: scene wiring, input and dynamically built modal content.
- `scripts/Game.gd`: player state, catalogue and save migration.
- `scripts/farm/`: farm services, delivery, eggs, fusion, raids, income and save storage.
- `scripts/config/`, `data/farm_config.tres`: probabilities, prices and tunable rules.
- `scripts/ui/EggDropRatePopup.gd`: read-only cartoon shop odds modal.
- `scenes/shop/ShopScreen.tscn`, `scripts/ui/ShopScreen.gd`: tabbed shop with
  Eggs / Chickens / Items, a two-column catalogue and explicit purchase states.
- `assets/ui/shop/`: generated transparent awning, card frame and feed icon;
  generation prompts are preserved in `PROMPTS.md`. Existing egg/chicken art is reused.
- `scripts/battle/`, `scripts/collection/`: respective screens.
- `scripts/battle/BattleSkillCatalog.gd`: 100 named skills keyed to collection IDs.
- `scripts/battle/BattleSimulation.gd`: scene-independent fixed-step combat.
- `scripts/battle/OfflineOpponent.gd`: seeded AI rosters and serializable match snapshots.
- `BATTLE.md`: offline rules, skill mechanics and Bluetooth boundaries.
- `assets/chickens/`, `assets/map/`, `assets/ui/`: current runtime art.

Some UI is still built in `App.gd`; do not assume every modal layout is authored
in a `.tscn`. Old `Main.gd` and prototype assets are not the active app entry point.

## Save integrity

Current file: `user://mutation_farm_save_v3.json` (save schema 3, planet progression
schema 2). Godot v2 saves can migrate. Old shared egg/UFO upgrades migrate to
Earth; new planets begin independently. Valid current per-planet records persist.

Saves are written to `.tmp`, read back/validated, then renamed into place. A
previous verified snapshot is retained as `.bak`. Loading can recover from that
backup. If all existing saves are invalid, the app preserves the files and disables
autosave instead of replacing them with fresh progress. Autosave runs every five
seconds and on pause/close notifications. Android OS lifecycle behavior still
requires real-device testing.

## Regression checks

From the project directory in PowerShell:

```powershell
.\tools\run_regression.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual
```

Omit `-Visual` for headless checks. If Godot is in PATH or currently running,
the runner can discover it without `-Godot`. Use the standard Godot build; no
.NET SDK is required.

The suite uses separate generated save directories and does not touch player
saves. It runs farm smoke, save/migration/five-map, cross-map drag and Fusion
rule regression. `-Visual` additionally checks Egg Upgrade, Collection/discovery,
Fusion card layout and all three outcomes, boss HP, and Shop odds/purchases with
rendered captures and injected mouse/touch input at three phone sizes. Shop
coverage includes category navigation, planet-specific starter purchases, text
containment and capacity/affordability states (`tests/shop_redesign_qa.gd`). Results
are in `qa/`. Pointer tests dispatch viewport-local events through Godot's GUI
hit-testing (not button signals), avoiding host-window DPI/focus drift. Scrolling
tests exercise drag cancellation so swiping over BUY does not purchase an item.
Fusion offspring always belong to the active planet; cross-planet
legacy recipes use the existing parent-lineage fallback without changing old saves.
Battle checks cover all 100 skill mappings and effects, fixed-step reproducibility,
AI roster/difficulty/snapshot integrity, offline lobby/picker, 15v15 layouts,
swiping, countdown, speed, exit, one-time rewards and rematches.
This is targeted regression coverage, not a claim that every game feature or
Android release has passed. Additional acceptance gaps are listed in BUSINESS.md.

## Android

Test APK artifacts exist in this workspace. Their existence does not prove a
release build is current or validated. Save/resume, touch and performance need
physical-device testing; Google Play release and monetization remain unfinished.
