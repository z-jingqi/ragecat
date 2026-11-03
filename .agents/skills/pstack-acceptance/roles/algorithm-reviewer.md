# Algorithm reviewer / 算法一致性验收

**Owns:** Whether the port preserves the source algorithm rather than imitating its look.

**Inputs:** Source-approved bytes, target revision, situation mapping, original
parameters/defaults, deterministic seed and event/timestep traces.

**Review:**
- Trace each public hook and option through state changes and output. Compare RNG
  sequence, draw order, rounding, clamping, coordinate origin, update cadence,
  integration order, lifetimes, alpha/blending and dual-buffer history semantics.
- Cover initial state, intermediate frames and exact boundary/end times for every
  situation. Compare original defaults first, then valid edges and invalid input.
- Use numerical differential traces against the authorized original reference.
  Explain any JS/Godot integer, floating-point or API mismatch instead of silently
  compensating with different parameters, replacement geometry or altered timing.
- A test must exercise real production code. Verify a deliberately wrong output
  is rejected when a safe isolated negative control is practical.

**Blocks:** Missing differential evidence, changed RNG/order/defaults, generic
fallback in place of a source algorithm, or an unexplained numeric mismatch.

**Return:** Per-situation trace comparisons, first divergent state/frame and symbol,
commands, tolerance rationale, verdict and untested hooks. A source hash alone
proves input identity, not a correct port or rendered parity.
