# Ice (ice.ts)

Faceted ice for every case: spikes erupting along the ground, a frost nova that crusts the floor and snaps crystal clusters up, a shimmering cluster, a block shattering, and a character frozen solid that cracks free.

Previews (animated WebP, 320 × 200 art pixels): Nova https://www.spritefusion.com/images/pixel-art-vfx/ice-nova.webp, Spikes https://www.spritefusion.com/images/pixel-art-vfx/ice-spikes.webp, Crystals https://www.spritefusion.com/images/pixel-art-vfx/ice-crystals.webp, Shatter https://www.spritefusion.com/images/pixel-art-vfx/ice-shatter.webp, Freeze https://www.spritefusion.com/images/pixel-art-vfx/ice-freeze.webp

Page: https://www.spritefusion.com/pixel-art-vfx/ice. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/ice.zip

## Recipe
- **Palette:**
  - `palette`, 8 hex, light to dark, default #ffffff, #dcfbff, #a6ecff, #62c8f4, #3a8bd8, #2c58aa, #212f6b, #151a3d (warm lights, cool shadows). All 8 steps are used, plus a fixed white.
  - Step 0: the nova's release shards, the hot edge of its rings, the lit lip above cracks.
  - Step 1: crystal edges, ridges and flaws; bodies' lit edges and upper-left ridges; the frost's top row; glints; flake arms; the chips knocked off a block.
  - Step 2: crystals' lit face near the ridge; body facets; frost; mist and vapour; drips; most glows.
  - Step 3: crystals' lit face toward the edge; body facets; frost below the ground line; mist; streak tails; the frozen character's tint (42%); the broad glows.
  - Step 4: crystals' shaded face near the ridge; body facets.
  - Step 5: crystals' shaded face toward the edge; body facets and far edges; the nova core's outline.
  - Step 6: the last 1.2 px of a crystal's shaded face; cracks.
  - Step 7: outlines of crystals, bodies and chunks.
  - White (#ffffff whatever `palette`): crystal tips, white flashes, fresh cracks, streak heads, the hoarfrost's fresh edge and tuft tips, the streak of light across a body, star centres.
  - Flash colour: rgb(214, 244, 255).
- **Shapes and motion** (all kinds): sizes in art px, positions and speeds in world units. Rates "per update" assume 60 updates a second.
  - Partial opacity is a 4 × 4 Bayer ordered dither. Alpha-blended: mist, vapour, and the shell over a frozen character. Glows add colour × strength × (1 − d/r)² to the light buffer; timed lights shrink from r to 0.55r and fade as strength × (life left)².
  - Crystal: a leaning triangle h tall and w wide at its foot, its tip shifted `lean` px.
    - A ridge runs from 0.14w left of centre at the foot to the tip.
    - Lit face (left of the ridge): a 1 px outer edge step 1, step 3 toward the edge, step 2 near the ridge (past 55% of the way), the ridge step 1.
    - Shaded face (right): step 4 near the ridge, step 5 past halfway, the last 1.2 px step 6.
    - The top 10% white. 5% of pixels step 1 (flaws). A 1 px step 7 outline on every side but along the ground.
    - Variants: all white (a flash); dithered opacity (melting); a glint band sweeping up the lit face and ridge (±0.05 of its height white, ±0.1 step 1); dim (every colour one step darker, the tip step 1).
    - It grows from its foot with an overshoot (outBack).
  - Body (a block, or a shell over a character): a mask, faceted.
    - max(4, w × h / 70) seeds; each pixel takes its nearest seed (distances with y × 0.8). Each facet is one flat tone, step 2–5, random ± and darker toward the lower right.
    - Borders between facets (within 1.1 px of a second seed): step 1 in the upper-left half, step 2 in the other.
    - Left and top edges step 1; right and bottom edges step 5; a white diagonal streak (x + 0.6y between 0.22·min(w, h) and + 1.6) across its upper 60%; 3% flaws step 1; a 1 px step 7 outline.
    - Block: w × h with its top corners cut diagonally by 22% of w and its top uneven by 0–2 px in 3 px columns.
  - Cracks: n walkers from the impact point, up to 30 steps of 1.5–2.6 px, turning ±0.55 rad each step, forking on 12% of steps (half as long, up to 2n paths), stopping at the body's edge. Revealed from the impact over 0.24 s. Each point is a step 6 pixel with a step 0 pixel above it; the newest 2 points of each walker white for the first 0.3 s.
  - Body burst (shatter, freeze), with a power and a blow angle:
    - About 16% of the body's pixels fly off as shards in their own colour: away from the impact at (120–360) × power, plus (60–240) × power along the blow, plus (80–260) × power up. Life 1–1.6 s, 1.5–4 px long.
    - max(4, w × h / 70) chunks: (100–260) × power away, (120–300) × power up, life 1.2–1.8 s, size 2.2–4.5.
    - 12 mist puffs, 8 glints, a white light r (2.4h + 30)/2 at 0.7 for 0.14 s and a step 3 light r (4h + 50)/2 at 0.5 for 0.45 s.
  - Bits ("front"), falling at 1900 × g units/s² (g 0.6–1), drag 0.4–0.6, spinning up to ±22 rad/s:
    - Shard: a 1 px sliver s long turning, its leading pixel white.
    - Chunk: a turning lozenge (|u|/s + |v|/0.62s ≤ 1), its quarters step 1, 2, 3 and 5, a step 7 outline.
    - Drip: a step 2 pixel with a step 3 pixel above at 60%.
    - On the ground: shards skid (vx × 1.6), drips vanish, bits faster than 140 bounce (× 0.25–0.3, vx × 0.7), slower ones rest. All dither out over their last 0.4 s.
  - Particles (drag is v −= v·drag·dt):
    - Mist ("back"): an alpha-blended disc growing from 0.6 to 1.5 × size, opacity 0.7 × (life left)^1.3, drag 4, rising 10 units/s².
    - Vapour ("back"): the same at 0.45 opacity, plus a light glow r 1.8 × radius, step 2.
    - Star: a twinkling plus, arms round(size × twinkle) px, tips at 75% brightness, diagonal corners from 3 px, a white centre; under size 1 a single pixel. Drag 1.6, rising 10 units/s².
    - Streak: accelerating (v × e^(3t)), 1–7 px long (speed / 60): a white head, its colour, a step 3 tail fading. Light glow r 4.
    - Flake: one pixel, plus step 1 arms above size 1.3; it drifts down (up to about 32 units/s), sways 14 units/s, fades over its last third.
    - Mist burst at (x, y): n mist puffs within ±10 units, ±(30–160) sideways, 2–14 up, life 0.6–1.2 s, steps 2 and 3, size 2–4.
    - Glints over an area: stars ±20 sideways, 0–30 up, life 0.4–1 s, size 1–2.6, step 2 unless noted.
    - Shard burst out of the ground: n shards fanned ±1.3 rad round straight up at (120–420) × power, life 0.9–1.6 s, 1.5–3.5 px, steps 2–4.
  - Frost on the ground: for each art column, hashed: 75% get a pixel on the ground row (step 1 or 2), 40% one below it (step 3, 70%), 12% another (step 4, 60%). Optionally tapered over its last few px.
- **Nova** (`kind: "nova"`): defaults `charge` 0.5, spread 0.7, `hold` 0.75, so release at 0.5 s, held until 1.95 s, gone at 2.85 s.
  - **Timeline:**
    - 0–0.5 s, charge: a core 30 units above the ground swells with two heartbeats (at 0.27 and 0.42 s); cold streaks fly in to it and along the ground; a ring on the ground closes in toward it; a frost patch grows under it.
    - 0.5 s, release: a flash, shake and ripple; an 8-ray flare (0.22 s) as the core collapses; 22 shards and 14 flakes burst out; a ring through the air (0.4 s).
    - 0.5–1.2 s: a ring races out along the ground to `reach`, leaving hoarfrost behind it, mist and flakes kicked up at its front. Crystal clusters spring up as it passes (0.52–0.9 s).
    - Until 1.95 s, it holds: glints on the crystals, flakes drifting down.
    - About 2.0–2.4 s: the crystals break, inner ones first. 2.05–2.85 s: the hoarfrost melts back from the rim inward.
    - `done()`: after 2.85 s once bits and particles are gone, about 4.6 s.
  - **Layers:** "back": the hoarfrost, the far halves of the closing and racing rings, the back row of crystals (dim), mist and vapour. "front": the near halves of those rings, the core and flare, the air ring, the front row of crystals, bits, stars, streaks and flakes. Light: the core r 10 + 6r (step 2, 0.4 + 0.6k); the flare r 46 white (0.6 → 0); 7 glows along the air ring's upper arc r 14 (step 2, 0.35); glows at both ends of the racing ring r 22 (step 2, 0.55); 7 ambient glows along the frozen ground r 26 (step 3, 0.16, breathing at 2.4 rad/s, fading 1.95–2.85 s); release lights r 145 (step 3, 0.8, 0.55 s) and r 45 (white, 0.7, 0.12 s); vapour and particle glows.
  - **Shapes and motion** (all sizes × `size`; reach = `reach` / 2 = 132 px each side):
    - Core: a diamond (|dx| + |dy| ≤ n + 1) of radius (1 + 3.5k²) px × heartbeat (+25%, +30%), k = t / charge. Outline step 5; upper-left quarter white within 60%, else step 1; lower-right step 3; the other two step 2. Four axis rays reach out to n + 2 + r × (1.2 + 0.4·sin 12t), step 1 then step 2 for their last quarter, dithered at k + 0.3.
    - Bands (all the rings): a band of thickness th inward from radius r: its outer 15% white when hot, else step 1; to 40% step 1; to 70% step 2; the inner part step 3, dithering out (× 1.15 − depth).
    - Closing ring (charge): an ellipse (ry = 0.16 rx) on the ground, rx 64 → 10 px, 2.5 px thick, one step darker, opacity 0.3 → 1.
    - Flare: 8 rays at 45°, horizontal ones 36 × (1 − a)^1.5 px long (a over 0.22 s), vertical ones 0.6 × that, diagonals 0.3 ×. White for the first 35%, step 1 to 70%, step 2 after; the horizontal rays thickened by a zigzag step 1 pixel near the centre. The core shrinks from 5 px to nothing over its first 40%.
    - Air ring: a circle on the core, radius 6 → 6 + 0.6 × reach in 0.4 s (outCubic), 8 × (1 − u)^0.7 px thick (min 3), only above the ground; hot for 0.08 s; fading over its last 25%.
    - Racing ring: an ellipse (ry = 0.16 rx) on the ground at the frost front, rx = reach × (1 − (1 − u)³) over 0.7 s, 11 × (1 − u)^0.7 px thick (min 2), hot for 0.1 s, fading over the last 25% of 0.85 s.
    - Hoarfrost: over the ground from −front to +front (a 14 px patch grows under the core during the charge). Per column, at q = distance / reach:
      - The ground row: white within 3 px behind the front (the fresh edge) and on 25% of columns, else step 1.
      - Tufts on 45% of columns, 1–4 px tall (shorter outward), step 2 with a white tip, some with a step 1 side pixel.
      - Below the ground row: 5–10 px deep (halved toward the rim), step 1, then step 2 from 25%, then step 3 from 55%, 6% white sparkles, dithered stronger near the top, shimmering at 0.85–1 (sin(5t + x)), 1.3× at the fresh edge.
      - It melts back from the rim inward over 2.05–2.85 s.
    - Crystal clusters: 12 sites each side, at these fractions of the reach (±0.025): 0.1, 0.16, 0.22, 0.29, 0.36, 0.44, 0.52, 0.6, 0.68, 0.76, 0.84, 0.92, with heights 30, 6, 24, 5, 19, 5, 15, 4, 11, 4, 8, 3 px (× 0.85–1.1): big clusters alternate with tiny ones, shrinking outward.
      - Width 45–55% of the height (3–16 px). The main crystal leans outward by 12–30% of its height.
      - Sites of height 30, 24 have 1–2 extra crystals; 19, 15, 11 have 0–1: 40–62% as tall, 0.62 × as wide, offset 0.3–0.5 w to alternate sides, each leaning toward its own side by 35–60% of its height.
      - The big sites alternate between front and back along each side; back ones are drawn dim, 1 px higher.
      - Each springs up as the ring reaches it (+0–0.03 s), growing in 0.1 s (outBack 2.6), white for its first 0.03 s and its last 0.05 s. A glint band sweeps up it for 0.71 s every 2.29 s.
      - Each breaks at 1.95 + 0.4 × fraction + 0–0.08 s.
    - Particles:
      - Charge (until 0.42 s): 90% chance per update, a streak from 26–58 px round the core (kept above the ground) flying in to it in 0.2–0.3 s; 60%, a streak along the ground from 28–70 px out flying in; 12%, a vapour wisp along the ground flying in (70–140 units/s, size 2–3). Steps 1 and 2.
      - Release: 22 shards from the core over the upper half and a little below (−180° to +14°), 220–560 units/s, life 0.9–1.5 s, steps 0–2; 14 flakes up at 80–320, life 1.2–2.2 s, white or step 1.
      - 0.8–0.9 s: 3 per update, stars or flakes where the air ring ended, drifting outward at 40.
      - 0.5–1.2 s: each side, every update, a vapour puff at the ring's front (30–150 outward, size 3–5.5 shrinking 40% toward the rim) and a 45% chance of a flake kicked up (60–170 up).
      - A crystal springing up (taller than 6): a shard burst of 2 + h/8 at power 0.5 + h/40, a vapour puff, a glint.
      - A crystal breaking: 4 + h/3 bits (20% chunks) from along its height, ±140 sideways, 40–220 up, life 0.8–1.3 s, size 1.2–3, steps 1–4; a vapour puff if taller than 14; a glint at 50%.
      - Until 2.25 s, 50% per update a glint on a standing crystal. 0.8–2.35 s, 10% per update a flake falls from 60–170 units above the frozen ground.
- **Spikes** (`kind: "spikes"`):
  - **Timeline:** frost runs out along the ground over 0.05–0.35 s. 6 spikes erupt one after another at 0.28 + 0.085i s (0.28 to 0.71 s), each shoving past its height and settling in 0.11 s. They stand; each flashes white for 0.06 s and shatters at 2 + 0.07i s (2.0 to 2.35 s). The frost fades over 2.4–3.4 s. `done()` after 2.55 s once the bits are gone, about 3.9 s.
  - **Layers:** "back": the frost, mist. "front": the spikes, bits, glints. Light: each spike r 0.9h + 8 at mid-height (step 3, 0.18, +0.5 fading over its first 0.15 s, +0.5 while white); a pop at its foot r 14 (white, 0.6 fading over 0.15 s); star glows.
  - **Shapes and motion:**
    - Spike i (0 to count − 1): at x + dir × (60 + i × `spacing` ± 8) units; height (20 + 9i ± 2) px, foot width 10 + 1.8i px (both × `size`); tip lean (−1…2.5 + 0.4i) px toward `dir`.
    - Two smaller crystals at its foot, one each side, offset 3–5 × w/8 px, 30–50% as tall, 0.55 w wide, leaning outward 2–4 px.
    - Frost from x to 10 px past the last spike.
    - Erupting (n-th): a shard burst of 6 + n at power 0.8 + 0.08n, 8 mist puffs, 4 glints up its height.
    - Shattering: 10 + h/2 bits (20% chunks) from along its height, ±160 sideways, 60–340 up, life 1–1.5 s, size 1.5–4.5, steps 1–5; 6 slower mist puffs; 3 glints in step 1.
    - Standing: 25% per update a step 1 star on a standing spike, up to 80% of its height, drifting up 6 units/s.
- **Crystals** (`kind: "crystals"`):
  - **Timeline:** 7 crystals pop up from 0 to 0.27 s, the big one first, each growing in 0.16 s (outBack 2.2); frost spreads round their feet over 0.6 s. They stand until 0.5 + `hold` (2.9 s), shimmering. Then, with `end: "melt"`: they shrink and slump over 0.9 s, dither out over 3.4–3.9 s, dripping until 3.7 s; the frost shrinks back over 3.3–4.1 s; `done()` after 4.1 s. With `end: "shatter"`: white for 0.06 s, then they burst at 2.9 s; `done()` once the bits are gone, about 4.5 s.
  - **Layers:** "back": the frost, mist. "front": the crystals, drips, bits, glints. Light: r 46 at 16 px up (step 3, 0.32, breathing at 2.6 rad/s) and r 20 at 4 px up (step 2, 0.25), both fading in over 0.3 s and out as they melt; the first pop's light r 60 (step 2, 0.8, 0.3 s); a shatter's r 80 (white, 0.8, 0.2 s).
  - **Shapes and motion:** (all × `size`)
    - The 7 crystals as [x offset, height, foot width, tip lean, pop time]: [0, 36, 12, 1.5, 0], [−7, 23, 9, −6, 0.07], [8, 26, 9.5, 7, 0.11], [−3, 15, 7, −3, 0.15], [−13, 12, 7, −7, 0.19], [14, 13, 7, 8, 0.23], [4, 10, 6, 4, 0.27]; drawn in that order.
    - Each pop: the first a shard burst of 10 at power 1, 8 mist puffs; the others 4 shards at power 0.6, 3 mist puffs.
    - A glint band sweeps up each one for 1.1 s every 2.55 s, each at its own phase.
    - Frost ±34 px round them, tapered over 10 px.
    - Standing: 20% per update a star (step 1 or white) on a crystal; after 0.3 s, 12% per update a mist puff drifting along the ground within ±40 units (life 1–1.8 s, size 2.5–4.5).
    - Melting: height × (1 − 0.85m), width × (1 − 0.3m), lean × (1 − m), m going 0 → 1. Drips: 45% per update, falling from up to 60% of a crystal's height, gone when they land.
    - Shattering: per crystal 6 + h/3 bits (25% chunks), ±260 sideways, 100–420 up, life 1–1.6 s, size 1.5–4.5, steps 1–4; 10 mist puffs.
- **Shatter** (`kind: "shatter"`):
  - **Timeline:** a block rises out of the ground over 0–0.25 s with a little overshoot, mist puffing at its foot. Struck at `crack` (0.7 s): chips fly back, cracks race over it from the impact for 0.24 s. White for 0.04 s, then it bursts at `crack` + 0.36 (1.06 s). The frost under it fades over 1.66–2.66 s. `done()` after 1.16 s once the bits are gone, about 2.8 s.
  - **Layers:** "back": frost, mist. "front": the block, cracks, bits, glints. Light: the block r h + 10 at its middle (step 3, 0.25, +0.6 while white); the impact r 30 (white, 0.9, 0.12 s); the burst's two lights.
  - **Shapes and motion:**
    - Block: 24 × 30 px (× `size`), standing on the ground at x; revealed from the bottom row up (outBack 1.6).
    - Impact point: (w/2 − 0.42w × cos(angle), 0.55h − 0.3h × sin(angle)) in the block. With `angle` 0, its left side a little below the middle.
    - At the strike: 7 cracks; 6 step 1 chips flying back against the blow (angle + π ± 0.9 rad) at 120–300 and 80 up, life 0.6–1 s, 1–2.2 px.
    - Burst: the body burst at power 1 along `angle` (about 100 shards and 10 chunks at size 1).
    - Frost under it, ±0.8 w, tapered over 6 px.
- **Freeze** (`kind: "freeze"`): lock at 0.45 s, cracks at 0.45 + `hold` (2.05 s), burst 0.3 s later (2.35 s).
  - **Timeline:** on its first update it takes the character's pixels and cues "freeze". 0–0.45 s, frost creeps up it from its feet (fast, then slowing: outCubic). 0.45 s, the shell locks in: a white flash for 0.05 s, crystals snapping out of it, a light, glints. It holds, glinting, until 2.05 s; cracks race over it for 0.24 s; at 2.35 s it bursts upward and cues "thaw". The frost round its feet fades over 2.85–3.85 s. `done()` after 2.45 s once the bits are gone, about 4 s.
  - **Layers:** "back": frost round its feet (fading in over 0.3 s), mist. "front": the character's tinted pixels, the shell, its crystals, the creeping front, cracks, bits, glints. The front layer covers the character, so keep drawing it as usual. Light: the shell r 0.8h (step 3, up to 0.3 by 0.45 s, breathing at 3 rad/s); the lock light r 60 (step 2, 0.9, 0.25 s); the burst's two lights.
  - **Shapes and motion:**
    - Shell: the silhouette grown by 3 px diamond-wise (45° facets), not below its lowest pixel, faceted as a body. Drawn translucent: its step 1, step 5 and white pixels (edges, upper ridges, flaws, the darkest facets, the streak) opaque, the rest alpha-blended at 38%.
    - Under it, the character's own pixels from that first update, mixed 42% toward step 3: frozen in that pose.
    - Without a silhouette: an opaque 16 × 38 px block standing at x, with no crystals.
    - Creeping: rows are shown from the bottom up to a level that reaches the top at 0.45 s; the front row's pixels are white (60%) or step 1. 70% per update a star at the front (±12 sideways, up to 20 up); 30% a mist puff at its feet.
    - Crystals snapping out at the lock, each growing in 0.12 s (outBack 2.4), white for 0.04 s:
      - On top: 10 px tall, 5 wide, leaning ±2, at 0.45 s.
      - Three pairs on its sides at 20%, 37% and 54% of its height down: 6–9 px tall, 3.5–4.5 wide, leaning 4–6 px outward, at 0.48–0.56 s.
      - Four round its feet (at −3, 2, w − 2 and w + 3 px): 6–10 px tall, 4–6 wide, leaning −5, −2, 2, 5 px, at 0.45–0.53 s.
    - Holding: 12% per update a star (step 1 or white) on the shell. Cracks: 8 walkers from a point 35–65% across and 30–50% down.
    - Burst: the body burst from its middle (w/2, 0.45h) at power 0.7, upward.
- **Feel:**
  - Nova: at release a flash of 0.22, a camera shake of 0.5 and a scene ripple from the core, radius 20 → 1.3 × reach × size (343) over 0.65 s. A shake of 0.08 as each crystal taller than 20 px breaks.
  - Spikes: a shake of 0.12 + 0.02n as the n-th erupts (0.14 to 0.24), 0.1 as each shatters.
  - Crystals: a shake of 0.2 at the first pop, 0.05 at the others. Shatter end: a shake of 0.35 and a flash of 0.3.
  - Shatter: a shake of 0.15 at the strike. At the burst a shake of 0.4, a flash of 0.35 and a ripple from radius 10 to 160 over 0.4 s.
  - Freeze: shakes of 0.15 at the lock, 0.08 at the cracks, 0.3 at the burst, with a flash of 0.25.

## Situations
- **Nova:** `ice({ kind: "nova", actor: player, ground: 300 })`: cold gathers at the player's feet, then bursts: rings through the air and along the ground, hoarfrost and crystal clusters 264 units either side, breaking and melting back.
- **Spikes:** `ice({ kind: "spikes", x: 160, ground: 300 })`: frost runs right from x 160 and six spikes, each bigger than the last, erupt along it, stand, then shatter in turn.
- **Crystals:** `ice({ kind: "crystals", x: 440, ground: 300, hold: 1.9 })`: a cluster of 7 crystals pops out of the ground, shimmers for 2.4 s, then melts down, dripping.
- **Shatter:** `ice({ kind: "shatter", x: 440, ground: 300 })`: a block of ice rises, is struck from the left, cracks and bursts into shards and chunks flung to the right.
- **Freeze:** `ice({ kind: "freeze", actor: player, ground: 300 })`: the player is frozen in a faceted shell creeping up from its feet, held 1.6 s, then cracked and burst off.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `kind` | `"spikes" \| "nova" \| "crystals" \| "shatter" \| "freeze"` | `"spikes"` | Which situation. |
| `x` | number (world units) | the actor's `feet()[0]`, else spikes `470`, nova `640`, crystals `760`, shatter `780` (no actor fallback), freeze `640` | Spikes: where the row starts (the first spike is 60 units on). Nova, crystals, shatter: their centre. Freeze: where its block stands when there's no silhouette. |
| `ground` | `number \| ((x: number) => number)` (world y) | `600` | The ground everything stands on and bits land on. Always set it. |
| `actor` | `Actor` | none | See below. |
| `size` | number | `1` | Scale. Spikes: heights and widths. Nova: the core, reach, rings, crystals and their particles. Crystals: the cluster, its frost and light. Shatter: the block. Not freeze. |
| `palette` | `string[]` (hex, light to dark) | the ice ramp above | Its 8 colours. |
| `seed` | number | `1` | Random seed. |
| `dir` | number | `1` | Spikes: which way they run (its sign: 1 right, −1 left). |
| `count` | number | `6` | Spikes: how many (at least 1). |
| `spacing` | number (world units) | `74` | Spikes: from one to the next. |
| `reach` | number (world units) | `264` | Nova: how far the frost and crystals reach each side (× `size`). |
| `charge` | number (s) | `0.5` | Nova: gathering time before the burst. |
| `hold` | number (s) | nova `0.75`, crystals `2.4`, freeze `1.6` | Nova: held after the 0.7 s spread. Crystals: standing time after 0.5 s (`Infinity`: until `stop()`). Freeze: from the lock to the cracks. |
| `end` | `"melt" \| "shatter"` | `"melt"` | Crystals: how they go. |
| `angle` | number (rad) | `0` | Shatter: the direction the blow travels. 0: from the left, debris flies right; π: from the right. |
| `crack` | number (s) | `0.7` | Shatter: when it's struck (it bursts 0.36 s later). |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |
| `flash` | `(k: number, rgb: string) => void` | none | Screen flash hook. |
| `ripple` | `(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number) => void` | none | Scene ripple hook. |
| `cue` | `(name: "freeze" \| "thaw") => void` | none | Freeze: holds and releases your character. See below. |

## Actor, methods and hooks
- `actor`:
  - `feet(): [number, number]` (world units): the x for spikes, nova and crystals when `x` is left out, read once at creation (the effect stays there). Freeze's block x without a silhouette.
  - `silhouette?(): { x: number; y: number; w: number; h: number; data: Uint32Array }`: the character's pixels now, in art px (x, y its top-left; `data` ABGR row by row; alpha > 0 is the character). Freeze reads it once, on its first update, to build the shell and the tinted copy.
- `stop()`: crystals only: ends their standing now, so they melt or shatter. Use it with `hold: Infinity`. It does nothing for the other kinds.
- `cue(name: "freeze" | "thaw")`: freeze only. "freeze" on its first update: hold the character still (the shell is a snapshot of its pose there). "thaw" at the burst (0.75 + `hold` s, 2.35 s by default): let it move again.
- `shake(trauma: number)`: see Feel: per kind, at the eruptions, pops, strikes, locks, cracks, breaks and bursts listed there.
- `flash(k: number, rgb: string)`: always "214,244,255": nova release 0.22, crystals' shatter end 0.3, shatter burst 0.35, freeze burst 0.25.
- `ripple(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number)`: nova release with (x, ground − 30 × size, 20, 1.3 × reach × size, 0.65, 0.2, 26); shatter burst with (x, ground − 30 × size, 10, 160, 0.4, 0.12, 18). It asks for a ring that distorts the scene round (x, y): its radius goes from r0 to r1 world units over dur seconds, with strength amp and band width w.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: ice.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { feet(): [number, number]; silhouette?(): { x: number; y: number; w: number; h: number; data: Uint32Array } }
export interface Options {
  kind?: "spikes" | "nova" | "crystals" | "shatter" | "freeze";
  x?: number; ground?: number | ((x: number) => number); actor?: Actor; size?: number; palette?: string[]; seed?: number;
  dir?: number; count?: number; spacing?: number;
  reach?: number; charge?: number; hold?: number;
  end?: "melt" | "shatter";
  angle?: number; crack?: number;
  shake?(trauma: number): void;
  flash?(k: number, rgb: string): void;
  ripple?(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number): void;
  cue?(name: "freeze" | "thaw"): void;
}
export default function ice(o: Options = {}) {
  const pal = o.palette?.map(hex) ?? ICE0;
  ICE = pal;
  const R = new Rng(o.seed ?? 1), ground = (x: number) => (o.ground === undefined ? 600 : typeof o.ground === "number" ? o.ground : o.ground(x));
  const c: Ctx = { o, R, ground, ps: new Particles(R), bits: new Bits(ground), lights: new Lights() };
  const scene = ({ nova, crystals, shatter, freeze, spikes }[o.kind ?? "spikes"] ?? spikes)(c);
  let t = 0;
  return {
    update(dt: number) { ICE = pal; scene.update((t += dt)); c.bits.step(dt); c.lights.update(dt); c.ps.update(dt); },
    draw(f: Frame, layer?: Layer) {
      ICE = pal;
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") { scene.back(buf, light, t); c.ps.draw(buf, light, "back"); }
      if (layer === "back") return;
      scene.front(buf, light, t);
      for (const b of c.bits.list) {
        const a = Math.min(1, b.life / 0.4);
        if (b.kind === SHARD) shard(buf, b, a);
        else if (b.kind === CHUNK) chunk(buf, b, a);
        else dot(buf, b.x / PX, b.y / PX, ICE[2]!), dot(buf, b.x / PX, b.y / PX - 1, ICE[3]!, 0.6);
      }
      c.ps.draw(buf, light, "front");
      c.lights.draw(light);
    },
    stop: () => scene.stop?.(t),
    done: () => scene.over(t) && c.ps.list.length === 0 && c.bits.list.length === 0,
  };
}
interface Ctx { o: Options; R: Rng; ground: (x: number) => number; ps: Particles; bits: Bits; lights: Lights }
interface Scene { update(t: number): void; back(buf: Px, light: Px, t: number): void; front(buf: Px, light: Px, t: number): void; over(t: number): boolean; stop?(t: number): void }
const SHARD = 0, CHUNK = 1, DRIP = 2;
function burst(c: Ctx, x: number, y: number, n: number, up: number) {
  const R = c.R;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI / 2 + R.range(-1.3, 1.3), sp = R.range(120, 420) * up;
    c.bits.add({ kind: SHARD, x: x * PX + R.range(-6, 6), y: y * PX, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 0.8, drag: 0.6, bounce: 0.3, life: R.range(0.9, 1.6), a: R.range(0, TAU), va: R.range(-18, 18), s: R.range(1.5, 3.5), c: R.pick([ICE[2]!, ICE[3]!, ICE[4]!]) });
  }
}
function mist(c: Ctx, x: number, y: number, n: number, sp: number) {
  const R = c.R;
  for (let i = 0; i < n; i++) c.ps.spawn(K.DUST, x * PX + R.range(-10, 10), y * PX - R.range(0, 6), R.sign() * R.range(30, 160) * sp, -R.range(2, 14), R.range(0.6, 1.2), R.chance(0.5) ? ICE[2]! : ICE[3]!, R.range(2, 4));
}
function glints(c: Ctx, x: number, y: number, n: number, w: number, h: number, col = ICE[2]!) {
  const R = c.R;
  for (let i = 0; i < n; i++) c.ps.spawn(K.STAR, x + R.range(-w, w), y - R.range(0, h), R.range(-20, 20), R.range(-30, 0), R.range(0.4, 1), col, R.range(1, 2.6));
}
function frost(buf: Px, c: Ctx, x0: number, x1: number, a: number, edge = 0) {
  for (let x = Math.floor(Math.min(x0, x1)); x <= Math.max(x0, x1); x++) {
    const y = c.ground(x * PX) / PX, h = hash(x, 17), d = edge ? Math.min(Math.abs(x - x0), Math.abs(x - x1)) / edge : 1;
    if (h < 0.75 * Math.min(1, d * 2)) dot(buf, x, y, h < 0.3 ? ICE[1]! : ICE[2]!, a);
    if (h < 0.4 * Math.min(1, d * 2)) dot(buf, x, y + 1, ICE[3]!, a * 0.7);
    if (h < 0.12 * d) dot(buf, x, y + 2, ICE[4]!, a * 0.6);
  }
}
function spikes(c: Ctx): Scene {
  const { o, R, ps } = c;
  const X = o.x ?? o.actor?.feet()[0] ?? 470, DIR = Math.sign(o.dir ?? 1) || 1, N = Math.max(1, o.count ?? 6), GAP = o.spacing ?? 74, S = o.size ?? 1;
  const list = Array.from({ length: N }, (_, i) => {
    const x = (X + DIR * (60 + i * GAP + R.range(-8, 8))) / PX;
    return {
      x, base: c.ground(x * PX) / PX, h: (20 + i * 9 + R.range(-2, 2)) * S, w: (10 + i * 1.8) * S, lean: (R.range(-1, 2.5) + i * 0.4) * DIR, at: 0.28 + i * 0.085, breakAt: 2 + i * 0.07,
      kids: [-1, 1].map((s) => ({ dx: s * R.range(3, 5), h: R.range(0.3, 0.5), lean: s * R.range(2, 4) })),
    };
  });
  const span = Math.abs(list[N - 1]!.x - X / PX) + 10;
  let erupted = 0, broken = 0;
  return {
    update(t) {
      while (erupted < N && t >= list[erupted]!.at) {
        const s = list[erupted++]!;
        burst(c, s.x, s.base, 6 + erupted, 0.8 + erupted * 0.08);
        mist(c, s.x, s.base, 8, 1);
        o.shake?.(0.12 + erupted * 0.02);
        glints(c, s.x * PX, s.base * PX - 10, 4, 14, s.h * PX);
      }
      while (broken < N && t >= list[broken]!.breakAt) {
        const s = list[broken++]!;
        for (let i = 0; i < 10 + s.h / 2; i++) {
          const u = R.next(), y = s.base - s.h * u;
          c.bits.add({ kind: R.chance(0.2) ? CHUNK : SHARD, x: (s.x + s.lean * u + R.range(-s.w / 3, s.w / 3) * (1 - u)) * PX, y: y * PX, vx: R.range(-160, 160), vy: -R.range(60, 340), g: 0.9, drag: 0.5, bounce: 0.25, life: R.range(1, 1.5), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1.5, 4.5), c: R.pick([ICE[1]!, ICE[2]!, ICE[3]!, ICE[4]!, ICE[5]!]) });
        }
        mist(c, s.x, s.base, 6, 0.6);
        o.shake?.(0.1);
        glints(c, s.x * PX, s.base * PX - 10, 3, 10, s.h * PX, ICE[1]!);
      }
      if (erupted > broken && R.chance(0.25)) {
        const s = list[R.int(broken, erupted - 1)]!;
        ps.spawn(K.STAR, (s.x + R.range(-s.w / 3, s.w / 3)) * PX, s.base * PX - R.range(4, s.h * 1.6), 0, -6, R.range(0.25, 0.5), ICE[1]!, R.range(1, 2.2));
      }
    },
    back: (buf, _, t) => frost(buf, c, X / PX, X / PX + DIR * (clamp((t - 0.05) / 0.3) * span), 1 - smooth(2.4, 3.4, t)),
    front(buf, light, t) {
      for (const s of list) {
        const g = t < s.at ? 0 : outBack((t - s.at) / 0.11, 2.4), after = t - s.breakAt;
        if (g <= 0 || after > 0.05) continue;
        const white = after > -0.06, pop = clamp(1 - (t - s.at) / 0.15);
        for (const k of s.kids) crystal(buf, s.x + k.dx * (s.w / 8), s.base, s.h * k.h * g, s.w * 0.55, k.lean, 1, white);
        crystal(buf, s.x, s.base, s.h * g, s.w, s.lean, 1, white);
        light.glow(s.x, s.base - s.h * 0.5, s.h * 0.9 + 8, ICE[3]!, 0.18 + 0.5 * pop + (white ? 0.5 : 0));
        if (pop > 0) light.glow(s.x, s.base - 2, 14, WHITE, 0.6 * pop);
      }
    },
    over: (t) => t > list[N - 1]!.breakAt + 0.2,
  };
}
const LAYOUT = [[0.1, 30, 2], [0.16, 6, 0], [0.22, 24, 2], [0.29, 5, 0], [0.36, 19, 1], [0.44, 5, 0], [0.52, 15, 1], [0.6, 4, 0], [0.68, 11, 1], [0.76, 4, 0], [0.84, 8, 0], [0.92, 3, 0]] as const;
function nova(c: Ctx): Scene {
  const { o, R, ps } = c;
  const S = o.size ?? 1, X = o.x ?? o.actor?.feet()[0] ?? 640, G = c.ground(X), cx = X / PX, cy = G / PX, coreY = cy - 15 * S;
  const B = o.charge ?? 0.5, SPREAD = 0.7, REACH = ((o.reach ?? 264) * S) / PX, HOLD = B + SPREAD + (o.hold ?? 0.75), GONE = HOLD + 0.9;
  const front = (t: number) => (t < B ? 0 : REACH * (1 - Math.pow(1 - clamp((t - B) / SPREAD), 3)));
  const at = (d: number) => B + SPREAD * (1 - Math.cbrt(1 - Math.min(1, d / REACH)));
  const sites: { x: number; q: number; h: number; dim: number; t0: number; tb: number; up: boolean; broke: boolean; parts: { dx: number; h: number; w: number; lean: number }[] }[] = [];
  for (const side of [-1, 1])
    for (const [i, [q0, h0, kids]] of LAYOUT.entries()) {
      const q = q0 + R.range(-0.025, 0.025), h = h0 * S * R.range(0.85, 1.1), w = clamp(h * R.range(0.45, 0.55), 3 * S, 16 * S);
      const parts = [{ dx: 0, h, w, lean: side * h * R.range(0.12, 0.3) }];
      for (let j = kids ? R.int(kids - 1, kids) : 0; j > 0; j--) {
        const s = j % 2 ? side : -side, kh = h * R.range(0.4, 0.62);
        parts.unshift({ dx: s * R.range(0.3, 0.5) * w, h: kh, w: w * 0.62, lean: s * kh * R.range(0.35, 0.6) });
      }
      sites.push({ x: cx + side * q * REACH, q, h, dim: h0 > 6 && (i / 2 + (side > 0 ? 1 : 0)) % 2 ? 1 : 0, t0: at(q * REACH) + R.range(0, 0.03), tb: HOLD + 0.4 * q + R.range(0, 0.08), up: false, broke: false, parts });
    }
  let released = false;
  const toward = (D: number, T: number) => (D * PX * 3) / (Math.exp(3 * T) - 1);
  const rings = (buf: Px, light: Px, t: number, back: boolean) => {
    const half = (g: number) => Math.sin(g) < 0 === back;
    if (t < B) { const k = t / B, r = (64 - 54 * k * k) * S; return band(buf, cx, cy, r, 0.16, 2.5, 0.3 + 0.7 * k, false, half, 1); }
    const a = t - B, u = clamp(a / (SPREAD + 0.15)), r = front(t) + 2;
    if (u >= 1) return;
    band(buf, cx, cy, r, 0.16, Math.max(2, 11 * S * Math.pow(1 - u, 0.7)), u < 0.75 ? 1 : (1 - u) / 0.25, a < 0.1, half);
    if (!back) for (const s of [-1, 1]) light.glow(cx + s * r, cy - 2, 22 * S, ICE[2]!, 0.55 * (1 - u));
  };
  const draw = (buf: Px, t: number, back: boolean) => {
    for (const s of sites) {
      if (!s.up || s.broke || s.dim !== (back ? 1 : 0)) continue;
      const g = outBack(clamp((t - s.t0) / 0.1), 2.6), white = t > s.tb - 0.05 || t < s.t0 + 0.03, sw = (((t - s.t0) * 0.7 + s.q * 3) % 1.6) / 0.5;
      for (const p of s.parts) crystal(buf, s.x + p.dx, cy - s.dim, p.h * g, p.w, p.lean * g, 1, white, sw <= 1 ? sw : -1, s.dim);
    }
  };
  return {
    update(t) {
      if (t < B - 0.08) {
        if (R.chance(0.9)) {
          const a = R.range(0, TAU), D = R.range(26, 58) * S, T = R.range(0.2, 0.3), v = toward(D, T), y = Math.min(coreY + Math.sin(a) * D * 0.8, cy - 2);
          ps.spawn(K.STREAK, (cx + Math.cos(a) * D) * PX, y * PX, ((cx - (cx + Math.cos(a) * D)) / D) * v, ((coreY - y) / D) * v, T, R.chance(0.5) ? ICE[1]! : ICE[2]!);
        }
        if (R.chance(0.6)) {
          const s = R.sign(), D = R.range(28, 70) * S, T = R.range(0.22, 0.32), v = toward(D, T);
          ps.spawn(K.STREAK, (cx + s * D) * PX, G - R.range(1, 8), -s * v, 0, T, R.chance(0.5) ? ICE[1]! : ICE[2]!);
        }
        if (R.chance(0.12)) {
          const s = R.sign();
          ps.spawn(K.VAPOUR, (cx + s * R.range(26, 56) * S) * PX, G - R.range(0, 4), -s * R.range(70, 140), -R.range(0, 6), R.range(0.35, 0.5), ICE[1]!, R.range(2, 3) * S);
        }
      }
      if (t < B) return;
      if (!released) {
        released = true;
        o.flash?.(0.22, "214,244,255");
        o.shake?.(0.5);
        o.ripple?.(X, coreY * PX, 20, REACH * PX * 1.3, 0.65, 0.2, 26);
        c.lights.add(X, coreY * PX, REACH * PX * 1.1, ICE[3]!, 0.8, 0.55);
        c.lights.add(X, coreY * PX, 90 * S, WHITE, 0.7, 0.12);
        for (let i = 0; i < 22; i++) {
          const a = R.range(-Math.PI, 0.25), sp = R.range(220, 560) * S;
          c.bits.add({ kind: SHARD, x: X + R.range(-6, 6), y: coreY * PX, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 0.7, drag: 0.6, bounce: 0.3, life: R.range(0.9, 1.5), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1.5, 3.5), c: R.pick([ICE[0]!, ICE[1]!, ICE[2]!]) });
        }
        for (let i = 0; i < 14; i++) {
          const a = R.range(-Math.PI, 0), sp = R.range(80, 320) * S;
          ps.spawn(K.FLAKE, X, coreY * PX, Math.cos(a) * sp, Math.sin(a) * sp, R.range(1.2, 2.2), R.chance(0.6) ? WHITE : ICE[1]!, R.range(0.5, 1.6));
        }
      }
      const fr = front(t);
      if (t > B + 0.3 && t < B + 0.4)
        for (let i = 0; i < 3; i++) {
          const g = -R.range(0.1, Math.PI - 0.1), r = 6 + REACH * 0.6;
          ps.spawn(R.chance(0.5) ? K.STAR : K.FLAKE, X + Math.cos(g) * r * PX, (coreY + Math.sin(g) * r) * PX, Math.cos(g) * 40, Math.sin(g) * 40, R.range(0.4, 0.8), R.chance(0.5) ? WHITE : ICE[1]!, R.range(0.6, 1.6));
        }
      if (t < B + SPREAD)
        for (const s of [-1, 1]) {
          ps.spawn(K.VAPOUR, (cx + s * fr) * PX + R.range(-4, 4), G - R.range(0, 10), s * R.range(30, 150), -R.range(4, 30), R.range(0.6, 1), R.chance(0.7) ? ICE[1]! : ICE[2]!, R.range(3, 5.5) * S * (1 - 0.4 * (fr / REACH)));
          if (R.chance(0.45)) ps.spawn(K.FLAKE, (cx + s * fr) * PX, G - 4, s * R.range(20, 90), -R.range(60, 170), R.range(1.1, 1.9), R.chance(0.5) ? WHITE : ICE[1]!, R.range(0.5, 1.2));
        }
      for (const s of sites) {
        if (!s.up && t >= s.t0) {
          s.up = true;
          if (s.h > 6) {
            burst(c, s.x, cy, 2 + Math.round(s.h / 8), 0.5 + s.h / 40);
            ps.spawn(K.VAPOUR, s.x * PX, G - 2, R.range(-60, 60), -R.range(4, 16), R.range(0.5, 0.9), ICE[1]!, R.range(2.5, 4) * S);
            glints(c, s.x * PX, G - 6, 1, 6, s.h * PX);
          }
        }
        if (!s.up || s.broke || t < s.tb) continue;
        s.broke = true;
        for (let i = 0; i < 4 + s.h / 3; i++) {
          const u = R.next(), p = R.pick(s.parts);
          c.bits.add({ kind: R.chance(0.2) ? CHUNK : SHARD, x: (s.x + p.dx + p.lean * u) * PX, y: G - p.h * u * PX, vx: R.range(-140, 140), vy: -R.range(40, 220), g: 0.9, drag: 0.5, bounce: 0.25, life: R.range(0.8, 1.3), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1.2, 3) * S, c: R.pick([ICE[1]!, ICE[2]!, ICE[3]!, ICE[4]!]) });
        }
        if (s.h > 14) ps.spawn(K.VAPOUR, s.x * PX, G - 2, R.range(-30, 30), -R.range(4, 14), R.range(0.5, 0.8), ICE[1]!, R.range(2.5, 4) * S);
        if (s.h > 20) o.shake?.(0.08);
        if (R.chance(0.5)) glints(c, s.x * PX, G - 4, 1, 6, s.h * PX, ICE[1]!);
      }
      if (t < HOLD + 0.3 && R.chance(0.5)) {
        const s = R.pick(sites);
        if (s.up && !s.broke) ps.spawn(K.STAR, s.x * PX + R.range(-6, 6), G - R.range(4, s.h * PX * 0.9), 0, -6, R.range(0.3, 0.6), R.chance(0.6) ? ICE[1]! : WHITE, R.range(0.6, 2.2));
      }
      if (t > B + 0.3 && t < HOLD + 0.4 && R.chance(0.1)) ps.spawn(K.FLAKE, X + R.range(-1, 1) * fr * PX, G - R.range(60, 170) * S, R.range(-10, 10), R.range(5, 20), R.range(1.6, 2.4), R.chance(0.5) ? WHITE : ICE[1]!, R.range(0.5, 1.4));
    },
    back(buf, light, t) {
      const out = 1 - smooth(HOLD + 0.1, GONE, t);
      if (out > 0) hoarfrost(buf, c, cx, Math.max(14 * S * outCubic(t / B), front(t) + 1), REACH, t, out, front(t));
      rings(buf, light, t, true);
      draw(buf, t, true);
    },
    front(buf, light, t) {
      rings(buf, light, t, false);
      if (t < B) {
        const k = t / B, beat = 1 + 0.25 * Math.exp(-((t - B * 0.55) ** 2) / 0.002) + 0.3 * Math.exp(-((t - B * 0.85) ** 2) / 0.002);
        core(buf, light, cx, coreY, (1 + 3.5 * k * k) * S * beat, t * 4, k);
      } else if (t < B + 0.22) {
        const a = (t - B) / 0.22;
        if (a < 0.4) core(buf, light, cx, coreY, 5 * S * (1 - a / 0.4), 0, 1);
        flare(buf, cx, coreY, 36 * S * Math.pow(1 - a, 1.5), 1 - a);
        light.glow(cx, coreY, 46 * S, WHITE, 0.6 * (1 - a));
      }
      const a = t - B;
      if (a >= 0 && a < 0.4) {
        const u = a / 0.4, r = 6 + REACH * 0.6 * outCubic(u);
        band(buf, cx, coreY, r, 1, Math.max(3, 8 * S * Math.pow(1 - u, 0.7)), u < 0.75 ? 1 : (1 - u) / 0.25, a < 0.08, (g) => coreY + Math.sin(g) * r < cy - 1);
        for (let i = 0; i < 7; i++) {
          const g = -Math.PI * (0.08 + (i / 6) * 0.84);
          light.glow(cx + Math.cos(g) * r, coreY + Math.sin(g) * r, 14 * S, ICE[2]!, 0.35 * (1 - u));
        }
      }
      draw(buf, t, false);
      if (t <= B) return;
      const k = (1 - smooth(HOLD, GONE, t)) * (0.85 + 0.15 * Math.sin(t * 2.4)), fr = front(t);
      for (let i = -3; i <= 3; i++) light.glow(cx + (i / 3.5) * fr, cy - 4, 26 * S, ICE[3]!, 0.16 * k);
    },
    over: (t) => t > GONE,
  };
}
function core(buf: Px, light: Px, x: number, y: number, r: number, spin: number, k: number) {
  if (r < 0.6) return;
  const X = Math.round(x), Y = Math.round(y), n = Math.round(r), L = n + 2 + r * (1.2 + 0.4 * Math.sin(spin * 3));
  for (let dy = -n - 1; dy <= n + 1; dy++)
    for (let dx = -n - 1; dx <= n + 1; dx++) {
      const m = Math.abs(dx) + Math.abs(dy);
      if (m <= n + 1) buf.set(X + dx, Y + dy, m === n + 1 ? ICE[5]! : dx <= 0 && dy <= 0 ? (m < n * 0.6 ? WHITE : ICE[1]!) : dx > 0 && dy > 0 ? ICE[3]! : ICE[2]!);
    }
  for (const [ca, sa] of CROSS) for (let d = n + 1; d <= L; d += 0.5) dot(buf, X + 0.5 + ca * d, Y + 0.5 + sa * d, d < L * 0.75 ? ICE[1]! : ICE[2]!, k + 0.3);
  light.glow(x, y, 10 + r * 6, ICE[2]!, 0.4 + 0.6 * k);
}
function flare(buf: Px, x: number, y: number, L: number, k: number) {
  if (L < 1) return;
  for (let i = 0; i < 8; i++) {
    const an = (i * Math.PI) / 4, len = i % 4 === 0 ? L : i % 2 === 0 ? L * 0.6 : L * 0.3, ca = Math.cos(an), sa = Math.sin(an);
    for (let d = 0; d <= len; d += 0.5) {
      const u = d / len;
      dot(buf, x + ca * d, y + sa * d, u < 0.35 ? WHITE : u < 0.7 ? ICE[1]! : ICE[2]!, u < 0.6 ? 1 : k * 1.5 * (1 - u) + 0.2);
      if (i % 4 === 0 && u < 0.4) dot(buf, x + ca * d, y + sa * d + (d % 2 < 1 ? 1 : -1), ICE[1]!);
    }
  }
}
function band(buf: Px, cx: number, cy: number, r: number, sy: number, th: number, k: number, hot: boolean, keep: (ang: number) => boolean, dim = 0) {
  if (r <= 0 || k <= 0) return;
  for (let j = 0, n = Math.ceil(r * TAU * 1.2); j < n; j++) {
    const ang = (j / n) * TAU, ca = Math.cos(ang), sa = Math.sin(ang);
    if (!keep(ang)) continue;
    for (let o = th; o >= 0; o -= 0.5) {
      const u = o / th;
      dot(buf, cx + ca * (r - o), cy + sa * (r - o) * sy, ICE[Math.min(7, (u < 0.15 ? (hot ? 0 : 1) : u < 0.4 ? 1 : u < 0.7 ? 2 : 3) + dim)]!, k * (u < 0.4 ? 1.2 : 1.15 - u));
    }
  }
}
function hoarfrost(buf: Px, c: Ctx, cx: number, fr: number, reach: number, t: number, out: number, edge: number) {
  for (let x = Math.floor(cx - fr); x <= Math.ceil(cx + fr); x++) {
    const d = Math.abs(x + 0.5 - cx), q = d / reach, a = clamp((out * 1.15 - q) / 0.15);
    if (a <= 0) continue;
    const y = Math.round(c.ground(x * PX) / PX), h = hash(x, 17), fresh = edge > 0 && d > edge - 3, tuft = h < 0.45 ? Math.round((1 + hash(x, 5) * 3) * (1 - q * 0.6)) : 0, D = (5 + hash(x, 11) * 5) * (1 - q * 0.5);
    dot(buf, x, y, fresh || h < 0.25 ? WHITE : ICE[1]!, a);
    for (let j = 1; j <= tuft; j++) dot(buf, x, y - j, j === tuft ? WHITE : ICE[2]!, a);
    if (tuft > 1 && hash(x, 9) < 0.5) dot(buf, x + (hash(x, 3) < 0.5 ? -1 : 1), y - tuft + 1, ICE[1]!, a);
    for (let j = 1; j <= D; j++) {
      const v = j / D;
      dot(buf, x, y + j, hash(x * 31 + j, 7) < 0.06 ? WHITE : v < 0.25 ? ICE[1]! : v < 0.55 ? ICE[2]! : ICE[3]!, a * (1.1 - v) * (fresh ? 1.3 : 1) * (0.85 + 0.15 * Math.sin(t * 5 + x)));
    }
  }
}
function crystals(c: Ctx): Scene {
  const { o, R, ps } = c;
  const X = o.x ?? o.actor?.feet()[0] ?? 760, S = o.size ?? 1, END = o.end ?? "melt", G = c.ground(X), cx = X / PX, cy = G / PX;
  const parts = [[0, 36, 12, 1.5, 0], [-7, 23, 9, -6, 0.07], [8, 26, 9.5, 7, 0.11], [-3, 15, 7, -3, 0.15], [-13, 12, 7, -7, 0.19], [14, 13, 7, 8, 0.23], [4, 10, 6, 4, 0.27]].map(([dx, h, w, lean, at], i) => ({ dx: dx! * S, h: h! * S, w: w! * S, lean: lean! * S, at: at!, phase: hash(i, 9) }));
  let gone = 0.5 + (o.hold ?? 2.4), popped = 0, broke = false;
  return {
    update(t) {
      while (popped < parts.length && t >= parts[popped]!.at) {
        const p = parts[popped++]!, first = popped === 1;
        burst(c, cx + p.dx, cy, first ? 10 : 4, first ? 1 : 0.6);
        mist(c, cx + p.dx, cy, first ? 8 : 3, 0.8);
        o.shake?.(first ? 0.2 : 0.05);
        if (first) c.lights.add(X, G - 20, 120, ICE[2]!, 0.8, 0.3);
      }
      if (t < gone) {
        if (R.chance(0.2)) {
          const p = parts[R.int(0, parts.length - 1)]!;
          ps.spawn(K.STAR, (cx + p.dx + R.range(-p.w / 3, p.w / 3)) * PX, G - R.range(4, p.h * PX * 0.9), 0, -6, R.range(0.3, 0.6), R.chance(0.5) ? ICE[1]! : WHITE, R.range(1, 2.4));
        }
        if (t > 0.3 && R.chance(0.12)) ps.spawn(K.DUST, X + R.range(-40, 40) * S, G - R.range(0, 4), R.range(-24, 24), -R.range(2, 8), R.range(1, 1.8), ICE[2]!, R.range(2.5, 4.5));
      } else if (END === "shatter" && !broke) {
        broke = true;
        o.shake?.(0.35);
        o.flash?.(0.3, "214,244,255");
        c.lights.add(X, G - 30, 160, WHITE, 0.8, 0.2);
        for (const p of parts)
          for (let i = 0; i < 6 + p.h / 3; i++) {
            const u = R.next();
            c.bits.add({ kind: R.chance(0.25) ? CHUNK : SHARD, x: (cx + p.dx + p.lean * u) * PX, y: G - p.h * u * PX, vx: R.range(-260, 260), vy: -R.range(100, 420), g: 0.9, drag: 0.5, bounce: 0.25, life: R.range(1, 1.6), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1.5, 4.5), c: R.pick([ICE[1]!, ICE[2]!, ICE[3]!, ICE[4]!]) });
          }
        mist(c, cx, cy, 10, 1);
      } else if (END === "melt" && t < gone + 0.8 && R.chance(0.45)) {
        const p = parts[R.int(0, parts.length - 1)]!;
        c.bits.add({ kind: DRIP, x: (cx + p.dx + R.range(-3, 3)) * PX, y: G - R.range(6, p.h * PX * 0.6), vy: 20, g: 0.6, life: 1 });
      }
    },
    back(buf, _, t) {
      const k = outCubic(t / 0.6) * (1 - smooth(gone + 0.4, gone + 1.2, t));
      if (k > 0) frost(buf, c, cx - 34 * S * k, cx + 34 * S * k, 1, 10);
    },
    front(buf, light, t) {
      if (broke && t > gone + 0.05) return;
      const m = END === "melt" ? smooth(gone, gone + 0.9, t) : 0, a = 1 - smooth(gone + 0.5, gone + 1, t), white = END === "shatter" && t > gone - 0.06;
      for (const p of parts) {
        const g = t < p.at ? 0 : outBack((t - p.at) / 0.16, 2.2), sw = ((t * 0.55 + p.phase) % 1.4) / 0.6;
        if (g > 0) crystal(buf, cx + p.dx, cy, p.h * g * (1 - m * 0.85), p.w * (1 - m * 0.3), p.lean * (1 - m), a, white, sw <= 1 ? sw : -1);
      }
      light.glow(cx, cy - 16 * S, 46 * S, ICE[3]!, 0.32 * (0.85 + 0.15 * Math.sin(t * 2.6)) * (1 - m) * smooth(0, 0.3, t));
      light.glow(cx, cy - 4, 20 * S, ICE[2]!, 0.25 * (1 - m) * smooth(0, 0.3, t));
    },
    over: (t) => t > gone + (END === "melt" ? 1.2 : 0.1),
    stop: (t) => void (gone = Math.min(gone, t)),
  };
}
function shatter(c: Ctx): Scene {
  const { o, R } = c;
  const X = o.x ?? 780, S = o.size ?? 1, CRACK = o.crack ?? 0.7, BURST = CRACK + 0.36, A = o.angle ?? 0, G = c.ground(X), cx = X / PX, cy = G / PX;
  const body = block(cx, cy, 24 * S, 30 * S);
  const ix = Math.round(body.w / 2 - Math.cos(A) * body.w * 0.42), iy = Math.round(body.h * 0.55 - Math.sin(A) * body.h * 0.3);
  const cracks = cracksOf(R, body, clamp(ix, 1, body.w - 2), clamp(iy, 1, body.h - 2), 7);
  let struck = false, broke = false;
  return {
    update(t) {
      if (t < 0.25 && R.chance(0.5)) mist(c, cx, cy, 1, 0.5);
      if (!struck && t >= CRACK) {
        struck = true;
        o.shake?.(0.15);
        c.lights.add((body.x0 + ix) * PX, (body.y0 + iy) * PX, 60, WHITE, 0.9, 0.12);
        for (let i = 0; i < 6; i++) {
          const a = A + Math.PI + R.range(-0.9, 0.9), sp = R.range(120, 300);
          c.bits.add({ kind: SHARD, x: (body.x0 + ix) * PX, y: (body.y0 + iy) * PX, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 80, g: 0.8, drag: 0.6, bounce: 0.3, life: R.range(0.6, 1), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1, 2.2), c: ICE[1]! });
        }
      }
      if (!broke && t >= BURST) {
        broke = true;
        o.shake?.(0.4);
        o.flash?.(0.35, "214,244,255");
        o.ripple?.(X, G - body.h, 10, 160, 0.4, 0.12, 18);
        burstBody(c, body, ix, iy, A, 1);
      }
    },
    back: (buf, _, t) => frost(buf, c, cx - body.w * 0.8, cx + body.w * 0.8, 1 - smooth(BURST + 0.6, BURST + 1.6, t), 6),
    front(buf, light, t) {
      if (broke) return;
      const rise = outBack(t / 0.25, 1.6), white = t > BURST - 0.04;
      drawBody(buf, body, 1, white, (y) => y >= body.h * (1 - rise));
      if (t >= CRACK) drawCracks(buf, body, cracks, clamp((t - CRACK) / 0.24), t - CRACK);
      light.glow(cx, cy - body.h * 0.5, body.h + 10, ICE[3]!, 0.25 + (white ? 0.6 : 0));
    },
    over: (t) => t > BURST + 0.1,
  };
}
function freeze(c: Ctx): Scene {
  const { o, R, ps } = c;
  const A = o.actor, LOCK = 0.45, CRACK = LOCK + (o.hold ?? 1.6), BURST = CRACK + 0.3;
  let body: Body | null = null, sil: Sil | null = null, cracks: [number, number][][] = [], locked = false, cracked = false, broke = false;
  const spires: { x: number; base: number; h: number; w: number; lean: number; at: number }[] = [];
  const grow = (b: Body) => {
    const row = (y: number) => {
      let l = -1, r = -1;
      for (let x = 0; x < b.w; x++) if (b.m[y * b.w + x] === 1) (l = l < 0 ? x : l), (r = x);
      return [l, r] as const;
    };
    let top = 0;
    while (top < b.h - 1 && row(top)[0] < 0) top++;
    const [tl, tr] = row(top + 1);
    spires.push({ x: b.x0 + (tl + tr) / 2, base: b.y0 + top + 4, h: 10, w: 5, lean: R.range(-2, 2), at: LOCK });
    for (let k = 0; k < 3; k++) {
      const y = top + Math.floor(b.h * (0.2 + 0.17 * k)), [l, r] = row(Math.min(b.h - 1, y));
      if (l < 0) continue;
      spires.push({ x: b.x0 + l + 1.5, base: b.y0 + y + 3, h: R.range(6, 9), w: R.range(3.5, 4.5), lean: -R.range(4, 6), at: LOCK + 0.03 * (k + 1) });
      spires.push({ x: b.x0 + r - 0.5, base: b.y0 + y + 3, h: R.range(6, 9), w: R.range(3.5, 4.5), lean: R.range(4, 6), at: LOCK + 0.03 * (k + 1.5) });
    }
    for (const [dx, lean] of [[-3, -5], [2, -2], [b.w - 2, 2], [b.w + 3, 5]]) spires.push({ x: b.x0 + dx!, base: b.y0 + b.h, h: R.range(6, 10), w: R.range(4, 6), lean: lean!, at: LOCK + R.range(0, 0.08) });
  };
  const level = (t: number) => (body ? body.h * (1 - outCubic(t / LOCK)) : 0);
  return {
    update(t) {
      if (!body) {
        const s = A?.silhouette?.();
        if (s && s.w > 0) grow((body = shell((sil = { ...s, data: s.data.slice() }), 3)));
        else { const x = (o.x ?? A?.feet()[0] ?? 640) / PX; body = block(x, c.ground(x * PX) / PX, 16, 38); }
        o.cue?.("freeze");
      }
      const b = body, mx = (b.x0 + b.w / 2) * PX;
      if (t < LOCK) {
        if (R.chance(0.7)) ps.spawn(K.STAR, (b.x0 + R.range(2, b.w - 2)) * PX, (b.y0 + level(t)) * PX, R.range(-12, 12), -R.range(0, 20), R.range(0.25, 0.5), R.chance(0.5) ? ICE[1]! : WHITE, R.range(0.8, 2));
        if (R.chance(0.3)) mist(c, b.x0 + b.w / 2, b.y0 + b.h, 1, 0.6);
      }
      if (!locked && t >= LOCK) {
        locked = true;
        o.shake?.(0.15);
        c.lights.add(mx, (b.y0 + b.h / 2) * PX, 120, ICE[2]!, 0.9, 0.25);
        glints(c, mx, (b.y0 + b.h) * PX, 6, b.w, b.h * PX);
      }
      if (locked && t < CRACK && R.chance(0.12)) ps.spawn(K.STAR, (b.x0 + R.range(1, b.w - 1)) * PX, (b.y0 + R.range(1, b.h - 1)) * PX, 0, -4, R.range(0.3, 0.6), R.chance(0.5) ? ICE[1]! : WHITE, R.range(1, 2.2));
      if (!cracked && t >= CRACK) {
        cracked = true;
        cracks = cracksOf(R, b, Math.round(b.w * R.range(0.35, 0.65)), Math.round(b.h * R.range(0.3, 0.5)), 8);
        o.shake?.(0.08);
      }
      if (!broke && t >= BURST) {
        broke = true;
        o.shake?.(0.3);
        o.flash?.(0.25, "214,244,255");
        o.cue?.("thaw");
        burstBody(c, b, Math.round(b.w / 2), Math.round(b.h * 0.45), -Math.PI / 2, 0.7);
      }
    },
    back(buf, _, t) { if (body) frost(buf, c, body.x0 - 6, body.x0 + body.w + 6, smooth(0, 0.3, t) * (1 - smooth(BURST + 0.5, BURST + 1.5, t)), 5); },
    front(buf, light, t) {
      if (!body || broke) return;
      const b = body, lv = level(t), shown = (y: number) => y >= lv;
      if (sil)
        for (let y = 0; y < sil.h; y++)
          for (let x = 0; x < sil.w; x++) {
            const col = sil.data[y * sil.w + x]!;
            if (col >>> 24 && shown(sil.y + y - b.y0)) buf.set(sil.x + x, sil.y + y, mix(col, ICE[3]!, 0.42));
          }
      drawBody(buf, b, sil ? 0.38 : 1, t >= LOCK && t < LOCK + 0.05, shown);
      for (const p of spires) {
        const g = outBack(clamp((t - p.at) / 0.12), 2.4);
        if (g > 0) crystal(buf, p.x, p.base, p.h * g, p.w, p.lean * g, 1, t < p.at + 0.04);
      }
      if (t < LOCK) for (let x = 0; x < b.w; x++) if (b.m[Math.floor(lv) * b.w + x]) dot(buf, b.x0 + x, b.y0 + Math.floor(lv), hash(x, 5) < 0.6 ? WHITE : ICE[1]!);
      if (cracked) drawCracks(buf, b, cracks, clamp((t - CRACK) / 0.24), t - CRACK);
      light.glow(b.x0 + b.w / 2, b.y0 + b.h * 0.5, b.h * 0.8, ICE[3]!, 0.3 * smooth(0, LOCK, t) * (0.85 + 0.15 * Math.sin(t * 3)));
    },
    over: (t) => t > BURST + 0.1,
  };
}
function crystal(buf: Px, x: number, base: number, h: number, w: number, lean: number, a = 1, white = false, glint = -1, dim = 0) {
  if (h < 1.5) return;
  const C = (i: number) => ICE[Math.min(7, i + dim)]!, TIP = dim ? ICE[1]! : WHITE, top = base - h, ridge0 = x - w * 0.14;
  const inside = (px: number, py: number) => {
    const u = (base - (py + 0.5)) / h;
    return u >= 0 && u <= 1 && Math.abs(px + 0.5 - (x + lean * u)) <= (w / 2) * (1 - u) + 0.35;
  };
  for (let py = Math.floor(top) - 1; py < Math.ceil(base); py++)
    for (let px = Math.floor(x - w / 2 - Math.abs(lean) - 2); px <= Math.ceil(x + w / 2 + Math.abs(lean) + 2); px++) {
      if (a < 1 && a <= bayer(px, py)) continue;
      if (!inside(px, py)) {
        if (inside(px - 1, py) || inside(px + 1, py) || inside(px, py + 1) || (inside(px, py - 1) && py < base - 1)) buf.set(px, py, C(7));
        continue;
      }
      if (white) { buf.set(px, py, WHITE); continue; }
      const u = (base - (py + 0.5)) / h, rx = lerp(ridge0, x + lean, u), c = x + lean * u, hw = (w / 2) * (1 - u) + 0.35, fx = px + 0.5;
      let col = u > 0.9 ? TIP : Math.abs(fx - rx) < 0.55 ? C(1) : fx < rx ? (fx - (c - hw) < 1 ? C(1) : (fx - (c - hw)) / Math.max(1, rx - (c - hw)) > 0.55 ? C(2) : C(3)) : c + hw - fx < 1.2 ? C(6) : (fx - rx) / Math.max(1, c + hw - rx) > 0.5 ? C(5) : C(4);
      if (glint >= 0 && fx <= rx + 0.6) { const g = Math.abs(u - glint); if (g < 0.05) col = TIP; else if (g < 0.1) col = C(1); }
      buf.set(px, py, col !== TIP && hash(px * 13 + py * 101) < 0.05 ? C(1) : col);
    }
}
function shard(buf: Px, b: Bit, a: number) {
  const x = b.x / PX, y = b.y / PX, ca = Math.cos(b.a), sa = Math.sin(b.a);
  for (let d = -b.s / 2; d <= b.s / 2; d += 0.5) dot(buf, x + ca * d, y + sa * d, d > b.s / 2 - 0.6 ? WHITE : b.c, a);
}
function chunk(buf: Px, b: Bit, a: number) {
  const x = Math.round(b.x / PX), y = Math.round(b.y / PX), ca = Math.cos(b.a), sa = Math.sin(b.a), r = Math.ceil(b.s) + 1;
  for (let py = -r; py <= r; py++)
    for (let px = -r; px <= r; px++) {
      const u = (px + 0.5) * ca + (py + 0.5) * sa, v = -(px + 0.5) * sa + (py + 0.5) * ca, d = Math.abs(u) / b.s + Math.abs(v) / (b.s * 0.62);
      if (d <= 1.3 && (a >= 1 || a > bayer(x + px, y + py))) buf.set(x + px, y + py, d > 1 ? ICE[7]! : v < 0 ? (u < 0 ? ICE[1]! : ICE[2]!) : u < 0 ? ICE[3]! : ICE[5]!);
    }
}
interface Body { x0: number; y0: number; w: number; h: number; m: Uint8Array; c: Uint32Array }
interface Sil { x: number; y: number; w: number; h: number; data: Uint32Array }
function facet(x0: number, y0: number, w: number, h: number, m: Uint8Array): Body {
  const c = new Uint32Array(w * h), seeds: [number, number][] = [], at = (x: number, y: number) => x >= 0 && y >= 0 && x < w && y < h && m[y * w + x] === 1;
  for (let i = 0; i < Math.max(4, Math.round((w * h) / 70)); i++) seeds.push([hash(i, 31 + w) * w, hash(i, 37 + h) * h]);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      if (!m[y * w + x]) continue;
      let d1 = 1e9, d2 = 1e9, k = 0;
      for (const [i, [sx, sy]] of seeds.entries()) {
        const d = Math.hypot(x + 0.5 - sx, (y + 0.5 - sy) * 0.8);
        if (d < d1) (d2 = d1), (d1 = d), (k = i);
        else if (d < d2) d2 = d;
      }
      const [sx, sy] = seeds[k]!, lit = clamp(0.5 + 0.35 * (hash(k, 41) - 0.5) * 2 + 0.3 * ((sx - w / 2) / w) + 0.3 * ((sy - h / 2) / h)), s = x + y * 0.6 - Math.min(w, h) * 0.22;
      let col = ICE[2 + Math.min(3, Math.floor(lit * 4))]!;
      if (d2 - d1 < 1.1) col = (sx + sy) / (w + h) < 0.55 ? ICE[1]! : ICE[2]!;
      if (!at(x - 1, y) || !at(x, y - 1)) col = ICE[1]!;
      if (!at(x + 1, y) || (!at(x, y + 1) && y < h - 1)) col = ICE[5]!;
      if (s > 0 && s < 1.6 && y < h * 0.6) col = WHITE;
      c[y * w + x] = hash(x * 13 + y * 101, w) < 0.03 ? ICE[1]! : col;
    }
  return { x0, y0, w, h, m, c };
}
function block(cx: number, base: number, w: number, h: number): Body {
  (w = Math.round(w)), (h = Math.round(h));
  const m = new Uint8Array(w * h), cut = Math.round(w * 0.22);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) m[y * w + x] = y >= Math.round(hash(Math.floor(x / 3), 7) * 2) + Math.max(0, cut - Math.min(x, w - 1 - x)) ? 1 : 0;
  return facet(Math.round(cx - w / 2), Math.round(base - h), w, h, m);
}
function shell(s: Sil, g: number): Body {
  const W = s.w + g * 2, H = s.h + g * 2, big = new Uint8Array(W * H), on = (x: number, y: number) => s.data[y * s.w + x]! >>> 24;
  let bottom = 0, x0 = W, y0 = H, x1 = -1, y1 = -1;
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) if (on(x, y)) bottom = Math.max(bottom, y);
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) if (on(x, y)) for (let dy = -g; dy <= g; dy++) for (let dx = -g; dx <= g; dx++) if (Math.abs(dx) + Math.abs(dy) <= g && y + dy <= bottom) big[(y + dy + g) * W + x + dx + g] = 1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (big[y * W + x]) (x0 = Math.min(x0, x)), (y0 = Math.min(y0, y)), (x1 = Math.max(x1, x)), (y1 = Math.max(y1, y));
  const w = x1 - x0 + 1, h = y1 - y0 + 1, m = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) m[y * w + x] = big[(y + y0) * W + x + x0]!;
  return facet(s.x - g + x0, s.y - g + y0, w, h, m);
}
function drawBody(buf: Px, b: Body, a: number, white: boolean, shown: (row: number) => boolean) {
  const at = (x: number, y: number) => x >= 0 && y >= 0 && x < b.w && y < b.h && b.m[y * b.w + x] === 1;
  for (let y = -1; y <= b.h; y++) {
    if (!shown(Math.max(0, y))) continue;
    for (let x = -1; x <= b.w; x++) {
      const px = b.x0 + x, py = b.y0 + y;
      if (!at(x, y)) { if (at(x - 1, y) || at(x + 1, y) || at(x, y - 1) || (at(x, y + 1) && shown(y + 1))) buf.set(px, py, ICE[7]!); continue; }
      const col = white ? WHITE : b.c[y * b.w + x]!;
      if (a >= 1 || white || col === ICE[1]! || col === WHITE || col === ICE[5]!) buf.set(px, py, col);
      else buf.blend(px, py, col, a);
    }
  }
}
function cracksOf(R: Rng, b: Body, ix: number, iy: number, n: number) {
  const out: [number, number][][] = [], inside = (x: number, y: number) => x >= 0 && y >= 0 && x < b.w && y < b.h && b.m[Math.floor(y) * b.w + Math.floor(x)] === 1;
  const walk = (x: number, y: number, a: number, len: number) => {
    const pts: [number, number][] = [[x, y]];
    for (let s = 0; s < len; s++) {
      a += R.range(-0.55, 0.55);
      x += Math.cos(a) * R.range(1.5, 2.6);
      y += Math.sin(a) * R.range(1.5, 2.6);
      if (!inside(x, y)) break;
      pts.push([x, y]);
      if (pts.length > 3 && out.length < n * 2 && R.chance(0.12)) walk(x, y, a + R.sign() * R.range(0.6, 1.2), len / 2);
    }
    out.push(pts);
  };
  for (let i = 0; i < n; i++) walk(ix, iy, (i / n) * TAU + R.range(-0.3, 0.3), 30);
  return out;
}
function drawCracks(buf: Px, b: Body, cracks: [number, number][][], k: number, age: number) {
  for (const pts of cracks)
    for (let i = 0, n = Math.floor(pts.length * k); i < n; i++) {
      const [x, y] = pts[i]!, px = Math.floor(b.x0 + x), py = Math.floor(b.y0 + y), fresh = i > n - 3 && age < 0.3;
      buf.set(px, py, fresh ? WHITE : ICE[6]!);
      if (!fresh) buf.set(px, py - 1, ICE[0]!);
    }
}
function burstBody(c: Ctx, b: Body, ix: number, iy: number, a: number, power: number) {
  const R = c.R, mx = (b.x0 + b.w / 2) * PX, my = (b.y0 + b.h / 2) * PX;
  for (let y = 0; y < b.h; y++)
    for (let x = 0; x < b.w; x++) {
      if (!b.m[y * b.w + x] || hash(x * 7 + y * 131, 3) > 0.16) continue;
      const dx = x - ix, dy = y - iy, d = Math.hypot(dx, dy) || 1, sp = R.range(120, 360) * power;
      c.bits.add({ kind: SHARD, x: (b.x0 + x) * PX, y: (b.y0 + y) * PX, vx: (dx / d) * sp + Math.cos(a) * R.range(60, 240) * power, vy: (dy / d) * sp * 0.8 + Math.sin(a) * R.range(60, 200) * power - R.range(80, 260) * power, g: 0.9, drag: 0.5, bounce: 0.25, life: R.range(1, 1.6), a: R.range(0, TAU), va: R.range(-22, 22), s: R.range(1.5, 4), c: b.c[y * b.w + x]! });
    }
  for (let i = 0; i < Math.max(4, Math.round((b.w * b.h) / 70)); i++) {
    let x = 0, y = 0;
    for (let k = 0; k < 20 && !b.m[y * b.w + x]; k++) (x = R.int(0, b.w - 1)), (y = R.int(0, b.h - 1));
    const dx = x - ix, dy = y - iy, d = Math.hypot(dx, dy) || 1, sp = R.range(100, 260) * power;
    c.bits.add({ kind: CHUNK, x: (b.x0 + x) * PX, y: (b.y0 + y) * PX, vx: (dx / d) * sp + Math.cos(a) * R.range(40, 160) * power, vy: (dy / d) * sp * 0.6 - R.range(120, 300) * power, g: 1, drag: 0.4, bounce: 0.3, life: R.range(1.2, 1.8), a: R.range(0, TAU), va: R.range(-14, 14), s: R.range(2.2, 4.5) });
  }
  mist(c, b.x0 + b.w / 2, b.y0 + b.h, 12, 1.2);
  glints(c, mx, (b.y0 + b.h) * PX, 8, b.w * 1.2, b.h * PX, ICE[1]!);
  c.lights.add(mx, my, b.h * 2.4 + 30, WHITE, 0.7, 0.14);
  c.lights.add(mx, my, b.h * 4 + 50, ICE[3]!, 0.5, 0.45);
}
const PX = 2, TAU = Math.PI * 2, CROSS = [[1, 0], [-1, 0], [0, 1], [0, -1]] as const, DIAG = [[1, 1], [1, -1], [-1, 1], [-1, -1]] as const;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { (this.w = f.w), (this.h = f.h), (this.ox = f.ox), (this.oy = f.oy), (this.data = data); }
  at(x: number, y: number) { (x = (x - this.ox) | 0), (y = (y - this.oy) | 0); return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
  blend(x: number, y: number, c: number, a: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, oa = a + ((d >>> 24) / 255) * (1 - a);
    if (oa <= 0) return;
    const k = a / oa, ch = (s: number) => (((c >>> s) & 255) * k + ((d >>> s) & 255) * (1 - k)) & 255;
    this.data[i] = ((oa * 255) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
  add(x: number, y: number, c: number, k: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, ch = (s: number) => Math.min(255, ((d >>> s) & 255) + ((c >>> s) & 255) * k) & 255;
    this.data[i] = (255 << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
  alphaDisc(cx: number, cy: number, r: number, c: number, a: number) {
    if (a <= 0.01) return;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++)
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) {
        const dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        if (dx * dx + dy * dy <= r * r) this.blend(x, y, c, a);
      }
  }
  glow(cx: number, cy: number, r: number, c: number, k: number) {
    if (r < 1 || k <= 0.01) return;
    const x0 = Math.max(this.ox, Math.floor(cx - r)), x1 = Math.min(this.ox + this.w - 1, Math.ceil(cx + r)), y0 = Math.max(this.oy, Math.floor(cy - r)), y1 = Math.min(this.oy + this.h - 1, Math.ceil(cy + r));
    for (let y = y0; y <= y1; y++)
      for (let x = x0; x <= x1; x++) {
        const dx = (x + 0.5 - cx) / r, dy = (y + 0.5 - cy) / r, d = dx * dx + dy * dy, f = 1 - Math.sqrt(d);
        if (d < 1) this.add(x, y, c, f * f * k);
      }
  }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
function bayer(x: number, y: number) { return (BAYER[((y & 3) << 2) | (x & 3)]! + 0.5) / 16; }
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function mix(c1: number, c2: number, t: number) {
  const ch = (s: number) => ((c1 >>> s) & 255) * (1 - t) + ((c2 >>> s) & 255) * t;
  return rgb(ch(0), ch(8), ch(16), ch(24));
}
function scale(c: number, k: number) { return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24); }
const WHITE = hex("#ffffff"), ICE0 = ["#ffffff", "#dcfbff", "#a6ecff", "#62c8f4", "#3a8bd8", "#2c58aa", "#212f6b", "#151a3d"].map(hex);
let ICE = ICE0;
class Rng {
  s: number;
  constructor(seed = 1) { this.s = seed >>> 0 || 1; }
  next() {
    let t = (this.s = (this.s + 0x6d2b79f5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(a: number, b: number) { return a + (b - a) * this.next(); }
  int(a: number, b: number) { return Math.floor(this.range(a, b + 1)); }
  sign() { return this.next() < 0.5 ? -1 : 1; }
  chance(p: number) { return this.next() < p; }
  pick<T>(a: readonly T[]): T { return a[Math.floor(this.next() * a.length)]!; }
}
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }
function smooth(a: number, b: number, x: number) { const t = (x - a) / (b - a); return x <= a ? 0 : x >= b ? 1 : t * t * (3 - 2 * t); }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
function outBack(t: number, s = 1.7) { const u = clamp(t) - 1; return 1 + (s + 1) * u * u * u + s * u * u; }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
const K = { DUST: 0, STAR: 1, STREAK: 2, FLAKE: 3, VAPOUR: 4 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  constructor(R: Rng) { this.R = R; }
  spawn(k: K, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100 });
  }
  update(dt: number) {
    this.t += dt;
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i]!;
      if ((p.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      if (p.k === K.STREAK) (p.vx += p.vx * 3 * dt), (p.vy += p.vy * 3 * dt);
      else if (p.k === K.FLAKE) { p.vx -= p.vx * 2.2 * dt; p.vy -= p.vy * 2.2 * dt - 70 * dt; p.x += Math.sin(this.t * 2.5 + p.seed) * 14 * dt; } else {
        const drag = p.k === K.DUST || p.k === K.VAPOUR ? 4 : 1.6;
        p.vx -= p.vx * drag * dt;
        p.vy -= p.vy * drag * dt + 10 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }
  draw(buf: Px, light: Px, layer: Layer) {
    for (const p of this.list) {
      if ((p.k === K.DUST || p.k === K.VAPOUR) !== (layer === "back")) continue;
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
      if (p.k === K.DUST) buf.alphaDisc(ax, ay, p.size * (0.6 + (1 - k) * 0.9), p.col, Math.pow(k, 1.3) * 0.7);
      else if (p.k === K.VAPOUR) {
        const r = p.size * (0.6 + (1 - k) * 0.9);
        buf.alphaDisc(ax, ay, r, p.col, Math.pow(k, 1.3) * 0.45);
        light.glow(ax, ay, r * 1.8, ICE[2]!, 0.16 * k);
      } else if (p.k === K.STREAK) {
        const sp = Math.hypot(p.vx, p.vy), L = clamp(sp / 60, 1, 7), ux = p.vx / sp, uy = p.vy / sp;
        for (let d = L; d >= 0; d -= 0.5) dot(buf, ax - ux * d, ay - uy * d, d < 1 ? WHITE : d < L * 0.5 ? p.col : ICE[3]!, d < L * 0.5 ? 1 : 1.2 - d / L);
        light.glow(ax, ay, 4, p.col, 0.4);
      } else if (p.k === K.FLAKE) {
        const a = Math.min(1, k * 3);
        dot(buf, ax, ay, p.col, a);
        if (p.size > 1.3) for (const [dx, dy] of CROSS) dot(buf, ax + dx, ay + dy, ICE[1]!, a * 0.8);
      } else {
        const tw = 0.6 + 0.4 * Math.sin(this.t * (8 + (p.seed % 5)) + p.seed);
        if (p.size < 1) { if (tw * k > 0.25) buf.set(px, py, tw > 0.8 ? WHITE : p.col); light.glow(ax, ay, 3, p.col, 0.4 * k * tw); continue; }
        const arm = Math.max(1, Math.round(p.size * tw * Math.min(1, k * 3))), tip = scale(p.col, 0.75);
        for (let d = 1; d <= arm; d++) for (const [dx, dy] of CROSS) buf.set(px + dx * d, py + dy * d, d === arm && arm > 1 ? tip : p.col);
        if (arm >= 3) for (const [dx, dy] of DIAG) buf.set(px + dx, py + dy, tip);
        buf.set(px, py, WHITE);
        light.glow(ax, ay, 3 + arm * 2, p.col, 0.5 * k * tw);
      }
    }
  }
}
class Lights {
  list: { x: number; y: number; r: number; color: number; k: number; life: number; max: number }[] = [];
  add(x: number, y: number, r: number, color: number, k: number, life: number) { this.list.push({ x, y, r, color, k, life, max: life }); }
  update(dt: number) { for (let i = this.list.length - 1; i >= 0; i--) if ((this.list[i]!.life -= dt) <= 0) this.list.splice(i, 1); }
  draw(light: Px) {
    for (const l of this.list) { const k = l.life / l.max; light.glow(l.x / PX, l.y / PX, (l.r / PX) * (0.55 + 0.45 * k), l.color, l.k * k * k); }
  }
}
interface Bit { x: number; y: number; vx: number; vy: number; life: number; max: number; a: number; va: number; s: number; c: number; kind: number; g: number; drag: number; bounce: number; rest: boolean }
class Bits {
  list: Bit[] = [];
  ground: (x: number) => number;
  constructor(ground: (x: number) => number) { this.ground = ground; }
  add(b: Partial<Bit> & { x: number; y: number }) {
    const life = b.life ?? 1;
    this.list.push({ vx: 0, vy: 0, a: 0, va: 0, s: 1, c: 0, kind: 0, g: 0, drag: 0, bounce: 0, rest: false, ...b, life, max: life });
  }
  step(dt: number) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const b = this.list[i]!;
      if ((b.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      if (b.rest) continue;
      b.vy += 1900 * b.g * dt;
      b.vx -= b.vx * b.drag * dt;
      b.vy -= b.vy * b.drag * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.a += b.va * dt;
      const floor = this.ground(b.x), sp = b.vy;
      if (b.g <= 0 || b.y < floor || sp <= 0) continue;
      b.y = floor - 0.01;
      if (b.kind === SHARD) b.vx *= 1.6;
      if (b.kind === DRIP) b.life = 0;
      if (b.bounce > 0 && sp > 140) (b.vy = -sp * b.bounce), (b.vx *= 0.7), (b.va *= 0.6);
      else (b.rest = true), (b.vx = b.vy = 0);
    }
  }
}
```
