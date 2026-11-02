# Engine-neutral model

Snapshot RGBA is input; production host pose/art is external. For every source pixel, choose a fixed cell `floor(pixel / cluster_size)`. A deterministic cell hash and projection onto the configured direction form a threshold in (0,1). Threshold = 0.07 + 0.86 × (0.64 directional projection + 0.36 cell noise). A monotonic time-derived progress erases cells below it. Surviving pixels near the front take the configured edge color. Output alpha = original alpha × surviving mask. At progress zero every original pixel is retained; at one none survive.

Sparse ash starts from seeded occupied host positions (standalone: origin), with seeded emission delay, velocity and lifetime. Positions are a direct function of elapsed time, never Euler-integrated, so frame subdivision does not change paths. Lifetime is capped by the overall deadline. A cooling color switch and a 2→1 pixel size step avoid long translucent smears. No per-frame re-randomization, unbounded emitters, or redraw-time state mutation.

`advance` ignores nonpositive/nonfinite delta, clamps at duration, clears all particles, and emits completion once. Replaying resets all state and the RNG. `configure` is an explicit stopped/replay boundary. The host visual and standalone burst are separate modes of one controller; neither knows health, rewards, enemy deletion, camera shake or gameplay damage.

Porting later requires the target engine's sprite material/pivot/texture semantics. The timing and equations are engine-neutral, but this delivery contains only Godot code.
