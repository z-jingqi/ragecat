# Blood acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/blood.tscn`
after editor import. Space pauses, R replays and S calls the original stop hook.

- Baseline and stress: 743 frames, 2,972 separate back/front color/light hashes,
  exact hooks, actor coordinates and source done timing all match TypeScript.
- Independent actual Compatibility comparison: 12/12 states match the
  independent shared-Frame compositor, replayed one source tick at a time
  through tick 540. Completed states at ticks 527 and 540 were checked.
- The final 10.0167-second, 960×684 movie was visually reviewed, including
  the source spray, long decay, cleared end and complete two-line footer.

The initial leftward spray reaches the original fixed canvas edge. That clipping
is part of the unchanged fixture position and source raster result; the effect
was not moved or rescaled to make the video look cleaner.

Reproduce saved original-source comparisons with
`python spritefusion_exact/tools/test_effect.py blood`.
See [blood.json](blood.json) for the exact finite configurations. Sampled WebP/PNG
files are CPU diagnostics from verified combined frames, not viewport recordings.

The website's background and actor art are not reproduced or redistributed.
The effect preserves callbacks without inventing unverified host camera effects.
Finite matched configurations do not prove every possible option. Mesa llvmpipe
Compatibility fixed-frame recording is not a real-time or physical-GPU benchmark.
