# Reversible source-pixel trajectories

1. Read each input RGBA texel with alpha >0 once. Store source-pixel position and original color. Reject images larger than 64×64, bounding all storage to 4096 entries.
2. Generate a seeded schedule. A projection onto `release_degrees`, mixed with 20% seeded jitter, determines each pixel's release time. Separate seeded values determine lifetime, speed multiplier, curl phase/frequency, density selection and accent selection. No per-frame randomness occurs.
3. Before release, draw the original source pixel at its original position. After release, reuse that record as a one-pixel particle. Its displacement is analytic: wind velocity plus constant acceleration, vertical lift and a bounded sinusoidal lateral curl whose amplitude starts at zero. Thus the first released position exactly equals the previous source position.
4. Snap in source-pixel space before mapping through the captured transform. This avoids different rasterization at 1× and 2× detail. Dust changes through discrete source/ash palette stages and vanishes only after its own lifetime.
5. Disintegrate samples time `t`; materialize samples `T−t` where `T=release_seconds+dust_seconds`. Both use the same schedule, positions, draw order, colors and alpha. No forward simulation is numerically integrated backward.
6. Completion clears the active schedule. Materialize draws the complete original source; disintegrate draws nothing. Cancel restores the source; reset returns to the selected mode's start. Inactive instances do not continuously update.

The effect consumes a frozen image. It is not an automatic adapter for arbitrary animated nodes or custom materials. A future engine port must preserve the image sampling, alpha, schedule, transform and rasterization contracts.
