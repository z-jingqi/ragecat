# Sparkle (sparkle.ts)

Four-point flares twinkling: a big glint turning and pulsing among small ones, or small glints catching here and there. For treasure, secrets and anything shiny.

Previews (animated WebP, 320 × 200 art pixels): Glint https://www.spritefusion.com/images/pixel-art-vfx/sparkle-glint.webp, Twinkle https://www.spritefusion.com/images/pixel-art-vfx/sparkle-small-glints.webp

Page: https://www.spritefusion.com/pixel-art-vfx/sparkle. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/sparkle.zip

## Recipe
- **Timeline:** sizes are in art px, speeds in world units/s. The flare lasts 2.5 s, and the last particles are gone by about 3.2 s.
  - Main flare:
    - 0–0.25 s: it pops in on an outBack curve (overshoot 2), peaking 13% oversize at 0.14 s.
    - It turns at 0.7 rad/s the whole time.
    - It pulses +35% at 0.9 s and +30% at 1.5 s: pulse = 1 + 0.35·e^(−(t − 0.9)²/0.01) + 0.3·e^(−(t − 1.5)²/0.01), each bump about 0.2 s wide.
    - 1.9–2.5 s: it shrinks to nothing (smoothstep). The twinkle pixels and the big glow fade with it.
  - Satellite flares: flare i (0-based) appears at 0.1 + 0.17i + 0–0.08 s and lives 0.35–0.6 s. With 11, the last appears at about 1.8 s.
  - Particles: 35% chance of one per update until 2.3 s, which is about 48 at 60 updates/s.
  - `done()` is true after 2.5 s once the particles are gone.
- **Layers:**
  - Everything is drawn on "front". `draw(frame, "back")` draws nothing.
  - Light buffer, additive, each glow falling off as (1 − d/r)² × strength:
    - Each flare adds a glow of r 4 + 1.4L in its c1 at 0.5, and one of r 2 + 0.5L in white at 0.4.
    - The main flare adds one more, of r 34·fade in warm[2] at 0.35·fade.
    - Particles add r 3 + 2·arm at 0.5·life·twinkle (r 3 at 0.4·life·twinkle for single pixels).
  - The colour buffer gets only opaque pixels, faded by 4 × 4 Bayer dithering.
- **Palette:** two ramps, light to dark.
  - `warm` (7): #ffffff, #fffbe2, #fff0a6, #ffd862, #f6aa3c, #cf722b, #7e3c1f.
    - warm[1]: half the particles and the coloured twinkle pixels.
    - warm[2]: c1 of the main flare and the warm satellites, and the big glow.
    - warm[3]: their c2.
  - `cool` (8): #ffffff, #dcfbff, #a6ecff, #62c8f4, #3a8bd8, #2c58aa, #212f6b, #151a3d.
    - cool[2]: c1 of the icy satellites, and a quarter of the particles.
    - cool[3]: their c2.
  - The other steps are never drawn.
  - Ray cores, centres and the rest of the twinkles and particles are #ffffff.
- **Shapes and motion:**
  - Flare (the main one and the satellites): 8 rays at 45° steps, rotated by its angle, each plotted every 0.5 px.
    - Four long rays are L long. Each is white for its first 30%, c1 to 65%, then c2. When L > 4 px, each has a 1 px c1 border on both sides over its first 22% (a 3 px wide core).
    - Four diagonal rays are 0.42L long: c1 for their first half, then c2.
    - Every ray is opaque to 70% of its length, then Bayer-dithered out to about 14% at the tip.
    - The centre pixel is white. A flare with L < 0.8 px is skipped.
  - Main flare: at (x, y), with L = size × pop-in × fade × pulse. At the default size of 19 the long rays are 19 px and the diagonals 8 px. Its angle is 0.7t, its c1 warm[2] and its c2 warm[3].
  - Satellites (`flares`, 11 by default): each at a random angle, 9–32 px from the centre (× 0.85 vertically).
    - L is 4–8.5 px × sin(πu)^0.7 over its life u.
    - Its angle is 0.4 + spin·u, with spin ±2 rad.
    - 35% are icy (cool[2]/cool[3]); the rest use warm[2]/warm[3].
  - Twinkle pixels: 26 fixed spots, 6–46 px from the centre at hashed angles (× 0.8 vertically). Each is lit with chance 0.3·fade, re-rolled 12 times a second. Each is a single pixel in white or warm[1].
  - Particles: born within 40 px horizontally and 34 px vertically of the centre, in an ellipse.
    - They start with vx ±10 and vy −14 to +6, under drag 1.6/s and a 10 units/s² rise, and live 0.5–0.9 s.
    - Colours: warm[1] (50%), cool[2] (25%) or white (25%).
    - Each has a twinkle, tw = 0.6 + 0.4 sin(t·(8 to 13) + phase).
    - With size 0.4–2.2: under 1 it is a single pixel, white when tw > 0.8, shown while tw·life > 0.25. Otherwise it is a plus with arms of max(1, round(size·tw·min(1, 3·life))) px. Its end pixels are at 75% brightness, it gains 4 diagonal pixels at (±1, ±1) when arms ≥ 3, and its centre is white.
- **Feel:** none. No shake, no flash, no hooks.

## Situations
- **Glint:** `sparkle({ x: 320, y: 180 })`: a big glint turning and pulsing among small ones.
- **Twinkle:** `sparkle({ x: 280, y: 140, size: 9, flares: 3, seed: 3 })`, then 0.35 s apart `sparkle({ x: 400, y: 200, size: 9, flares: 3, seed: 4 })`, `sparkle({ x: 340, y: 80, size: 9, flares: 3, seed: 5 })` and `sparkle({ x: 220, y: 220, size: 9, flares: 3, seed: 6 })`: small glints catching here and there, one after another.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `740` | The centre. |
| `y` | number (world units) | `480` | The centre. |
| `size` | number (art px) | `19` | The main flare's long-ray length (its diagonals are 0.42×). The satellites, twinkles and particles don't scale with it. |
| `warm` | `string[]` (7 × `#rrggbb`) | `["#ffffff", "#fffbe2", "#fff0a6", "#ffd862", "#f6aa3c", "#cf722b", "#7e3c1f"]` | The main flare's ramp, light to dark. Steps 1–3 are used. |
| `cool` | `string[]` (8 × `#rrggbb`) | `["#ffffff", "#dcfbff", "#a6ecff", "#62c8f4", "#3a8bd8", "#2c58aa", "#212f6b", "#151a3d"]` | The icy satellites' and some particles' ramp. Steps 2–3 are used. |
| `flares` | number | `11` | How many satellite flares there are. They appear 0.17 s apart. |
| `seed` | number | `1` | Random seed (the satellites and the particles). |

## Actor, methods and hooks
- None: it takes no actor, has no methods beyond update, draw and done, and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: sparkle.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options { x?: number; y?: number; size?: number; warm?: string[]; cool?: string[]; flares?: number; seed?: number }
export default function sparkle(o: Options = {}) {
  const H = (o.warm ?? ["#ffffff", "#fffbe2", "#fff0a6", "#ffd862", "#f6aa3c", "#cf722b", "#7e3c1f"]).map(hex);
  const I = (o.cool ?? ["#ffffff", "#dcfbff", "#a6ecff", "#62c8f4", "#3a8bd8", "#2c58aa", "#212f6b", "#151a3d"]).map(hex);
  const SIZE = o.size ?? 19;
  const R = new Rng(o.seed ?? 1);
  const X = o.x ?? 740, Y = o.y ?? 480, cx = X / PX, cy = Y / PX;
  const ps = new Particles(R);
  const sats = Array.from({ length: o.flares ?? 11 }, (_, i) => {
    const a = R.range(0, TAU), d = R.range(9, 32);
    return { x: cx + Math.cos(a) * d, y: cy + Math.sin(a) * d * 0.85, t0: 0.1 + i * 0.17 + R.range(0, 0.08), dur: R.range(0.35, 0.6), L: R.range(4, 8.5), spin: R.range(-2, 2), ice: R.chance(0.35) };
  });
  let t = 0;
  return {
    update(dt: number) {
      t += dt;
      if (t < 2.3 && R.chance(0.35)) {
        const a = R.range(0, TAU), d = R.range(4, 40);
        ps.spawn(X + Math.cos(a) * d * 2, Y + Math.sin(a) * d * 1.7, R.range(-10, 10), R.range(-14, 6), R.range(0.5, 0.9), R.chance(0.5) ? H[1]! : R.chance(0.5) ? I[2]! : WHITE, R.range(0.4, 2.2));
      }
      ps.update(dt);
    },
    draw(f: Frame, layer?: Layer) {
      if (layer === "back") return;
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      const grow = outBack(clamp(t / 0.25), 2), gone = 1 - smooth(1.9, 2.5, t);
      const pulse = 1 + 0.35 * Math.exp(-((t - 0.9) ** 2) / 0.01) + 0.3 * Math.exp(-((t - 1.5) ** 2) / 0.01);
      flare(buf, light, cx, cy, SIZE * grow * gone * pulse, t * 0.7, H[2]!, H[3]!);
      if (grow * gone > 0.1) light.glow(cx, cy, 34 * gone, H[2]!, 0.35 * gone);
      for (const s of sats) {
        const u = (t - s.t0) / s.dur;
        if (u <= 0 || u >= 1) continue;
        flare(buf, light, s.x, s.y, s.L * Math.sin(u * Math.PI) ** 0.7, s.spin * u + 0.4, s.ice ? I[2]! : H[2]!, s.ice ? I[3]! : H[3]!);
      }
      for (let i = 0; i < 26; i++) {
        const fr = Math.floor(t * 12) + i * 3;
        if (hash(fr, i) >= 0.3 * gone) continue;
        const a = hash(i, 1) * TAU, d = 6 + hash(i, 2) * 40;
        dot(buf, cx + Math.cos(a) * d, cy + Math.sin(a) * d * 0.8, hash(fr, 5) < 0.5 ? WHITE : H[1]!);
      }
      ps.draw(buf, light);
    },
    done: () => t > 2.5 && ps.list.length === 0,
  };
}
function flare(buf: Px, light: Px, x: number, y: number, L: number, ang: number, c1: number, c2: number, a = 1) {
  if (L < 0.8) return;
  for (let i = 0; i < 8; i++) {
    const diag = i % 2 === 1, an = ang + (i * TAU) / 8, len = diag ? L * 0.42 : L, ca = Math.cos(an), sa = Math.sin(an);
    for (let d = 0; d <= len; d += 0.5) {
      const u = d / len, c = diag ? (u < 0.5 ? c1 : c2) : u < 0.3 ? WHITE : u < 0.65 ? c1 : c2;
      dot(buf, x + ca * d, y + sa * d, c, a * (u < 0.7 ? 1 : 1 - (u - 0.7) / 0.35));
      if (!diag && u < 0.22 && L > 4) { dot(buf, x + ca * d - sa, y + sa * d + ca, c1, a); dot(buf, x + ca * d + sa, y + sa * d - ca, c1, a); }
    }
  }
  dot(buf, x, y, WHITE, a);
  light.glow(x, y, 4 + L * 1.4, c1, 0.5 * a);
  light.glow(x, y, 2 + L * 0.5, WHITE, 0.4 * a);
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
const WHITE = hex("#ffffff");
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
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function outBack(t: number, s = 1.7) { const u = clamp(t) - 1; return 1 + (s + 1) * u * u * u + s * u * u; }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
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
      p.vx -= p.vx * 1.6 * dt;
      p.vy -= p.vy * 1.6 * dt + 10 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }
  draw(buf: Px, light: Px) {
    for (const p of this.list) {
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
      const tw = 0.6 + 0.4 * Math.sin(this.t * (8 + (p.seed % 5)) + p.seed);
      if (p.size < 1) { if (tw * k > 0.25) buf.set(px, py, tw > 0.8 ? WHITE : p.col); light.glow(ax, ay, 3, p.col, 0.4 * k * tw); continue; }
      const arm = Math.max(1, Math.round(p.size * tw * Math.min(1, k * 3))), tip = scale(p.col, 0.75);
      for (let d = 1; d <= arm; d++) {
        const cc = d === arm && arm > 1 ? tip : p.col;
        buf.set(px + d, py, cc);
        buf.set(px - d, py, cc);
        buf.set(px, py + d, cc);
        buf.set(px, py - d, cc);
      }
      if (arm >= 3) for (let j = 0; j < 4; j++) buf.set(px + (j & 1 ? -1 : 1), py + (j & 2 ? -1 : 1), tip);
      buf.set(px, py, WHITE);
      light.glow(ax, ay, 3 + arm * 2, p.col, 0.5 * k * tw);
    }
  }
}
```
