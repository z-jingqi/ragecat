# Validation

- 3023 executable assertions in `test_poison.gd`: 1000 reuse cycles, deterministic seed, 30/60/144 Hz expiry, cancellation, non-finite numeric inputs, min/max clamps, callback restart and preview controls.
- Native Godot preview exercised restart, pause, stop, palette, light background and reset.
- Actual Godot fixed-time 60 fps recording: 684 frames / 11.4 seconds, 640×360. All frames' 2× view exactly equal nearest enlargement of the 1× viewport.
- Normal-size silhouettes and motion reviewed: stable floor footprint, independently rolling low gas, staggered bubbles, geometric formation/exit, empty completed state. Green/default, violet/smaller, and larger/light-background variants included.
- The recording is engine-rendered fixed-time output, not a spritesheet and not a desktop screen recording. It is not a performance benchmark for target hardware.
- Host-bound poison tint and gameplay health mutation are not implemented by this standalone world-region effect.

Run `godot --headless --path preview/godot -s res://effects/VFX-10_poison/test_poison.gd`.
