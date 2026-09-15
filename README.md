# Mutation Farm — Godot build

Mobile (portrait, touch) merge-farm game built in Godot 4 / GDScript, based
on the HTML/CSS/JS prototype at `../mutation-farm/`. See `GAMEPLAY.md` for
the player-facing design doc.

## Why GDScript, not C#

`godogen`'s default Godot guide (`../godogen/engines/godot.md`) targets the
**.NET/Mono** build of Godot with C#. This machine has:
- the **standard** (non-Mono) Godot 4.7.2 build (`Godot_v4.7.2-stable_win64.exe`
  in Downloads — no `GodotSharp/` folder, no C# support), and
- no working **.NET SDK** (`dotnet --version` reports no SDK installed).

GDScript needs neither, so the project was built with it instead. If a Mono
Godot build + .NET SDK become available later, this could be ported to C#
following the godogen guide, but there's no functional need to.

## Status

**Built:** farm view (buy/merge/crossbreed/rare-mutation/passive
income/collection/save-load), portrait mobile UI matching the prototype's
look. See `GAMEPLAY.md` for full detail.

**Not built:** battle/PK arena, adventure chapters + bosses, full shop
(food/gem pouch/mystery egg), Android export (needs Export Templates +
Android SDK/JDK — not installed, sizable download, needs user go-ahead).

## Asset table

| Asset | Source | Notes |
|---|---|---|
| `assets/sprites/sit_1.png`, `sit_4.png`, `tall_1.png` | `../mutation-farm/assets/sprites/` | Shared idle-a/idle-b/walk flipbook frames, tinted per species/rarity at runtime |
| `assets/icons/*.png` | `../mutation-farm/assets/icons/` | Currency + UI icons, used as-is |

No AI-generated assets used yet — reusing the prototype's existing art per
user preference. `godogen`'s `/asset-gen` skill is available under
`.claude/skills/asset-gen/` (published from godogen) if new art is wanted
later — needs `GOOGLE_API_KEY`/`XAI_API_KEY`/`TRIPO3D_API_KEY` and user
confirmation before any paid generation.

## Running

Open `project.godot` in Godot 4.7.2, press Run. Or headless proof capture:

```bash
godot --path . --write-movie screenshots/result/frame.png --fixed-fps 30 --quit-after 90
```
