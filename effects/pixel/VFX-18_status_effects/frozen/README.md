# Frozen · standalone attached status

Third independent status rebuild. This effect freezes the **appearance of a sprite**, not its gameplay movement, animation, physics or input. It is not a world ice spike or an ice projectile. Burning and poison remain separate components.

## Reference and visual design

Primary reference: the actual poster and eight-moment strip of [Freeze Effect](https://particlefx.studio/effects/freeze-effect), linked from [Sprite FX](https://particlefx.studio/effects/sprite-fx). The adaptation targets its encasing ice material and coherent breakup, without claiming frame-exact timing or an exact recreation.

- An uneven freezing front travels upward from the feet.
- A connected crust thickens the source silhouette locally; irregular front slabs introduce distinct light cyan faces, blue backs, narrow selected bevels and short dark seams while retaining the body underneath.
- Five unequal source-anchored front slabs and a few grouped edge plates grow with the crust. A subtle surface gleam and sparse low mist support the held state without replacing the ice material with a glow.
- On release, the same surface panels and front slabs separate, rotate and drift downward, exposing the original body progressively. Their identity is maintained rather than deleting the shell and spawning unrelated debris. There is no white explosion or full-body flashing pulse.

All visual geometry is generated in code. Reference images and third-party assets are not bundled. This is a restrained pixel adaptation, not a pixel-identical reproduction of the HD references.

## Integration

`preview/godot/effects/VFX-18_status_effects/frozen/frozen.gd`

Create the component as a **sibling** of a Sprite2D, then call `bind_host(sprite)`, `configure(parameters)`, `play(sustain_seconds)` and `tick(delta)` once per update. `play()` with no argument uses `sustain_time`. Total lifetime is formation + sustain + release. `play()` during sustain refreshes its remaining duration without restarting formation; reapplying during release reforms from the current coverage. `cancel()` begins thaw from the current coverage; `cancel(true)` / `clear()` remove immediately. `finished` emits on normal or faded completion. Reuse with `clear()` then `play()`.

The current texture frame, hframes/vframes, region, offset and flips determine the source mask. Texture/frame changes refresh the mask; call `invalidate_mask()` after in-place texture edits. Frames must be nonempty and no larger than 128×128 logical pixels. Scale the host for larger presentation. The preview retains the simple two-frame fixture shared with burning for mask tests and adds an original detailed knight fixture for visual review; runtime frozen has no dependency on another effect.

The original texture, shader/material, transform, alpha and animation settings stay installed. A small RGB-only body tint preserves source alpha and latest external self-modulate updates; clearing or deletion restores the latest base unless another system has taken ownership. Existing shaders must honor CanvasItem modulation for that tint. Crust anchors come from fully opaque source pixels. The ice is an independent encasing volume: bevels, front slabs and crystals may extend across narrow gaps or beyond the silhouette, while the original body alpha is never rewritten. Its combined silhouette is intentionally larger than the original sprite; it is not an alpha-exact replacement sprite.

Reserve host effective Z−1 for mist and Z+1 for crust/crystals. Host and component should share their parent so ancestor modulation and visibility are consistent. Fragment movement is local-space presentation, without world collision. This module does not implement status stacking or gameplay freezes; one component per host is refreshed/replaced through `play()`.

## Configuration

| Parameter | Default | Bounds / meaning |
|---|---:|---|
| intensity | 0.40 | 0–0.7, all visual strength; zero hides all layers/tint |
| plate_count | 5 | 0–5 source-anchored front slabs |
| plate_scale | 1 | 0.5–1.5, front slab size |
| shell_thickness | 1 | 0.4–1.2, multiplier of local 1–2.4px crust thickness |
| crystal_density | 0.065 | 0–0.3, fraction of alpha boundary; capped at 24 crystals |
| crystal_size | 4.2 | 1–7 logical pixels, randomized unequal facets |
| form_time | 0.5 | 0.05–3 s |
| sustain_time | 1.8 | 0–60 s, used by argument-free play() |
| release_time | 0.6 | 0.15–3 s, cracks then detached fragments and thaw |
| sweep_strength | 0.10 | 0–0.3, subtle surface gleam; zero disables |
| mist_strength | 0.12 | 0–0.4, low background puffs; zero disables |
| seed | 41 | Deterministic facet sites/crystal proportions/gleam phase |
| body_color | `84bbdc` | Multiplicative underlying body tint |
| ice_color | `77b4cf` | Crust and crystal shadow face |
| facet_color | `c3e3e9` | Unequal crystal / coating facets |
| edge_color | `e4f0ed` | Frost rim and restrained gleam |
| crack_color | `42728c` | Dark thaw cracks |
| mist_color | `638caa` | Low cold puffs |

All six color channels are configurable independently; no hardcoded white flash. Numeric values clamp safely; nonfinite input retains the prior value. At most 12 shell panels, 5 front slabs, 10 grouped edge crystals / 64 fragments and seven procedural mist puffs; no scene nodes are spawned per particle. No blanket animation freeze or shake is applied.

## Preview and validation

`godot --path preview/godot res://effects/VFX-18_status_effects/frozen/frozen.tscn`

A 960×540 preview compares an original, procedurally drawn asymmetric 64×72 knight with three independent frozen variants, plus the original simple alpha-test dummy. Both native 1× and identical 2× nearest views are shown. Dark/light background and lower-intensity purple-palette comparisons. Replay, pause, frame-step, cancel, clear, animation toggle, intensity and refresh controls. The game remains responsible for stopping host animation if appropriate.

`python effects/pixel/VFX-18_status_effects/frozen/run_checks.py`

Checks cover silhouette-derived crystal origins, bottom-up coverage, transparent holes, current frame/region/flip/size changes, palette controls, phase continuity, cancel/reapply, 30/60/144 Hz completion, bounded fragments, invalid inputs, host loss, repeated reuse, alpha and external color ownership. `test_render.gd` separately checks body-tint alpha and existing material restoration on the actual renderer with external visual layers hidden.
