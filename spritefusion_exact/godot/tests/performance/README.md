# Native live preview measurements

Run one case at a time in an approved, otherwise idle native display environment:

```sh
godot --path spritefusion_exact/godot --rendering-method gl_compatibility \
  --script tests/performance/live_measure.gd -- \
  embers /absolute/fresh/output-directory
```

Supported selections are `sparkle` (default Glint), `fog` (Night), and `embers`. Use a different fresh absolute directory outside the entire repository for each run. The scripts write only completed-run receipts there. If the operating environment needs writable Godot cache/data paths, set its standard `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_CONFIG_HOME` before launching.

## Fixed observation scope

- Keep the existing default fixture, source options and seed, source resolution, and window layout.
- Render one initial state, then every original warmup update/draw/presentation, followed by exactly 60 measured source updates. Embers has 210 warmup updates; the other cases have none.
- Call the original preview `_process(delta)` with the real engine delta. Its ordinary one-source-tick-per-render behavior remains unchanged. The normal 60 Hz source step and preview frame cap are not a synthetic wall-time override.
- Do not use a recorder, MovieWriter, `--fixed-fps`, headless mode, pre-rendered frames, reduced particles, sparse warmup, or concurrent performance jobs. The script rejects headless and fixed-fps/MovieWriter arguments.
- Do not shorten a slow run by dropping ticks. If interrupted, preserve the failed attempt and confirm its process stopped before a new run.

The observer uses a transparent effect wrapper to time `update`, and calls the original `draw_buffers` and `present` methods. The latter includes Image conversion, texture update, and label work. These are elapsed stage durations, not exclusive thread CPU time or GPU counters. Timer and telemetry overhead is included. No effect algorithm or core helper is copied into this harness.

## Completion gates and receipt

A valid receipt has no failures, exactly 60 source updates, exactly 60 distinct native rendered source states, and the original warmup update/presentation counts. After the last measured render, all four separate-layer buffers must match source tick 60 in the existing `tests/fixtures/<effect>/oracle/<case>/expected.json`. Final combined buffer hashes are also retained. No separate golden data is copied into this test directory.

`result.json` records initialization and warmup time separately; source simulation time (60 ticks = 1 second) versus actual wall duration; frame and distinct-source cadence; update/draw/present/host stage durations; renderer, adapter, API and display details; original-source hashes and runtime/fixture hashes; and buffered per-frame observations. Input hashes cover the host, observer, effect and core files, and are collected after measurement. Runtime and fixture hashes are also collected before initialization, and the receipt fails if they changed by completion. No hashing, telemetry file writes, or screenshots occur inside the measured loop.

Percentiles use nearest rank: `sorted[ceil(n * p) - 1]`. With 60 samples, p99 is the worst sample. `frame_post_draw` measures completed native renderer callback cadence, not physical monitor scanout or input latency. Record whether the adapter is software-rendered; do not generalize its results to hardware GPUs or other platforms.

A 60 fps movie is not evidence of live 60 fps performance. This harness does not replace full effect lifecycle or native pixel-equivalence gates. Keep raw logs, result JSON, and captures outside the repository; commit only concise reviewed findings and these reusable scripts.

## Portable input guards

These additional portable-script guards do not change the completed baseline measurement method. The supported resource layout is `<repository>/spritefusion_exact/godot`; output must be outside that entire repository. Reject `--time-scale` overrides and a non-unit `Engine.time_scale`, as well as the recorder/headless modes above. A final time-scale check is retained. Replay/pause/case-switch key attempts are blocked and recorded as a failed receipt, rather than silently contaminating a run. Runtime, fixture and observer hashes must match before initialization and after measurement. Preserve failed outputs and never reuse an existing output target.
