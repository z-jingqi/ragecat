# Rain acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/rain.tscn`.
Space pauses, R replays and S invokes the source stop hook. The native GDScript
API retains the source configuration, random sequence and fixed-step behavior.

- Baseline/stress: 439 frames / 1,756 separate back/front color/light
  hashes match unchanged TypeScript, with exact hooks, actor state and done timing.
  These comparisons were rerun using the final canonical shared runtime.
- Actual Compatibility viewport: 15/15 checked states match the
  independent single-Frame compositor byte for byte.
- The actual native movie is 10.02 seconds at 960×684. Effect frames and
  the two-line footer were visually inspected.
- The original 180-tick warmup, stop transition and done 218/240 states are preserved. Rain stops but the source leaves a few pale-blue ground points; the preview does not erase this original final state.

Reproduce with `python spritefusion_exact/tools/test_effect.py rain`.
[validation/rain.json](../validation/rain.json) records source hashes,
finite test inputs and combined-frame diagnostic provenance. Static PNGs and
any optional WebP files are CPU diagnostics, not native viewport recordings.

Back, synthetic actor and front share one mutable Frame, then additive light is
shown before alpha color. The 640×400 effect stage remains unchanged above the
footer. Website actor/background art is not redistributed, and full website-scene
identity or all possible parameter combinations are not claimed. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not live-FPS or
physical-GPU performance measurement.
