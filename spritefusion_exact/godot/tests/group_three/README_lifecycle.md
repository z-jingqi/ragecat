# Lifecycle regression checks

Run `godot --headless --path spritefusion_exact/godot --script res://tests/group_three/test_wrapper_reuse.gd` and `godot --headless --path spritefusion_exact/godot --script res://tests/group_three/test_host_controls.gd`. Tests return nonzero on a failed check. Also reject any engine/script error in the log rather than relying only on the final PASS count.

The wrapper test dynamically loads only installed effects and prints skipped names. It checks old effect/capture-scope release, repeated stop/dispose, and identical initial color/light buffers and done state for three bounded ticks after reconfiguration. The host test requires Pickup; Sparkle switching is explicitly skipped if absent. It combines real host ownership checks with a lightweight effect spy for pause and done/replay scheduling. Neither test replays full weather lifecycles.

The generated wrappers dispose their old owned state before configure replaces it. Existing dispose is idempotent. Fog has no captured closure cycle and resets its arrays and timing directly, so its implementation is unchanged.

Pause freezes simulation, warmup and automatic replay countdown. Explicit user actions remain available while paused: R and arrows reset/switch, C collects, and S stops. These intentional user actions are not claimed to be frozen.

Full raw parity and native movie evidence were captured on the pre-lifecycle-patch effect SHA; the old/new hashes and exact test scope are retained in `validation/group_three_lifecycle.json`. Only one disposal call was inserted per generated wrapper, with all remaining source bytes unchanged.
