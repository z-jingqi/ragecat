# Verification

- State checks: 30/60/144Hz yields the same scheduled hit count for fixed targets; exact-radius target included, outside excluded, duplicate candidates deduplicated.
- Leaving before a tick skips that target; re-entering after it does not cause another hit in the same tick.
- Weak target references tolerate deletion. Stop and repeated play clear geometry/references immediately; completion releases target references and lets bounded harmless geometry retract. 1000 reuse cycles are checked. Callback-driven stop/play cancels old-generation event dispatch.
- Extreme visual configurations remain bounded, finite and clipped to the region. Same seed/time reproduces identical paths.
- Preview controls: restart, pause, stop, palette, radius/density, and reset tested. Original-size and light/dark render visually reviewed in the native scene.
- Fresh Godot render: 684 frames at 60Hz, 11.4s, 640×360. Every frame's 2× panel equals a nearest-neighbour replication of the 1× panel exactly. No spritesheet or precomputed movie drives the live effect.
- These focused checks verify the Godot component and preview, not game damage balance or future engine integration.

## Fine-current revision

Removed the expanded outline, capped main segments at 2 source pixels and branches at 1; most default current segments are 1 pixel. Late decay is entirely 1 pixel. All existing state checks plus per-segment width caps pass. A newly recorded 684-frame preview passes exact nearest replication. In the same default first 3-second sample, summed pixels using the three electric colors fall from 88,501 to 43,133 (51.3% reduction); timing, target movement and hit cadence are unchanged. This measures occupied pixels, not brightness or perceived impact.

## Temporal-current revision

- Re-inspected the actual reference strip, not merely the effect description. Current leaders now travel along their paths in 72 ms at default lifetime; delayed forks arrive after their junction, and cooled remnants shrink independently. Default lifetime is 300 ms, overlapping the 100 ms emission cadence.
- Temporal-window checks prove partial growth, unreached endpoints, full arrival and spatial erosion. Sparse requested lifetime/cadence is extended to preserve overlap. Normal expiry drains without any further target events; stop remains immediate. Fixed-target 30/60/144 Hz hit counts remain unchanged.
- Actual isolated-current render at 10/30/60/90/150/210/270/300 ms contains 10/28/60/80/82/62/19/0 electric-colored pixels. Visual inspection confirms leader travel, delayed fork, broken remnants and an empty end, rather than merely uniform fading.
- Re-recorded 684 frames / 11.4 seconds at 60 Hz after the temporal revision. All frames preserve exact nearest 1×→2× correspondence. Native 1× reviewed. Fixed a floating-point boundary emission discovered by the isolated render; a regression test now prevents starts at duration.
