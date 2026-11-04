# Native effect differential tests

Each effect folder contains the canonical 16×32 actor fixture, exact binary64 options, selected compressed raw RGBA snapshots, and the unmodified TypeScript reference hashes for every 320×200 frame. `frames.json` keeps the exact completion state and hook stream. The reference uses Node 24 and the attributed MIT TypeScript source, never a separately recreated algorithm.

From this Godot project, run each suite and then compare its hook stream:

```sh
godot --headless --path . --script res://tests/run_differential.gd -- tests/effects/heal/baseline heal /tmp/heal-baseline
python3 ../tools/compare_effect_hooks.py tests/effects/heal/baseline /tmp/heal-baseline heal
```

Repeat with `stress`, and replace `heal` with another installed effect. A missing report, any differing byte hash, actor state or lifecycle fails the test. The Python comparison checks numbers using round-trip binary64 parsing, avoiding the engine JSON parser's occasional one-ULP decimal differences. At sampled frames, decompressed raw buffers are also compared directly byte for byte. On a buffer-hash mismatch, the actual raw RGBA buffer is written to the output directory.

Frame zero is drawn before updates. Later frames update with exactly `1.0 / 60.0`; back and front are independently cleared for differential testing. Live composition instead clears once, draws back, actor, then front into the same buffer, and presents light additively before straight-alpha color at nearest 2× scaling.

Validation records describe tested cases only. They do not claim proof for every possible option or pixel equality with a different actor, background, camera response, or GPU compositor.

## Adapter lifecycle

Call `dispose()` before dropping an adapter. This releases closure graphs that JavaScript normally garbage-collects. Calling `configure()` again first disposes the prior graph, then creates the requested effect with fresh source state and RNG. The complete group-two source checkout also includes `tests/reconfigure_group_two.gd`, which checks 57 reconfigurations across all 19 variants, exact repeated pixels and clean process exit. This optional whole-group test requires all eight families and is not included in an incremental single-family release. The per-family baseline and stress suites above are self-contained. Run the batch command below only after the complete group-two test has been installed.

```sh
godot --headless --path . --script res://tests/reconfigure_group_two.gd
```
