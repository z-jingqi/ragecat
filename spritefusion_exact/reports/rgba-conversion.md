# Exact RGBA conversion fast path

The pixel buffer now uses a bulk packed-word conversion only after a one-time
sentinel verifies RGBA byte order and high-bit narrowing. If that check fails,
it keeps the original scalar conversion. Pixel storage, source math, RNG,
parameters, particle counts, resolution, simulation ticks and compositor are
unchanged. In particular, the experimental global `u32` change was not adopted.

## Correctness evidence

Godot 4.6.3, final conversion-only runtime:

- Focused conversion tests: 47 checks. An independent original scalar oracle
  verifies full byte arrays and Images, signed/high-bit values, channel order,
  forced fallback, source preservation and non-aliasing.
- Core: 435,370 assertions. Source raster adapter: 184,689 assertions including
  834 original TypeScript snapshots.
- Canonical integration: 28 combined-frame original-TypeScript hashes, eight
  group-one lifecycle cases, 44 group-three reuse checks and 20 host-control
  checks pass. These are bounded checks, not a replay of every long effect.
- Actual X11 Compatibility rendering: 12 scalar/bulk viewport pairs match in
  every RGBA byte at 640×400, with bulk conversion actually enabled. Tests cover
  alpha, additive light, opaque actor occlusion, nearest 2×, texture updates,
  resize and clearing. Six retained Fog/Embers/Glint samples are individual
  source-layer pairs, not reconstructed complete effects or new effect movies.
- Runtime bytes in the integrated file match the native-tested candidate.
  The platform guard is a fallback, not a claim that every platform was tested.

Reproduce the portable conversion test with:

```sh
godot --headless --path spritefusion_exact/godot --script res://tests/core/test_rgba_conversion.gd
```

## Measured benefit and remaining cost

An earlier isolated, serial Linux headless A/B measured both complete
`to_image()` calls, including Image allocation, over ten repetitions. Means
were approximately 15.8 ms for the scalar path and 1.7–1.8 ms for the bulk path.
That prototype also had an unrelated `u32` experiment, which is excluded here;
the measured conversion path does not call it. These figures are bounded prior
conversion measurements, not a fresh final-build FPS test.

Source rasterization remains the main bottleneck for dense atmospheric effects.
In the same bounded 30-source-tick run, original Glint/Fog/Embers draw times were
approximately 25.6/400.1/564.4 ms respectively. This patch does not change that
algorithm. A faster Image conversion does not make those heavy effects real-time
on the tested environment. No renderer, texture-upload or physical-GPU FPS claim
is inferred from those CPU timings.

Preview hosts retain each source tick and slow wall-clock playback when CPU-bound
rather than dropping particles or changing the reference simulation. Fixed-frame
movies show the intended simulation cadence, not measured live responsiveness.
Strict visual comparisons use lossless viewport RGBA/PNG; encoded movies are
lossy. The additional physical-window 3× check remains inconclusive because the
available desktop screenshots were JPEG. Logical native viewport comparisons and
nearest 2× checks passed; no physical-display zero-difference claim is made.
