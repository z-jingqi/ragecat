# VFX-09 · Frost Ring

A reusable, damage-only Frost Ring visual for Mountains and Seas. One pale-cyan
pixel annulus snaps outward, exposes short inner crystalline facets, then breaks
and clears. Three opaque colors, a few small inward flecks, no blur, bloom,
screen distortion, persistent field, ice shell, slow, freeze or damage logic.
This fills the circular-pulse gap; it does not replace the existing ice-crystal
line or attached frost/frozen statuses.

## Source and preview

Runtime source lives in `preview/godot/effects/VFX-09_frost_ring/`:

- `frost_ring.gd` and `frost_ring.gdshader`: the only two files a game needs.
- `runtime_preview.tscn` / `.gd`: isolated preview with 100, 120 and 140-unit rings.
- `test_frost_ring.gd`: focused state and parameter tests.
- `render_probe.gd`: native pixel-boundary, pause, replay, transform and cleanup tests.

Open the preview scene with F6. Space pauses; R restarts; T switches quarter-speed;
+/- changes the three actual radii together; B changes the background. The four
lower examples freeze expansion, full reach, fracture and clearance. Witness ticks
lie outside the true radius and are preview helpers, not part of the effect.

```sh
godot --path preview/godot res://effects/VFX-09_frost_ring/runtime_preview.tscn
godot --headless --path preview/godot --script res://effects/VFX-09_frost_ring/test_frost_ring.gd
godot --path preview/godot --script res://effects/VFX-09_frost_ring/render_probe.gd -- --output=/absolute/outside/repo/frost
```

The last command needs a real rendering display. Its output directory must already
exist; it saves 15 transparent lifecycle PNGs. Headless tests cannot validate
shader compilation or appearance. Record native output with Godot MovieWriter;
keep movies, PNG captures and logs outside the repository.

## Integration contract

```gdscript
const FrostRing = preload("res://path/to/frost_ring.gd")
var pulse = FrostRing.new()
world_effects.add_child(pulse)
pulse.play(cast_origin, actual_damage_radius, {"duration": 0.18, "pixel_size": 2.0})
# Advance from the same simulation step used by the existing skill controller.
pulse.advance(delta)
if pulse.done:
    pulse.queue_free()
```

`origin` and `actual_radius` use the parent's local/world coordinate system, not
screen pixels. Supply a stable world-effects parent rather than attaching to a
moving actor when the cast must remain at its snapshot origin. Keep that parent's
world scale at 1; normal camera/viewport scaling works. The renderer does not
change the passed origin/radius, choose enemies, delay damage, or retain targets.
No signal, timer, tween, process callback, collision or physics node is installed.
The caller remains responsible for damage, clock, scene pause, reset and disposal.

- `play(origin, actual_radius, options={})` resets the previous run; snapshots options.
- `advance(delta)` advances the caller-owned clock; invalid/nonpositive deltas are ignored.
- `paused = true` freezes `advance`; `seek(seconds)` remains an explicit editing operation.
- `seek(seconds)` samples a deterministic absolute age, clamped to the duration.
- `stop()` immediately hides the effect; `replay()` explicitly restarts its saved cast.
- `reset()` clears the cast and replay state without allocating another surface.
- `done` becomes true exactly at duration. Neither expiry nor stop frees the node.

A finite radius in `(0, 4096]` is accepted verbatim. Invalid origins/radii clear the
visual rather than silently shrinking the gameplay footprint. `art_pixel_size`
reports the effective art grid, normally the requested size; very small circles
use at most radius/8 to retain enough samples for their outline. Sub-screen-pixel circles can still
be invisible at a distant camera zoom, as with any pixel-art geometry. The entire colored art pixel is
clipped inside the requested circle, so the visible edge is conservatively inside
its exact mathematical boundary by at most approximately two art pixels.

## Adjustable options

| Option | Default | Safe range / meaning |
|---|---:|---|
| duration | 0.18 | 0.05–2 seconds; presentation only |
| pixel_size | 2 | 0.5–8 world units per art pixel |
| thickness | 4 | 1–8 art pixels; also bounded to 18% of the art radius |
| expansion_ratio | 0.40 | 0.15–0.65 of total lifetime |
| hold_ratio | 0.10 | 0–0.20 of total lifetime |
| facets | 18 | 8–32 angular facets, integer |
| shards | 12 | 0–24 inward crystal flecks, integer |
| seed | 29 | 0–65535, integer; stable geometry, not gameplay RNG |
| highlight | e5fbff | Color or HTML color string |
| body | 83d5e7 | Color or HTML color string |
| shade | 397eaa | Color or HTML color string |

Invalid/nonfinite numeric options fall back to defaults, finite values clamp,
unknown options are ignored and palette alpha is opaque. Parent CanvasItem
modulation remains effective. Changing options does not change damage, hit range,
attack cooldown or status behavior. The 180 ms default matches the existing
Mountains element feedback duration; duration can be supplied from game config.
