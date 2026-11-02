# Validation

- 1,055 controller / lifecycle / UI assertions: sanitization, finite inputs, pause, seek, clear, replay, 30/60/144 Hz completion, 1,000 reuses, bounded child count and duration limits.
- 971 actual rendered-pixel checks: four presets sampled across 31 ages, binary alpha, non-clipped default preset coverage, clean final frame, and all 720 preview frames exactly matching the 2× nearest enlargement.
- First fracture boundary sampled at 0.4199 s and 0.4201 s has identical pixels. There is no empty-frame swap from whole crystals to new debris.
- Default nontransparent area rises from 2→118→225→320 pixels, peaks near 954, and ends 82→21→2→0. This confirms growth and retirement are spatial, not merely whole-image fading.
- Repeated seed/time renders match exactly; irregularity 0 and 1 produce different geometry. A maximum-size/speed/lean probe is also saved.
- Native normal-speed playback reviewed on dark and light backgrounds. Replay, pause, single step, clear and reset were operated. Four preset configurations were rendered in the new 12-second preview.

Run state tests from the Godot project:

`godot --headless --path preview/godot --script res://effects/VFX-09_ice/test_ice.gd`

Run real graphics pixel probes (requires a rendering display):

`godot --path preview/godot --script res://effects/VFX-09_ice/render_probe.gd -- --probe-out=/absolute/output/path`

Capture the preview using `--fixed-fps 60` and arguments `--ice-showcase --ice-capture-dir=/absolute/output/path --ice-capture-frames=720`. These are actual Godot viewport frames, not pre-rendered production assets.
