# Algorithm and reference

Reference inspected: [Sprite Fusion · Dash & Blink](https://www.spritefusion.com/pixel-art-vfx/movement), obtained through the free `get_vfx(movement)` reference tool. The useful mature pattern is arrival cues aligned to a feet anchor, inward particle motion, finite silhouette reconstruction, then independent cleanup. Our implementation is original: it does not copy the TypeScript source, move the actor, reconstruct every pixel, add global flashes or reproduce the reference's longer departure/arrival sequence. No third-party art or code is bundled.

Let `u = elapsed / duration`:

1. Ground ring: radius contracts from `R` to `0.55R` by u=0.6. Its y radius is 0.35 of x; broken quadrants avoid a solid flat disc. Colors switch in discrete steps. A brief inner ring at u=0.35–0.58 reinforces compression. The dim residual ring expands only to 0.8R and disappears at u=0.92.
2. Particles: a fixed seeded schedule is generated once per play, bounded to 32 entries. Each entry has an angle in [0,2π), start delay in [0,0.2], travel fraction [0.22,0.38], radial multiplier [0.8,1.3], destination height [8,27] pixels and size of 1–2 pixels. Position is `lerp(start,end,q²)` during its own lifespan. No per-frame random sampling or new emitter allocation.
3. Body: sample the existing host texture, retain its alpha and modulate. A pixel-row threshold rises from bottom to top over the configured reveal interval. Only the two active boundary rows receive a mild ivory tint. At full reveal there is no tint; fully transparent texels never receive color coverage.
4. Arrival: emit exactly one `appeared` signal at the reveal endpoint. A compact feet bracket lasts u=0.58–0.73; it is not an explosion or persistent aura.
5. End: at u=1, clear particle storage, stop drawing and restore the saved host material. Cancellation restores pre-play visibility as well. A generation token ensures a cancellation/replay from an event callback wins over the previous tick.

All shape/time formulas use absolute elapsed time, so frame cadence does not alter particle paths or seeded structure. There is no fixed visual-frame count. Event crossings occur on the first update at or after their specified timestamp.
