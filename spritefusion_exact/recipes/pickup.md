# Pickup (pickup.ts)

Items hovering and glinting, their shadows breathing, then pulled into the character along an arc or popped in place, their sparkles curving into it. A gem, a coin, an orb or your own sprite: keep the ones your game needs.

Previews (animated WebP, 320 × 200 art pixels): Collect https://www.spritefusion.com/images/pixel-art-vfx/pickup-gem-coin-orb.webp

Page: https://www.spritefusion.com/pixel-art-vfx/pickup. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/pickup.zip

## Recipe
- **Timeline:** sizes are in art px and positions and speeds in world units. Times count from creation; tc is the moment of collection.
  - Hover, from 0 until tc. tc comes at `wait` (0.9 s) or at `collect()`. The item bobs ±3 units (sin 3.4t, a 1.85 s period). Two motes orbit it, one turn every 2.42 s. A glint flashes on its upper left for 0.29 s every 1.3 s, the first at 0.9 s. A coin spins, a half turn every 0.6 s. Its shadow breathes on the ground.
  - Magnet, the default with an actor:
    - Lift, tc to tc + 0.1 s: the item rises 8 units (outCubic) and stretches to 0.85 × 1.2.
    - Flight, the next 0.34 s: it follows a quadratic arc to the actor's chest, accelerating as progress^2.2, shrinking to 75%, and leaving a trail.
    - It pops on arrival, at tc + 0.44 s (1.34 s by default). It pops at the chest, so its sparks burst out of the character and curve back in.
  - No magnet (`magnet: false` or no actor): it pops where it hovers, at tc.
  - Pop, timed from the pop (p):
    - 0–0.05 s: the sprite is squashed to 1.5 × 0.6 in its own colours.
    - 0.05–0.1 s: the sprite is stretched to 0.7 × 1.45, all in step 0 (white).
    - A white disc shrinks from radius 8 to 1 px over 0.08 s, and a light flash fades over 0.3 s.
    - A ring opens over 0.4 s, and 14 sparks burst out.
  - Sparks:
    - For their first 0.12 s they fly out, slowed by drag 3/s and pulled down by gravity 60 units/s².
    - After that (with an actor) they home on the chest. Their target speed is 380 + 900·age units/s, and each update their velocity moves toward it by min(1, dt·(3 + 22·age)).
    - Within 9 units of the chest a spark is absorbed. Each absorption releases 2 rising motes, and the 1st, 4th, 7th… also open a small ring there.
    - Without an actor they just burst, sag and fade. They live 0.75–1.05 s.
  - `done()` is true 0.5 s after the pop, once all sparks and motes are gone.
- **Layers:**
  - "back": the shadow (only while hovering) and the orbit motes on the far, upper half of their orbit.
  - "front": everything else: the trail, the item, its glint, the near orbit motes, the pop frames and disc, the rings, the sparks and their trails, and the motes.
  - Light buffer, additive, each glow falling off as (1 − d/r)² × strength:
    - While the item lives: a glow of r 14 + 2 sin 4t px in step 3 at 0.45, rising to 0.85 by the end of the flight, plus r 5 in step 0 at 0.25.
    - Each orbit mote: r 4 in step 2 at 0.35.
    - Each star (glint, spark, mote): r 3 + 2.5·arm in its colour at 0.4.
    - Each ring: r 16 in step 2 at 0.5·(1 − progress).
    - The pop: r 30 in step 2, from 0.9 to 0 over 0.3 s.
  - The colour buffer gets only opaque pixels, faded by 4 × 4 Bayer dithering.
- **Palette:** `palette` is 6 steps: white, highlight, light, mid, dark, outline. Each item has its own default:
  - gem: #ffffff, #e0faff, #7fe0ff, #2f9ee8, #1d4aa8, #101a3e.
  - orb: #ffffff, #e6ffe0, #8cff7a, #2fc95a, #157a46, #0b2e1f.
  - coin: #fffbe8, #ffec92, #ffd243, #f4a923, #a8601a, #3a1d0c.
  - Besides the sprite:
    - 0: the glint, the white pop frame and disc, the rings' first 30%, and the small glow.
    - 1: the near orbit motes.
    - 2: the rings after 30%, the trail's 2 newest segments, each spark trail's newest dot, and the orbit, ring and pop glows.
    - 3: the far orbit motes, the item glow, and the older trail and spark-trail dots.
    - 4: the coin seen edge-on.
    - 5: the sprite's outline only.
    - Sparks pick from steps 0–2 and motes from steps 1–2.
  - Fixed colours: the shadow is #0b0814, and star centres are #ffffff.
  - A custom sprite keeps its own pixels and uses the gem palette (or `palette`) for everything else.
- **Shapes and motion:**
  - Sprites: lit from the top left, with a 1 px outline. The gem is 11 × 10 (faceted, pointed at the bottom), the orb and the coin 9 × 9. Pixel maps are in `SPRITES`. They are drawn centred, nearest-neighbour scaled with no smoothing, by `blitScaled`.
  - Coin spin: the horizontal scale is max(0.15, |cos 5.2t|). While |cos| < 0.3 the whole coin is drawn in step 4 (the edge).
  - Shadow: drawn on the ground row under `x` and the row below it, made of dithered #0b0814 dots. With h = (ground − item y)/80 units, clamped 0..1:
    - The top row has half-width (w/2 + 1)·(1 − 0.35h) px and opacity (0.8 − 0.4h)·(1 − (dx/half-width)²).
    - The row below is limited to |dx| < 0.6 × half-width, at 60% of that opacity.
  - Orbit: two single pixels on opposite sides of an ellipse 9 × 2.6 px, centred 1 px above the item, turning at 2.6 rad/s.
  - Star (the glint, sparks and motes): a plus with arms n px long. Its end pixels are at 80% brightness when n > 1, and its centre is white (when n = 0, it is a single pixel in its colour).
    - The glint sits at (−0.22w, −0.2h) from the item's centre. Its arms go 0 → 3 → 0 px (round(2.5 sin)), in white.
  - Arc: from 8 units above the item to the chest. The chest is midway between `head()` and `feet()`, or 40 units above the feet. The control point is at mid x, max(40, 0.35 × distance) units above the higher end. The arc is re-aimed every update, so it follows a moving character.
  - Trail: the last 7 positions, joined by 1 px lines. It shrinks by one point per update after the pop.
  - Sparks: 14, at evenly spaced angles ±0.2 rad, at 150–300 units/s with an extra 40 units/s upward.
    - Arms are 2 px (40%) or 1 px, shrinking in the last third of life.
    - Each is randomly step 0, 1 or 2.
    - Each trails its last 4 positions as dithered dots at opacity 0.8, 0.6, 0.4, 0.2.
  - Motes: 2 per absorbed spark, at the chest ±10 units in x and −14 to +10 in y. They rise at 30–80 units/s with vx ±12 (drag 1.5/s) and live 0.4–0.8 s. Each is a single pixel, or has 1 px arms (30%). Each is randomly step 1 or 2. They flicker: drawn only while life·(0.6 + 0.4 sin(30·life)) > 0.25.
  - Rings: circles, not ellipses. The pop ring opens from 2 to 22 px radius and each absorption ring from 2 to 14, over 0.4 s (outCubic). Thickness max(1, 2·(1 − progress)) px; dithered opacity 1.2 − progress.
- **Feel:** a tiny camera shake of 0.05 at the pop. No flash.

## Situations
- **Collect:** `pickup({ item: "gem", x: 330, y: 250, actor: player, ground: 300, wait: 0.6, seed: 2 })`, `pickup({ item: "coin", x: 420, y: 260, actor: player, ground: 300, wait: 0.95, seed: 8 })` and `pickup({ item: "orb", x: 510, y: 238, actor: player, ground: 300, magnet: false, wait: 1.3, seed: 5 })`, all started together: three items hover ahead of the player. The gem and then the coin are pulled into the player. The orb pops where it hovers, and its sparks curve into the player.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `780` | Where the item hovers (its centre). |
| `y` | number (world units) | `556` | Where the item hovers (its centre). |
| `item` | `"gem" \| "orb" \| "coin" \| Sprite` | `"gem"` | A built-in item, or your own sprite `{ w, h, data }` (art px, `Uint32Array` ABGR, alpha 0 = empty). Only `"coin"` spins. |
| `palette` | `string[]` (6 × `#rrggbb`) | the item's own (the gem's for a custom sprite) | White, highlight, light, mid, dark, outline: the built-in sprite and every spark, ring, trail and glow. |
| `actor` | `Actor` | none | Who collects it. Its chest is where the item flies and the sparks home. Without one, it pops in place and the sparks fade where they burst. |
| `magnet` | boolean | `true` | Pull the item to the actor along an arc before popping. `false` pops it where it hovers, though its sparks still home in. Has no effect without an actor. |
| `wait` | number (s) | `0.9` | Seconds before it collects itself. `Infinity` waits for `collect()`. |
| `ground` | `number \| ((x: number) => number)` (world units) | none | The ground's y under the item, for its shadow. Without it, there is no shadow. |
| `seed` | number | `1` | Random seed (the spark angles, speeds and colours). |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |

## Actor, methods and hooks
- `actor`: `feet(): [number, number]` and the optional `head?(): [number, number]` (world units) are read on every update. The target is the point midway between them, or 40 units above the feet without `head`, and it is followed as the actor moves.
- `collect()`: call it when the player touches the item, to start the lift, flight and pop (or the pop alone without a magnet) right away. A second call does nothing. If it is never called, the item collects itself after `wait`. With `wait: Infinity` and no `collect()`, `done()` never turns true.
- `shake(trauma: number)`: called once at the pop with 0.05.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: pickup.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { feet(): [number, number]; head?(): [number, number] }
export interface Sprite { w: number; h: number; data: Uint32Array }
export interface Options {
  x?: number;
  y?: number;
  item?: "gem" | "orb" | "coin" | Sprite;
  palette?: string[];
  actor?: Actor;
  magnet?: boolean;
  wait?: number;
  ground?: number | ((x: number) => number);
  seed?: number;
  shake?(trauma: number): void;
}
const LIFT = 0.1, FLY = 0.34;
export default function pickup(o: Options = {}) {
  const X = o.x ?? 780, Y = o.y ?? 556, R = new Rng(o.seed ?? 1);
  const kind = typeof o.item === "object" ? null : o.item ?? "gem";
  const C = (o.palette ?? PALETTES[kind ?? "gem"]).map(hex), [WH, HI, LI, MI, DK] = [C[0]!, C[1]!, C[2]!, C[3]!, C[4]!], BURST = [WH, HI, LI], MOTE = [HI, LI];
  const spr = typeof o.item === "object" ? o.item : sprite(SPRITES[kind ?? "gem"], { w: C[0]!, h: C[1]!, l: C[2]!, m: C[3]!, d: C[4]!, o: C[5]! });
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const magnet = (o.magnet ?? true) && !!o.actor;
  const target = (): [number, number] | null => {
    if (!o.actor) return null;
    const [fx, fy] = o.actor.feet(), h = o.actor.head?.();
    return h ? [(h[0] + fx) / 2, (h[1] + fy) / 2] : [fx, fy - 40];
  };
  const sparks: Spark[] = [], motes: Spark[] = [], rings: { x: number; y: number; t: number; r: number }[] = [];
  let t = 0, tc = Infinity, popT = Infinity, px = X, py = Y, from: [number, number] = [X, Y];
  const trail: [number, number][] = [];
  let absorbed = 0;
  function collect() { if (tc === Infinity) { tc = t; from = [px, py]; if (!magnet) pop(); } }
  function pop() {
    popT = t;
    o.shake?.(0.05);
    rings.push({ x: px, y: py, t, r: 20 });
    for (let i = 0; i < 14; i++) {
      const a = (i / 14) * TAU + R.range(-0.2, 0.2), sp = R.range(150, 300);
      sparks.push({ x: px, y: py, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 40, life: R.range(0.75, 1.05), max: 1.05, s: R.chance(0.4) ? 2 : 1, c: R.pick(BURST), tr: [] });
    }
  }
  return {
    collect,
    update(dt: number) {
      t += dt;
      if (tc === Infinity && t >= (o.wait ?? 0.9)) collect();
      const tg = target();
      if (tc === Infinity || (magnet && popT === Infinity)) {
        const bob = Math.sin(t * 3.4) * 3;
        if (tc === Infinity) (px = X), (py = Y + bob);
        else if (tg) {
          const k = t - tc;
          if (k < LIFT) py = from[1] - 8 * outCubic(k / LIFT);
          else {
            const u = Math.pow(clamp((k - LIFT) / FLY), 2.2), sx = from[0], sy = from[1] - 8;
            const mx = (sx + tg[0]) / 2, my = Math.min(sy, tg[1]) - Math.max(40, Math.hypot(tg[0] - sx, tg[1] - sy) * 0.35);
            px = (1 - u) * (1 - u) * sx + 2 * (1 - u) * u * mx + u * u * tg[0];
            py = (1 - u) * (1 - u) * sy + 2 * (1 - u) * u * my + u * u * tg[1];
            trail.unshift([px, py]);
            if (trail.length > 7) trail.pop();
            if (u >= 1) pop();
          }
        }
      } else if (trail.length) trail.pop();
      for (let i = sparks.length - 1; i >= 0; i--) {
        const s = sparks[i]!, age = s.max - s.life;
        s.tr.unshift([s.x, s.y]);
        if (s.tr.length > 5) s.tr.pop();
        if ((s.life -= dt) <= 0) { sparks.splice(i, 1); continue; }
        if (tg && age > 0.12) {
          const dx = tg[0] - s.x, dy = tg[1] - s.y, d = Math.hypot(dx, dy) || 1, want = 380 + 900 * age, k = Math.min(1, dt * (3 + 22 * age));
          s.vx += ((dx / d) * want - s.vx) * k;
          s.vy += ((dy / d) * want - s.vy) * k;
          if (d < 9) {
            sparks.splice(i, 1);
            if (absorbed++ % 3 === 0) rings.push({ x: tg[0], y: tg[1], t, r: 12 });
            for (let j = 0; j < 2; j++) motes.push({ x: tg[0] + R.range(-10, 10), y: tg[1] + R.range(-14, 10), vx: R.range(-12, 12), vy: -R.range(30, 80), life: R.range(0.4, 0.8), max: 0.8, s: R.chance(0.3) ? 1 : 0, c: R.pick(MOTE), tr: [] });
            continue;
          }
        } else { s.vx -= s.vx * 3 * dt; s.vy -= s.vy * 3 * dt; s.vy += 60 * dt; }
        s.x += s.vx * dt;
        s.y += s.vy * dt;
      }
      for (let i = motes.length - 1; i >= 0; i--) {
        const m = motes[i]!;
        if ((m.life -= dt) <= 0) { motes.splice(i, 1); continue; }
        m.vx -= m.vx * 1.5 * dt;
        m.x += m.vx * dt;
        m.y += m.vy * dt;
      }
      for (let i = rings.length - 1; i >= 0; i--) if (t - rings[i]!.t > 0.4) rings.splice(i, 1);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      const ax = px / PX, ay = py / PX, alive = popT === Infinity, g = groundAt(X);
      const orbit = (front: boolean) => {
        if (!alive) return;
        for (let i = 0; i < 2; i++) {
          const a = t * 2.6 + i * Math.PI, ox = Math.cos(a) * 9, oy = Math.sin(a) * 2.6 - 1;
          if (Math.sin(a) > 0 !== front) continue;
          dot(buf, ax + ox, ay + oy, front ? HI : MI);
          light.glow(ax + ox, ay + oy, 4, LI, 0.35);
        }
      };
      if (layer !== "front") {
        if (alive && tc === Infinity && Number.isFinite(g)) {
          const h = clamp((g - py) / 80), rx = (spr.w / 2 + 1) * (1 - 0.35 * h);
          for (let x = Math.floor(-rx); x <= rx; x++) {
            const a = (0.8 - 0.4 * h) * (1 - Math.abs(x / rx) ** 2);
            dot(buf, X / PX + x, g / PX, SHADOW, a);
            if (Math.abs(x) < rx * 0.6) dot(buf, X / PX + x, g / PX + 1, SHADOW, a * 0.6);
          }
        }
        orbit(false);
      }
      if (layer === "back") return;
      trail.forEach(([tx, ty], i) => i > 0 && buf.line(trail[i - 1]![0] / PX, trail[i - 1]![1] / PX, tx / PX, ty / PX, i < 3 ? LI : MI));
      if (alive) {
        const flying = tc !== Infinity ? clamp((t - tc - LIFT) / FLY) : 0;
        const spin = kind === "coin" ? Math.cos(t * 5.2) : 1, sx = Math.max(0.15, Math.abs(spin)) * (1 - 0.25 * flying), sy = 1 - 0.25 * flying;
        const lift = tc !== Infinity && t - tc < LIFT ? outCubic((t - tc) / LIFT) : 0;
        blitScaled(buf, spr, ax, ay, sx * (1 - 0.15 * lift), sy * (1 + 0.2 * lift), Math.abs(spin) < 0.3 && kind === "coin" ? DK : 0);
        const gl = ((t + 0.4) % 1.3) / 1.3;
        if (gl < 0.22) star(buf, light, ax - spr.w * 0.22, ay - spr.h * 0.2, Math.round(2.5 * Math.sin((gl / 0.22) * Math.PI)), WH);
        orbit(true);
        light.glow(ax, ay, 14 + 2 * Math.sin(t * 4), MI, 0.45 + 0.4 * flying);
        light.glow(ax, ay, 5, WH, 0.25);
      } else {
        const k = t - popT;
        if (k < 0.1) blitScaled(buf, spr, ax, ay, k < 0.05 ? 1.5 : 0.7, k < 0.05 ? 0.6 : 1.45, k < 0.05 ? 0 : WH);
        if (k < 0.08) buf.disc(ax, ay, 7 * (1 - k / 0.08) + 1, WH);
        if (k < 0.3) light.glow(ax, ay, 30, LI, 0.9 * (1 - k / 0.3));
      }
      for (const r of rings) {
        const k = (t - r.t) / 0.4, e = outCubic(k);
        buf.ring(r.x / PX, r.y / PX, 2 + (r.r / PX) * e * 2, Math.max(1, 2 * (1 - k)), k < 0.3 ? WH : LI, 1.2 - k);
        light.glow(r.x / PX, r.y / PX, 16, LI, 0.5 * (1 - k));
      }
      for (const s of sparks) {
        const k = s.life / s.max;
        s.tr.forEach(([tx, ty], i) => i > 0 && dot(buf, tx / PX, ty / PX, i < 2 ? LI : MI, 1 - i / 5));
        star(buf, light, s.x / PX, s.y / PX, Math.round(s.s * Math.min(1, k * 3)), s.c);
      }
      for (const m of motes) { const k = m.life / m.max; if (k * (0.6 + 0.4 * Math.sin(m.life * 30)) > 0.25) star(buf, light, m.x / PX, m.y / PX, m.s, m.c); }
    },
    done: () => popT !== Infinity && t - popT > 0.5 && sparks.length === 0 && motes.length === 0,
  };
}
interface Spark { x: number; y: number; vx: number; vy: number; life: number; max: number; s: number; c: number; tr: [number, number][] }
const SHADOW = hex("#0b0814");
const PALETTES = {
  gem: ["#ffffff", "#e0faff", "#7fe0ff", "#2f9ee8", "#1d4aa8", "#101a3e"],
  orb: ["#ffffff", "#e6ffe0", "#8cff7a", "#2fc95a", "#157a46", "#0b2e1f"],
  coin: ["#fffbe8", "#ffec92", "#ffd243", "#f4a923", "#a8601a", "#3a1d0c"],
};
const SPRITES = {
  gem: ["...ooooo...", "..ohwhlmo..", ".ohwhllmmo.", "olllllmmmdo", "odmmmmmmddo", ".odlmmmmdo.", "..odlmmdo..", "...odmdo...", "....odo....", ".....o....."],
  orb: ["..ooooo..", ".ollllmo.", "olwhllmmo", "olhlllmmo", "ollllmmmo", "ommmmmmdo", "ommmmmddo", ".odmlddo.", "..ooooo.."],
  coin: ["..ooooo..", ".ohllllo.", "ohlmmmmdo", "olmhlmmdo", "olmlmmmdo", "olmmmmmdo", "olddmmddo", ".odddddo.", "..ooooo.."],
};
function sprite(rows: string[], pal: Record<string, number>): Sprite {
  const h = rows.length, w = Math.max(...rows.map((r) => r.length)), data = new Uint32Array(w * h);
  rows.forEach((r, y) => [...r].forEach((ch, x) => ch !== "." && (data[y * w + x] = pal[ch] ?? 0)));
  return { w, h, data };
}
function blitScaled(buf: Px, s: Sprite, cx: number, cy: number, sx: number, sy: number, tint = 0) {
  const hw = (s.w * sx) / 2, hh = (s.h * sy) / 2;
  for (let y = Math.floor(cy - hh); y <= Math.ceil(cy + hh); y++)
    for (let x = Math.floor(cx - hw); x <= Math.ceil(cx + hw); x++) {
      const u = Math.floor((x + 0.5 - cx) / sx + s.w / 2), v = Math.floor((y + 0.5 - cy) / sy + s.h / 2);
      if (u < 0 || v < 0 || u >= s.w || v >= s.h) continue;
      const c = s.data[v * s.w + u]!;
      if (c >>> 24) buf.set(x, y, tint || c);
    }
}
function star(buf: Px, light: Px, x: number, y: number, arm: number, c: number) {
  const px = Math.floor(x), py = Math.floor(y);
  for (let d = 1; d <= arm; d++) {
    const cc = d === arm && arm > 1 ? scale(c, 0.8) : c;
    buf.set(px + d, py, cc);
    buf.set(px - d, py, cc);
    buf.set(px, py + d, cc);
    buf.set(px, py - d, cc);
  }
  buf.set(px, py, arm > 0 ? hex("#ffffff") : c);
  light.glow(x, y, 3 + arm * 2.5, c, 0.4);
}
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
  add(x: number, y: number, c: number, k: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, r = Math.min(255, (d & 255) + (c & 255) * k), g = Math.min(255, ((d >>> 8) & 255) + ((c >>> 8) & 255) * k), b = Math.min(255, ((d >>> 16) & 255) + ((c >>> 16) & 255) * k);
    this.data[i] = (255 << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255);
  }
  disc(cx: number, cy: number, r: number, c: number) {
    if (r <= 0.5) return this.set(Math.round(cx), Math.round(cy), c);
    const r2 = r * r;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const dx = x + 0.5 - cx; if (dx * dx + dy * dy <= r2) this.set(x, y, c); }
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
  line(x0: number, y0: number, x1: number, y1: number, c: number) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (let n = 0; n < 4096; n++) {
      this.set(x0, y0, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) (err += dy), (x0 += sx);
      if (e2 <= dx) (err += dx), (y0 += sy);
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
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function scale(c: number, k: number) {
  return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24);
}
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
  chance(p: number) { return this.next() < p; }
  pick<T>(a: readonly T[]): T { return a[Math.floor(this.next() * a.length)]!; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
```
