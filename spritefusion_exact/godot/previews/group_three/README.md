# Native Sprite Fusion effects 17–25

Open any scene here in Godot 4.6.3 and run it. For example:

    godot --path spritefusion_exact/godot res://previews/group_three/pickup.tscn

Each scene instantiates the native GDScript port, uses a fixed 1/60-second simulation step, and uses one shared Frame: back effects draw, then the original synthetic actor is blitted into its color buffer, then front effects draw. One Canvas presents the final combined light additively before the combined color. Separate layer canvases are not used. No original website background or actor art is redistributed. The buffers, exact defaults, original warmup, spawn schedule, stop and graceful drain match the baseline oracle. Demonstrations replay after source `done()` becomes true. Space pauses, R restarts, arrows change named situations, C calls `collect()`, and S calls `stop()` when available.

A displayed shake event is an explicit hook visualization, not a camera implementation. Effects 17–25 have no other scene-distortion hooks. The preview is not a claim of full website-scene equality.

Controls occupy a reserved footer below the unchanged 640×400 effect canvas. The logical viewport is 640×456 and the window is 960×684; the art-resolution 320×200 frame, origin and effective 3× pixel display stay unchanged. The label starts at (8,408), puts status/hook/warmup on its first line and controls on its second line. This prevents high Sparkle flares or weather from obscuring the controls. Run `godot --headless --path spritefusion_exact/godot --script res://tests/group_three/test_preview_layout.gd` to check actual font-laid-out Label bounds for all examples, including nonempty Pickup shake status. Original Pickup viewport acceptance predates this UI-only layout adjustment.

Original algorithms: MIT License, Copyright (c) 2026 Hugo Duprez. See `spritefusion_exact/LICENSE` and the unchanged TypeScript originals in `spritefusion_exact/source/`.

The CPU reference favors exactness over real-time throughput. Every source tick is retained, including warmup; playback slows if native rendering cannot keep up. The UI remains responsive instead of accumulating an unbounded catch-up loop. Raw-buffer parity is independent of wall-clock playback speed.

Re-run a committed effect's immutable baseline and stress fixtures without the original audit workspace:

    python spritefusion_exact/tools/test_effect.py pickup

The shared tool and native host harness compare every frame's four buffer hashes, actor state, done state, and hooks against the retained original TypeScript oracle. The effect's `validation/*.json` records tested versions and counts. Passing a finite fixture set is not proof for every possible parameter combination.

## Source-preserving native hot loops

Fog is a direct typed GDScript translation of the source bake, sample and bank loops. Its noise field and per-column arrays use PackedFloat32Array, preserving Float32Array rounding on every write. Do not overwrite it with a generic generated output without repeating its complete byte comparison.

Bubbles keeps the generated source simulation and bubble rendering. The three environment raster functions run through `scripts/effects/bubbles_raster.gd`, with the same loops, order, formulas, clipping, opacity and full caustics/tint passes. After regenerating `bubbles.gd` with the transpiler's `--native-px` option, run `python spritefusion_exact/tools/optimize_bubbles_raster.py spritefusion_exact/godot/scripts/effects/bubbles.gd`, then repeat its parity test. This is a dispatch optimization, not a visual approximation.

The WebP files are CPU diagnostic previews from the verified combined Frame, not actual viewport recordings. They are up to three-second excerpts sampled every third source frame. The full lifecycles, including graceful stopping and long weather tails, are covered by the saved every-frame test fixtures.

Combined presentation is independently checked against original TypeScript using `tools/generate_group_three_presentation.mjs` and `godot/tests/group_three/capture_presentation.gd`. Each baseline example includes 61 selected states and two combined-buffer hashes per state. Actual native viewport capture is a separate acceptance gate; do not represent these reconstructed diagnostics as viewport recordings.
