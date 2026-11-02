# Verification

- State checks: 30/60/144Hz yields the same scheduled hit count for fixed targets; exact-radius target included, outside excluded, duplicate candidates deduplicated.
- Leaving before a tick skips that target; re-entering after it does not cause another hit in the same tick.
- Weak target references tolerate deletion. Stop, completion, repeated play and 1000 reuse cycles clear geometry/references. Callback-driven stop/play cancels old-generation event dispatch.
- Extreme visual configurations remain bounded, finite and clipped to the region. Same seed/time reproduces identical paths.
- Preview controls: restart, pause, stop, palette, radius/density, and reset tested. Original-size and light/dark render visually reviewed in the native scene.
- Fresh Godot render: 684 frames at 60Hz, 11.4s, 640×360. Every frame's 2× panel equals a nearest-neighbour replication of the 1× panel exactly. No spritesheet or precomputed movie drives the live effect.
- These focused checks verify the Godot component and preview, not game damage balance or future engine integration.
