# Blood (blood.ts)

A spray that flies on along the hit: strands, mist, droplets splatting into stains that dry darker, and drops beading at the wound. Recolour it for any creature.

Previews (animated WebP, 320 × 200 art pixels): Hit https://www.spritefusion.com/images/pixel-art-vfx/blood-hit.webp

Page: https://www.spritefusion.com/pixel-art-vfx/blood. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/blood.zip

## Recipe
- **Timeline:** one call is one hit. Values are for `amount` 1 and `size` 1 (S = `size`).
  - 0 s: the hooks fire: `cue("hurt")`, `cue("knock")`, then `shake`.
  - 0–0.035 s: a blob at the wound.
  - 0–0.045 s: 7 strands shoot out of the wound in a fan along `angle` (ease-out cubic).
  - 0.04–0.09 s: the strands break up. Their roots let go, and the break runs out to the tips as they thin to half. They are gone at 0.09 s. The wound's glow fades over the same 0.09 s.
  - 0–0.07 s: 46 drops are released, each after its own random delay. Late ones are slower.
  - 0–0.05 s: a jet of 14 fast, fine drops is released, one after another.
  - 0 to about 0.65 s: 6 mist puffs swell and fade.
  - About 0.1–1 s: drops land on `ground` as stains, which spread to full width in 0.12 s. Big, fast drops throw a crown of 1–3 droplets.
  - Stains dry, darkening at 0.35, 1.4 and 3.2 s; 30% of them are a step darker throughout. After `stainLife` (6 s) they dissolve by dither over 1.2 s.
  - Drips: 3 drops form under the wound, at 0.22–0.32, 0.6–0.8 and 1.1–1.4 s (only the first 2 if `amount` < 1).
    - Each runs 3 px down over 0.18 s, beads, and falls 0.2 s after it started forming.
    - Its run fades 1–1.6 s after it started forming.
  - `done()` turns true once the last stain has faded: about 7.2 s after the last landing, about 8.8 s in all. Without `ground` there are no stains: drops vanish 3 s after leaving, about 4.5 s in all.
- **Layers:**
  - "back": the stains.
  - "front", in draw order: mist, strands and the wound's blob, drips, flying drops.
  - Light buffer: a single glow at the wound, r 16S art px, C1, at 0.25 × (1 − t/0.09), falling off as (1 − d/r)². Blood barely lights the scene.
  - Mist is alpha-blended discs. Everything else is opaque pixels.
- **Palette:** `ramp` is 6 colours, light to dark. The default is red: C0 #ff8a7a wet highlight, C1 #f2384a fresh, C2 #c71e33 dark, C3 #931327 drying, C4 #5e0c1b dry, C5 #350711 clot.
  - Strands: a C4 rim, C1 over the first 35% of their length, C2 beyond, and a C0 highlight pixel along their first half.
  - The wound's blob: a C1 disc with a C0 centre.
  - Flying drops:
    - 1 px drops are C1 or C2.
    - 2 px drops are a 2 × 2 square: C0 C1 on top, C2 C3 below.
    - 3 px drops: a C4 rim disc, a C1 body and a C0 highlight up-left.
    - Speed tails: C3 behind 1 px drops, C2 behind bigger ones.
  - Mist: C3.
  - Drips: the run is C3; the bead is C2, with C3 to its right, C2 below and a C0 highlight.
  - Stains:
    - The body steps C1 → C2 → C3 → C4 as it dries. Its ends and the row under it are one step darker, down to C5.
    - A C0 wet glint for the first 0.4 s, and a C1 highlight on top of thick stains for the first 1 s.
- **Shapes and motion:** sizes are in art px and speeds in world units/s. Gravity g = 1900 units/s². Drag is v −= v·drag·dt. Fades are 4 × 4 Bayer ordered dither unless alpha is stated.
  - Strands: 7, fanned ±0.62 rad around `angle` with ±0.08 jitter, the middle ones longest.
    - For strand i (0–6), u = (i − 3)/3 runs from −1 to 1.
    - Length (11 + 7 × (1 − |u|) + (−2 to +3)) × S.
    - Radius (1.3 + 0.6 × (1 − |u|)) × S, tapering as (1 − d/L)^0.6, with a 0.5 px blob added at the tip (the last 15%).
    - Each is drawn every 0.5 px as filled discs: a rim (+0.7), then the body, then the highlight.
  - The wound's blob: discs of radius 2.6S (C1) and 1.5S (C0).
  - Spray: 46 × `amount` drops, starting 0–8 units out along `angle`.
    - 12% are 3 px, about 31% 2 px, and the rest 1 px.
    - Spread around `angle`: up to ±0.78 rad for 1 px drops and ±0.52 for bigger ones.
    - Speed: 260–950 (1 px), 200–650 (2 px) or 150–460 (3 px), × (1 − 4 × delay) × √S, plus 0–150 upward.
  - Jet: 14 × `amount` drops (25% are 2 px), within ±0.12 rad of `angle` at 620–1050 × √S, plus 0–60 upward.
  - Flying drops: full gravity. Horizontal drag 0.7 / drop size (in px); vertical drag half that. A tail line behind each, speed × 0.008 px long (max 6), drawn when ≥ 1 px. Life 3 s unless they land.
  - Mist: 6 × √`amount` puffs, starting 2–14 units out.
    - Thrown within ±0.5 rad of `angle` at 30–110, with −12 vertical. Drag 3, a slight rise.
    - Start delay 0–0.05 s. Life 0.35–0.6 s.
    - Each is an alpha disc whose radius grows from (2.5–5) × S to 1.6× that, at opacity 0.4 × life left. It fades in over the first eighth of its life.
  - Stains: a horizontal run on the ground's top pixel row, centred where the drop landed.
    - Half-width: 0.5 + min(0.6, speed/1200) for 1 px drops; the drop's px size × 0.6 + min(0.9, speed/800) for bigger ones; halved for crown droplets.
    - It reaches out ahead in the direction of travel. The back side is × (1 − 0.3·lean) and the front side × (1 + 0.8·lean), with lean = min(1, |vx|/400).
    - Half-widths over 1.6 get a darker row below (the middle 60%). Over 2.2, they also get a row above (the middle 45%).
    - 1–2 spatter dots land ahead: 2 for drops of ≥ 2 px landing faster than 350, otherwise 1 for drops faster than 450.
  - Crowns: when a drop of ≥ 2 px lands faster than 260, 1–3 droplets jump off. They fly sideways at 10–130 (±70) and up at 80–170. Life 0.8 s.
  - Drips: they hang from the wound, which moves with `actor.feet()`. Each falls from 6 units under the wound at 30 units/s down. Half are 2 px.
- **Feel:** all at creation, once each.
  - `shake(0.25 × min(1.5, amount))`.
  - `cue("hurt", { t: 0.12 })`: flash the hit character for 0.12 s.
  - `cue("knock", { vx: cos(angle) × 520 × min(1.4, √amount), vy: -60 })`: push it the blood's way.
  - No flash or ripple.

## Situations
- **Hit:** `blood({ actor: player, angle: 3.45, ground: 300, seed: 3 })`: a character standing on y 300, shot from the right. The spray bursts from its chest (44 units above its feet) back and up to the left, and lands as stains that dry darker on the floor. Drops bead and fall from the wound as the character is knocked back.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | the actor's feet x, else `640` | The wound's x. |
| `y` | number (world units) | 44 above the actor's feet, else `556` | The wound's y. |
| `angle` | number (rad) | `3.45` | Where the blood flies, usually along the hit (0 right, π/2 down). 3.45 is back and up to the left. |
| `amount` | number (multiplier) | `1` | How much. <br>• Spray drops 46 × amount and jet drops 14 × amount. <br>• Mist 6 × √amount. <br>• Shake 0.25 × min(1.5, amount), and the knock's speed. <br>• Below 1, 2 drips instead of 3. |
| `size` | number (multiplier) | `1` | The splash's scale: strand length and width, the wound's blob, the glow, mist radius, and drop speeds (× √size). Drop pixel sizes don't change. |
| `ramp` | `readonly number[]` (6 × ABGR) | red: `#ff8a7a #f2384a #c71e33 #931327 #5e0c1b #350711` | 6 colours, light to dark: wet highlight, fresh, dark, drying, dry, clot. Recolour it for green alien blood, black oil, ink. |
| `stainLife` | number (s) | `6` | How long stains stay before they dissolve (over 1.2 s). |
| `ground` | `number \| ((x: number) => number)` (world y) | none | The floor, where drops land as stains. Without it there are no stains. |
| `actor` | `{ feet(): [number, number] }` | none | The character hit (see below). |
| `seed` | number | `1` | Random seed. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |
| `cue` | `(name: string, data?: Record<string, number>) => void` | none | Asks the game to react: `"hurt"`, `"knock"`. |

## Actor, methods and hooks
- `actor`: `feet(): [number, number]` (world units).
  - It is read once, at creation, to place the wound 44 units above the feet (unless `x`/`y` are given).
  - It is read again on every update and draw, so the drips stay on the wound as the character moves. The wound keeps its offset from the feet.
- `shake(trauma: number): void`: called once, at creation, with 0.25 × min(1.5, amount).
- `cue(name: string, data?: Record<string, number>): void`: called twice, at creation:
  - first `"hurt"` with `{ t: 0.12 }`: flash the hit character for t seconds.
  - then `"knock"` with `{ vx: cos(angle) × 520 × min(1.4, √amount), vy: -60 }`: a push on it, in world units/s.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: blood.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { feet(): [number, number] }
export interface Options {
  x?: number;
  y?: number;
  angle?: number;
  amount?: number;
  size?: number;
  ramp?: readonly number[];
  stainLife?: number;
  ground?: number | ((x: number) => number);
  actor?: Actor;
  seed?: number;
  shake?(trauma: number): void;
  cue?(name: string, data?: Record<string, number>): void;
}
export default function blood(o: Options = {}) {
  const R = new Rng(o.seed ?? 1), C = o.ramp ?? BLOOD, A = o.angle ?? 3.45, N = o.amount ?? 1, S = o.size ?? 1, LIFE = o.stainLife ?? 6;
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const feet0 = o.actor?.feet() ?? [o.x ?? 640, (o.y ?? 556) + 44];
  const X = o.x ?? feet0[0], Y = o.y ?? feet0[1] - 44, ux = Math.cos(A), uy = Math.sin(A);
  const wound = (): [number, number] => { if (!o.actor) return [X, Y]; const [fx, fy] = o.actor.feet(); return [fx + X - feet0[0], fy + Y - feet0[1]]; };
  const drops: Drop[] = [], stains: Stain[] = [], mist: Mist[] = [];
  const strands = Array.from({ length: 7 }, (_, i) => {
    const u = (i - 3) / 3;
    return { a: A + u * 0.62 + R.range(-0.08, 0.08), l: (11 + 7 * (1 - Math.abs(u)) + R.range(-2, 3)) * S, w: (1.3 + 0.6 * (1 - Math.abs(u))) * S };
  });
  const drips = [R.range(0.22, 0.32), R.range(0.6, 0.8), R.range(1.1, 1.4)].slice(0, N >= 1 ? 3 : 2).map((t0) => ({ t0, fell: false }));
  let t = 0;
  o.cue?.("hurt", { t: 0.12 });
  o.cue?.("knock", { vx: ux * 520 * Math.min(1.4, Math.sqrt(N)), vy: -60 });
  o.shake?.(0.25 * Math.min(1.5, N));
  const n = Math.round(46 * N);
  for (let i = 0; i < n; i++) {
    const s = R.chance(0.12) ? 3 : R.chance(0.35) ? 2 : 1, spread = R.range(-1, 1) * R.range(0.1, 0.65) * (s === 1 ? 1.2 : 0.8);
    const delay = R.range(0, 0.07), sp = (s === 1 ? R.range(260, 950) : s === 2 ? R.range(200, 650) : R.range(150, 460)) * (1 - delay * 4) * Math.sqrt(S), a = A + spread;
    drops.push({ x: X + ux * R.range(0, 8), y: Y + uy * R.range(0, 8), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - R.range(0, 150), s, delay, life: 3, crown: false, seed: R.next() });
  }
  for (let i = 0; i < Math.round(14 * N); i++) {
    const a = A + R.range(-0.12, 0.12), sp = R.range(620, 1050) * Math.sqrt(S);
    drops.push({ x: X, y: Y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - R.range(0, 60), s: R.chance(0.25) ? 2 : 1, delay: (i / 14) * 0.05, life: 3, crown: false, seed: R.next() });
  }
  for (let i = 0; i < Math.round(6 * Math.sqrt(N)); i++) {
    const a = A + R.range(-0.5, 0.5), sp = R.range(30, 110);
    mist.push({ x: X + ux * R.range(2, 14), y: Y + uy * R.range(2, 14), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 12, r: R.range(2.5, 5) * S, life: R.range(0.35, 0.6), max: 0, t0: R.range(0, 0.05) });
  }
  for (const m of mist) m.max = m.life;
  function splat(d: Drop, g: number) {
    const sp = Math.hypot(d.vx, d.vy), dir = Math.sign(d.vx) || 1;
    const w = (d.s === 1 ? 0.5 + Math.min(0.6, sp / 1200) : d.s * 0.6 + Math.min(0.9, sp / 800)) * (d.crown ? 0.5 : 1);
    const sats: [number, number][] = [];
    for (let k = 0; k < (d.s >= 2 && sp > 350 ? 2 : sp > 450 ? 1 : 0); k++) sats.push([R.range(1, 3) + k * R.range(1.5, 3), R.chance(0.2) ? 2 : 1]);
    stains.push({ x: d.x / PX, y: Math.round(g / PX), w, lean: Math.min(1, Math.abs(d.vx) / 400), dir, t0: t, sats, tone: R.chance(0.3) ? 1 : 0 });
    if (!d.crown && d.s >= 2 && sp > 260) for (let k = 0; k < R.int(1, 3); k++) drops.push({ x: d.x, y: g - 1, vx: dir * R.range(10, 130) + R.range(-70, 70), vy: -R.range(80, 170), s: 1, delay: 0, life: 0.8, crown: true, seed: R.next() });
  }
  return {
    update(dt: number) {
      t += dt;
      for (let i = drops.length - 1; i >= 0; i--) {
        const d = drops[i]!;
        if (d.delay > 0) { d.delay -= dt; continue; }
        if ((d.life -= dt) <= 0) { drops.splice(i, 1); continue; }
        const drag = 0.7 / d.s;
        d.vy += GRAVITY * dt;
        d.vx -= d.vx * drag * dt;
        d.vy -= d.vy * drag * 0.5 * dt;
        const py = d.y;
        d.x += d.vx * dt;
        d.y += d.vy * dt;
        const g = groundAt(d.x);
        if (d.vy > 0 && py <= g && d.y >= g) { splat(d, g); drops.splice(i, 1); }
      }
      const [wx, wy] = wound();
      for (const d of drips)
        if (!d.fell && t >= d.t0 + 0.2) {
          d.fell = true;
          drops.push({ x: wx + R.range(-1, 1), y: wy + 6, vx: R.range(-10, 10), vy: 30, s: R.chance(0.5) ? 2 : 1, delay: 0, life: 3, crown: false, seed: R.next() });
        }
      for (let i = mist.length - 1; i >= 0; i--) {
        const m = mist[i]!;
        if (m.t0 > 0) { m.t0 -= dt; continue; }
        if ((m.life -= dt) <= 0) { mist.splice(i, 1); continue; }
        m.vx -= m.vx * 3 * dt;
        m.vy -= m.vy * 3 * dt + 6 * dt;
        m.x += m.vx * dt;
        m.y += m.vy * dt;
      }
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front")
        for (const s of stains) {
          const age = t - s.t0, fade = 1 - clamp((age - LIFE) / 1.2);
          if (fade <= 0) continue;
          const spread = smooth(0, 0.12, age), hw = s.w * (0.55 + 0.45 * spread);
          const dry = Math.min(4, (age < 0.35 ? 1 : age < 1.4 ? 2 : age < 3.2 ? 3 : 4) + s.tone), body = C[dry]!, under = C[Math.min(5, dry + 1)]!;
          const x0 = s.x - hw * (1 - 0.3 * s.lean), x1 = s.x + hw * (1 + 0.8 * s.lean), lo = s.dir > 0 ? x0 : 2 * s.x - x1, hi = s.dir > 0 ? x1 : 2 * s.x - x0;
          for (let x = Math.floor(lo); x <= Math.ceil(hi); x++) {
            const q = Math.abs(x + 0.5 - s.x) / Math.max(0.5, (hi - lo) / 2);
            if (fade < 1 && fade <= bayer(x, s.y)) continue;
            dot(buf, x, s.y, q > 0.85 && s.w > 1 ? under : body);
            if (s.w > 1.6 && q < 0.6) dot(buf, x, s.y + 1, under);
            if (s.w > 2.2 && q < 0.45) dot(buf, x, s.y - 1, q < 0.2 && age < 1 ? C[1]! : body);
          }
          if (age < 0.4 && s.w > 1) dot(buf, s.x - s.dir * hw * 0.3, s.y, C[0]!);
          for (const [d, sz] of s.sats) {
            const sx = s.x + s.dir * (hw * (1 + 0.6 * s.lean) + d * spread);
            if (fade < 1 && fade <= bayer(Math.floor(sx), s.y)) continue;
            dot(buf, sx, s.y, body);
            if (sz > 1) dot(buf, sx + s.dir, s.y, under);
          }
        }
      if (layer === "back") return;
      for (const m of mist) {
        if (m.t0 > 0) continue;
        const k = m.life / m.max;
        buf.alphaDisc(m.x / PX, m.y / PX, m.r * (1.6 - 0.6 * k), C[3]!, 0.4 * k * Math.min(1, (1 - k) * 8));
      }
      if (t < 0.09) {
        const grow = outCubic(t / 0.045), brk = clamp((t - 0.04) / 0.05), [wx, wy] = [X / PX, Y / PX];
        for (const s of strands) {
          const L = s.l * grow, d0 = L * brk, ca = Math.cos(s.a), sa = Math.sin(s.a);
          for (let pass = 0; pass < 3; pass++)
            for (let d = d0; d <= L; d += 0.5) {
              const u = d / Math.max(1, L), r = s.w * Math.pow(1 - u, 0.6) * (1 - brk * 0.5) + (u > 0.85 ? 0.5 : 0);
              if (r < 0.35) continue;
              const x = wx + ca * d, y = wy + sa * d;
              if (pass === 0) buf.disc(x, y, r + 0.7, C[4]!);
              else if (pass === 1) buf.disc(x, y, r, d < L * 0.35 ? C[1]! : C[2]!);
              else if (d < L * 0.5 && r > 0.9) buf.set(Math.round(x - sa * r * 0.4), Math.round(y + ca * r * 0.4 - 0.4), C[0]!);
            }
        }
        if (t < 0.035) { buf.disc(wx, wy, 2.6 * S, C[1]!); buf.disc(wx, wy, 1.5 * S, C[0]!); }
        light.glow(wx, wy, 16 * S, C[1]!, 0.25 * (1 - t / 0.09));
      }
      const [wx, wy] = wound();
      for (const d of drips) {
        const u = t - d.t0;
        if (u < 0 || u > 1.6) continue;
        const run = Math.min(3, 3 * smooth(0, 0.18, u)), fade = 1 - clamp((u - 1) / 0.6);
        for (let k = 0; k <= run; k++) dot(buf, wx / PX, wy / PX + k, C[3]!, fade);
        if (!d.fell) {
          const bead = smooth(0, 0.2, u);
          dot(buf, wx / PX, wy / PX + run + 1, C[2]!);
          if (bead > 0.6) {
            dot(buf, wx / PX + 1, wy / PX + run + 1, C[3]!);
            dot(buf, wx / PX, wy / PX + run + 2, C[2]!);
            dot(buf, wx / PX, wy / PX + run + 1, C[0]!);
          }
        }
      }
      for (const d of drops) if (d.delay <= 0) drop(buf, d, C);
    },
    done: () => t > 1 && drops.length === 0 && stains.every((s) => t - s.t0 > LIFE + 1.2),
  };
}
interface Drop { x: number; y: number; vx: number; vy: number; s: number; delay: number; life: number; crown: boolean; seed: number }
interface Stain { x: number; y: number; w: number; lean: number; dir: number; t0: number; sats: [number, number][]; tone: number }
interface Mist { x: number; y: number; vx: number; vy: number; r: number; life: number; max: number; t0: number }
function drop(buf: Px, d: Drop, C: readonly number[]) {
  const x = d.x / PX, y = d.y / PX, sp = Math.hypot(d.vx, d.vy) || 1, ux = d.vx / sp, uy = d.vy / sp, tail = Math.min(6, sp * 0.008);
  if (tail >= 1) buf.line(x - ux * tail, y - uy * tail, x - ux, y - uy, d.s >= 2 ? C[2]! : C[3]!);
  if (d.s === 3) { buf.disc(x, y, 1.7, C[4]!); buf.disc(x, y, 1.15, C[1]!); buf.set(Math.round(x - 0.7), Math.round(y - 0.7), C[0]!); } else if (d.s === 2) {
    const px = Math.floor(x), py = Math.floor(y);
    buf.set(px, py, C[0]!);
    buf.set(px + 1, py, C[1]!);
    buf.set(px, py + 1, C[2]!);
    buf.set(px + 1, py + 1, C[3]!);
  } else buf.set(Math.floor(x), Math.floor(y), d.seed < 0.5 ? C[1]! : C[2]!);
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
  disc(cx: number, cy: number, r: number, c: number) {
    if (r <= 0.5) return this.set(Math.round(cx), Math.round(cy), c);
    const r2 = r * r;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const dx = x + 0.5 - cx; if (dx * dx + dy * dy <= r2) this.set(x, y, c); }
    }
  }
  alphaDisc(cx: number, cy: number, r: number, c: number, a: number) {
    if (a <= 0.01) return;
    const r2 = r * r;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const dx = x + 0.5 - cx; if (dx * dx + dy * dy <= r2) this.blend(x, y, c, a); }
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
function rgb(r: number, g: number, b: number) { return (255 << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
const BLOOD = ["#ff8a7a", "#f2384a", "#c71e33", "#931327", "#5e0c1b", "#350711"].map(hex);
const GRAVITY = 1900;
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
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
```
