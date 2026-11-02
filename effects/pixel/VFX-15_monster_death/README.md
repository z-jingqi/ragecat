# VFX-15 Monster death

A short, directional **host-aware dissolve plus sparse ash**. A separate preset is an independent compact burst that does not require any host. Godot realtime prototype; no spritesheet, no Unity implementation.

Open `preview/godot/project.godot`, then run `effects/VFX-15_monster_death/death.tscn`. Left: native game pixels. Right: exact nearest-neighbor 3× detail. All previews run at real speed. Pause, frame step, replay, cancel, reset, flip, three backgrounds, and three presets are provided. Numeric controls replay the effect with the new configuration.

## Scope and host contract

`death.gd` exposes `set_host(Image)`, `configure(Dictionary)`, `play()`, `advance(delta_seconds)`, `reset()` and `completed`. The host image is a **snapshot of the death pose**, not a live animation controller. Image size must be ≤256×256; the demo uses an original code-generated 40×44 creature. The effect owns a separate Sprite2D/material and does not mutate the original host material. Caller must hide its original host when showing this snapshot, and decide deletion/gameplay itself. Place/rotate/scale the effect to match the captured host, including its pivot/attachment offset. `flipped` mirrors the snapshot and fragment spawn points.

Original image alpha, including transparent interior holes and fractional alpha, multiplies the dissolve mask. It is never replaced by a rectangular glow. The stable seeded 2-pixel cells give a clustered break-up; direction biases the disappearing front. Ash is sampled from occupied snapshot cells, but is **not exact image-colored debris or a reconstructed cut-out of every source pixel**. Standalone mode starts its fragments at the origin and draws no host, so it cannot claim to dissolve an unbound monster.

Playback is externally clocked. Completion emits once and clears all debris. Reset/cancel clears particles and restores the host snapshot; replay does not stack instances. `configure` stops/reset the instance; call `play` to replay. Different instances have private materials and state.

## Parameters

| Key | Default | Unit / accepted range | Meaning |
|---|---:|---|---|
| duration | 0.38 | seconds, 0.12–1.0 | Total effect deadline |
| dissolve_seconds | 0.20 | seconds, 0.06–duration | Body disappear time |
| fragment_count | 9 | integer, 0–24 | Sparse ash count; 0 disables ash |
| spread | 24 | px/s, 0–48 | Radial debris velocity |
| drift | 24 | px/s, -40–60 | Upward velocity bias |
| seed | 17 | integer, 0–65535 | Stable dissolve/debris variation |
| direction_degrees | -90 | degrees, wrapped to [-180,180) | Direction in which erosion advances |
| cluster_size | 2 | source pixels, 1–6 | Stable dissolve cell size |
| edge_width | 0.07 | normalized threshold, 0–0.2 | Edge color band; 0 disables |
| tint | e5c19c | Color / hex | Edge and initial ash color |
| ash_color | 8b8795 | Color / hex | Cooling debris color |
| host_mode | true | boolean | False enables standalone burst |
| flipped | false | boolean | Mirror host and source positions |

Numeric values outside ranges are clamped. Configure with finite numbers and valid Godot Colors. Size is controlled by the Node2D transform; preserve integer display scale for crisp game pixels. Colors are not HDR bloom. These parameters are **replay-time**, not hot geometry edits.

The preset JSON in this folder is mirrored in the preview folder for distribution. Edit both together; the check script detects mismatch. `defaults` plus each preset's `overrides` are loaded by the demo. Reset restores preset 0. No invisible parameters or unsupported Unity promises.

## References

- [Simple 2D dissolve](https://godotshaders.com/shader/simple-2d-dissolve/) and [the author's dissolve source](https://github.com/gamedevserj/Godot-Shaders/blob/master/Dissolve/dissolve_shader.shader): researched the threshold and alpha-constrained edge technique. This implementation is independently written; no third-party textures, code blocks or visual assets were copied.
- Pixel-specific choices here: fixed source-pixel cell noise, directional front, restrained edge color, 35 ms modest flash, analytically positioned 1–2 px ash, bounded lifetime.

Run `python3 effects/pixel/VFX-15_monster_death/tests/run_checks.py` from repository root. See QA.md for verified scope.
