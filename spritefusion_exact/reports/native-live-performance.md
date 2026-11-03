# Native live performance baseline, 2026-11-03

These are actual no-recorder native preview measurements, not MovieWriter
playback. The accepted RGBA packing optimization is present; source effect
algorithms and `sf_math.gd` are unchanged. The tested runtime snapshot was
`fd1dd8fbb1fedfed02e3504dfd8bedf820d45b03`.

## Method

Godot 4.6.3, Compatibility/OpenGL 3, Mesa llvmpipe (LLVM 19.1.7, 256 bits).
The native window was 960×684, the logical viewport 640×456, and the source
buffers 320×200. This software-renderer result does not predict other devices.

Each run kept its original default case, options and seed, every source update,
and every warmup draw/presentation. After the complete warmup, 60 distinct source
states were rendered live. This is 1.0 second of source simulation, not
necessarily 1.0 second of wall time. No recorder, fixed-FPS override, synthetic
delta, sparse warmup, pre-rendered animation, skipped source tick or reduced
particle count/resolution was used. No competing Godot or encoding work ran.

The existing host received the engine's real `_process(delta)`. An external
observer timed update, raster draw and presentation calls and collected native
`frame_post_draw` callbacks. Measurements stayed in memory until completion;
source hashes were checked afterward. All three clean runs confirmed 60 distinct
rendered states and matched all four original TypeScript tick-60 buffer hashes.
All 210 Embers warmup states were also rendered. An earlier isolated snapshot
omitted a navigation autoload; those startup-error attempts were excluded, and
corrected runs used fresh output directories.

## Results

Times below are milliseconds unless marked as seconds. Percentiles use nearest
rank, `sorted[ceil(n × p) - 1]`; with 60 intervals, p99 is the worst sample.

| Case | Warmup wall time | Wall time for 60 source ticks | Mean interval | p50 | p95 | p99 / worst |
|---|---:|---:|---:|---:|---:|---:|
| Sparkle Glint | none | 2.427608 s | 40.460 | 38.488 | 51.247 | 64.144 |
| Fog Night | none | 25.959953 s | 432.666 | 431.892 | 463.542 | 468.609 |
| Embers | 120.814108 s for 210 ticks | 38.346154 s | 639.103 | 638.694 | 684.186 | 735.336 |

Mean elapsed CPU-stage times:

| Case | Update | Raster draw | Present | Host total |
|---|---:|---:|---:|---:|
| Sparkle Glint | 0.355 | 29.856 | 2.341 | 32.607 |
| Fog Night | 0.0024 | 421.470 | 2.749 | 424.299 |
| Embers | 6.230 | 621.029 | 2.485 | 629.814 |

`Present` includes Image conversion, texture update and label work; it is not a
separate upload or conversion measurement. Host total excludes later rendering
and frame-cadence overhead.

## Interpretation and limits

CPU rasterization dominates. These heavy previews are not real-time on this
machine, even after faster byte packing. A 60-FPS encoded movie cannot substitute
for live measurements. Any further optimization must preserve source output and
be measured using the same full-warmup, no-recorder method.

Renderer callback cadence is not physical monitor scanout or input latency.
Observer/timer overhead is included. Each result is one bounded run, not a
confidence interval, a complete lifecycle performance profile or an all-platform
claim. ALSA fallback to Dummy audio and unsupported-VSync warnings were retained;
the accepted runs had no script or autoload errors. Raw logs, captures and
machine-readable receipts remain outside the source repository.

## Reusable measurement harness

The [native observation scripts](../godot/tests/performance/README.md) retain
this measurement method and read the existing original-source fixtures. Their
portable entry point was separately checked in a real native Glint run: 60
rendered states, all four reference hashes and 35 unchanged input-file hashes.
Reusing an output directory, specifying a time-scale override and writing inside
the repository were each rejected with exit code 2. A headless launch was also
rejected. These input-safety checks do not expand the performance sample above.
