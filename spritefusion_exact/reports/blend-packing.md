# Exact alpha-blend packing

This change retains the accepted glow implementation and original
coordinate conversion. Only the final RGBA packing inside `PixelBuffer.blend()`
changes; global JavaScript numeric helpers are untouched.

The original order is preserved: find the pixel, read its packed word, compute
`oa`, return for nonpositive `oa`, compute `k`, then `j`, and evaluate each color
channel with the same binary64 expression. The new branch applies only when
alpha is in [0,1] and the existing pixel word is an unsigned 32-bit value.

In that domain, `oa` is finite and nonnegative. After the existing early return,
`oa >= a`, hence `k` and `j` remain in [0,1]. Channel expressions and `oa * 255`
are finite and far within integer conversion range. Local truncation toward zero
followed by the original 255 byte masks equals JavaScript ToUint32 packing.
The masks are retained, including at floating rounding boundaries.

Negative, greater-than-one or non-finite alpha, and signed/wide existing pixel
words, retain the original `JS.rgb` path. Incoming color words may be signed or
wide because both paths extract the same low RGB bytes before any arithmetic.
No geometric expression, RNG, particle count, option, update, draw order or
resolution changes; no effect frames are precomputed or cached.

## Focused checks

```sh
bash spritefusion_exact/tools/test_core.sh
```

On Godot 4.6.3, this runtime passes 435,370 shared-core assertions, 184,689
source raster adapter assertions including 834 original TypeScript snapshots,
65,882 V8 binary64 checks and 3,367 glow comparisons.

The added blend regression initially passed 66,815 complete-buffer comparisons.
A final test-only addition decoded ten exact IEEE-754 alpha boundaries from hex,
retaining all original cases, and raised the passing count to 69,705. These
compare against an independent original at-and-blend expression. It covers channel extremes,
wide/signed input colors and existing words, alpha zero/one and adjacent values,
subnormals, NaN, infinities, out-of-range alpha, fractional camera origins,
coordinate wrapping/clipping and ordered overlapping writes. Buffers are reset
regularly so saturation and exceptional writes cannot conceal normal mixing.
A separate complete-original-file comparison also passed all 66,815 initial
cases and all 69,705 strengthened cases. The final hardening did not change
the runtime, source-oracle fixtures or native benchmark inputs.

## Microbenchmark, not a live-effect result

One quiet headless sequence alternated baseline/candidate order for two warmup
and ten measured rounds. Each round blended all 320×200 pixels over the same
mixed-alpha background, including the unchanged coordinate lookup. Complete
buffers matched after each round. Mean elapsed time was 159.5107 ms before and
102.0791 ms after (1.5626×). This isolates the blend operation and does not
establish a Fog or renderer frame-rate gain.

## Native Fog A/B/B/A

The predeclared serial test used Godot 4.6.3 Standard, X11, Compatibility,
OpenGL 3 and Mesa llvmpipe (LLVM 19.1.7, 256 bits), with unchanged original Fog
fixtures and the same live observational harness. A was accepted glow only;
B added only this blend packing. Each trial retained all 60 original source
updates as distinct rendered states. No recording, fixed-FPS override, sparse
warmup, source-step omission, resolution change or frame readback was used.

| Trial, in run order | 60 source steps: wall seconds |
|---|---:|
| A1, accepted glow | 27.084623 |
| B1, plus blend packing | 23.820747 |
| B2, plus blend packing | 21.826165 |
| A2, accepted glow | 26.146153 |

A averaged 26.615388 seconds and B 22.823456 seconds: 14.2471% less elapsed
wall time. Both B trials were faster than both A trials. The improvement also
exceeded the relative range between the two baseline trials (3.5260%) and
between the two candidate trials (8.7392%), passing both predeclared practical
benefit gates. All four original-source terminal layer hashes and both combined
color/light hashes were identical for every trial.

This remains a bounded software-renderer observation, not a real-time guarantee
or physical monitor/input-latency measurement. Candidate Fog averaged about
380 ms per source tick, so it remains slow. The rejected coordinate experiment
is not included in this runtime.

## Full source and lifecycle acceptance

The accepted runtime SHA-256 is
`8a71ff354706c45a571c72e908b3070a1e69b069707471d6e36fd305727c7c5f`.
All 17 published families at this revision pass their full baseline and stress
source-oracle suites: 44 cases, 13,640 frames and 54,560 separate back/front
color/light buffer comparisons, with zero mismatches. Per-frame actor state,
nonzero counts, done values, complete done timing and host hooks also agree.
Runtime and source inputs were frozen throughout the serial sweep.

Additional checks pass:

- Eight group-one repeated-configure/dispose cases.
- 44 group-three wrapper reuse checks, 20 host-control checks and 20 actual
  Label layout states, with no skipped installed wrappers.
- 28 group-one combined-frame original-TypeScript hashes.
- Ten group-three cases, each with 61 sampled combined frames and two channels:
  1,220 combined-frame hashes match independent original-TypeScript outputs.

These combined-frame and interaction checks are CPU/headless tests, not new
viewport screenshot comparisons or real-time FPS measurements. Native timing
is limited to the Fog trials above. This does not certify every possible
parameter combination or the unfinished 25-family catalog.

Reproduce a full source suite with, for example:

```sh
python3 spritefusion_exact/tools/test_effect.py fog
```

The default includes both baseline and stress cases and every source frame
through completion. The failed coordinate fast-path experiment was not merged;
its original coordinate coercion remains in this accepted runtime.
