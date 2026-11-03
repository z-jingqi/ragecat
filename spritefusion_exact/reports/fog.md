# Fog acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/fog.tscn`.
Space pauses, R replays and S invokes the source stop hook. The native GDScript
API retains the source configuration, random sequence and fixed-step behavior.

- Baseline/stress: 662 frames / 2,648 separate back/front color/light
  hashes match unchanged TypeScript, with exact hooks, actor state and done timing.
  These comparisons were rerun using the final canonical shared runtime.
- Actual Compatibility viewport: 13/13 checked states match the
  independent single-Frame compositor byte for byte.
- The actual native movie is 8.02 seconds at 960×684. Effect frames and
  the two-line footer were visually inspected.
- The original stop at tick 180 and done 330/350 states are covered. The final frame genuinely clears, with zero non-background pixels. The typed native implementation preserves the source Float32 storage behavior and must not be replaced by generic regeneration without rerunning its oracle.

Reproduce with `python spritefusion_exact/tools/test_effect.py fog`.
[validation/fog.json](../validation/fog.json) records source hashes,
finite test inputs and combined-frame diagnostic provenance. Static PNGs and
any optional WebP files are CPU diagnostics, not native viewport recordings.

Back, synthetic actor and front share one mutable Frame, then additive light is
shown before alpha color. The 640×400 effect stage remains unchanged above the
footer. Website actor/background art is not redistributed, and full website-scene
identity or all possible parameter combinations are not claimed. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not live-FPS or
physical-GPU performance measurement.
