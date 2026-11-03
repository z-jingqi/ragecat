# Poison (poison.ts)

Toxic gas drawn the way smoke is, in sickly greens: a thrown flask's cloud, a bubbling, fuming puddle, and a poisoned character with a pulse running up its pixels, drips and fumes.

Previews (animated WebP, 320 × 200 art pixels): Cloud https://www.spritefusion.com/images/pixel-art-vfx/poison-gas-cloud.webp, Puddle https://www.spritefusion.com/images/pixel-art-vfx/poison-toxic-puddle.webp, Poisoned https://www.spritefusion.com/images/pixel-art-vfx/poison-poisoned.webp

Page: https://www.spritefusion.com/pixel-art-vfx/poison. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/poison.zip

## Recipe
- **Timeline:** sizes are in art px, positions and speeds in world units. P[i] is step i of `colors` (POISON by default, below). Values are for `size` 1.
  - Cloud (`kind: "cloud"`, the default), 4.3 s:
    - 0–0.5 s: a flask is lobbed from the hand to `x` on the ground, along an arc peaking 110 units above the straight line, spinning at 16 rad/s.
    - 0.5 s, it smashes: a shake, a green light (0.2 s), 10 glass shards, 14 venom drops, and 16 gas puffs bursting low and outward.
    - 0.5–2.2 s: more puffs join, ever fewer (28% a tick at first, 0% by 2.2 s).
    - 0.5–3.2 s: bubbles, venom drips and glowing spores rise out of it.
    - 0.5–1.3 s: the ground stain spreads from the middle out. 3.4–4.2 s: it fades.
    - Every puff fades over its last 0.9 s, ending between 3.3 and 4.1 s. `done()` from 4.3 s, once the last spores and drops are gone (about 4.9 s).
  - Puddle (`kind: "puddle"`), a loop:
    - 0 s: a splash of 10 drops and a small shake.
    - 0–0.6 s: the pool spreads to full width (outCubic).
    - From 0.2 s: fumes rise off it. From 0.3 s: bubbles swell on it and pop.
    - It goes on until `stop()`. Then it dries up: it shrinks to nothing over 1.4 s, its glow and splatter fading. `done()` 1.5 s after `stop()`, once the last fumes and drops are gone.
  - Aura (`kind: "aura"`), a loop on a poisoned character:
    - 0–0.4 s: it fades in.
    - A green pulse runs up the body from feet to head every 1.28 s. Venom drips off it and stains the ground, bubbles and thin fumes rise off it, spores drift up, a light breathes round it.
    - A pool at its feet widens over 3 s.
    - It goes on until `stop()`. Then nothing new comes off it and it fades over 0.7 s. `done()` 0.8 s after `stop()`, once the last drops and fumes are gone.
- **Layers:**
  - Cloud: "back" holds the ground stain and its glow. "front" holds the flask, the gas, the shards, drops and bubbles, the spores, and the smash light.
  - Puddle: "back" holds the pool, the splatter round it, and its glows. "front" holds the bubbles, pops, gas (at half opacity), drops and spores.
  - Aura: "back" holds the pool at the feet, the stains and a glow at the feet. "front" holds the pulse over the body, the gas (at 55%), drops, bubbles, spores and the body glow.
  - Light buffer, additive glows falling off as (1 − d/r)² × strength:
    - Cloud: the flask in flight r 8 in P[2] at 0.4. The smash: r 60 shrinking to 33 in P[2], 0.8 × k² over 0.2 s, 5 px above the ground. The stain: r 90 × size in P[3], 14 px up, at 0.3 × the gas's mean opacity × (0.85 + 0.15·sin 4t).
    - Puddle: r (half-width × 2.4 + 10) in P[3] at 0.34 × (0.85 + 0.15·sin 3.4t), 6 px up; r (half-width × 1.1) in P[2] at 0.18; both fading as it dries. Each bubble r 2 × radius + 3 in P[2] at 0.2.
    - Aura: r (body height × 0.9 + 8) in P[3] at the body's centre, 0.28 × (0.8 + 0.2·sin 7t) × level. At the feet r 18 in P[3] at 0.2 × level.
    - Gas puffs wider than 9 px: r 1.5 × radius in P[3] at 0.06 × opacity. Spores: r 3 + 3 × size in their colour at 0.35 × opacity.
  - Colour buffer: the gas and the spores are alpha-blended discs (true opacity, not dithered). Everything else is opaque pixels, with a 4 × 4 Bayer ordered dither where it fades.
- **Palette:** `colors`, POISON (exported), 8 steps light to dark: #f6ffc2, #cfff63, #8eea3f, #55b92f, #318232, #23552e, #173320, #0e1d14. Steps 0 and 7 are not drawn.
  - Gas: half the puffs start P[4], half 40% toward P[3]. Each sinks toward P[6] with age (85% of the way; age runs over 2.6 s for cloud puffs, over their life for fumes). Its lit top is mixed 22% toward P[1].
  - Spores: P[2] (60%) or P[1], with a white core.
  - Drops: P[1]; 2 px drops have P[3] on top. Bubbles: a ring of P[2] with a white highlight; popping, a cross of P[1].
  - Puddle: its surface row P[2], shimmering to P[1] with white glints; the row under it P[3] in places; its body P[4]; its bottom row P[5]; its ends P[4] and P[5], with a 1 px #1a1422 pixel above the very edges. Splatter round it P[5]. Its bubbles: a P[3] rim lit P[1] on the upper left, a clear inside (P[2] at 30%), a white highlight.
  - Cloud stain: P[4] in its inner half, P[5] outside, a row of P[6] under it.
  - Aura: the pulse P[1] at its core, P[2] round it. Pool and stains: P[4] and P[5].
  - Flask: outline #1a1422, glass #d8f6ff, cork #9b6a45, venom P[2] shaded P[4] on its right and bottom. Glass shards: #d8f6ff with a #62c8f4 pixel.
- **Shapes and motion:**
  - Gas puff: three alpha discs: a skirt of radius 1.08r at 0.4 × opacity, a body of 0.76r offset down-right (0.05r, 0.08r) at 0.55, a lit top of 0.48r offset up-left (−0.22r, −0.3r) at 0.38 × (1 − 0.6 × age).
    - Its radius grows from r0 to r1 over 1.4 s (outCubic). It fades in over 0.15 s.
    - It drifts: its launch velocity decays at 2.2/s, plus a slow noise wander of ±6 units across and ±4 up and down. Fumes also rise at a steady speed.
    - Cloud puffs hug the ground: their centre stays at least 0.7 radius above it. They fade over their last 0.9 s; others over the last 60% of their life.
  - Cloud:
    - Smash puffs: 16 from ±10 units of the impact, 16 units up, at 60–220 within ±1.4 rad of straight up; then × 1.3 × size across and × 0.9 up, −30. r0 3–5 → r1 9–17 px.
    - Later puffs: within ±70 × size, 10–40 units up, ±50 × size across and 20–90 up. r0 3–5 → r1 8–16 px.
    - Bubbles: 18% a tick, within ±90 × size, 8–40 up, rising 16–40, 0.5–1 s, radius 1.4 or 2 (30%). Drips: 8% a tick, within ±80 × size, 20–40 up. Spores: 20% a tick, within ±100 × size, 20–90 up, rising 14–36, 1.2–2.2 s, size 1–2.2.
    - Stain: up to 52 × size px each side on the ground line. A column is filled when hash × 0.6 + its distance < 1.1 × level, so it spreads from the middle with a ragged edge.
    - Flask: a 7 × 8 px sprite (cork, neck, round belly), rotated about its centre, sampled pixel by pixel.
  - Puddle:
    - Half-width 44 × size px. Its surface is raised in the middle, min(2.4, 0.9 + 0.04 × half-width) px (2 at size 1), so it's a thin lens on the ground.
    - The shimmer is two noises sliding along the surface; glints are re-picked 6 times a second.
    - Splatter: dotted pixels out to 1.3 × the half-width, thinner further out.
    - Bubbles: (9% × size + 4%) a tick, within 80% of the half-width, radius 1.5–3.4 px growing from 30%, 0.45–1 s. Each is a dome on the surface.
    - A pop: 5 pixels flying out 2 → 5 px in 0.1 s, 2 + radius drops (±90 across, 90–200 up), a fume puff (r 0.9 → 2.6 × the bubble's radius, rising 18 units/s, 1.4–2 s), and half the time a spore.
    - Fumes: 7.5% × size a tick, r0 2–3 → r1 6–9 px, 20–40 up, rising 22 units/s, 1.6–2.4 s. Spores: 5% a tick.
  - Aura:
    - The body box is the bounds of the silhouette's opaque pixels; without one, 12 × 46 px over the feet. Things come off random opaque pixels of it, at a height between two fractions of the box (0 at the top).
    - Per tick: 11% a drop from 35–95% (falling, 0.7g, 1.4 s; half are 2 px tall); 9% a bubble from 10–80% (rising 20–46, 0.4–0.8 s, radius 1.1 or 1.6); 10% a fume from the top 35% (r0 1.5–2.5 → r1 4.5–7 px, 26–44 up, rising 26 units/s, 1.2–1.8 s); 6% a spore near the top.
    - 2 px drops that land leave a stain: a 2.4–5.2 px dash on the ground, fading 1.5–3 s after (40 at most).
    - Pulse: a band at height v (0 at the feet), v = ((0.9t) mod 1.15)/0.95. Every opaque body pixel is blended toward the pulse colour at (0.12 + 0.42 × e^(−((u − v)/0.13)²)) × level, u its height in the body (0 feet, 1 head).
    - Pool: dotted pixels on the ground line, half-width 6 → 14 px over 3 s, at 0.85 × max(level, 0.3).
  - Bits (world units/s; g = 1900): glass shards fall at 1g, drag 0.4, bounce × 0.35 when landing faster than 140, spin ±20 rad/s, 0.6–1.1 s, 10 thrown ±260 across and 150–420 up. Drops: 0.9g, 14 thrown ±200 across and 100–360 up at the smash; a landing drop lies 0.25 s. Bubbles don't fall; they pop as a 4-pixel cross 2 px out in their last 0.06 s. Shards and drops dither out over their last 0.3 s.
  - Spores: alpha discs of their size at 0.45 and a white core of half that at 0.5, drag 0.8, breathing (0.7 + 0.3·sin), fading in over their first 20% and out over their last third.
- **Feel:** cloud: a shake of 0.25 at the smash. Puddle: a shake of 0.08 at the start. No flash.

## Situations
- **Cloud:** `poison({ kind: "cloud", x: 420, ground: 300, actor: player })`: the player lobs a flask to x 420; it shatters into a green cloud rolling out low along the floor, bubbling, then thins out.
- **Puddle:** `poison({ kind: "puddle", x: 380, ground: 300 })`: a toxic pool spreads on the floor, bubbles swelling and popping, fumes rising, until `stop()`.
- **Poisoned:** `poison({ kind: "aura", actor: player, ground: 300 })`: a sickly pulse runs up the player's pixels while venom drips off it and fumes rise, until `stop()`.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `kind` | `"cloud" \| "puddle" \| "aura"` | `"cloud"` | Which situation. |
| `x` | number (world units) | cloud `790`, puddle `760`, aura `640` | Cloud: where the flask lands. Puddle: the pool's centre. Aura: the feet's x without an actor. |
| `ground` | `number \| ((x: number) => number)` (world y) | `600` | The ground: where the flask smashes, the pool and stains lie, and drops and shards land. |
| `from` | `[number, number]` (world units) | the actor's hand, else 330 left of `x` and 90 above the ground | Cloud: where the flask is thrown from. |
| `actor` | `Actor` | none | Cloud: who throws. Aura: who is poisoned. |
| `size` | number (multiplier) | `1` | Cloud: the spread of its puffs, bubbles, drips, spores and stain. Puddle: its width, and its bubble and fume rates. |
| `colors` | `readonly number[]` (8 ABGR, light to dark) | POISON | The poison's ramp. Ignored unless it has at least 8 colours. |
| `seed` | number | `1` | Random seed. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |

## Actor, methods and hooks
- `actor`:
  - `feet(): [number, number]` (world units), required by the type. Aura: read every tick for the box without a silhouette.
  - `hand?(): { x, y, a }` (world units). Cloud: read once at creation; the flask starts 10 units above (x, y). `a` is not used.
  - `silhouette?(): { x, y, w, h, data }`: the character's pixels now (art px; x, y the top-left; `data` ABGR, row by row). Aura: read every tick. Its pixels with alpha > 0 get the pulse, and drops, bubbles and fumes come off them.
- `stop()`: the puddle dries up, the aura fades. Puddle and aura are loops: they never finish without it. No effect on a cloud.
- `shake(trauma: number)`: cloud, 0.25 at the smash (0.5 s). Puddle, 0.08 at the start.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: poison.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export type Kind = "cloud" | "puddle" | "aura";
export interface Actor {
  feet(): [number, number];
  hand?(): { x: number; y: number; a: number };
  silhouette?(): { x: number; y: number; w: number; h: number; data: Uint32Array };
}
export interface Options {
  kind?: Kind;
  x?: number;
  ground?: number | ((x: number) => number);
  from?: [number, number];
  actor?: Actor;
  size?: number;
  colors?: readonly number[];
  seed?: number;
  shake?(trauma: number): void;
}
export default function poison(o: Options = {}) {
  const R = new Rng(o.seed ?? 1);
  const groundAt = (x: number) => (o.ground === undefined ? 600 : typeof o.ground === "number" ? o.ground : o.ground(x));
  const P = o.colors && o.colors.length >= 8 ? o.colors : POISON;
  const c: Ctx = { o, R, P, ground: groundAt, ps: new Particles(R), bits: new Bits(groundAt), gas: new Gas(), lights: new Lights() };
  const kind = o.kind ?? "cloud";
  const scene = kind === "puddle" ? puddle(c) : kind === "aura" ? aura(c) : cloud(c);
  let t = 0;
  return {
    update(dt: number) {
      t += dt;
      scene.update(t);
      c.bits.step(dt, (b) => { if (b.kind !== DROP) return; b.life = Math.min(b.life, 0.25); if (b.s > 1 && scene.stain) scene.stain(b.x, b.y, t); });
      c.gas.prune(t);
      c.lights.update(dt);
      c.ps.update(dt);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") scene.back(buf, light, t);
      if (layer !== "back") { scene.front(buf, light, t); drawBits(buf, c); c.ps.draw(buf, light); c.lights.draw(light); }
    },
    stop() { scene.stop?.(t); },
    done: () => scene.over(t) && c.ps.list.length === 0 && c.bits.list.length === 0 && c.gas.list.length === 0,
  };
}
interface Ctx { o: Options; R: Rng; P: readonly number[]; ground: (x: number) => number; ps: Particles; bits: Bits; gas: Gas; lights: Lights }
interface Scene {
  update(t: number): void;
  back(buf: Px, light: Px, t: number): void;
  front(buf: Px, light: Px, t: number): void;
  over(t: number): boolean;
  stop?(t: number): void;
  stain?(x: number, y: number, t: number): void;
}
const GLASS = 0, DROP = 1, BUBBLE = 2;
function drawBits(buf: Px, c: Ctx) {
  const P = c.P;
  for (const b of c.bits.list) {
    const x = b.x / PX, y = b.y / PX, fa = Math.min(1, b.life / 0.3);
    if (b.kind === GLASS) { dot(buf, x, y, b.c, fa); dot(buf, x + Math.cos(b.a), y + Math.sin(b.a), hex("#62c8f4"), fa); } else if (b.kind === DROP) {
      dot(buf, x, y, P[1]!, fa);
      if (b.s > 1) dot(buf, x, y - 1, P[3]!, fa);
    } else if (b.life < 0.06) { for (const [dx, dy] of [[2, 0], [-2, 0], [0, 2], [0, -2]]) dot(buf, x + dx!, y + dy!, P[1]!); } else {
      buf.ring(x, y, b.s, 1, P[2]!);
      dot(buf, x - 0.6, y - 0.8, PAL.white);
    }
  }
}
function cloud(c: Ctx): Scene {
  const { o, R, P, ps, bits, gas } = c;
  const X = o.x ?? 790, SPREAD = o.size ?? 1, LAND = 0.5;
  const G = c.ground(X), vial = flask(P);
  const hand = o.from ? { x: o.from[0], y: o.from[1] + 10 } : o.actor?.hand ? o.actor.hand() : { x: X - 330, y: G - 80 };
  const ox = hand.x, oy = hand.y - 10;
  let smashed = false;
  return {
    update(t) {
      if (t >= LAND && !smashed) {
        smashed = true;
        o.shake?.(0.25);
        c.lights.add(X, G - 10, 120, P[2]!, 0.8, 0.2);
        for (let i = 0; i < 10; i++) bits.add({ kind: GLASS, x: X, y: G - 4, vx: R.range(-260, 260), vy: -R.range(150, 420), g: 1, drag: 0.4, bounce: 0.35, life: R.range(0.6, 1.1), a: R.range(0, TAU), va: R.range(-20, 20), s: R.range(1.5, 2.5), c: hex("#d8f6ff") });
        for (let i = 0; i < 14; i++) bits.add({ kind: DROP, x: X, y: G - 4, vx: R.range(-200, 200), vy: -R.range(100, 360), g: 0.9, life: 1.2, s: R.int(1, 2) });
        for (let i = 0; i < 16; i++) {
          const a = -Math.PI / 2 + R.range(-1.4, 1.4), sp = R.range(60, 220);
          gas.add(t, X + R.range(-10, 10), G - 16, Math.cos(a) * sp * 1.3 * SPREAD, Math.sin(a) * sp * 0.9 - 30, R.range(3, 5), R.range(9, 17), R.range(3.4, 4.1), 0, true);
        }
      }
      if (smashed && t < 2.2 && R.chance(0.28 * (1 - (t - LAND) / 1.7))) gas.add(t, X + R.range(-70, 70) * SPREAD, G - R.range(10, 40), R.range(-50, 50) * SPREAD, R.range(-90, -20), R.range(3, 5), R.range(8, 16), R.range(3.3, 4.1), 0, true);
      if (smashed && t < 3.2) {
        if (R.chance(0.18)) bits.add({ kind: BUBBLE, x: X + R.range(-90, 90) * SPREAD, y: G - R.range(8, 40), vy: -R.range(16, 40), life: R.range(0.5, 1), s: R.chance(0.3) ? 2 : 1.4 });
        if (R.chance(0.08)) bits.add({ kind: DROP, x: X + R.range(-80, 80) * SPREAD, y: G - R.range(20, 40), vy: 20, g: 0.5, life: 1.2, s: 1 });
        if (R.chance(0.2)) ps.spawn(X + R.range(-100, 100) * SPREAD, G - R.range(20, 90), R.range(-12, 12), -R.range(14, 36), R.range(1.2, 2.2), R.chance(0.6) ? P[2]! : P[1]!, R.range(1, 2.2));
      }
    },
    back(buf, light, t) {
      if (!smashed) return;
      const cx = X / PX, cy = G / PX, k = smooth(LAND, LAND + 0.8, t) * (1 - smooth(3.4, 4.2, t)), w = 52 * SPREAD;
      for (let x = Math.floor(cx - w); x <= cx + w; x++) {
        const d = Math.abs(x - cx) / w, h = hash(x, 41);
        if (h * 0.6 + d < k * 1.1) { dot(buf, x, cy, d < 0.5 ? P[4]! : P[5]!); if (h < 0.5) dot(buf, x, cy + 1, P[6]!, k); }
      }
      light.glow(cx, cy - 14, 90 * SPREAD, P[3]!, 0.3 * gas.density(t, c.ground) * (0.85 + 0.15 * Math.sin(t * 4)));
    },
    front(buf, light, t) {
      if (t < LAND) {
        const k = clamp(t / LAND), x = lerp(ox, X, k), y = lerp(oy, G - 6, k) - Math.sin(Math.PI * k) * 110;
        blitRot(buf, vial, x / PX, y / PX, t * 16);
        light.glow(x / PX, y / PX, 8, P[2]!, 0.4);
        return;
      }
      gas.draw(buf, light, t, c.ground, P, 1);
    },
    over: (t) => t > 4.3,
  };
}
function puddle(c: Ctx): Scene {
  const { o, R, P, ps, bits, gas } = c;
  const X = o.x ?? 760, S = o.size ?? 1, G = c.ground(X), cx = X / PX, cy = G / PX, W = 44 * S;
  const bubbles: { x: number; t0: number; life: number; r: number }[] = [];
  const pops: { x: number; y: number; t: number }[] = [];
  let stopAt = Infinity;
  const width = (t: number) => W * outCubic(t / 0.6) * (1 - smooth(stopAt, stopAt + 1.4, t));
  const live = (t: number) => t < stopAt;
  return {
    update(t) {
      if (t < 0.05 && bits.list.length === 0) {
        for (let i = 0; i < 10; i++) bits.add({ kind: DROP, x: X + R.range(-10, 10), y: G - 4, vx: R.range(-180, 180), vy: -R.range(80, 260), g: 0.9, life: 1.2, s: R.int(1, 2) });
        o.shake?.(0.08);
      }
      const w = width(t);
      if (live(t) && t > 0.3 && R.chance(0.09 * S + 0.04)) bubbles.push({ x: cx + R.range(-0.8, 0.8) * w, t0: t, life: R.range(0.45, 1), r: R.range(1.5, 3.4) });
      for (let i = bubbles.length - 1; i >= 0; i--) {
        const b = bubbles[i]!;
        if (t - b.t0 < b.life) continue;
        bubbles.splice(i, 1);
        if (Math.abs(b.x - cx) > width(t)) continue;
        pops.push({ x: b.x, y: surface(b.x, cx, cy, width(t)), t });
        for (let j = 0; j < 2 + Math.round(b.r); j++) bits.add({ kind: DROP, x: b.x * PX, y: (cy - 2) * PX, vx: R.range(-90, 90), vy: -R.range(90, 200), g: 0.8, life: 0.9, s: 1 });
        gas.add(t, b.x * PX, (cy - 3) * PX, R.range(-15, 15), -R.range(30, 50), b.r * 0.9, b.r * 2.6, t + R.range(1.4, 2), 18);
        if (R.chance(0.5)) ps.spawn(b.x * PX, (cy - 4) * PX, R.range(-10, 10), -R.range(20, 40), R.range(1.2, 2), R.chance(0.6) ? P[2]! : P[1]!, R.range(1, 2));
      }
      for (let i = pops.length - 1; i >= 0; i--) if (t - pops[i]!.t > 0.1) pops.splice(i, 1);
      if (live(t) && t > 0.2 && R.chance(0.075 * S)) gas.add(t, X + R.range(-0.8, 0.8) * w * PX, G - 4, R.range(-12, 12), -R.range(20, 40), R.range(2, 3), R.range(6, 9), t + R.range(1.6, 2.4), 22);
      if (live(t) && R.chance(0.05)) ps.spawn(X + R.range(-0.8, 0.8) * w * PX, G - R.range(10, 40), R.range(-8, 8), -R.range(14, 30), R.range(1.4, 2.2), R.chance(0.6) ? P[2]! : P[1]!, R.range(1, 2));
    },
    back(buf, light, t) {
      const w = width(t);
      if (w < 1) return;
      const dry = smooth(stopAt, stopAt + 1.4, t);
      for (let x = Math.floor(cx - w * 1.3); x <= cx + w * 1.3; x++) {
        const d = Math.abs(x - cx) / w;
        if (d > 1 && hash(x, 41) < 1.3 - d) dot(buf, x, cy, P[5]!, 1 - dry * 0.6);
      }
      for (let x = Math.floor(cx - w); x <= Math.ceil(cx + w); x++) {
        const d = Math.abs(x + 0.5 - cx) / w;
        if (d > 1) continue;
        const top = surface(x, cx, cy, w);
        for (let y = top; y <= cy; y++) {
          let col = y === top ? P[2]! : y === cy ? P[5]! : P[4]!;
          if (d > 0.9) col = y === top ? P[4]! : P[5]!;
          if (y === top && d < 0.9) {
            const n = noise(x * 0.18 - t * 1.6, 3) + noise(x * 0.07 + t * 0.9, 4) * 0.6;
            if (n > 0.55) col = P[1]!;
            if (n > 0.95 && hash(x, Math.floor(t * 6)) < 0.3) col = PAL.white;
          } else if (y === top + 1 && d < 0.85 && noise(x * 0.12 + t * 0.7, 5) > 0.3) col = P[3]!;
          buf.set(x, y, col);
        }
        if (d > 0.97) buf.set(x, top - 1, OUTLINE);
      }
      light.glow(cx, cy - 6, w * 2.4 + 10, P[3]!, 0.34 * (1 - dry) * (0.85 + 0.15 * Math.sin(t * 3.4)) * smooth(0, 0.4, t));
      light.glow(cx, cy - 2, w * 1.1, P[2]!, 0.18 * (1 - dry));
    },
    front(buf, light, t) {
      for (const b of bubbles) {
        const k = (t - b.t0) / b.life, r = b.r * (0.3 + 0.7 * outCubic(k * 1.3)), sy = surface(b.x, cx, cy, width(t));
        for (let y = Math.floor(sy - r); y <= sy; y++)
          for (let x = Math.floor(b.x - r - 1); x <= Math.ceil(b.x + r + 1); x++) {
            const dx = x + 0.5 - b.x, dy = y + 0.5 - sy, d = Math.hypot(dx, dy);
            if (d > r + 0.5) continue;
            if (d > r - 0.7) buf.set(x, y, dx < 0 && dy < -r * 0.3 ? P[1]! : P[3]!);
            else buf.blend(x, y, P[2]!, 0.3);
          }
        dot(buf, b.x - r * 0.4, sy - r * 0.6, PAL.white);
        light.glow(b.x, sy - r * 0.5, r * 2 + 3, P[2]!, 0.2);
      }
      for (const p of pops) {
        const k = (t - p.t) / 0.1;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0.6, -0.7], [-0.6, -0.7], [0, -1]]) dot(buf, p.x + dx! * (2 + 3 * k), p.y + dy! * (2 + 3 * k), P[1]!, 1 - k);
      }
      gas.draw(buf, light, t, c.ground, P, 0.5);
    },
    over: (t) => t > stopAt + 1.5,
    stop(t) { stopAt = Math.min(stopAt, t); },
  };
}
function surface(x: number, cx: number, cy: number, w: number) {
  const d = Math.min(1, Math.abs(x + 0.5 - cx) / Math.max(1, w));
  return cy - Math.round(Math.sqrt(1 - d * d) * Math.min(2.4, 0.9 + w * 0.04));
}
function aura(c: Ctx): Scene {
  const { o, R, P, ps, bits, gas } = c;
  const A = o.actor;
  const stains: { x: number; y: number; t: number; r: number }[] = [];
  let stopAt = Infinity, sil: Sil | null = null;
  const where = () => {
    const [fx, fy] = A ? A.feet() : [o.x ?? 640, c.ground(o.x ?? 640)];
    const s = A?.silhouette?.();
    if (s && s.w > 0) {
      let x0 = s.w, y0 = s.h, x1 = -1, y1 = -1;
      for (let y = 0; y < s.h; y++)
        for (let x = 0; x < s.w; x++)
          if (s.data[y * s.w + x]! >>> 24) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
      sil = { x: s.x, y: s.y, w: s.w, h: s.h, data: s.data, bx0: s.x + x0, by0: s.y + y0, bx1: s.x + x1, by1: s.y + y1 };
    } else sil = null;
    return sil ? { x0: sil.bx0, y0: sil.by0, x1: sil.bx1, y1: sil.by1 } : { x0: fx / PX - 6, y0: fy / PX - 46, x1: fx / PX + 6, y1: fy / PX };
  };
  const on = (box: { x0: number; y0: number; x1: number; y1: number }, u0: number, u1: number): [number, number] => {
    for (let k = 0; k < 24; k++) {
      const x = R.range(box.x0, box.x1 + 1), y = lerp(box.y0, box.y1, R.range(u0, u1));
      const s = sil as Sil | null;
      if (!s || s.data[Math.floor(y - s.y) * s.w + Math.floor(x - s.x)]! >>> 24) return [x, y];
    }
    return [(box.x0 + box.x1) / 2, lerp(box.y0, box.y1, (u0 + u1) / 2)];
  };
  let box = { x0: 0, y0: 0, x1: 0, y1: 0 };
  const level = (t: number) => smooth(0, 0.4, t) * (1 - smooth(stopAt, stopAt + 0.7, t));
  return {
    update(t) {
      box = where();
      if (t >= stopAt) return;
      if (R.chance(0.11)) {
        const [x, y] = on(box, 0.35, 0.95);
        bits.add({ kind: DROP, x: x * PX, y: y * PX, vy: R.range(0, 30), vx: R.range(-10, 10), g: 0.7, life: 1.4, s: R.chance(0.5) ? 2 : 1 });
      }
      if (R.chance(0.09)) {
        const [x, y] = on(box, 0.1, 0.8);
        bits.add({ kind: BUBBLE, x: x * PX, y: y * PX, vx: R.range(-14, 14), vy: -R.range(20, 46), life: R.range(0.4, 0.8), s: R.chance(0.3) ? 1.6 : 1.1 });
      }
      if (R.chance(0.1)) {
        const [x, y] = on(box, 0, 0.35);
        gas.add(t, x * PX, y * PX, R.range(-10, 10), -R.range(26, 44), R.range(1.5, 2.5), R.range(4.5, 7), t + R.range(1.2, 1.8), 26);
      }
      if (R.chance(0.06)) ps.spawn((box.x0 + box.x1) * 0.5 * PX + R.range(-20, 20), box.y0 * PX + R.range(0, 40), R.range(-10, 10), -R.range(16, 34), R.range(1.2, 2), R.chance(0.6) ? P[2]! : P[1]!, R.range(0.8, 1.8));
    },
    back(buf, light, t) {
      const k = level(t), fy = c.ground((box.x0 + box.x1) * PX * 0.5) / PX, fx = (box.x0 + box.x1) / 2;
      const w = 6 + 8 * smooth(0, 3, t);
      for (let x = Math.floor(fx - w); x <= fx + w; x++) if (hash(x, 43) < 1.15 - Math.abs(x - fx) / w) dot(buf, x, fy, hash(x, 44) < 0.5 ? P[4]! : P[5]!, 0.85 * Math.max(k, 0.3));
      for (const s of stains) {
        const a = 1 - smooth(s.t + 1.5, s.t + 3, t);
        for (let x = Math.floor(s.x - s.r); x <= s.x + s.r; x++) dot(buf, x, s.y, Math.abs(x - s.x) < s.r * 0.5 ? P[4]! : P[5]!, a);
      }
      light.glow(fx, fy - 2, 18, P[3]!, 0.2 * k);
    },
    front(buf, light, t) {
      const k = level(t);
      if (k <= 0.01) return;
      const s = sil as Sil | null;
      if (s) {
        const v = ((t * 0.9) % 1.15) / 0.95, H = Math.max(1, s.by1 - s.by0);
        for (let y = s.by0; y <= s.by1; y++) {
          const u = (s.by1 - y) / H, band = Math.exp(-(((u - v) / 0.13) ** 2));
          for (let x = s.bx0; x <= s.bx1; x++) {
            const col = s.data[(y - s.y) * s.w + (x - s.x)]!;
            if (!(col >>> 24)) continue;
            buf.blend(x, y, band > 0.5 ? P[1]! : P[2]!, k * (0.12 + 0.42 * band));
          }
        }
      }
      gas.draw(buf, light, t, c.ground, P, 0.55);
      const cxb = (box.x0 + box.x1) / 2, cyb = (box.y0 + box.y1) / 2;
      light.glow(cxb, cyb, (box.y1 - box.y0) * 0.9 + 8, P[3]!, 0.28 * k * (0.8 + 0.2 * Math.sin(t * 7)));
    },
    over: (t) => t > stopAt + 0.8,
    stop(t) { stopAt = Math.min(stopAt, t); },
    stain(x, y, t) { stains.push({ x: x / PX, y: Math.round(y / PX), t, r: R.range(1.2, 2.6) }); if (stains.length > 40) stains.shift(); },
  };
}
interface Sil { x: number; y: number; w: number; h: number; data: Uint32Array; bx0: number; by0: number; bx1: number; by1: number }
function flask(P: readonly number[]) {
  return sprite(["..ccc..", ".occo..", "..ogo..", ".ogvgo.", "ogvvvdo", "ogvvvdo", ".odddo.", "..ooo.."], { o: OUTLINE, g: hex("#d8f6ff"), c: hex("#9b6a45"), v: P[2]!, d: P[4]! });
}
interface Puff { x: number; y: number; vx: number; vy: number; r0: number; r1: number; t0: number; end: number; seed: number; rise: number; hug: boolean }
class Gas {
  list: Puff[] = [];
  n = 0;
  add(t: number, x: number, y: number, vx: number, vy: number, r0: number, r1: number, end: number, rise = 0, hug = false) {
    this.list.push({ x, y, vx, vy, r0, r1, t0: t, end, seed: (this.n++ * 37.7) % 100, rise, hug });
  }
  prune(t: number) { for (let i = this.list.length - 1; i >= 0; i--) if (t > this.list[i]!.end) this.list.splice(i, 1); }
  at(p: Puff, t: number, ground: (x: number) => number) {
    const age = t - p.t0, e = 1 - Math.exp(-age * 2.2);
    const x = p.x + (p.vx / 2.2) * e + noise(t * 0.7 + p.seed, 1) * 6 * Math.min(1, age);
    let y = p.y + (p.vy / 2.2) * e - p.rise * age + noise(t * 0.6 + p.seed, 2) * 4 * Math.min(1, age);
    const r = p.r0 + (p.r1 - p.r0) * outCubic(age / 1.4);
    if (p.hug) y = Math.min(y, ground(x) - r * PX * 0.7);
    const a = smooth(0, 0.15, age) * (1 - smooth(p.end - (p.hug ? 0.9 : (p.end - p.t0) * 0.6), p.end, t));
    return { x: x / PX, y: y / PX, r, a, age: clamp(age / (p.hug ? 2.6 : p.end - p.t0)) };
  }
  density(t: number, ground: (x: number) => number) {
    let s = 0;
    for (const p of this.list) s += this.at(p, t, ground).a;
    return s / Math.max(1, this.list.length);
  }
  draw(buf: Px, light: Px, t: number, ground: (x: number) => number, P: readonly number[], opacity: number) {
    for (const [i, p] of this.list.entries()) {
      const { x, y, r, a: a0, age } = this.at(p, t, ground), a = a0 * opacity;
      if (a < 0.02) continue;
      const c = mix(hash(i, 70) < 0.5 ? P[4]! : mix(P[4]!, P[3]!, 0.4), P[6]!, age * 0.85);
      buf.alphaDisc(x, y, r * 1.08, c, a * 0.4);
      buf.alphaDisc(x + r * 0.05, y + r * 0.08, r * 0.76, c, a * 0.55);
      buf.alphaDisc(x - r * 0.22, y - r * 0.3, r * 0.48, mix(c, P[1]!, 0.22), a * 0.38 * (1 - age * 0.6));
      if (r > 9) light.glow(x, y, r * 1.5, P[3]!, 0.06 * a);
    }
  }
}
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
  blend(x: number, y: number, c: number, a: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, oa = a + ((d >>> 24) / 255) * (1 - a);
    if (oa <= 0) return;
    const k = a / oa, j = 1 - k, r = (c & 255) * k + (d & 255) * j, g = ((c >>> 8) & 255) * k + ((d >>> 8) & 255) * j, b = ((c >>> 16) & 255) * k + ((d >>> 16) & 255) * j;
    this.data[i] = ((oa * 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255);
  }
  add(x: number, y: number, c: number, k: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, r = Math.min(255, (d & 255) + (c & 255) * k), g = Math.min(255, ((d >>> 8) & 255) + ((c >>> 8) & 255) * k), b = Math.min(255, ((d >>> 16) & 255) + ((c >>> 16) & 255) * k);
    this.data[i] = (255 << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255);
  }
  alphaDisc(cx: number, cy: number, r: number, c: number, a: number) {
    if (a <= 0.01) return;
    const r2 = r * r;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const dx = x + 0.5 - cx; if (dx * dx + dy * dy <= r2) this.blend(x, y, c, a); }
    }
  }
  ring(cx: number, cy: number, r: number, thick: number, c: number, alpha = 1) {
    const ro = r + thick * 0.5, ri = Math.max(0, r - thick * 0.5), ro2 = ro * ro, ri2 = ri * ri;
    for (let y = Math.floor(cy - ro); y <= Math.ceil(cy + ro); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - ro); x <= Math.ceil(cx + ro); x++) {
        const dx = x + 0.5 - cx, d2 = dx * dx + dy * dy;
        if (d2 <= ro2 && d2 >= ri2 && (alpha >= 1 || alpha > bayer(x, y))) this.set(x, y, c);
      }
    }
  }
  glow(cx: number, cy: number, r: number, c: number, k: number) {
    if (r < 1 || k <= 0.01) return;
    const x0 = Math.max(this.ox, Math.floor(cx - r)), x1 = Math.min(this.ox + this.w - 1, Math.ceil(cx + r));
    const y0 = Math.max(this.oy, Math.floor(cy - r)), y1 = Math.min(this.oy + this.h - 1, Math.ceil(cy + r));
    for (let y = y0; y <= y1; y++) {
      const dy = (y + 0.5 - cy) / r;
      for (let x = x0; x <= x1; x++) {
        const dx = (x + 0.5 - cx) / r, d = dx * dx + dy * dy;
        if (d >= 1) continue;
        const f = 1 - Math.sqrt(d);
        this.add(x, y, c, f * f * k);
      }
    }
  }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
function bayer(x: number, y: number) { return (BAYER[((y & 3) << 2) | (x & 3)]! + 0.5) / 16; }
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
interface Sprite { w: number; h: number; data: Uint32Array }
function sprite(rows: string[], pal: Record<string, number>): Sprite {
  const h = rows.length, w = Math.max(...rows.map((r) => r.length)), data = new Uint32Array(w * h);
  rows.forEach((r, y) => [...r].forEach((ch, x) => ch !== "." && ch !== " " && (data[y * w + x] = pal[ch] ?? 0)));
  return { w, h, data };
}
function blitRot(buf: Px, s: Sprite, cx: number, cy: number, ang: number) {
  const c = Math.cos(ang), sn = Math.sin(ang), r = Math.ceil(Math.hypot(s.w, s.h) / 2) + 1, px0 = Math.round(cx), py0 = Math.round(cy);
  for (let y = -r; y <= r; y++)
    for (let x = -r; x <= r; x++) {
      const iu = Math.floor(c * x + sn * y + s.w / 2), iv = Math.floor(-sn * x + c * y + s.h / 2);
      if (iu < 0 || iv < 0 || iu >= s.w || iv >= s.h) continue;
      const col = s.data[iv * s.w + iu]!;
      if (col >>> 24) buf.set(px0 + x, py0 + y, col);
    }
}
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
}
const PAL = { white: hex("#ffffff") };
const OUTLINE = hex("#1a1422");
export const POISON = ["#f6ffc2", "#cfff63", "#8eea3f", "#55b92f", "#318232", "#23552e", "#173320", "#0e1d14"].map(hex);
class Rng {
  private s: number;
  constructor(seed = 1) { this.s = seed >>> 0 || 1; }
  next() {
    let t = (this.s = (this.s + 0x6d2b79f5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(a: number, b: number) { return a + (b - a) * this.next(); }
  int(a: number, b: number) { return Math.floor(this.range(a, b + 1)); }
  chance(p: number) { return this.next() < p; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }
function smooth(a: number, b: number, x: number) { if (x <= a) return 0; if (x >= b) return 1; const t = (x - a) / (b - a); return t * t * (3 - 2 * t); }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return lerp(hash(i, seed) * 2 - 1, hash(i + 1, seed) * 2 - 1, u);
}
interface P { x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  constructor(R: Rng) { this.R = R; }
  spawn(x: number, y: number, vx: number, vy: number, life: number, col: number, size: number) {
    this.list.push({ x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100 });
  }
  update(dt: number) {
    this.t += dt;
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i]!;
      if ((p.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      p.vx -= p.vx * 0.8 * dt;
      p.vy -= p.vy * 0.8 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }
  draw(buf: Px, light: Px) {
    for (const p of this.list) {
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX;
      const br = 0.7 + 0.3 * Math.sin(this.t * (2 + (p.seed % 3)) + p.seed), a = Math.min(1, (1 - k) * 5) * Math.min(1, k * 3) * br;
      if (a < 0.05) continue;
      buf.alphaDisc(ax, ay, p.size, p.col, 0.45 * a);
      buf.alphaDisc(ax, ay, p.size * 0.5, PAL.white, 0.5 * a);
      light.glow(ax, ay, 3 + p.size * 3, p.col, 0.35 * a);
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
interface Bit {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  a: number;
  va: number;
  s: number;
  c: number;
  kind: number;
  g: number;
  drag: number;
  bounce: number;
  rest: boolean;
}
class Bits {
  list: Bit[] = [];
  ground: (x: number) => number;
  constructor(ground: (x: number) => number) { this.ground = ground; }
  add(b: Partial<Bit> & { x: number; y: number }) {
    const life = b.life ?? 1;
    this.list.push({ vx: 0, vy: 0, a: 0, va: 0, s: 1, c: 0, kind: 0, g: 0, drag: 0, bounce: 0, rest: false, ...b, life, max: life });
  }
  step(dt: number, onLand?: (b: Bit, speed: number) => void) {
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
      const floor = this.ground(b.x);
      if (b.g > 0 && b.y >= floor && b.vy > 0) {
        const sp = b.vy;
        b.y = floor - 0.01;
        onLand?.(b, sp);
        if (b.bounce > 0 && sp > 140) { b.vy = -sp * b.bounce; b.vx *= 0.7; b.va *= 0.6; } else { b.rest = true; b.vx = b.vy = 0; }
      }
    }
  }
}
```
