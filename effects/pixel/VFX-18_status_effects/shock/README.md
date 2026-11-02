# Shock · standalone attached status

Fourth independent status rebuild: fine electric current attached to a sprite. This is not world-space chain lightning, an EMP zone, a falling bolt or a stun/knockback implementation. Burning, poison and frozen are unchanged.

## References

Searched [Sprite FX](https://particlefx.studio/effects/sprite-fx). Its `Stunned` example is a dizziness effect, not an electric-shock reference. The directly relevant visual reference is the same site's [Energy Outline Aura](https://particlefx.studio/effects/energy-outline-aura): electric traces follow the actual sprite outline. Also reviewed the actual eight-moment strip of [Pixel Art Lightning Strike](https://particlefx.studio/effects/pixel-art-lightning-strike), especially staggered onset and cooling residual segments.

The implementation uses short, **1-logical-pixel** local arcs rather than a full bright outline. A leader draws on, a short fork starts later, and each segment cools from the core palette through the mid-tone into a dim residual. Segments have different arrival times, so they do not all appear/disappear together. No full-body white flash, screen flash, forced jitter or shake. The body tint is optional and independent of arc brightness.

No reference images, sprite sheets or external runtime are bundled. This is a procedural pixel adaptation, not a literal reproduction of the HD aura.

## Integration and host fidelity

Runtime: `preview/godot/effects/VFX-18_status_effects/shock/shock.gd`.

Add the component as a **sibling** of the host Sprite2D. Call `bind_host(host)`, `configure(parameters)`, `play(seconds)`, and `tick(delta)` once per update. `play()` while active refreshes duration and retains current arc phases; reapply during cancellation resumes without resetting the whole effect. `cancel()` stops new arcs and fades the remainder; `cancel(true)` / `clear()` remove immediately. `finished` emits after timed or faded completion. Reuse through clear/play.

Contour paths are walks over the current alpha boundary, with 1–2 pixel irregular outward offsets. Cross-body paths start from alpha edges and are projected onto the current body surface. Short forks may extend slightly outside it. Existing arcs keep their individual lifetimes when a sprite animation changes; their drawing is remapped/clipped to the current frame rather than restarting every arc. Transparent holes are not replaced by a body rectangle. The original sprite alpha remains unchanged; external arc pixels intentionally extend past it.

Frame/hframes/vframes, region, flips, offsets, movement, rotation and scale are respected. The component follows the host transform and effective Z+1. Source frames must be nonempty and at most 128×128 logical pixels. Frame/texture changes refresh automatically; call `invalidate_mask()` after in-place ImageTexture edits. Keep host/component under the same parent for matching ancestor modulation/visibility.

The original material/shader/texture/animation remain installed. Optional RGB-only `self_modulate` tint preserves host alpha. Latest external color updates are retained on cleanup; an external owner writing after our last tick is not overwritten. A custom body shader must honor CanvasItem modulation for the tint. No damage, stun timer, movement or animation state is mutated. One component per host uses refresh/replace semantics rather than multiplying same-status brightness.

## Parameters

| Parameter | Default | Bounds / purpose |
|---|---:|---|
| intensity | 0.42 | 0–0.7, arcs only; tint is independent |
| arc_rate | 7 | 0–20 local leaders/sec; timings randomized |
| arc_length | 15 | 4–30 logical pixels, target path length |
| arc_speed | 100 | 40–300 logical pixels/sec; controls visible draw-on |
| hold_time | 0.055 | 0.02–0.3 s per segment |
| cool_time | 0.28 | 0.08–0.6 s per-segment cooling decay |
| branch_chance | 0.45 | 0–1, delayed short fork probability |
| enter_time | 0.10 | 0.02–1 s global entry |
| exit_time | 0.35 | 0.1–2 s cancellation/expiry fade |
| tint_strength | 0.08 | 0–0.35, continuous optional body tint; 0 disables |
| seed | 57 | Deterministic path generation and phase staggering |
| core_color | `b1e0e4` | Pale, non-white leader core |
| arc_color | `6ca5cd` | Mid-age current |
| cool_color | `41557f` | Residual segments |
| branch_color | `7cbbd1` | Delayed fork |
| tint_color | `b4ceeb` | Independent body tint |
| play duration | 3 | Positive seconds, capped at 60 |

All palette channels are configurable. Segment thickness stays at 1 logical pixel to preserve the requested fine style; use host scale for larger display. No additive bloom or wide halo. Overlapping endpoints use maximum alpha instead of accumulating into a bright blob. At most 20 concurrent leaders and their short forks; no scene nodes are spawned per arc. Nonfinite parameter input preserves the previous setting, numeric ranges clamp safely.

## Preview and tests

`godot --path preview/godot res://effects/VFX-18_status_effects/shock/shock.tscn`

Five independently seeded animated targets at native 1× plus matching 2× nearest views. Dark/light backgrounds and a dimmer warm-palette comparison. Replay, pause, frame-step, cancel, clear, refresh, animation toggle, arc-intensity and tint-strength controls. The procedural two-frame fixture is shared with burning only for preview; runtime is independent.

`python effects/pixel/VFX-18_status_effects/shock/run_checks.py`

Checks cover alpha-derived path vertices, delayed forks, leader-before-tail visibility, cooling before later segments, host frame/flip/region/size/transform changes, palette controls, zero intensity/rate/tint, lifetime at 30/60/144 Hz, bounded arcs, cancel/reapply, pool reuse, host loss and external color restoration. `test_render.gd` isolates the body tint to verify exact source alpha and material/cleanup behavior on the renderer. Arc layers are reviewed separately at normal speed and native scale.
