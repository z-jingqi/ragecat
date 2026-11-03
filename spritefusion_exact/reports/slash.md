# Slash acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/slash.tscn`
after editor import. Space pauses, R replays and S calls the original stop hook.
Original options and source callbacks remain available through configure.

- Baseline and alternate seed/palette/geometry stress: 92 frames and 368
  separate color/light hashes match original TypeScript, with exact hooks,
  actor state and done timing.
- Corrected sampled previews use a source-verified shared Frame, not separately
  blended front/back canvases.
- Independent real Compatibility readback: 20/20 states match the independent
  compositor, including both sides of the 0.16-second second hit, overlapping
  host and completed states at ticks 45 and 60.
- The fresh 10.0167-second 960×600 movie was inspected for the two bright blades
  and clean end frame; no script or rendering error was observed.

Reproduce source comparisons with `python spritefusion_exact/tools/test_effect.py slash`.
The exact input coverage is in [slash.json](slash.json). The retained WebP/PNG
are CPU diagnostic samples, separate from the actual native recording.

Verification covers the saved configurations, not every possible option. The
original website host art is not available or redistributed. Native recording
used Mesa llvmpipe Compatibility and fixed-frame MovieWriter, so it is not a
real-time performance or physical-GPU test.

## Preview UI revision

The accepted effect recording above predates a footer-only layout refinement.
Controls now occupy two lines below the unchanged 640×400 effect area, in a
640×456 logical viewport. Original frame coordinates, scale, algorithms and
combined-buffer hashes are unchanged. Actual native font bounds and a short
recording verified the complete footer fits without covering effect pixels.
