# VFX-17 hostile geometry adapter

The original 128² raster warning remains unchanged. `preview/godot/effects/VFX-17_boss_warning/hostile_warning.gd` is an additive, pure visual variant for real game-sized locked warnings, where the original radius54 / length96 / width56 clamp is inappropriate.

## Contract

- `play(shape, origin, endpoint, radius)` accepts `circle`, `capsule`, or `line` (same capsule footprint, intended for projectile lanes). `circle` is centered on endpoint. `radius` is the circle radius or capsule **half-width**, never full width.
- Points are node-local. Keep the effect node transform identity to supply parent-local points. A moving parent requires the caller to convert locked world points into that parent's local space. The adapter does not select or follow a target, infer attack length, or clamp to arena bounds.
- `seek(progress)` explicitly sets normalized [0,1] progress. No `_process`, clock, duration, activation signal, damage, collision, timer or auto expiry exists. At progress1 the full warning remains until the caller stops it, including during an elite charge. No seek calls means exact pause.
- `stop()` / `cancel()` immediately clear the visual on the next canvas redraw. Seeking a stopped visual cannot revive it. Repeated play replaces the old geometry and resets progress.
- Invalid shape, non-finite endpoints/radius, or nonpositive radius fail closed. No finite positive dimensions are silently clamped. Nonfinite seek is ignored.
- Layer order belongs to the caller. The game integration should place hostile warnings above actors and friendly effects but below UI.

## Real game geometry inspected before implementation

The actual `EnemyBehavior._draw()` and `EnemyTuning` on the Mountains integration source use:

| Warning | Locked geometry | Current tuning |
| --- | --- | --- |
| Heavy | Circle centered on locked player point | radius62 |
| Elite | Capsule from locked origin to arena-clamped endpoint | radius23, maximum segment260 |
| Ranged | Capsule to origin + locked direction × projectile speed × lifetime | radius7, segment190×2.4=456 |

Do not add target body radius17 to these visual bounds: that is existing gameplay hit-test behavior, not part of the existing warning footprint. Do not substitute the ranged locked target position for full projectile travel distance. No gameplay values were edited by this adapter.

The source-verified pre-change native stress frame (`mountains-polish/stage-3/overlap.png`, enemy_behavior SHA256 `06181d33df93515dab073d8c3e1de7bd2ebd8f9934cf4b05131d0a3a315678cb`) was visually inspected: red/orange complete heavy ring and orange charge corridor over thin friendly amber ground rings. The current friendly solar overlap frame was also inspected. The adapter retains red-orange boundary `ff8760`, pale orange progress `ffbc83`, a restrained red transparent fill, and hard non-antialiased edges. It adds complete capsule sidewalls and endcaps instead of using a centerline alone. No blur, glow wash, character art, flashing, or new animation timing.

## References and design decisions

- [Riot: Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), consulted 2026-11-03: gameplay footprint alignment, low noise, visual priority, and keeping warning borders visible during opening. Applied by keeping the complete outer silhouette fixed while progress changes only inside it.
- [Riot: VALORANT Shaders and Gameplay Clarity](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity), consulted 2026-11-03: art supports readable gameplay rather than obscuring it. No third-party code/art copied.

## Geometry/raster tolerance

Vector polygons remove any fixed texture crop. Circle/capsule boundary vertices lie on the supplied analytic boundary; straight capsule edges join its two semicircles. Stroke is inset by half its width, preventing intentional outside glow. Raster sample rounding allows up to one native output pixel beyond the analytic edge. Tests sample pixel centers, not integer corner coordinates. The polygon has48–512 segments, rounded to a multiple of4, retaining circle cardinal extrema and bounding CPU/memory cost. Curved edges are inscribed chords; error at radius10000 with512 segments is about0.19 world units. Geometry tests allow0.002 + radius×0.00001 for float32 coordinate roundoff at large translated positions. Those tolerances do not alter caller input.

## Validation commands

From repository root, with writable XDG data/cache/config directories if needed:

```
godot --headless --path preview/godot --script res://effects/VFX-17_boss_warning/test_hostile_warning.gd
godot --headless --path preview/godot --script res://effects/VFX-17_boss_warning/test_warning.gd
godot --path preview/godot --script res://effects/VFX-17_boss_warning/test_hostile_warning_gpu.gd
godot --path preview/godot --script res://effects/VFX-17_boss_warning/preview_hostile_warning.gd
```

The GPU test requires a real renderer, not headless dummy rendering. It checks full outline visibility, actual occupied pixels against analytic bounds, visible progress, exact paused image equality, and cancellation to a fully transparent viewport. The10s preview uses actual62/23/7 radii and260/456 lengths plus a zero-length capsule; shows externally supplied progress, paused50%, held100%, then cleared state. Capture1280×720 at startup for full-resolution MovieWriter output.

Initial headless results (Godot 4.6.3): missing-adapter regression failed before implementation; 12,948 adapter assertions passed after; 16,585 original VFX-17 assertions passed unchanged; full preview project import completed without script errors. Native GPU results are recorded separately after capture, not inferred from headless success.

Native renderer result (2026-11-03): **576 / 576 GPU-path assertions passed**, Godot 4.6.3 Compatibility, OpenGL 4.5 Mesa llvmpipe (software OpenGL, not a discrete hardware-GPU benchmark). Actual 1280×720 / 600-frame / 10-second recording completed. Reviewed native frames at2s (50% progressing),7s (held100%),9s (fully cleared); complete62-radius circle,260×46 capsule,456×14 lane and23-radius zero-length capsule are visible without cropped ends. Capture worker also supplies5s paused frame. Captured runtime SHA256: `9d971b3dcfe7c9cce0d9a55faf83b584aa774e0912bfac181b5a35147e0fa68c`.
