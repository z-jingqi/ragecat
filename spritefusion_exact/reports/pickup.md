# Pickup acceptance

Open `godot/previews/group_three/pickup.tscn` in Godot 4.6.3 and press F6,
or run `godot --path spritefusion_exact/godot res://previews/group_three/pickup.tscn`
after the initial editor import. Space pauses, R replays, C calls collect and
S calls stop. The scene demonstrates gem, coin and orb source behavior.

- Baseline and moving-host/palette/camera stress: 294 frames, 1,176 separate
  color/light hashes match the original TypeScript, along with hooks and done timing.
- Original TypeScript combined-frame oracle: 61 states, 122 color/light hashes
  match the actual preview host with actor pixels inside the shared Frame.
- Independent Compatibility viewport check: 24 of 24 rendered states are
  byte-identical to an independently constructed shared-frame compositor, including
  visible/hidden host, collection, tail and expiry.
- Fresh native recording: 10.0167 seconds, 601 frames, 960×600. The collection
  peaks and cleared end state were visually inspected.

The preview uses one Frame: back, synthetic actor, front, then additive light
and alpha color. Earlier split-Canvas diagnostic images were replaced. The
retained WebP/PNG are sampled CPU diagnostics, not the native video.

Reproduce all saved source comparisons with
`python spritefusion_exact/tools/test_effect.py pickup`.
The full metadata is in [validation/pickup.json](../validation/pickup.json).

This verifies the named configurations, not every conceivable option. The
website host art and camera behavior are not reproduced or redistributed.
Compatibility ran on Mesa llvmpipe; fixed-frame capture is not a live FPS or
physical-GPU performance result. Effects retain source ticks and may play slower
than real time when CPU rasterization cannot keep up.
