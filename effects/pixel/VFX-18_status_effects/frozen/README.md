# Frozen · standalone attached status

Third independent status rebuild. This effect freezes the **appearance of a sprite**, not its gameplay movement, animation, physics or input. It is not a world ice spike or an ice projectile. Burning and poison remain separate components.

## Reference and visual design

Reviewed the actual eight-moment strips and posters for [Frozen Solid](https://particlefx.studio/effects/frozen-solid) and [Freeze Effect](https://particlefx.studio/effects/freeze-effect), linked from [Sprite FX](https://particlefx.studio/effects/sprite-fx).

- An uneven freezing front travels upward from the feet.
- A low-opacity, irregular faceted crust preserves the original body details. Frost follows the current frame's silhouette rather than surrounding it with a rectangle.
- A few unequal edge crystals grow with the crust; a subtle diagonal gleam and sparse low cold mist keep the held state readable.
- On release, dark facet cracks appear, the existing crystals detach, and the coating retreats while fragments fall and fade. There is no white explosion or full-body flashing pulse.

All visual geometry is generated in code. Reference images and third-party assets are not bundled. This is a restrained pixel adaptation, not a pixel-identical reproduction of the HD references.

## Integration

`preview/godot/effects/VFX-18_status_effects/frozen/frozen.gd`

Create the component as a **sibling** of a Sprite2D, then call `bind_host(sprite)`, `configure(parameters)`, `play(sustain_seconds)` and `tick(delta)` once per update. `play()` with no argument uses `sustain_time`. Total lifetime is formation + sustain + release. `play()` during sustain refreshes its remaining duration without restarting formation; reapplying during release reforms from the current coverage. `cancel()` begins thaw from the current coverage; `cancel(true)` / `clear()` remove immediately. `finished` emits on normal or faded completion. Reuse with `clear()` then `play()`.

The current texture frame, hframes/vframes, region, offset and flips determine the source mask. Texture/frame changes refresh the mask; call `invalidate_mask()` after in-place texture edits. Frames must be nonempty and no larger than 128×128 logical pixels. Scale the host for larger presentation. The preview's two-frame procedural fixture is shared with burning, but runtime frozen has no dependency on another effect.

The original texture, shader/material, transform, alpha and animation settings stay installed. A small RGB-only body tint preserves source alpha and latest external self-modulate updates; clearing or deletion restores the latest base unless another system has taken ownership. Existing shaders must honor CanvasItem modulation for that tint. The separate crust is restricted to fully opaque source pixels, leaving original antialiased partial-alpha edges and holes uncoated. Edge crystals and mist are independent visual layers and may extend beyond the silhouette; the combined effect is intentionally not restricted to the body alpha.

Reserve host effective Z−1 for mist and Z+1 for crust/crystals. Host and component should share their parent so ancestor modulation and visibility are consistent. Fragment movement is local-space presentation, without world collision. This module does not implement status stacking or gameplay freezes; one component per host is refreshed/replaced through `play()`.

## Configuration

| Parameter | Default | Bounds / meaning |
|---|---:|---|
| intensity | 0.40 | 0–0.7, all visual strength; zero hides all layers/tint |
| crystal_density | 0.065 | 0–0.3, fraction of alpha boundary; capped at 24 crystals |
| crystal_size | 4.2 | 1–7 logical pixels, randomized unequal facets |
| form_time | 0.5 | 0.05–3 s |
| sustain_time | 1.8 | 0–60 s, used by argument-free play() |
| release_time | 0.6 | 0.15–3 s, cracks then detached fragments and thaw |
| sweep_strength | 0.10 | 0–0.3, subtle surface gleam; zero disables |
| mist_strength | 0.12 | 0–0.4, low background puffs; zero disables |
| seed | 41 | Deterministic facet sites/crystal proportions/gleam phase |
| body_color | `84bbdc` | Multiplicative underlying body tint |
| ice_color | `76b1d3` | Crust and crystal shadow face |
| facet_color | `b1d8e8` | Unequal crystal / coating facets |
| edge_color | `c4e1eb` | Frost rim and restrained gleam |
| crack_color | `365c80` | Dark thaw cracks |
| mist_color | `638caa` | Low cold puffs |

All six color channels are configurable independently; no hardcoded white flash. Numeric values clamp safely; nonfinite input retains the prior value. At most 24 attached crystals / 64 fragments and five procedural mist puffs; no scene nodes are spawned per particle. No blanket animation freeze or shake is applied.

## Preview and validation

`godot --path preview/godot res://effects/VFX-18_status_effects/frozen/frozen.tscn`

Five independently seeded animated hosts at native 1× and identical 2× nearest scale. Dark/light background and lower-intensity purple-palette comparisons. Replay, pause, frame-step, cancel, clear, animation toggle, intensity and refresh controls. The game remains responsible for stopping host animation if appropriate.

`python effects/pixel/VFX-18_status_effects/frozen/run_checks.py`

Checks cover silhouette-derived crystal origins, bottom-up coverage, transparent holes, current frame/region/flip/size changes, palette controls, phase continuity, cancel/reapply, 30/60/144 Hz completion, bounded fragments, invalid inputs, host loss, repeated reuse, alpha and external color ownership. `test_render.gd` separately checks body-tint alpha and existing material restoration on the actual renderer with external visual layers hidden.
