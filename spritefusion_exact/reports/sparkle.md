# Sparkle: Glint and Twinkle acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_three/sparkle.tscn`.
Left/right selects the mode, Space pauses and R replays. The source options
remain configurable; both source situations are implemented as native GDScript.

- Baseline and stress: 861 frames / 3,444 separate back/front color/light hashes
  match original TypeScript, including hooks, actor state and done timing.
- Sampled original combined-frame oracle: 122 states / 244 color+light hashes
  match with the synthetic actor inside the same mutable Frame.
- Actual Compatibility viewport comparison: 24/24 rendered states are byte-identical
  to an independently constructed shared-Frame compositor. Both modes, peak
  stars and the Twinkle tick239 tail were inspected.
- Final two-mode movie: 8.5167 seconds at 960×684. The two-line footer is fully
  visible below the unchanged 640×400 effect area. Earlier top-overlay footage
  was rejected because it overlapped high stars and is not the accepted preview.

Reproduce with `python spritefusion_exact/tools/test_effect.py sparkle`.
See [validation/sparkle.json](../validation/sparkle.json) for retained fixtures
and finite coverage. The layout regression checks twenty real Label states
using only an already-installed Pickup instance, so a partial release does not
try loading effects that have not been published yet.

One Frame receives back, actor and front pixels, then additive light is shown
before alpha color. PNG/WebP files are CPU diagnostics, distinct from the actual
native movie. The synthetic actor is not website artwork. This does not claim
full website-scene identity or all possible options. Native capture used Mesa
llvmpipe Compatibility and fixed-frame MovieWriter, not a real-time performance
or physical-GPU benchmark.
