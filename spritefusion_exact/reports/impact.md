# Impact acceptance

Run `godot --path spritefusion_exact/godot res://previews/group_one/impact.tscn`
from the repository root after the first editor import. Space pauses, R replays,
and S calls the original stop hook. The scene loops after the source reports done.
The effect API is `configure(options)`, `update(1.0 / 60.0)`, `draw(frame, layer)`,
`done()` and `dispose()`. Options remain those in [the original](../source/impact.ts).

## Recorded verification

- Original TypeScript baseline and stress: 165 frames, 660 separate color/light
  buffer SHA comparisons, actor state, host hooks and done timing all match.
- Shared-frame regression: 28 original TypeScript combined-buffer hashes match
  at ticks 0, 1, 2, 6, 12, 24 and 36, with and without an overlapping opaque host.
- Independent real Godot Compatibility readback: all 14 corresponding rendered
  states match an independently constructed single-Frame presentation exactly.
  The lower-level Canvas separately passes 48 light/alpha/nearest checks.
- A fresh 10.0167-second, 601-frame, 960×600 native movie was visually reviewed.
  It uses the same single-Frame host as this scene. Sampled native animations
  and a contact sheet are retained in `../previews/impact/`.

The first split-Canvas preview was rejected: tick 6 differed at 96 output pixels.
The corrected host draws back, actor, then front into one Frame and presents
combined light before combined color. The old preview is not distributed.

Reproduce numerical checks with `python spritefusion_exact/tools/test_effect.py impact`
and `godot --headless --path spritefusion_exact/godot --script res://tests/common/test_group_one_presentation.gd`.

## Scope

These are finite verified seeds/options, not a proof for every possible input.
The original website's scene and character art are unavailable; this scene uses
an original synthetic host, not copied website artwork. The real renderer was
Compatibility on Mesa llvmpipe. Fixed-frame recording is not a real-time FPS or
physical-device performance measurement. Source callbacks are preserved and shown
by the host; arbitrary game camera/postprocess behavior remains a host concern.
