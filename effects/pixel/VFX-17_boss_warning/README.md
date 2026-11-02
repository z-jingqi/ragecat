# VFX-17 Boss warning

Procedural pixel telegraph, four shapes: circle, annulus, sector and rectangle. Stable full boundary defines the intended region; a diagonally hatched fill progresses across it. The preview also displays remaining time and activation count. Information is not color-only. No particles obscure the area. No full-screen flash or damage implementation.

## Reference

Inspected ParticleFX [Meteor Strike](https://particlefx.studio/effects/meteor-strike), including its publicly available eight-stage strip. Its stationary pre-impact floor marker informed the separation of warning from impact. This module independently implements range telegraphs, not the meteor/explosion. No external art or source is included. Sparse stage images are not claimed to be a complete animation reconstruction.

## Runtime contract

`warning.gd` is the Godot-only preview component. Call `play(anchor, authority, visuals, target, follow_target)` and either allow `_process` or set `automatic=false` and call `tick(dt)`.

- `authority`: game-owned geometry and countdown. Circle/ring/sector radius, rectangle dimensions, orientation and deadline are **not cosmetic controls**. The preview's sliders simulate game input.
- `visuals`: line width, colors, hatch spacing, fill opacity and harmless release tail. These do not change `contains_world` or activation time.
- `activated(area_snapshot)` fires once at the exact countdown crossing, even if a tick crosses several phases. Snapshot contains sanitized geometry and `origin`. Damage/hit testing belongs to the game.
- `finished` means the short release has cleared, not a second attack.
- `cancel` immediately clears with no activation; `reset` additionally resets elapsed/fired state. Reentrant replay inside activation is safe.
- Default position is locked at start. Optional following mode maintains initial offset from target; destroyed target cancels safely. Use the same authoritative positioning policy in gameplay.
- Geometry `contains_world` is exact continuous geometry; raster visualization samples each logical pixel at its center. A pixel edge can extend at most half a logical pixel past continuous bounds. Rotations use the same transformation for rendering and containment.

## Parameters

All changes take effect on replay. Invalid shape becomes circle; non-finite numbers revert to defaults. Numeric inputs are clamped to the supported preview domain; use the returned sanitized `area` for matching game data or validate before calling.

| Authority | Default | Valid range / meaning |
|---|---:|---|
| shape | circle | circle / ring / sector / rectangle |
| radius | 42 px | 4–54 px; circle/ring/sector |
| inner_radius | 23 px | 0–radius−2; ring only |
| angle_deg | 90° | 5–360°; sector centered on +X |
| length | 84 px | 8–96 px; rectangle X length |
| width | 28 px | 4–56 px; rectangle Y width |
| orientation_deg | 0° | any finite degrees, clockwise in screen coordinates |
| countdown | 1.25 s | 0.1–10 s |

| Visual | Default | Range |
|---|---|---|
| line_width | 1 px | 1–3 px, rendered inward |
| fill_alpha | 0.23 | 0–0.5 |
| hatch_spacing | 6 px | integer 4–12 |
| release | 0.14 s | 0–0.4 s; no damage in tail |
| boundary_color | #f5b65a | valid HTML color |
| fill_color | #c15b44 | valid HTML color |
| ready_color | #ffe7a3 | valid HTML color |

The geometry is deterministic; no meaningless random seed is exposed. No spritesheet, PNG animation or Unity implementation is shipped.

## Preview and checks

Run `preview/godot/effects/VFX-17_boss_warning/boss_warning.tscn` in the existing Godot preview project. Left is actual logical 1×, right is exact nearest 2× of the same SubViewport. Controls: shape, radius, countdown, orientation, sector angle, pause, frame step, replay, cancel, reset, background, host movement and follow/lock policy.

Headless checks: `godot --headless --path preview/godot --script res://effects/VFX-17_boss_warning/test_warning.gd` and `test_demo.gd`. See QA.md for delivered verification.
