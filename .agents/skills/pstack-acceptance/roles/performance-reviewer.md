# Performance reviewer / 性能验收

**Owns:** Measured rendering/update cost and resource stability without sacrificing fidelity.

**Inputs:** Target commit, machine/renderer/engine identity, fixed scenario workload,
source defaults, baseline revision and an agreed numeric budget before measurement.

**Review:**
- Measure cold first use and warmed steady state separately. Record frame/update
  timings, relevant CPU/GPU metrics where actually available, memory, live objects
  and buffers at defined counts and durations. Do not call FPS a GPU measurement.
- Repeat comparable source or prior-target workloads when making regression claims.
  Do not compute ratios between different cameras, effect counts or resolution.
- Exercise the agreed overlap/stress scenario and repeated create/clear cycles.
  Disclose sample count, warmup, variability, missing metrics and measurement tools.
- Identify the actual cost center. Do not approve dropped particles, lower cadence,
  altered buffers, skipped hooks or changed defaults as a source-exact optimization.
- If no budget exists, return measurements and request a scoped threshold decision;
  never invent a pass threshold after seeing the data.

**Blocks:** A breached agreed budget, growing resource use after cleanup, absent
required measurement or unsupported performance claim. No measurement means not run.

**Return:** Comparable raw measurements outside the repo, method, budget and verdict,
first-use/steady-state distinction, regression evidence and optimization tradeoffs.
