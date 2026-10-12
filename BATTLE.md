# Battle — offline first

Updated: 2026-10-05. Product direction: offline AI duels now, Bluetooth phone-to-phone
duels later. Chapter progression and chapter bosses are excluded. Farm UFO raids
are a separate system and remain unchanged.

## Play flow

1. Open Arena (crossed-swords tab). Select up to 15 owned chickens from any farm.
   Tap an occupied slot to remove it; + opens cards with the real chicken, skill
   name, attack pattern, cooldown and secondary effect. Duplicate ownership IDs
   and stale IDs cannot add extra fighters.
2. Choose EASY / NORMAL / HARD and NEW AI TEAM. AI rosters match the player's
   number and tier distribution but have seeded randomized lineages and formation.
   Preview and battle use the same snapshot. AI stats scale by 0.8 / 1.0 / 1.2.
3. START BATTLE: asynchronous animation-sheet preparation, then a playful
   **1 → 2 → 3 → BATTLE!** intro (0.8 seconds per beat) and a 30-second automatic duel. x1/x2/x4
   changes simulation speed, not rules. Blue bars charge skills; green/red bars
   show HP. Tap a unit to inspect its active move/cooldown. Skills can be ready
   while waiting for a target in range.
   The match fills the entire game viewport, including intro and results. Resource
   HUD, bottom navigation and DEV are hidden; the grid expands in both dimensions.
   LEAVE/BACK TO TEAM restores the normal lobby shell. This is an in-game layout
   change, not a desktop window-mode switch.
4. Elimination ends the match. At timeout, compare hearts, surviving units,
   remaining HP fraction, then territory; equal scores draw. Victory pays the
   existing formula (150 + 10 per owned territory cell) and 20 XP once. Defeat,
   draw and abandonment do not pay. No farm animals are consumed or injured.
5. A blocking cartoon result popup opens for victory, defeat or draw, showing
   actual rewards, casts, HP damage and KOs. BACK TO TEAM closes it and returns
   to team selection; the secondary REMATCH resets the same seeded matchup.
   Successful rewards are saved before being shown as received; dismissing/reopening cannot
   pay again. If saving fails, Gold/XP roll back and a PENDING popup offers RETRY SAVE,
   blocking leave/rematch until saved without charging more Energy. Unsaved pending
   prizes do not survive force-close. Its full-screen overlay blocks background input and a brief opening
   guard prevents a combat tap from immediately dismissing the result.
   LEAVE during combat requires a second tap
   within three seconds. Other tabs cannot interrupt an active duel.

## Skill system

`BattleSkillCatalog.gd` explicitly maps all 100 sprite IDs from `chickens.json` to
100 named skills. ID = (tier - 1) * 10 + lineage + 1. Two owned copies of the same
character share a move; shiny variants retain the move and existing 5% stat bonus.
No new progression field or save migration is required.

Skills combine 11 targeting patterns (single shot, split volley, focused burst,
splash, lane pierce, chain, nova, weakest-target snipe, frontal wave, two-target
orbit, meteor splash) with ten secondary mechanics:

| Effect | Runtime behavior |
|---|---|
| Burn | 18% caster ATK/sec for 3 seconds |
| Poison | 12% caster ATK/sec for 5 seconds |
| Slow | Action timer advances at 60% speed for 2 seconds |
| Stun | Prevent actions and casting for 0.6 seconds |
| Weaken | 25% less direct outgoing damage for 3 seconds |
| Drain | Restore 35% of actual HP damage dealt, capped at max HP |
| Execute | 50% bonus damage if target is below 35% HP |
| Heal | Restore 120% caster ATK to lowest-health-fraction living ally |
| Shield | Self shield 150% ATK, capped at 50% max HP, expires after 4 seconds |
| Haste | Action timer advances at 135% speed for 3 seconds |

Shields absorb direct and damage-over-time damage before HP. Reapplying burn or
poison refreshes duration and retains the stronger DPS; status instances do not
stack without limit. Haste/slow affect basic attacks/movement, not skill cooldown.
Targeting, direct damage and secondary effects resolve in the fixed tick; visuals
are presentation, not physics projectiles. VFX uses lightweight procedural cartoon
shapes grouped by targeting pattern and explicit visual motif, NOT 100 separately
painted animations. Appearance is independent of the secondary mechanic: Ice
Chicken fires outlined cyan crystal shards with frost trails and six-arm snowflake
impacts, including its smaller basic shots. Water draws wave crests (not green heal
bullets), fire has flame tails, lightning zigzags, plants use leaves, earth/stone
uses rocks, and wind uses curved gusts. Healing itself still displays a plus sign.

Examples: Fire Chicken → Flame Comet (meteor/burn); Ice Chicken → Frost Shards
(volley/slow); Electric Chicken → Lightning Chain (chain/stun); Angel Chicken →
Angel Feathers (wave/heal); Laser Chicken → Laser Sweep (beam/burn).

## Architecture and tests

- `OfflineOpponent.gd` creates version-1 primitive-data match snapshots: mode,
  seed, difficulty, rosters, stats and opponent name. Does not write saves.
- `BattleSimulation.gd` runs 0.1-second ticks with local seeded RNG and alternating
  initiative. No scene references, wall clock or global RNG. Units cannot occupy
  the same cell. Rendering keeps persistent unit views instead of rebuilding them
  every frame. Layout has 7–11 rows to fit teams of up to 15 per side.
- `BattleArenaScreen.gd` renders, handles exit/result/rematch, and pays rewards.
  Background pause notifications stop the offline clock; in-progress matches are
  not persisted after force-close. Existing wallet/farm saves remain authoritative.
- `tests/battle_skill_regression.gd`: 100 skill mappings/casts, status expiration,
  shield, weaken/stun, board occupancy, all ten tiers, deterministic timestep
  comparison, AI difficulty, 15v15 and JSON snapshot round trip.
- `tests/battle_visual_qa.gd`: lobby/card layout at 360x640, 390x844, 720x1280;
  actual GUI events, picker shielding/swipe, countdown, speed, background-pause
  simulation, leave, one-time reward, rematch and farm roster preservation.
  Also captures all four intro beats and elemental projectiles/impacts at all three
  sizes; asserts no clock/HP changes before combat, pause freezes the intro, and
  abandoning threaded preparation followed by immediate restart works.
- `BattleCountdown.gd` uses the existing Baloo2 font, squash/stretch, slight wobble,
  rays and confetti drawn in code. The overlay blocks unit input, not LEAVE.
- `scenes/battle/BattleResultPopup.tscn` is an editable scene with a CanvasLayer
  overlay; `BattleResultPopup.gd` handles presentation only, never transactions.
- Animation sheets load through threaded requests; only completed requests are
  retrieved (two per update), with references retained for rematches. No combat
  advances while loading. Failed/timed-out preparation offers retry/leave without
  paying rewards. Each match gets a fresh countdown, including rematches.
- Desktop probe `tests/battle_start_probe.gd`, 15 vs 15: synchronous start measured
  191.551 ms before and 31.356 ms after. New preparation took 447.304 ms total,
  max measured preparation update 3.411 ms (`qa/battle-start-{before,after}.log`).
  These are local CPU measurements, not GPU frame-time or Android guarantees.

## Not delivered yet

Bluetooth discovery/pairing/permissions, transport, authoritative host, roster
validation, protocol negotiation, reconnect, desync recovery and two-device tests.
A serializable deterministic local match is groundwork, not a working multiplayer
implementation or proof of cross-device floating-point determinism. There is no
Bluetooth button pretending to connect in this build.

Balance remains an initial pass, not a validated economy or competitive ruleset.
Audio and physical Android performance/touch/lifecycle acceptance remain pending.
# Presentation polish and energy — 2026-10-05

- Lobby and arena now share a warm cream/green cartoon palette, clearer team colors, timer badge and visible match/rematch energy cost.
- Fixed-step combat rules remain unchanged. Presentation uses frame-time interpolation for movement and HP/cooldown bars, continuous sprite animation phase, a subtle walk bob/attack lunge, foot shadows/selection rings, damage numbers and a short defeat fade. Projectiles originate at the rendered unit position instead of jumping ahead to its logical cell.
- Effect time follows battle speed/pause. No new texture generation or synchronous asset loading was added to combat.
- Current Energy tuning: 5 per fight, deducted once after countdown; no passive regeneration. Optional verified ads restore 20 Energy up to 240. Preparation/early cancellation is free. See `PLAY_ECONOMY.md`.
- Lobby now previews the win reward (150 Gold + 10 per owned tile, +20 XP). Follow-up economy QA: 62 checks / zero failures including insufficient energy, exact debit, save failure/retry and one-time payout. Full Battle visual suite rerun: 1815 checks / zero failures; seven headless gameplay groups pass. Existing tutorial anchor warning remains unrelated.
- Battle visual regression: 1815 checks / zero failures after the movement changes. Focused polish/economy suite: 84 checks / zero failures. This demonstrates desktop behavior, not an Android FPS or subjective smoothness certification.

## Visual refresh — 2026-10-06

- Team lobby now uses a warm cream/orange cartoon hierarchy: compact opponent card, clearer flock cards, subdued empty slots, prominent Battle action and a separate reward/cost strip. It remains code-native Godot UI and reuses the established Baloo typography.
- The arena now reads as two sides: soft coral AI territory, mint player territory, and a gold neutral lane. Heavy dark grass tiles were replaced with rounded lightweight cells; captured territory changes color without rebuilding textures. Status effects use their own small badge instead of overlapping creature art.
- Verified at 360×640, 390×844 and 720×1280: Battle visual **1815 checks**, economy **62 checks**, both zero failures. Seven headless regression groups pass. The existing unrelated TutorialController anchor warning remains.

### Forest fantasy asset pass

- Added project-owned raster assets under `assets/ui/battle_forest/`: a transparent soil/vine/stone board frame, stone-and-wood battle header, control sheet, four textured terrain tiles, and a Straw Whirl skill icon. They were generated from the supplied visual reference with the built-in image generator, then imported by Godot.
- The board keeps its dynamic rules: 3 columns and 7 rows for teams up to 9, expanding to 9/11 rows for larger rosters up to 15. The artwork is an overlay and does not alter combat positions, pathing, damage, energy or rewards.
- Dynamic labels remain native Godot text. Art contains no baked text; the timer, player/AI counts, opponent, skill, Leave and speed values remain live. Grass variants alternate, the middle lane uses dirt, ownership receives a light team tint, and the forest frame leaves the combat center transparent.
- Final Battle visual run after asset integration: **1815 checks, zero failures** at 360×640, 390×844 and 720×1280. Economy remains **62 checks, zero failures** and seven headless regression groups pass.

### Simple farm-style pass

- Replaced the dense fantasy presentation with a version that matches the main farm: flat lime grass, sparse outlined tufts, a thin wooden frame, cream background and the same rounded Baloo typography.
- New non-destructive assets live in `assets/ui/battle_simple/`. The earlier forest set remains available but is no longer loaded by the arena.
- Skill, Leave and speed controls are native Godot buttons again, so live text stays centered and responsive instead of being baked into raster plates. Combat rules and the dynamic 3x7–3x11 board are unchanged.
- Verified after the simplification: Battle visual **1815 checks / zero failures**, Battle economy **62 checks / zero failures**, plus all seven headless regression groups.

