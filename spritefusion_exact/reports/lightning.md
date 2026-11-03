# Lightning: all four source modes

After editor import, run
`godot --path spritefusion_exact/godot res://previews/group_one/lightning.tscn`.
Left/right selects Strike, Impact, Chain or Electrified; Space pauses and R
replays. Original source parameters and callbacks remain configurable.

- Eight baseline/stress cases: 1,370 frames / 5,480 separate back/front
  color/light hashes match the unchanged TypeScript. Actor, hooks and done
  timing also match. All four exported situations are covered.
- Independent actual Compatibility viewport comparison: 43/43 rendered states
  match the independent single-Frame compositor byte for byte, including
  all four peaks, tails and host combinations.
- Final four-mode movie: approximately 14.52 seconds at 960×684. Actual peaks
  and decay were inspected; the host and two-line footer remain readable.
- The source top=-30 entry boundary is preserved, rather than moving the bolt
  to make the preview fit differently. Camera hooks are recorded, not applied
  as an invented scene camera behavior.

Reproduce with `python spritefusion_exact/tools/test_effect.py lightning`.
[lightning.json](lightning.json) and the four files under `reports/presentation/`
record finite oracle coverage. Retained PNG/WebP samples are verified combined
CPU frames, not actual viewport recordings.

Back, synthetic actor and front share one mutable Frame, displayed as additive
light followed by alpha color. Website host art is not included and full website
scene identity is not claimed. Tested seeds/options do not establish all possible
parameter combinations. Native capture used Mesa llvmpipe Compatibility with
fixed-frame MovieWriter, not a live-FPS or physical-GPU benchmark.
