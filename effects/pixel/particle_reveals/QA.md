# Validation

- 1839 Godot state assertions: bounded source image, exact seeded schedule, same forward/reverse trajectories at matching times, every source-pixel release starts at its original position, both endpoint modes at 30/60/144 Hz, once-only completion, cancel restoration, zero density, invalid numeric settings, teleport cleanup, 1000 reuse cycles, odd-sized/half-alpha images, and character/item preview controls.
- 18148 actual native GPU assertions: forward/reverse output byte-identical at a matched time; materialized RGBA byte-identical to the original rendered snapshot; disintegrated output entirely empty; cancellation restores the original; source alpha and transparent holes preserved, including a half-alpha pixel.
- Native normal-speed scene inspected. Character/materialize preset switching and cancellation were exercised through the actual window.
- Final recording: 12 seconds, 720 actual Godot MovieWriter frames at 60 fps, 640×360. It shows character disintegrate/materialize and gem disintegrate/materialize at 1× game size plus 2× nearest detail, with a bright-background pass. This is engine-rendered fixed-time video, not an external art animation or desktop recording.
- All 720 frames have exact 1×→2× nearest-neighbor equality in the matched source-region views.
- Preset copies match and the scene starts cleanly in headless checks. Current ground-debris death files were not changed.

Run `python3 effects/pixel/particle_reveals/tests/run_checks.py`. GPU tests require a rendering-capable session: `godot --path preview/godot --script res://effects/particle_reveals/test_render.gd -- --output=/absolute/qa/directory`.

The demo images are mechanism samples. Production integration supplies the correct image/frame and owns the original host visibility, pivots, sorting and gameplay events. No Unity code is part of this delivery.
