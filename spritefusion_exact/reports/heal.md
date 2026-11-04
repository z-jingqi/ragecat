# Heal and Mana acceptance

Run `godot --path spritefusion_exact/godot res://scenes/effects/heal.tscn`
after the initial editor import. The two panels display original heal and mana
behavior with a synthetic host, one shared Frame per panel, and automatic replay.
The effect accepts the original source options through `configure(options)`.

- All four baseline/stress cases pass: 685 frames and 2,740 separate buffer
  hashes, exact hooks, lifecycle and 176 selected raw byte samples.
- The selected original gzip samples are preserved unchanged inside deterministic
  ZIP_STORED archives. Their entry hashes, corruption negative control and archive-only
  replay were checked. Packaging changes no runtime algorithm or test coverage.
- Independent actual Compatibility rendering passes 16/16 states across both
  panels, including their complete cleared end state.
- The final 10.0167-second, 601-frame, 1280×400 native recording was inspected.
  A preview viewport-size mismatch found in the first capture was fixed in the
  source host; the corrected movie is not cropped.

Reproduce the two saved suites with `res://tests/run_differential.gd`, supplying
`godot/tests/effects/heal/baseline` or `stress`, effect name `heal`, and an output
folder. Then run `tools/compare_effect_hooks.py` on the same fixture/output pair.
[The retained archive report](../validation/heal-raw-archives.json) describes
the exact fixture format and coverage.

The PNGs are CPU diagnostics, not viewport screenshots. The later native
acceptance is recorded separately from that earlier diagnostic stage. Finite
configurations are verified, not every possible parameter. The website scene
and art are unavailable and are not redistributed. Native capture used Mesa
llvmpipe and fixed-frame MovieWriter; it does not measure real-time FPS or a
physical GPU.

## Current shared-core integration

The frozen Heal implementation was rerun with the shared core published at
`5860aa6fa081df5903cbd10cdc83ba309c9d464c`. All four source cases again pass
685 frames / 2,740 buffer hashes and exact hooks, actor state and completion.
The pixel-buffer runtime is SHA256
`8a71ff354706c45a571c72e908b3070a1e69b069707471d6e36fd305727c7c5f`.

A separate fresh Heal-only project, with no other unpublished family, passed
import, three exact two-panel reset/replay checks, old and exiting closure-graph
cleanup, six same-adapter reconfigurations and a full Heal/Mana scene smoke.
Those are headless functional checks; the separately recorded 16-state native
viewport evidence above remains the presentation evidence. No performance test
was run for this integration.
