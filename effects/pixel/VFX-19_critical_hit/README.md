# VFX-19 Critical hit / 暴击

An independent, directional critical-contact accent: an asymmetric pointed star grows into a short peak, followed by a subordinate broken ring and sparse travelling shards. Default total 0.34 s. No host sprite, textures, baked frames, screen flash, camera shake, damage or freeze-frame logic is required.

Open `preview/godot/effects/VFX-19_critical_hit/lab.tscn`. It shows actual 1× logical pixels and exact 2× nearest, with four palettes/presets and dark/light/checker backgrounds. Replay, pause, single-step, clear, reset, seed and playback rate are available. Inputs and preset changes replay immediately.

## Component contract

`critical.gd`: `play(world_position, settings)` snapshots config and bounded seeded shard geometry. `tick(seconds)` advances analytically; set `auto_tick=false` for a host clock. `clear()` cancels without a completion signal. Normal completion emits `finished` once after clearing all pixels. `replay()` uses the captured settings. A node owns a fixed 128×128 RGBA canvas and at most 12 shard records; simultaneous impacts use independent component instances or a caller-owned pool. No global state or material is changed.

A hit's world contact and orientation are caller inputs. This is visual only; no gameplay result is inferred from the drawn ring. The ring is not an attack hitbox.

## Parameters

Units are logical source pixels, seconds and degrees. Every value is applied on replay. Defaults live in `presets.json`.

| Parameter | Default | Bounds | Purpose |
|---|---:|---:|---|
| size | 30 px | 12–36 | Main spike reach; other geometry follows |
| angle | -28° | -180–180 | Direction of the elongated impact |
| duration | 0.34 s | 0.22–0.65 | Total visual lifetime |
| peak | 0.075 s | 0.04–min(0.12, 0.35×duration) | End of bright star plateau; growth uses first 60% |
| shards | 7 | 0–12 integer | Sparse moving fragments; zero disables |
| ring | 0.7 | 0–1 | Broken-ring radius factor; zero disables |
| intensity | 0.68 | 0–0.85 | RGB brightness multiplier, not alpha; zero makes no visible pixels |
| seed | 19 | integer | Stable directions/lengths/stagger |
| coreColor / edgeColor / coolColor | preset colors | HTML color | Finite star, body and remnant palette |
| playback_rate | 1 | 0–4 | Clock multiplier, applied during tick |

No additive blending is used. Coincident impacts overwrite/blend normally rather than accumulate unlimited brightness; keep the caller's emission rate bounded for crowded combat. The compact preset lowers intensity to 0.42. This does not claim medical or accessibility safety; review the actual game's density and backgrounds.

## Visual phases and portability

The rasterizer evaluates polygons and 1px lines on a logical image, then nearest-scales it. Seeded shapes do not randomize every frame. Six unequal spikes extend, briefly peak and retract at offset times; the moving shards use `1-(1-u)^2` outward motion plus small gravity, shrink along their own direction and leave a short dim endpoint. Three incomplete ring sections expand and shorten. These formulas and JSON parameters are portable design data; only the Godot implementation is delivered now.

## Reference

[ParticleFX Crit Hit](https://particlefx.studio/effects/crit-hit) was studied from its downloaded eight-moment strip and description: directional bright strike, expanding ring and travelling shards at different times. This implementation is shorter, lower brightness and independently coded. The source reference uses CodeManu assets with attribution requirements; none of its images, flipbooks or third-party code are included here. No claim of exact full-animation reproduction is made.

## Validation

From repo root: `godot --headless --path preview/godot --script res://effects/VFX-19_critical_hit/test_critical.gd`.

Tests cover deterministic images, 30/60/144 Hz analytical parity, parameter clamps/disable controls, final empty frame, one completion, repeated reuse, independent simultaneous instances and preview controls. Delivery also includes a new actual Godot fixed-time rendered preview with native controls and 1×/2× pixel inspection.

Preview **Multi hit** triggers three overlapping, independently seeded impacts with 45 ms spacing. The recorded showcase ends with this low-brightness overlap case.
