# VFX-12 Ground fracture / 震地

A standalone, procedural pixel ground-impact preview. This subtype covers propagating branching ground cracks, a subordinate broken shock front, thrown rocks and sparse settling dust. It does not implement combat collision, terrain deformation, camera shake or a character animation.

## Preview

Open `preview/godot/effects/VFX-12_earth/lab.tscn`. Left is actual logical pixel size; right is exactly 2× nearest. Four presets, dark/light/checker backgrounds, replay, pause, single step, clear and reset are provided. Each change restarts a deterministic shot. Renderer: `earth.gd` in the same directory. No spritesheet, baked animation, third-party textures, Unity runtime or shader dependency.

`play(world_position, config)` builds bounded geometry once. `tick(seconds)` evaluates analytical time; `auto_tick=false` supports a game-controlled clock. `clear()` cancels without emitting `finished`; normal completion emits it once after all visual pixels clear. `replay()` uses the captured settings. Seeded geometry remains stable between frames. Move the node only to relocate the whole effect; geometry is relative to its ground anchor.

## Parameters

All defaults are in `presets.json`. Units are logical source pixels and seconds. Values are snapshotted at play; UI changes replay.

- `radius`: 42 px, range 12–52. Ground x radius; y radius is 0.42× for a shallow ground-plane view.
- `angle`: 0 degrees, -180–180. Rotates fracture layout on that plane.
- `duration`: 0.9 s, 0.5–1.4. Full shot duration.
- `propagation`: 0.15 s, 0.06–min(0.3, 0.4×duration). Crack leader travel, not total lifetime.
- `branches`: 7, 3–12. Seeded primary fractures with subordinate branches.
- `rocks`: 10, 0–18. Disable with zero. Independent ballistic fragments, then land and shrink.
- `height`: 26 px, 4–38. Maximum launch height.
- `dust`: 8, 0–14. Sparse block-eroded dust puffs; zero disables.
- `seed`: 38, integer. Same seed/config/time produce the same image.
- `crackColor`, `hotColor`, `rockColor`, `lightColor`, `dustColor`: HTML colors. Finite palette, hard alpha.
- `playback_rate`: component time multiplier, clamped 0–4 during tick.

## Implementation and portability

The component rasterizes bounded geometric primitives into a 160×128 RGBA image, updates one texture, and draws nearest. Crack leaders traverse a deterministic polyline; each branch writes on only after propagation reaches its junction. The hot state cools to earth color and contracts into the center. A brief broken ellipse marks the pressure front but does not substitute for cracks. Rocks use `height(t)=4*h*t*(1-t)` and settle before shrinking. Dust expands slightly and erodes through a fixed cell mask. A future engine port can reuse these equations and preset contract; the current implementation is Godot only.

## References and license

Visual study: [ParticleFX Pixel Art Ground Slam Shockwave](https://particlefx.studio/effects/pixel-art-ground-slam-shockwave). The actual eight-time preview strip was downloaded and inspected: flattened front, radial cracks, thrown stones and dust wall appear as separate layers. We use a shorter independent interpretation, not a complete animation reproduction. Reference images and third-party implementation code are not included in production. This effect's shapes, rasterizer, timing and code were authored in this repository.

## Checks

Run `godot --headless --path preview/godot --script res://effects/VFX-12_earth/test_earth.gd` from repository root. This covers deterministic image/geometry, three frame rates, bounded primitives, pixel canvas margins, repeated clear/replay and preview controls. Native preview and actual rendered-frame QA accompany delivery. No gameplay hit area is inferred from the art.
