# Embers acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/embers.tscn`.
Space pauses, R replays and S invokes the source stop hook. The native GDScript
API retains the source configuration, random sequence and fixed-step behavior.

- Baseline/stress: 1,059 frames / 4,236 separate back/front color/light
  hashes match unchanged TypeScript, with exact hooks, actor state and done timing.
  These comparisons were rerun using the final canonical shared runtime.
- Actual Compatibility viewport: 16/16 checked states match the
  independent single-Frame compositor byte for byte.
- The actual native movie is 14.02 seconds at 960×684. Effect frames and
  the two-line footer were visually inspected.
- The full original 210-tick warmup and every-tick native replay were retained. Source done occurs at tick 513 (8.55 source seconds); the actual final image clears. Sparks, the ground light band and the complete footer were visually inspected. The large optional CPU diagnostic animation is omitted from Git; the static image and full oracle fixtures remain.

Reproduce with `python spritefusion_exact/tools/test_effect.py embers`.
[validation/embers.json](../validation/embers.json) records source hashes,
finite test inputs and combined-frame diagnostic provenance. Static PNGs and
any optional WebP files are CPU diagnostics, not native viewport recordings.

Back, synthetic actor and front share one mutable Frame, then additive light is
shown before alpha color. The 640×400 effect stage remains unchanged above the
footer. Website actor/background art is not redistributed, and full website-scene
identity or all possible parameter combinations are not claimed. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not live-FPS or
physical-GPU performance measurement.
