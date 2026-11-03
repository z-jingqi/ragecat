# Bubbles acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/bubbles.tscn`.
Space pauses, R replays and S invokes the source stop hook. The native GDScript
API retains the source configuration, random sequence and fixed-step behavior.

- Baseline/stress: 868 frames / 3,472 separate back/front color/light
  hashes match unchanged TypeScript, with exact hooks, actor state and done timing.
  These comparisons were rerun using the final canonical shared runtime.
- Actual Compatibility viewport: 15/15 checked states match the
  independent single-Frame compositor byte for byte.
- The actual native movie is 11.0167 seconds at 960×684. Effect frames and
  the two-line footer were visually inspected.
- Thirty original-TypeScript combined-buffer hashes also match, including the real completed-frame host hold. The source retains its underwater background after the bubbles stop. The subsequent configure-only disposal guard leaves the original algorithm unchanged; historical movie and long-sequence hashes are explicitly retained in the linked lifecycle record.

Reproduce with `python spritefusion_exact/tools/test_effect.py bubbles`.
[validation/bubbles.json](../validation/bubbles.json) records source hashes,
finite test inputs and combined-frame diagnostic provenance. Static PNGs and
any optional WebP files are CPU diagnostics, not native viewport recordings.

Back, synthetic actor and front share one mutable Frame, then additive light is
shown before alpha color. The 640×400 effect stage remains unchanged above the
footer. Website actor/background art is not redistributed, and full website-scene
identity or all possible parameter combinations are not claimed. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not live-FPS or
physical-GPU performance measurement.
