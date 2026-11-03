# Explosion acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/explosion.tscn`
after the first editor import. Space pauses, R replays, and S calls stop.
The native effect retains the original TypeScript parameters and callback timing.

- Baseline and stress: 488 frames, 1,952 independent back/front color/light
  hashes, hooks, actor state and complete done timing all match original source.
- Sampled shared-frame color/light hashes match original TypeScript with the
  synthetic host drawn between effect passes.
- Independent actual Compatibility readback: 20/20 states match an independently
  constructed single Frame, including ten ticks with and without an overlapping host.
- Fresh 10.0167-second native recording at 960×600 was visually inspected at
  the blast peak, smoke tail and final frame. The body is not cropped.

Lifecycle detail: the baseline reports done at tick192. Calling source draw after
that still renders a dark ground trace; the preview retains that source frame
until replay rather than falsely claiming every pixel clears at done. A host
removes the renderer when it no longer wants the completed effect displayed.

Reproduce the complete numerical fixtures with
`python spritefusion_exact/tools/test_effect.py explosion`.
See [the machine-readable report](explosion.json) for input coverage and hashes.

The retained WebP/PNG are CPU diagnostic excerpts from source-verified combined
frames, separate from the actual viewport movie. Exactness is verified for the
saved configurations, not all imaginable options. Website host art and camera
behavior are not copied. The native movie uses Mesa llvmpipe Compatibility and
fixed-frame MovieWriter, not a real-time or physical-device performance test.

## Preview UI revision

The accepted effect recording above predates a footer-only layout refinement.
Controls now occupy two lines below the unchanged 640×400 effect area, in a
640×456 logical viewport. Original frame coordinates, scale, algorithms and
combined-buffer hashes are unchanged. Actual native font bounds and a short
recording verified the complete footer fits without covering effect pixels.
