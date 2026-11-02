# Engine-neutral model

Snapshot RGBA is input; production host pose/art is external. For every source pixel, choose a fixed cell `floor(pixel / cluster_size)`. A deterministic cell hash and projection onto the configured direction form a threshold in (0,1). Threshold = 0.07 + 0.86 × (0.64 directional projection + 0.36 cell noise). A monotonic time-derived progress erases cells below it. Surviving pixels near the front take the configured edge color. Output alpha = original alpha × surviving mask. At progress zero every original pixel is retained; at one none survive.

Falling fragments start from seeded occupied host positions (standalone: origin). CPU and shader share the same integer-valued modular cell hash, so each fragment's birth time is exactly the dissolve threshold of its sampled source pixel. It keeps that source pixel's color and a small chip shape. A precomputed ballistic trajectory reaches the chosen ground point exactly: choose initial velocity, then solve acceleration from the source position, destination and flight time. Positions depend directly on elapsed time rather than Euler integration. Falling and grounded views reference the same particle ID, shape and position; landing never creates a second patch. Whole source bodies are not faithfully tessellated: these are representative pieces from their actual alpha mask.

Initial flash and dissolve remain quick. The particle flight overlaps the dissolve and ends by the airborne deadline. Retained chips hold at their landing world positions, cool in two color steps, then clear. No redraw-time state mutation, per-frame randomness or unbounded emitters.

`advance` ignores nonpositive/nonfinite delta, clamps at the combined airborne-plus-ground lifetime, clears all particles/remains, and emits completion once. Replaying resets all state and the RNG. `configure` is an explicit stopped/replay boundary. The host visual and standalone burst are separate modes of one controller; neither knows health, rewards, enemy deletion, camera shake or gameplay damage.

Porting later requires the target engine's sprite material/pivot/texture semantics. The timing and equations are engine-neutral, but this delivery contains only Godot code.

## Ground remains

At play, choose 0–20 retained IDs from the falling fragments. Each chip lands at its own analytic trajectory endpoint, then stays motionless. Normal effect movement does not move these stored world positions. The configured hold is 0–8 seconds after the airborne deadline, so early landings persist slightly longer. Reset/replay/teleport ownership cleanup clears both references to the same collection. The final 0.16 seconds remove whole pieces by a seeded schedule. Total lifetime includes the hold only when enabled. A generation token prevents a phase-signal callback reset from continuing the old timeline.
