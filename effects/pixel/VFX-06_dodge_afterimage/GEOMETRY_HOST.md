# Geometry-host adapter

`preview/godot/effects/VFX-06_dodge_afterimage/geometry_afterimage.gd` adapts the existing short cooling silhouette history and directional one-pixel accents to hosts drawn with geometry. It does not replace, move, recolor or animate the host. No sprite artwork, textures, attack animation or gameplay code is introduced.

## Contract

- `configure(overrides)` applies clamped settings. The compact default is six silhouettes, 0.025 s sampling, 0.16 s life, 0.42 opacity, ten-pixel minimum spacing and short 0.08 s directional accents. Configuration names match the canonical effect where applicable.
- `start(world_transform, geometry, host_alpha=1)` starts a clean accepted dash. Supply the actual host global transform. The adapter does not decide whether a dash is allowed.
- After each real movement step, `advance(dt, world_transform, geometry, host_alpha=1)` records only the segment between the last supplied transform and the new supplied transform. It never writes a transform or simulates a player. The current caller-supplied appearance is authoritative, as in the original Sprite2D adapter. Subdivide updates at appearance changes if historical pose timing must be exact.
- `stop()` stops new captures but leaves a short finite tail. Keep calling `advance` to age that tail. For the final dash step, advance before stop.
- `set_paused(true)` freezes time, capture and position. `reset()` immediately clears history, accents and pause. Reset on cancellation, death, run end, restart or pool reuse. A large teleport clears history instead of bridging it.
- Geometry coordinates are host-local. Each command is `circle` (`center`, `radius`, `color`), `polygon` (`points: PackedVector2Array`, `color`) or `line` (`from`, `to`, `width`, `color`), selected by `kind`. Host alpha multiplies captured command alpha once. Snapshot geometry and transforms are copied, not live aliases. Supply only actual body/facing geometry, not invulnerability or quantitative cooldown rings. This is command-based silhouette capture, not an offscreen framebuffer snapshot: opacity applies once per primitive, so overlapping translucent commands still composite separately. Prefer the body silhouette and detached facing marker, omitting facial detail, for a restrained trail without stacked alpha.

There is no `_process`, physics callback, host reference, gameplay signal, material override or automatic deletion. The effect node belongs below the host and hostile warnings inside the game's existing clip. Captured transforms stay in world space even if the effect parent moves. Rendering uses non-antialiased captured geometry and pixel-stepped accents; it does not manufacture a production character sprite.

Capacity is bounded to 24 snapshots and 24 accents, 32 commands per snapshot and 256 polygon vertices per command. Defaults are lower. Long time steps skip already-expired history and cap sampling work. No scene objects are spawned per capture. Unsupported or nonfinite commands are ignored; bad transforms cancel.

## Reference and verification

The public eight-moment [Dash Afterimage strip](https://particlefx.studio/effects/dash-afterimage) and the actual canonical Ragecat Godot preview were inspected. Retained the clear moving front, ordered fading/cooling history and short uneven direction accents. No launch ring, sword cut, dust or reference artwork is imported. Sparse reference moments are not a full animation reproduction.

`test_geometry.gd` covers 30/60/144 Hz, bounded history, exact supplied path segments, immutable shape snapshots, parent movement, stationary suppression, pause, invalid input, teleport, long stalls, finite stop and 1,000 reset/reuse cycles. `test_geometry_render.gd` is a separate native-renderer check for source alpha, silhouette, historical world transforms under effect translation/scale, frozen pause pixels, accents and complete cleanup. A headless pass alone does not establish appearance.
