# VFX-13 · Monster spawn

A short ground-anchored arrival: a broken elliptical summoning ring contracts, twelve sparse points stream inward, then the actual host silhouette resolves upward from the feet. Transient pixels clear at 0.55 seconds. This is the **monster arrival** subtype, not a teleport movement system or a generic magic circle generator.

## Run

Open `preview/godot/project.godot`, then run `effects/VFX-13_monster_spawn/lab.tscn`.

The preview shows normal 1× game pixels and an exact 2× nearest-neighbor detail. Replay applies the pending sliders. Pause, single-frame, Cancel, reset, color preset and seed controls are available. The demonstration monster is generated from rectangular pixels at runtime, not a production character asset or spritesheet.

## Integration

`spawn.gd` is a reusable `Node2D`. Place it at the intended monster's feet. Optionally assign an existing `Sprite2D` to `host`, call `configure(dictionary)` between plays, then `play()`. The caller advances `tick(delta_seconds)`; this explicit clock supports pause and deterministic preview. No gameplay entity or collision is created.

- `appeared` is emitted once after the body reveal completes, at 0.3465 seconds with default settings. This is the visual cue only; the game owns activation rules.
- `completed` is emitted once when all transient graphics have cleared.
- `cancel()` immediately removes the effect and restores the bound host's previous material and visibility. Replay safely cancels the previous run.
- Successful completion restores the original material and leaves the host visible. Freed hosts are tolerated. Instances do not share reveal materials.
- Host appearance is required for an actual body reveal. With no host, only the ring and particles are drawn; this is not advertised as a completed body materialization.
- The reveal temporarily replaces the host material. Custom material behavior must be composed deliberately in the target integration. Do not attach simultaneous material-owning effects to one sprite without a host-side coordinator.

## Parameters

| Key | Default | Range / units | Application |
| --- | --- | --- | --- |
| duration | 0.55 | 0.18–2.0 seconds | Entire transient timeline |
| radius | 29 | 10–56 art pixels | Initial ground gathering radius |
| particle_count | 12 | 0–32 | Finite precomputed points |
| ring_width | 1 | 1–3 art pixels | Ellipse radial thickness |
| reveal_at | 0.35 | 0.1–0.7 normalized time | Body reveal start |
| reveal_span | 0.28 | 0.08 to 0.9−reveal_at | Body reveal duration |
| seed | 13 | Integer | Stable particle schedule per play |
| palette | muted teal / mint / ivory | Three color strings | Ring shade, particles, reveal edge |

Changes apply only between plays; in-progress configuration calls are ignored, avoiding particle re-seeding mid-animation. Positions rasterize to whole art pixels. The effect has no bloom, smooth alpha fade, screen flash, camera movement or screen shake.

## Delivery scope

Godot procedural prototype plus the engine-neutral algorithm below. No Unity runtime code and no baked animation sequence are required. Future Unity work must port timing, pixel snapping, shader alpha rules and host restoration deliberately.

See `ALGORITHM.md` and `QA.md` for the implementation contract and checks.
