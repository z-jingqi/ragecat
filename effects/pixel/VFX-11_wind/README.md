# VFX-11 · Pixel Whirlwind

A procedural, layered funnel whirlwind with enter / sustain / exit phases. This is the **旋风** subtype from the brief, not a directional sword slash. It draws a narrow base, expanding upper ribbons, explicit back/front depth and a small number of rising leaves. There is no gameplay pull, damage or collision logic.

## Run

Open `preview/godot/project.godot`, then run `effects/VFX-11_wind/wind.tscn`. The left panel is 1× game-size; the right is an exact nearest 2× enlargement. Presets: jade, reverse rotation, low ground vortex, dust twister. Pause, single-frame step, replay, graceful stop, seed, reset, background and quarter-speed controls are available. Numeric changes replay the current configuration.

## Component API

`wind.gd` exposes `play(ground_anchor, overrides)`, `tick(seconds)`, `stop()` (short graceful drain), `clear()` (immediate silent reset) and `finished`. Set `automatic=false` when a parent owns the clock. The anchor is in the drawing node's local coordinates; use an untransformed pixel canvas or transform the game anchor into that canvas. Godot canvas coordinates are +X right, +Y down. No external texture or sprite sheet is required.

| Parameter | Default | Range / behavior |
|---|---:|---|
| radius | 32 px | 8–44, outer top radius |
| height | 66 px | 20–84, ground to top |
| layers | 6 | 3–9 ribbon levels |
| turns_per_second | 2.2 | 0.2–5, analytic continuous phase |
| clockwise | true | reverse rotation without flipping gravity |
| arc_degrees | 235° | 90–300 per ribbon; never full static rings |
| width | 2 px | 1–3, ends taper to one pixel |
| leaves | 9 | 0–24; zero disables leaves |
| seed | 17 | stable phase offset, no per-frame random redraw |
| enter | 0.18 s | 0.05–1 |
| sustain | 1.7 s | 0.05–30 |
| exit | 0.24 s | 0.08–1 |
| core / body / edge / leaf | palette in source | HTML color strings; invalid values fall back |

Configurations clamp to safe bounds. Play replaces the previous run; clear does not emit completion. Natural end and graceful stop emit completion once. No unbounded history or particle allocation occurs.

## Rendering and portability

All geometry is analytic in elapsed seconds. Ribbons sample partial ellipses, widening with height. Back-facing segments draw before front-facing segments, making the same rotation legible. Leaf positions use a wrapped rising helix; they enter and leave only at the narrow/top ends. The envelope grows and shrinks the geometry instead of a whole-image opacity flash. Positions and line thickness snap on a 128×128 logical canvas. Final display uses nearest integer scale; do not enable filtering.

The Godot implementation is the current runnable artifact. A future Unity implementation would reimplement these formulas and lifecycle; the files are not automatically engine-portable.

## Reference study

[ParticleFX Studio — Twister](https://particlefx.studio/effects/twister) was inspected using its actual poster and eight-moment strip. Its widening funnel, rotating partial wind streaks, rising leaves and separated floor skirt informed the silhouette. The downloaded images were used only for analysis outside the repository. The original HD smoke, bloom, source code and assets were not copied. This pixel variant intentionally uses fewer ribbons and clear color steps instead of a dense translucent smoke cone.

## Checks

`godot --headless --path preview/godot --script res://effects/VFX-11_wind/test_wind.gd`

`godot --headless --path preview/godot --script res://effects/VFX-11_wind/test_demo.gd`
