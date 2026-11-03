# Exact Fog sampling indexes

## Scope and mechanism

Only `Fog.sample_field` changes. After the original `floor(u)` and `floor(v)`,
if both results are within signed32 range, local integer conversion supplies
the existing 255/127 masked indexes. Integral binary64 values in this domain
have exactly the same value under Godot `int` and JavaScript `ToInt32`.
Negative values retain the same low bits under the masks. NaNs, infinities and
out-of-range coordinates keep the original `M.i32` path.

The original fractional coordinates, Float32 field storage, four field reads,
and bilinear arithmetic expression remain unchanged. No global math, Bayer,
parity, buffer addressing, source option, simulation tick, camera, resolution,
particle count or draw order changes. The rejected `PixelBuffer.at` experiment
is not part of this change.

## Focused and whole-effect checks

```sh
godot --headless --path spritefusion_exact/godot --script tests/effects/fog/test_sampling.gd
godot --headless --path spritefusion_exact/godot --script tests/effects/fog/test_lifecycle.gd
python3 spritefusion_exact/tools/test_effect.py fog --output /absolute/fresh/output
```

The portable focused regression passes 24,484 binary64 comparisons over four
deterministic Float32 fields, exact IEEE boundary values and fractional inputs
inside and outside the signed32 domain. It retains the original helper-based
sample expression as reference. NaNs compare as equivalent, and signed zero
compares by bits. A changed-field negative control is detected.

The focused lifecycle regression passes 23 checks: stop/dispose repetition,
stop completion and empty final buffers, reproducible reconfiguration, and
Frame versus dictionary adapters at integer and fractional camera origins.
Neither focused check is a native-rendering test.

An independent scratch review additionally checked 35,361 index pairs and
212,166 complete sample outputs over six Float32 fields, including source-baked
seeds 1 and 17, with zero differences. It covered both guarded and fallback
paths and nonfinite coordinates. These finite tests are not exhaustive proof
for every possible binary64 pair.

## Exploratory whole-draw measurement

One bounded, uninstrumented headless comparison froze baseline and stress
states at source ticks 0, 60 and 180 and ran original/candidate/candidate/original
at each state. All 24 draws matched all four original-source layer hashes.
Baseline mean draw elapsed time was 394.24 to 302.65 ms (23.23% less); stress
was 224.50 to 179.42 ms (20.08% less). The original and candidate ranges did
not overlap in that run. This is CPU draw timing, not a native FPS assertion.

Profiling beforehand counted roughly 126,000 bilinear samples in each baseline
draw. Each formerly invoked generic `M.i32` twice. Instrumentation itself added
about 25% total elapsed time, so its inclusive internal spans are not used to
claim a native gain.

## Version and evidence boundaries

- Original Fog SHA-256: `7df2c88f6096924af584b6bcbca7a5e09a60174b0eaff1482f97416d51898bf6`.
- Candidate Fog SHA-256: `2b6acc6d4a4b77feca8fed328714b8301ebb1de001752e92704ffa709a27d32a`.
- Unchanged accepted pixel-buffer SHA-256: `8a71ff354706c45a571c72e908b3070a1e69b069707471d6e36fd305727c7c5f`.

The earlier Fog viewport recording belongs to the original Fog hash above. It
is not a recording of this candidate. The new candidate passes all 662
baseline/stress source frames and 2,648
separate-layer hashes, including original per-frame nonzero counts, actor/done
states, complete hooks and done timing. Fourteen shared-Frame states across
both fixtures (ticks 0, 1, 60, 120, 180, 240 and 330) also match 28 color/light
hashes and 14 done checks generated directly from the unchanged original TS.
The candidate and core hashes remained fixed throughout these gates.

## Native A/B/B/A

The predeclared serial native comparison used Godot 4.6.3 Standard, X11,
Compatibility / OpenGL 3, and Mesa llvmpipe (LLVM 19.1.7, 256 bits). A retained
the accepted blend runtime and original Fog; B changed only Fog sampling.
Each run kept all 60 original source updates and 60 distinct rendered source
states, without recording, fixed-FPS override, skipped ticks, sparse warmup,
changed resolution or pre-rendered frames. The original host, observational
harness, source fixture and shared core were fixed.

| Trial, in run order | Wall seconds for 60 source ticks |
|---|---:|
| A1 | 22.080959 |
| B1 | 18.414442 |
| B2 | 18.671874 |
| A2 | 24.421851 |

A averaged 23.251405 seconds and B averaged 18.543158 seconds, a 20.249301%
reduction. Both candidate trials were faster than both original trials. The mean reduction
also exceeded the larger within-group relative range (A: 10.067744%;
B: 1.388286%), passing both predeclared practical-benefit gates. All trials exited successfully,
had no observer failures and passed before/after input-manifest checks.

All four terminal source-layer hashes matched the original tick-60 oracle,
and the terminal combined color/light hashes were identical across the four
trials. These are terminal buffer checks, not a new per-frame viewport-pixel
comparison or a replacement for the historical viewport recording. Full source
buffer parity is established separately by the 662-frame gate above.

The candidate still takes about 309.05 ms per source tick on this software
renderer, far from real time. The bounded four-trial result is not a statistical
or all-platform guarantee and does not measure physical display/input latency.
No workload or original timing was reduced to obtain the gain. The independent
source review accepted the final runtime and focused tests without a blocker.
