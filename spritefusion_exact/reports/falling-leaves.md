# Falling Leaves acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/falling-leaves.tscn`.
Space pauses, R replays and S invokes the source stop hook. The native GDScript
API retains the source configuration, random sequence and fixed-step behavior.

- Baseline/stress: 1,846 frames / 7,384 separate back/front color/light
  hashes match unchanged TypeScript, with exact hooks, actor state and done timing.
  These comparisons were rerun using the final canonical shared runtime.
- Actual Compatibility viewport: 15/15 checked states match the
  independent single-Frame compositor byte for byte.
- The actual native movie is 22.02 seconds at 960×684. Effect frames and
  the two-line footer were visually inspected.
- Thirty original-TypeScript combined-buffer hashes also match. The source intentionally retains settled ground leaves after done; the actual host holds that completed state. The full movie preserves the long source tail rather than truncating it into a false clear.

Reproduce with `python spritefusion_exact/tools/test_effect.py falling-leaves`.
[validation/falling-leaves.json](../validation/falling-leaves.json) records source hashes,
finite test inputs and combined-frame diagnostic provenance. Static PNGs and
any optional WebP files are CPU diagnostics, not native viewport recordings.

Back, synthetic actor and front share one mutable Frame, then additive light is
shown before alpha color. The 640×400 effect stage remains unchanged above the
footer. Website actor/background art is not redistributed, and full website-scene
identity or all possible parameter combinations are not claimed. Native capture
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, not live-FPS or
physical-GPU performance measurement.

## Reuse correction

A lifecycle follow-up adds only `dispose()` before replacing an existing configured
effect. Initial construction still releases an empty dictionary; the effect algorithm
and host are unchanged. The bounded nine-effect reuse checks passed 44/44, and
host pause/replay/exit checks passed 20/20. Long-sequence and movie evidence above
retain their historical implementation hashes; see
[the lifecycle record](../validation/group_three_lifecycle.json) for the exact diff,
new hashes, scope and partial-checkout checks.
