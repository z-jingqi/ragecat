# Particle Reveals

A reusable pixel-image transition for **characters or objects**, with disintegrate and reverse materialize modes. It is not tied to death, respawning, damage or pickups. The separate approved `VFX-15_monster_death` ground-debris effect is unchanged.

Each nontransparent source pixel is represented once. It remains in the original image until its scheduled release, then the **same pixel** drifts into the wind and cools. Materialize samples the exact same trajectories backward, returning to the original RGBA image. There is no second body sprite underneath, late particle pop after body disappearance, baked sequence or spritesheet.

## Run

Open `preview/godot/project.godot`; run `effects/particle_reveals/particle_reveals.tscn`. The preview includes character disappear/reform and gem disappear/reform, normal 1× game pixels and 2× nearest detail, parameters, pause, frame step, replay, reset, flip, cancel and backgrounds. Character and gem are original runtime-generated demonstration images, not final game art.

## API and host contract

`particle_reveals.gd` is a Node2D with `set_host(Image)`, `configure(Dictionary)`, `play()`, `advance(delta_seconds)`, `reset()`, `cancel()` and once-only `completed`.

- Input is a captured RGBA image, **at most 64×64 pixels**; all alpha >0 pixels, including fractional alpha and interior holes, are retained. No square opaque mask is substituted.
- This component draws its own snapshot and never changes an external host node/material. The integrating game must hide its original host while this snapshot owns the visible transition, otherwise it would deliberately draw a duplicate. It must choose the source animation frame, pivot/transform and gameplay activation/deletion.
- The snapshot origin is the image center rounded to a source-pixel boundary. Position/rotation/scale can be set on the node before play. A local horizontal flip preserves the image bounds, including odd dimensions.
- `reset()` clears the timeline and returns to the selected mode's start: visible for disintegrate, empty for materialize. `cancel()` instead restores the complete snapshot regardless of mode. Successful materialize leaves the complete image visible; successful disintegrate leaves it empty. Neither changes gameplay health or entity existence.
- Pixels use a captured play transform. Normal node motion does not drag released dust. A displacement exceeding 128 world units resets the instance; explicitly reset before pooling or any teleport.
- Source storage is bounded to 4096 records. Active schedules are cleared at completion/cancel/reset and regenerated deterministically on play. No internal autonomous process or unbounded particle emitter runs after completion.
- All settings apply on reset/replay. Changing mode/configuration while active resets the prior schedule. The same configuration and seed produce exact inverse paths in the two modes.

## Parameters

| Key | Default | Range / units | Meaning |
|---|---:|---|---|
| mode | disintegrate | disintegrate / materialize | Forward or reverse timeline |
| release_seconds | 0.48 | 0.08–1.5 s | Width of the directional release window |
| dust_seconds | 0.62 | 0.1–2.0 s | Maximum post-release particle life |
| wind_speed | 34 | 0–100 px/s | Initial wind travel speed |
| wind_acceleration | 38 | 0–100 px/s² | Acceleration along wind |
| wind_degrees | 0 | wrapped to [-180,180) degrees | Direction of drift |
| release_degrees | -180 | wrapped to [-180,180) degrees | Direction in which source pixels release |
| lift | 8 | -50–50 px/s | Extra upward drift; negative sinks |
| turbulence | 3 | 0–8 px | Lateral analytic curl extent |
| density | 1 | 0–1 | Fraction of released pixels shown as dust; source endpoint stays complete |
| seed | 23 | integer 0–65535 | Release jitter, life and curl schedule |
| use_host_colors | true | boolean | Start dust in its actual source color |
| dust_color | 82717c | Color string | Cooled dust palette |
| ember_color | e8c48a | Color string | Small warm accent and optional non-host-color base |
| ember_fraction | 0.025 | 0–0.15 | Sparse short-lived bright accents |
| flipped | false | boolean | Mirror source snapshot |

Total timeline = release_seconds + dust_seconds. Invalid numeric values retain the previous finite setting; out-of-range values clamp. Invalid color strings retain the previous color. Density 0 deliberately gives a directional cut/reveal without drifting dust; density 1 represents every source pixel. Dust always stays one logical pixel; color changes are discrete palette stages rather than bloom or soft fading.

Preset JSON is mirrored in the preview directory. Edit both copies; tests enforce parity. UI numerical values replay immediately. Very large parameter combinations can move outside the preview pane, which clips effect graphics to avoid covering the controls; this is a preview boundary, not an effect lifetime or world limit.

## Scope

Godot procedural prototype with engine-neutral trajectory documentation. No Unity runtime code, production sprite art, glow post-process or gameplay spawn/death logic is bundled. Existing particle effects and ground-debris death remain independent.
