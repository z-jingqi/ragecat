# VFX-15 Monster death

A short, directional **host-aware dissolve plus falling fragments**. The same fragments land and remain as ground debris held for 3 seconds by default. A separate preset is an independent compact burst that does not require any host. Godot realtime prototype; no spritesheet, no Unity implementation.

Open `preview/godot/project.godot`, then run `effects/VFX-15_monster_death/death.tscn`. Left: native game pixels. Right: exact nearest-neighbor 3× detail. All previews run at real speed. Pause, frame step, replay, cancel, reset, flip, three backgrounds, and four presets are provided. Numeric controls replay the effect with the new configuration.

## Scope and host contract

`death.gd` exposes `set_host(Image)`, `configure(Dictionary)`, `play()`, `advance(delta_seconds)`, `reset()` and `completed`. The host image is a **snapshot of the death pose**, not a live animation controller. Image size must be ≤256×256; the demo uses an original code-generated 40×44 creature. The effect owns a separate Sprite2D/material and does not mutate the original host material. Caller must hide its original host when showing this snapshot, and decide deletion/gameplay itself. Place/rotate/scale the effect to match the captured host, including its pivot/attachment offset. `flipped` mirrors the snapshot and fragment spawn points.

Original image alpha, including transparent interior holes and fractional alpha, multiplies the dissolve mask. It is never replaced by a rectangular glow. The stable seeded 2-pixel cells give a clustered break-up; direction biases the disappearing front. Fragments release from sampled occupied snapshot cells exactly when their dissolve threshold is crossed, retaining the sampled host color while falling. The same particle identity travels ballistically to the foot strip and remains there; there is no separate patch spawned after the monster vanishes. These representative chips are **not a reconstructed cut-out of every source pixel**. Standalone mode starts its fragments at the origin and draws no host, so it cannot claim to dissolve an unbound monster.

Playback is externally clocked. `burst_finished` emits once when body/airborne ash end; `completed` emits once after the ground hold also ends and clears all debris. Reset/cancel clears particles and ground remains and restores the host snapshot; replay does not stack instances. `configure` stops/reset the instance; call `play` to replay. Different instances have private materials and state.

## Parameters

| Key | Default | Unit / accepted range | Meaning |
|---|---:|---|---|
| duration | 0.38 | seconds, 0.12–1.0 | Body/airborne phase deadline |
| dissolve_seconds | 0.20 | seconds, 0.06–duration | Body disappear time |
| fragment_count | 16 | integer, 0–24 | Falling pieces; total is max(this, enabled residue_count) |
| spread | 24 | px/s, 0–48 | Horizontal launch variation; corrected ballistic path still lands exactly |
| drift | 24 | px/s, 0–60 | Initial upward kick variation; 0 falls without an upward kick |
| seed | 17 | integer, 0–65535 | Stable dissolve/debris variation |
| direction_degrees | -90 | degrees, wrapped to [-180,180) | Direction in which erosion advances |
| cluster_size | 2 | source pixels, 1–6 | Stable dissolve cell size |
| edge_width | 0.07 | normalized threshold, 0–0.2 | Edge color band; 0 disables |
| tint | e5c19c | Color / hex | Edge and initial ash color |
| ash_color | 8b8795 | Color / hex | Falling fragment color when no host pixel color is available |
| residue_seconds | 3.0 | seconds, 0–8 | Ground hold after airborne phase; 0 disables |
| residue_count | 7 | integer, 0–20 | Ground pieces; 0 disables and removes extra wait |
| residue_spread | 14 | pixels, 0–32 | Horizontal spread about the feet |
| residue_color | 666476 | Color / hex | Dark settled debris |
| residue_highlight | 97909a | Color / hex | Occasional lighter pieces |
| ground_offset | (0,18) | local Vector2, pixels | Feet/ground anchor relative to effect pivot |
| host_mode | true | boolean | False enables standalone burst |
| flipped | false | boolean | Mirror host and source positions |

Numeric values outside ranges are clamped. Configure with finite numbers and valid Godot Colors. Size is controlled by the Node2D transform; preserve integer display scale for crisp game pixels. Colors are not HDR bloom. These parameters are **replay-time**, not hot geometry edits.

Each chip keeps its source size/color through landing, then cools in two palette steps. Settled debris is fixed to world positions captured at `play`, not continuously emitted or floating. Normal effect translation does not drag it. A jump greater than 128 world units from the play origin resets the instance to prevent pooled/teleported effects leaving stale marks; call `reset` explicitly before pooling or teleports of any distance. `clear_residue` removes only the existing ground patch; `reset` cancels the full timeline and restores the snapshot. The last 0.16 seconds remove a few whole pieces in a seeded order, without slow alpha fading. Ground layering uses the effect node’s normal z-order; caller places it on the appropriate ground layer. No persistent decal database or unlimited corpse accumulation is created.

The preset JSON in this folder is mirrored in the preview folder for distribution. Edit both together; the check script detects mismatch. `defaults` plus each preset's `overrides` are loaded by the demo. Reset restores preset 0. No invisible parameters or unsupported Unity promises.

## References

- [Simple 2D dissolve](https://godotshaders.com/shader/simple-2d-dissolve/) and [the author's dissolve source](https://github.com/gamedevserj/Godot-Shaders/blob/master/Dissolve/dissolve_shader.shader): researched the threshold and alpha-constrained edge technique. This implementation is independently written; no third-party textures, code blocks or visual assets were copied.
- Pixel-specific choices here: fixed source-pixel cell noise, directional front, restrained edge color, 35 ms modest flash, analytically positioned 1–2 px ash, bounded lifetime.

Run `python3 effects/pixel/VFX-15_monster_death/tests/run_checks.py` from repository root. See QA.md for verified scope.
