# Burning · standalone sprite-shaped fire

This is the **first standalone status rebuild**. It does not call the earlier four-state component. Poison, frozen and shock are not part of this module.

## Reference and design

Reviewed [Sprite FX](https://particlefx.studio/effects/sprite-fx) and the actual poster/eight-moment strip of [Character On Fire](https://particlefx.studio/effects/character-on-fire). Its useful structure is an image-shaped fire source, back flames, front licking flames, rising embers and smoke. The previous rectangle-distributed marks did not supply those layers.

This is a procedural pixel interpretation, not a copied effect or a claim of pixel-identical reproduction. The warm contour is broken into varying upward tongues, with a separate pale-gold core; there is no white flash, bloom or additive full-body glow. Body tint is deliberately subtle. Smoke and embers are independently adjustable. No downloaded art or third-party code is included.

## Integration

Godot script: `preview/godot/effects/VFX-18_status_effects/burning/burning.gd`.

1. Add a component as a sibling of the host under the same CanvasItem parent.
2. `bind_host(sprite: Sprite2D)` returns whether the current frame has a valid alpha shape.
3. `configure(dictionary)` changes visual parameters.
4. `play(seconds)` starts or refreshes the duration. Refresh preserves phase and particles.
5. Call `tick(delta)` once per update. `cancel()` fades out; `cancel(true)` or `clear()` removes immediately. `finished` signals natural or faded cancellation completion.

The mask is taken from the **current texture frame**, with region, flip and offset support. Only alpha >= 0.15 surface pixels may emit particles. Transparent holes remain holes in the source mask. Particles are separate visible layers, so flames may legitimately travel across a hole; they do not change the host texture's alpha.

Frame/texture/region/flip/rectangle changes rebuild the mask. Call `invalidate_mask()` after mutating pixels of an existing ImageTexture without changing its identity. Empty, missing or >128×128 logical-pixel frames are rejected. Scale the host to enlarge the presentation; do not inflate source pixels solely to increase display size.

The host material, shader, frame, visibility and transform are never replaced. A small RGB-only `self_modulate` heat tint preserves alpha and adopts external color changes. Clearing/deleting restores the latest base unless another system took ownership. Shaders must honor CanvasItem modulation to show this optional body tint; particle layers remain independent.

The back layer uses host `z_index - 1`, front uses `z_index + 1` (relative to the host’s effective Z). Reserve these slots and place ground/background below the back layer; the preview uses host Z=10. Keeping the component and host as siblings also preserves their shared ancestor modulation. The effect follows the host transform; detach-to-world burning trails are a different behavior.

## Parameters

| Parameter | Default | Range / units |
|---|---:|---|
| intensity | 0.32 | 0–0.7; 0 removes all visible fire and body tint |
| density | 54 | 0–80 particle births/second; contour remains independent |
| flame_height | 11 | 2–20 logical pixels |
| rise_speed | 12 | 1–32 logical pixels/second |
| smoke | 0.32 | 0–1 share of smoke births |
| embers | 0.35 | 0–1 share of ember births |
| enter_time | 0.12 | 0.02–1 second |
| exit_time | 0.30 | 0.03–2 seconds |
| seed | 18 | Integer; applied on next fresh play |
| color | `ed8839` | HTML main flame color |
| core_color | `f9bb60` | Fire core, independent |
| edge_color | `6b3d1a` | Dark rim and outer flame |
| smoke_color | `1f1a1c` | Smoke |
| ember_color | `f2ac74` | Rising embers |
| body_color | `ff9966` | Subtle multiplicative body heat tint |
| play duration | 3 | Positive seconds, capped at 60 |

Intensity, geometry and colors can change live. The particle list is capped at 160 per component; smoke and ember shares reduce flame births rather than creating extra unbounded emitters. No gameplay damage or stun is applied. Pool reuse calls `clear()` and then `play()`.

## Preview and checks

`godot --path preview/godot res://effects/VFX-18_status_effects/burning/burning.tscn`

The preview has five different seeds, animated irregular silhouettes, native 1× and matching 2× nearest views, dark/light backgrounds, a lower-intensity comparison, refresh, cancel, clear, pause, step and intensity controls. The two-frame host fixture is original procedural test art, not an exported VFX sprite sheet.

`python effects/pixel/VFX-18_status_effects/burning/run_checks.py`

Tests cover alpha-surface emission, holes, frame/flip/region updates, external modulation ownership, refresh/cancel/reuse, duration at 30/60/144 Hz and bounded pools. `test_render.gd` checks the body tint independently of the external particle layers: exact host alpha, transparent holes, an existing custom material, clear and deletion restoration.
