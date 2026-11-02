# Poison · standalone attached status

Second independent status rebuild, following burning. This is **poison on a sprite**, not the world poison cloud, poison projectile, floor hazard or a gameplay damage implementation. Burning and the previous four-state prototype are unchanged.

## Reference

Reviewed [Sprite FX](https://particlefx.studio/effects/sprite-fx), the actual poster and eight-moment strip for [Poison Damage Over Time](https://particlefx.studio/effects/poison-damage-over-time), and its layer breakdown. The key motifs are a poisoned body, rising hollow bubbles, falling drips, thin gas and intermittent poison ticks. The reference's strong full-body flash and forced shake are deliberately not the default here: the character stays readable and multiple targets do not flash white together.

All geometry and motion are generated in code. No reference image, sprite sheet or third-party runtime is included. The pixel adaptation does not claim to reproduce the HD reference exactly.

## Host integration

Runtime: `preview/godot/effects/VFX-18_status_effects/poison/poison.gd`.

Add one component as a **sibling** of its Sprite2D host. Call `bind_host(host)`, `configure(parameters)`, `play(seconds)`, then `tick(delta)` once per update. `play()` on an active effect refreshes duration without resetting the phase or particles. `cancel()` fades out; `cancel(true)` and `clear()` remove immediately. `finished` emits after timed/faded completion. No health, position, animation, gameplay timers or collision state are changed.

Bubbles and gas originate on the current texture frame's alpha boundary. Drips specifically originate on downward-facing alpha edges, not a rectangle around the actor. Frames, region rectangles, horizontal/vertical flip and offsets are supported. Emission retains transparent holes in the source mask. Particles can subsequently pass across a hole as independent foreground objects; the original sprite alpha is not rewritten.

Frame/texture/region/flip changes automatically rebuild the source mask. If mutating an existing ImageTexture in place, call `invalidate_mask()`. Missing/empty frames or frames larger than 128×128 logical pixels are rejected. Changing valid frame dimensions reallocates buffers safely. Scale the host to enlarge the presentation.

The material, shader, texture, transform and pose are left installed. A low RGB-only `self_modulate` tint preserves host alpha. External modulation changes become the new base; clearing/deletion restores the latest base unless another system has already taken ownership. The body shader must honor CanvasItem modulation to display the tint; the attached particles remain separate.

Back gas occupies host effective Z−1, bubbles/drips Z+1. Reserve these slots and keep the ground behind the back layer. Sibling placement preserves ancestor modulation and CanvasLayer behavior. Local drips fall toward the bottom of the source frame and briefly flatten; this is presentation only, not world collision or a persistent puddle. Detached trails should use a separate world-space effect.

## Configuration

| Parameter | Default | Meaning / bounds |
|---|---:|---|
| intensity | 0.32 | 0–0.7; 0 disables both tint and particle visibility |
| bubble_rate | 10 | 0–40 bubbles/sec |
| drip_rate | 5 | 0–40 drips/sec |
| gas_rate | 3 | 0–40 gas puffs/sec |
| bubble_size | 2.4 | 1–5 logical-pixel base radius |
| rise_speed | 10 | 1–24 logical pixels/sec |
| gravity | 32 | 0–80 logical pixels/sec² for local drips |
| pulse_period | 0.9 | 0.3–3 seconds |
| pulse_strength | 0.14 | 0–0.4; 0 disables periodic body accents and small bursts |
| enter_time | 0.14 | 0.02–1 second |
| exit_time | 0.35 | 0.03–2 seconds |
| seed | 27 | Integer; next fresh play, independent crowd phases |
| bubble_color | `82b54b` | Bubble outlines |
| highlight_color | `c4d980` | Bubble rim highlights and drip highlights |
| drip_color | `6d982e` | Drips and small local splats |
| gas_color | `3c6037` | Back gas |
| rim_color | `619139` | Sparse damp contour |
| body_color | `98d858` | Multiplicative body tint |
| play duration | 3 | Positive seconds, capped at 60 |

All six palette channels are independently configurable HTML colors; there is no fixed lime or white highlight overriding them. Numeric parameters clamp safely and nonfinite values keep the previous configuration. Rate zero also suppresses that layer's timed bursts. Maximum 128 live particles per component. Pool reuse uses `clear()` then `play()`; the component does not accumulate emitters or allocate scene nodes per particle.

## Preview and checks

`godot --path preview/godot res://effects/VFX-18_status_effects/poison/poison.tscn`

Five independently seeded animated hosts, native 1× plus identical 2× nearest views, dark/light backgrounds, and a lower-intensity **purple six-channel palette** comparison. Controls: replay, refresh, cancel, clear, pause, step, animation toggle and intensity. The preview reuses the original procedural two-frame host fixture; runtime poison does not depend on the burning component.

`python effects/pixel/VFX-18_status_effects/poison/run_checks.py`

Checks include source-edge and lower-edge emission, holes/frame/flip/region/resize, independent palette channels, duration at 30/60/144 Hz, zero emission rates, reuse, pool caps, host loss, external color changes and cleanup. `test_render.gd` isolates body tint from external particles to check exact alpha, existing custom material behavior and restoration on clear/delete.
