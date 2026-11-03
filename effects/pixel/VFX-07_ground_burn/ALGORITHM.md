# Ground-fire algorithm and reference study

## Actual references inspected

- [ParticleFX Studio Ground Fire Hazard](https://particlefx.studio/effects/ground-fire-hazard): inspected its [eight-moment strip](https://particlefx.studio/strips/smoke-fire/groundFire.webp) and poster before implementation. The low, varied tongues lean and curl independently above a hot floor. The shape evolves while the source stays anchored. Its broad additive glow and HD smoke do not fit this game's clean pixel style, so those layers are omitted.
- [Sprite Fusion Fire](https://www.spritefusion.com/pixel-art-vfx/fire): inspected its [actual fire poster](https://www.spritefusion.com/images/pixel-art-vfx/fire-on-fire.webp). Useful cues are compact gold cores, orange edges and sparse upward geometry. That reference follows a sprite silhouette, whereas this module follows a game-owned circular ground region.
- Existing Ragecat explosion and sprite-burning source was inspected to avoid
  treating a short burst or a host alpha-mask emitter as a persistent ground
  zone. Neither existing lifecycle matches the new caller-owned absolute clock.

The references informed the visual hierarchy only. No reference art, animation
sheet, TypeScript, proprietary engine code or downloaded assets are included.

## Geometry and phase

1. Each component owns two fixed rectangles and two independent shader materials.
   Local positions are sampled at art-pixel centers. The rectangle bounds round
   outward to cover the given radius; the circular mask retains the true radius.
2. A porous translucent coal bed is formed from seeded fixed cells with short
   orange seams. It leaves large areas of the underlying floor visible.
3. At most 24 flame anchors are placed on a golden-angle spiral within 80% of
   the radius. Their radial distribution is proportional to square-root area,
   avoiding either a crowded center or an empty, ring-only effect.
4. Each tongue gets a stable phase offset, cycle speed and height variation from
   seed and index. Height is a sine pulse, further limited by radius, intensity,
   ignition and the remaining-lifetime exit envelope. A tapered width and
   height-dependent sway form pointed flames, not rectangular particles.
5. Every tongue uses three hard color bands, without additive bloom. The ground
   layer alone is translucent. The complete circular footprint clips every
   flame; no apparent hazard extends beyond it except raster quantization.
6. The outline is rendered in a separate Z+1 pass, above all Z+0 body fills.
   Its footprint and width do not oscillate. A small moving warm glint gives
   subtle activity without hiding any boundary. It stays complete until expiry;
   it is not a shrinking radius or a second gameplay countdown.
7. Exact age >= duration hides the component and also returns a transparent
   shader mask. Cancellation disables future seeks until a new play call.

All shapes are functions of absolute age and seeded constants. There is no
`TIME`, particle queue, accumulated emitter debt or per-frame random stream.
Without a new caller age, two frames render identically. Seeking back produces
the same image on the same rendering backend. Floating-point sine hashing does
not promise cross-GPU/cross-engine pixel-identical randomness.

## Bounds and game responsibilities

Per-zone state is constant-size: two surfaces, two materials, a small fixed
settings dictionary, one shader loop of at most 24 tongues per body pixel.
The host still owns total active-zone count and screen coverage; many huge
overlapping zones can cause fill-rate cost. A host visual budget must never
remove logical zones, suppress their damage, change strongest-overlap behavior
or silently hide required zone boundaries. No claim of unlimited overlap or
device-wide performance certification is made.
