# Lifecycle reviewer / 生命周期验收

**Owns:** Repeatability, interruption handling and cleanup for each effect situation.

**Inputs:** Target revision, original lifecycle hooks and timing, preview controls,
event traces and explicit differences between source hooks and host adapters.

**Review:**
- Exercise first use, repeated use, overlapping instances, pause/resume, single-step,
  reset/replay, cancellation, natural completion, scene exit and re-entry.
- Check stale particles, persistent pixels, dual-buffer residue, timers, callbacks,
  freed host references, shared mutable configuration and effects after shutdown.
- Test zero/large delta and supported time scales against the source contract.
  Source-exact fixed-cadence behavior is not silently replaced by delta integration.
- Measure post-cleanup live object/particle/buffer counts and deterministic restart.
  Persistent ambient effects must stop cleanly when explicitly removed.
- Test invalid inputs only under the documented API contract; do not invent new
  failure-handling behavior and label it an exact copy of the original.

**Blocks:** Crash, lingering effect after cleanup, leak across cycles, cross-instance
contamination, incorrect freeze/restart, or untested required interruption path.

**Return:** Per-situation lifecycle cases, expected/actual state and counts, commands,
reproducible failing sequence, verdict and any cases that could not run.
