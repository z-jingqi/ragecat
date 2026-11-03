# Fire acceptance

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_one/fire.tscn`.
Space pauses and R replays. The native GDScript API retains the original
configurable parameters, callbacks and fixed-step behavior.

- Baseline334 + stress243 = 577 frames / 2,308 separate back/front
  color/light hashes match the original TypeScript. Actor, hooks and done timing
  match. The fire-specific source raster adapter is included in the shared core.
- Independent actual Compatibility viewport: 12/12 rendered states match
  the independently constructed single-Frame compositor byte for byte.
- The actual peak and tick333 decay frames were inspected. The synthetic host
  remains readable, and the two-line footer is complete outside the effect area.
- Fresh native movie: 601 frames / 10.0167 seconds at 960×684.

Reproduce with `python spritefusion_exact/tools/test_effect.py fire`.
[fire.json](fire.json) records the finite source comparison coverage, while
[presentation/fire-burning.json](presentation/fire-burning.json) records the
combined-frame sampled diagnostics. PNG/WebP diagnostics are not viewport movies.

The scene combines back, synthetic actor and front into one mutable Frame, then
shows additive light before alpha color. No website actor or background art is
redistributed; full website-scene equivalence and untested parameter combinations
are not claimed. Native capture used Mesa llvmpipe Compatibility and fixed-frame
MovieWriter, not a real-time performance or physical-GPU benchmark.
