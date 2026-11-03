# VFX-07 · Persistent ground fire / 持续燃烧地面

Reusable, procedural pixel ground fire for Hou Yi's Solar zones. This is a new
ground-area subtype, separate from the one-shot explosion and sprite-bound
burning status. It has no collision, damage, strongest-overlap selection, timers,
input handlers or gameplay RNG. It does not create or remove logical zones.

Low, staggered gold/orange flame tongues sit over a porous, translucent coal bed.
A thin full circle always marks each live zone. All outlines draw above all
neighboring fills, so overlap cannot silently hide an earlier zone's boundary.
No glow, smoke cloud, opaque filled disk, baked animation or external art.

## Runtime integration

Copy these two adjacent files from `preview/godot/effects/VFX-07_ground_burn/`:

- `ground_burn.gd`
- `ground_burn.gdshader`

The shader preload is relative, so the pair can move together without changing
its path. The host owns lifetime and updates; it may pool/reuse the component.

```gdscript
const GroundBurn = preload("res://vfx/ground_burn/ground_burn.gd")
var visual = GroundBurn.new()
ground_layer.add_child(visual)
visual.play(zone.position, zone.radius, zone_lifetime, {"seed": 37})
# On the host's simulation update, never an independent wall-clock update:
visual.seek(zone_lifetime - zone.remaining)
# When gameplay deletes the zone, cancels, resets or leaves the scene:
visual.clear()
visual.queue_free() # Optional; the caller can also return it to a pool.
```

`play(origin, radius, duration, options)` snapshots settings and starts at age 0.
Origin/radius use the parent's local world coordinates; no screen-space position
or quantization is written back to the caller. Radius and duration remain exactly
as provided. Nonfinite/nonpositive required geometry/lifetime is rejected.

`seek(seconds)` clamps absolute age into `[0, duration]`. At exactly duration it
hides every visual pixel. Seeking earlier can scrub a completed preview; after
explicit `stop()` or `clear()`, seeks have no effect until another `play()`.
`advance(delta)` is optional and accepts only finite positive caller deltas.
There are no autonomous `_process` or `_physics_process` callbacks. Pausing the
game's update therefore freezes geometry and phase without a separate clock.

Reserve the ground layer's Z and Z+1 below actors and important telegraphs.
The body's relative Z is 0 and the outline's is 1. All live zones that should
retain mutual outlines must share the same effective parent Z; placing whole
zone nodes at differing Z levels would defeat this ordering. Do not put this
ground layer above enemy sprites. Host opacity/visibility/transform is honored.

The geometric circle uses the supplied radius, not a scaled explosion. Visible
edge pixels are sampled on the art grid, so the raster silhouette differs from
the continuous circle by at most one art pixel. This is presentation only;
damage must keep using the caller's original circle and overlap policy.

## Visual options

Defaults are defined by `sanitized()` in the runtime script. Options are applied
on `play()`; replay the same instance to change the visual preset. Options do not
change zone radius, lifetime or damage.

| Option | Default | Bounds / meaning |
|---|---:|---|
| `pixel_size` | 2 | 0.5–8 world units per art pixel |
| `flame_count` | 16 | 0–24 fixed analytic tongues |
| `flame_height` | 14 | 0–40 world units, also limited to 40% of radius |
| `intensity` | 0.8 | 0–1 flame height and heat; 0 leaves ground and boundary |
| `ground_opacity` | 0.22 | 0–0.5 porous coal-bed opacity |
| `outline_width` | 2 | 0.5–6 world units, at least one art pixel |
| `enter_time` | 0.10 | 0–1 seconds to ignite; boundary is immediate |
| `exit_time` | 0.25 | 0–2 seconds to lower flame height before exact expiry |
| `seed` | 37 | integer 0–4095; independent shape/phase variation |
| `core_color` | `ffe5a0` | bright inner flame |
| `body_color` | `ffb34b` | gold middle flame |
| `flame_color` | `e96632` | orange edge and hot seams |
| `coal_color` | `542d29` | translucent ground patches |
| `outline_color` | `ed9849` | persistent area boundary |

Color values accept Godot `Color` or HTML color strings. Palette alpha is forced
to 1; layer opacity is controlled separately. Invalid visual values fall back to
defaults; finite out-of-range options are clamped. Caller dictionaries are never
modified or retained by reference. No shared material instances.

## Preview and checks

```sh
godot --headless --editor --path preview/godot --import --quit
godot --headless --path preview/godot --script res://effects/VFX-07_ground_burn/test_ground_burn.gd
godot --headless --path preview/godot --script res://effects/VFX-07_ground_burn/test_lab.gd
godot --path preview/godot res://effects/VFX-07_ground_burn/lab.tscn
# Requires a real render display; --headless cannot verify pixels:
godot --path preview/godot --rendering-method gl_compatibility --script res://effects/VFX-07_ground_burn/test_render.gd
```

The preview compares actual 36-world-unit radius, matching 2× nearest detail,
and overlapping zones of different radius and seed. Controls: pause, single
frame, replay, 0.25× playback, background, clear, radius, height and intensity.
It loops a 4-second externally driven lifetime with a clear gap between cycles.

The preview layout is 1280×720. For MovieWriter capture, use an external disposable
copy of the preview project with its **initial project viewport** set to 1280×720;
Godot locks movie size before the scene's `_ready()` window setup. Copy source
unchanged, do not commit the capture copy, frames, reports or movie.

```sh
godot --path /absolute/capture-project --rendering-method gl_compatibility \
  --audio-driver Dummy --fixed-fps 60 --disable-vsync \
  --write-movie /absolute/outside-repository/ground-burn.avi --quit-after 600 \
  res://effects/VFX-07_ground_burn/lab.tscn
```

Contract tests cover caller geometry, local transforms, no autonomous clock,
pause, scrub, expiry, clear/replay, invalid options, fixed surface/loop bounds,
material independence and frame rates. Native rendered-pixel tests additionally
cover footprint, transparent ground, visible flames, pause/replay image identity,
phase evolution, exact expiry and an earlier outline under a later overlapping
zone. These checks do not replace the receiving game's damage and zone tests.

## References and portability

See [ALGORITHM.md](ALGORITHM.md) for the analytic design and the actual visual
references inspected. This implementation is original Godot code and shader,
with no third-party images or copied implementation. It is not a Unity package.
