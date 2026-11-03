# VFX-06 — Dodge afterimage

Short historical silhouettes for a moving `Sprite2D`. The component does not move the host or grant invulnerability. It samples the current frame, flip, pivot and world transform rather than moving a fixed decal behind it.

## Preview

Run `res://effects/VFX-06_dodge_afterimage/dodge.tscn` in the Godot preview project. The upper panel is actual 1×, the lower is a nearest-neighbour 2× view of the **same viewport**. Straight, diagonal, curved and reversed/animated dashes demonstrate the component without a rotation dependency. Pause, frame-step, replay, clear, colour, background and life controls are available.

The hero is an original procedural placeholder, not a production character. No exported animation sheet is used; the tiny two-pose fixture exists only to prove that historical animation frames do not change with the live host.

## Integration

Add `afterimage.gd` to a Node2D. Call `start(sprite)` when a dash begins; after updating the sprite's pose, call `advance(delta, sprite)` once per simulation step. `stop()` stops new captures and lets old poses expire. `reset()` immediately clears all history. Call reset for a deliberate teleport or pool reuse. A displacement above the teleport threshold automatically clears history and postpones the next capture.

Sampling time is fixed and intermediate transforms are interpolated between supplied transforms. Missing animation changes cannot be reconstructed: the frame supplied by the game at a call is authoritative for captures during that step. For exact animation-event boundaries, subdivide that update at the event. Stationary poses do not keep refreshing the trail. Parent motion does not drag already captured poses.

The source frame is cropped from region/hframes/vframes and copied at capture time. Transparent holes and partial alpha are retained. Texture RGB can be mixed with the configured tint, then cools toward the ending tint. Each snapshot fades independently, while its pixel edges remain nearest filtered. Snapshots render one Z layer behind the captured sprite. A maximum of 24 reusable Sprite2D nodes bounds the pool.

This version samples the sprite's texture and local modulate/self_modulate, not arbitrary custom shader output, CanvasModulate, parent colour filters, skeletons or meshes. For those hosts provide an explicitly baked current appearance or a dedicated snapshot adapter. No material on the host is replaced.

## Parameters

| Parameter | Default | Range / unit | Meaning |
|---|---:|---|---|
| interval | 0.035 | 0.01–0.2 s | Minimum sampling cadence |
| lifetime | 0.22 | 0.03–1 s | Each ghost's total age |
| hold | 0.025 | 0–half lifetime, s | Short initial plateau |
| max_images | 8 | 1–24 | Historical node capacity |
| opacity | 0.62 | 0–1 | Initial alpha multiplier |
| tint | cyan | RGBA | New-ghost tone |
| end_tint | indigo | RGBA | Old-ghost tone |
| color_mix | 0.85 | 0–1 | Source colour versus tint |
| minimum_distance | 2 | world px, ≥0 | Prevent stacked stationary snapshots |
| teleport_distance | 80 | world px, ≥4 | Break history on discontinuous movement |

Parameters are sanitized each update. Appearance/lifetime changes affect existing history; pose/frame/flip/pivot stay captured. Changing capacity takes effect on the next capture. Restart is the clearest way to apply a whole preset. No RNG or seed parameter is exposed because the effect is deterministic.

## Directional speed accents

The optional `speed_lines` layer adds bounded one-pixel short strokes, aligned to the real sampled movement direction rather than a fixed screen angle. Four unequal flank offsets and lengths keep the strokes from forming a regular ladder. They retract and fade within `line_lifetime`, independently of the pose history. They do not draw a slash, long beam, launch ring, or change the host's pose. World-space history is retained; teleport and reset clear both layers.

Additional parameters: `speed_lines=true`, `line_length=18` (2–36 world px), `line_spread=14` (0–32 world px), `line_opacity=0.8` (0–1), `line_lifetime=0.09` (0.02–0.25 s), `minimum_speed=100` (world px/s, ≥0). Accent history is capped at 24. Host local alpha multiplies the strokes. Use `speed_lines=false` for bare silhouettes.

The preview demonstrates a compact dash preset: 0.20 s movement with a fast onset/ease-out, 0.025 s capture interval, 0.16 s ghost life, six silhouettes maximum, and 10 px minimum spacing. These movement values belong to the demonstration, not the reusable component: gameplay remains authoritative.

## Reference study

- https://particlefx.studio/effects/iaido-slash
- https://particlefx.studio/effects/dash-afterimage
- https://particlefx.studio/effects/shadow-dash

The public eight-moment strips were downloaded and inspected before implementation. They show a clear moving front and older coloured silhouette layers losing prominence in order. This implementation uses short pose histories and independent cooling/fade, without copying their character assets, exported sheets, scene code, dust or launch rings. The Iaido Slash revision borrows only the decisive onset and tightly staggered silhouette spacing, not its sword cut or petals; Shadow Dash informs the restrained directional speed accents. Eight sparse moments are not claimed to be a complete frame-by-frame animation reproduction.

## Tests

`godot --headless --path preview/godot --script res://effects/VFX-06_dodge_afterimage/test_dodge.gd`

`godot --path preview/godot --script res://effects/VFX-06_dodge_afterimage/test_render.gd`

The first checks frame snapshots, alpha copies, flip/pivot, stationary suppression, historical transform retention, bounded pool, expiry, teleport, reuse and fixed-time sampling at 30/60/144Hz. The renderer test checks transparent holes and half-alpha source with host opacity, fixed historical position, and complete final cleanup.

## Geometry hosts

For code-drawn hosts without a `Sprite2D`, use [GEOMETRY_HOST.md](GEOMETRY_HOST.md). The adapter records caller-supplied body geometry and actual transforms with the same compact cooling history and short directional accents, under an external clock.
