# Exact glow raster fast path

The native pixel buffer has a guarded path for ordinary integer-camera glows.
It removes repeated per-pixel coordinate coercion, dispatch and color packing
calls. It does not cache effect frames or change any particle, option, source
update, RNG operation, draw order, geometry or resolution.

The original scalar glow body remains unchanged as `_glow_scalar`. Fire's
special typed-array indexing, fractional cameras, non-finite inputs and cameras
outside conservative signed-32 bounds retain that path. The global JavaScript
numeric helpers are unchanged.

## Equivalence boundary

- Clipping and floating `x`/`y` traversal retain the original expressions and
  order. Signed-32 integer camera bounds ensure clipped offsets are exact and
  match the original `at()` result.
- Division, squared distance, square root and `f * f * k` retain their original
  binary64 operation order. Channels are extracted once rather than per pixel.
- For the guarded finite-positive strength domain, source channel products can
  overflow to positive infinity, but the unchanged `minf(255, ...)` yields a
  finite value in [0,255]. Only then is `int()` used, with the same truncation
  as source ToUint32. The resulting alpha remains 255.
- Unusual inputs do not silently change domains. The scalar fallback retains
  the original semantics, including its limitations for unbounded inputs.

## Reproducible tests

Run the complete shared-core suite, including the focused fast-path regression:

```sh
bash spritefusion_exact/tools/test_core.sh
```

The focused test compares complete packed buffers to the retained scalar body,
with deterministic mixed initial buffers reset between edge cases and separate
ordered overlapping sequences. Cases include signed/wide colors, saturation,
threshold-adjacent values, fractional/fire fallbacks, signed-32 camera boundaries,
1×1 buffers, non-finite inputs and huge finite values with overflowing clipping
intermediates. Source-independent coverage remains essential: `test_core.gd`
and `test_source_px.gd` compare against unchanged original TypeScript vectors.

The accepted runtime SHA-256 is
`ddfe0cbb3a296bd625670cf4c71748217e318de09388dbd003d88b6c824b1568`.
On Godot 4.6.3, the focused regression passes 3,367 comparisons/guards;
the shared core passes 435,370 assertions, the source raster adapter passes
184,689 assertions including 834 original TypeScript snapshots, and the V8
trigonometry suite passes 65,882 binary64 checks.

All 13 previously installed families that use the shared glow path pass their
complete baseline and stress original-TypeScript suites: Sparkle, Embers,
Impact, Muzzle Flash, Lightning, Blood, Explosion, Movement, Slash, Pickup,
Fire, Fireflies and Bubbles. This is 36 cases, 8,545 frames and 34,180 separate
back/front color/light hashes, with zero mismatches. Per-frame nonzero counts,
actor state, done values, complete done timing and host hooks also agree.
Input files and runtime identities were checked before and after the serial
sweep. This does not extend acceptance to the unfinished 25-family catalog or
to every possible parameter combination.

Reproduce each full effect check with, for example:

```sh
python3 spritefusion_exact/tools/test_effect.py embers
python3 spritefusion_exact/tools/test_effect.py sparkle
```

The test runner defaults to both baseline and stress suites, retains each
source update/draw and checks every frame through the source lifecycle.

## Native no-recording A/B

Godot 4.6.3 Standard, X11, Compatibility/OpenGL 3, Mesa llvmpipe
(LLVM 19.1.7, 256 bits), same source fixtures and observational harness.
Source art remains 320×200, logical viewport 640×456 and native window 960×684.
Each run retained all 60 measured source updates and distinct rendered source
states. Embers also retained all 210 original update/draw/present warmup steps.
There was no MovieWriter, fixed-FPS override, sparse warmup, dropped source tick,
recording or frame readback during the measured loop.

| Fixture | Before: 60 steps, wall seconds | After: 60 steps, wall seconds | Before/after mean draw milliseconds |
|---|---:|---:|---:|
| Sparkle Glint | 2.428 | 1.182 | 29.856 / 9.339 |
| Embers | 38.346 | 12.195 | 621.029 / 187.346 |
| Fog Night control | 25.960 | 24.700 | 421.470 / 402.330 |

The full Embers warmup changed from 120.814 to 39.988 wall seconds. All four
original-source tick-60 layer hashes passed, and both combined color/light
hashes were identical before and after for every fixture. Fog does not use
this glow path; its approximately five-percent timing variation is not a gain
attributed to this patch.

These are serial, same-environment observations, not a real-time guarantee.
Embers still costs about 203 ms per displayed source tick and Fog about 412 ms
on this software renderer. Glint averaged about 19.7 ms per source tick.
`frame_post_draw` observes renderer completion cadence, not physical monitor
scanout or input latency. Hash checks and disk output ran after measurement.
The complete original-source per-frame regressions above are a separate gate
from these bounded native timing observations.
