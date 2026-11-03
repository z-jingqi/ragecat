# Embers (embers.ts)

Embers, cinders and ash rising off a fire below, with a warm glow breathing on the ground. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Embers https://www.spritefusion.com/images/pixel-art-vfx/embers-embers.webp

Page: https://www.spritefusion.com/pixel-art-vfx/embers. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/embers.zip

## Recipe
- **Timeline:**
  - Warm-up: it starts empty and fills in about 4 s; the preview is recorded from 3.5 s, so pre-run 3.5 s of updates to open on it full.
  - Spawning: spawns are chances per `update()` call, tuned for a fixed 1/60 s step. Each call makes 2 tries at 0.8 × density for a spark (about 96/s), one at 0.22 × density for a cinder (about 13/s, 30% of them big) and one at 0.05 × density for an ash flake (about 3/s).
  - Lifetimes: a spark lives 2.2–4.2 s, cooling from yellow to orange to red, and rises 135–250 units in all (median 190). A cinder lives 3.5–6 s and an ash flake 5–7 s. Both fade in over the first 1/8 of their life and out over the last 1/3.
  - `stop()`: spawning ends and live particles finish their lives (up to 7 s). The heat band dims with the spark count: full above 60 sparks, scaled by count / 60 below that. `done()` turns true once every particle is gone.
- **Layers:** "back" holds the heat along the bottom edge: a dark-red dither in the colour buffer and broad warm glows in the light buffer. "front" holds the cinders, the ash and the sparks, in that order: opaque pixels in the colour buffer plus a small glow per spark and per cinder in the light buffer. Ash has no light. Partial opacity is never alpha: it is a 4 × 4 Bayer dither (pixel drawn when opacity > threshold).
- **Palette:**
  - Fire, light to dark: #fff3a6 (hottest cinder core), #ffe26b (young sparks, hot cinder cores), #ff8a2a (mid-life sparks, cinder cores and rims, every cinder glow), #f2561d (cooled cinder rims), #c9281f (dying sparks).
  - Heat band, light to dark: #c9281f (rows 0–3 above the edge), #8a1f17 (rows 4–9), #4f1a13 (rows 10–21).
  - Ash: #5a5160, #3a3442.
  - Heat light: #ff7832.
- **Shapes and motion:**
  - Spark: 1 opaque art px, plus a light glow of radius 3 px in its own colour at 0.3 × life fraction. While over half its life remains it flickers yellow/orange (yellow when sin(22t + 3 × seed) > −0.2); then it turns orange, and red in its last 20%.
    - It spawns at x − 40 to x + w + 40, from 10 units above to 40 below the bottom edge, with vx ±40 and vy −90 to −240 units/s.
    - Each step it gets vy += (−60 + 40 sin(3t + seed)) dt (buoyancy) and vx += 90 cos(2.3t + seed) dt (wiggle), both damped at 1.6/s. It settles near 37 units/s upward and weaves about 15 units sideways.
  - Cinder: spawns across x to x + w, 10 units below the edge. Its vy is a constant −50 to −110 units/s and its vx starts at ±20. The vx wanders (noise × 60 units/s², damped 0.8/s) and it sways a further 10 units/s by sine.
    - Flicker fl = 0.65 + 0.35 × noise(9t), so 0.3–1, and heat = life fraction × fl. The core is #fff3a6 above 0.55, #ffe26b above 0.35, otherwise #ff8a2a. The rim is #ff8a2a above 0.45, otherwise #f2561d.
    - Small (70%): a core px with a rim px under it at 60% opacity, and a glow of radius 5 px in #ff8a2a at 0.35 × opacity × fl.
    - Big (30%): a plus sign (core plus 4 rim px) and a glow of radius 9 px at 0.45 × opacity × fl.
  - Ash: 2 px, #5a5160 with #3a3442 below it. The lower px shifts 0 or 1 px sideways with sin(3t + seed), so the flake tumbles. Same motion as a cinder but vy −30 to −60 units/s, always small, with the cinder's dithered fade.
  - Heat: every art column from 30 px left of the area to 30 px right of it gets 22 rows above the bottom edge, dithered at 0.6 × h × (1 − row / 22). h = 0.7 + 0.3 × noise(0.02x + 0.6t), so it breathes along the edge. Every 24th column adds a light glow of radius 80 px in #ff7832 at 0.26 × h, centred 6 px below the edge.
  - Light glows have a quadratic falloff ((1 − d/r)²) and are added with saturation.
- **Feel:** asks nothing of the camera, and reads best over a dark scene.

## Situations
- **Embers:** `embers({ area: { x: 0, y: 0, w: 640, h: 360 } })`: sparks, glowing cinders and ash rising off a fire's edge at the bottom of the screen, its heat glowing behind.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 300, y: 230, w: 680, h: 420 }` | Its bottom edge (y + h) is the fire's edge they rise from, and x to x + w is their spread. Its top is not used: particles rise until their life ends. |
| `density` | number | `1` | Multiplies the three spawn chances per update. |
| `heat` | boolean | `true` | The dark-red dither band and the warm light glows along the bottom edge ("back"). |
| `seed` | number | `1` | Seeds the random spawns. |

## Actor, methods and hooks
- `stop()`: call it when the fire goes out. Nothing new spawns and the live embers rise out within 7 s, then `done()` turns true. It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: embers.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options { area?: { x: number; y: number; w: number; h: number }; density?: number; heat?: boolean; seed?: number }
export default function embers(o: Options = {}) {
  const A = o.area ?? { x: 300, y: 230, w: 680, h: 420 }, X0 = A.x, X1 = A.x + A.w, BOTTOM = A.y + A.h;
  const R = new Rng(o.seed ?? 1), D = o.density ?? 1;
  const sparks: Spark[] = [], cinders: Cinder[] = [];
  const spark = (x: number, y: number, vx: number, vy: number, life: number) => sparks.push({ x, y, vx, vy, life, max: life, seed: R.next() * 100 });
  const cinder = (x: number, vx: number, vy: number, life: number, s: number, ash: boolean) => cinders.push({ x, y: BOTTOM + 10, vx, vy, life, max: life, s, seed: R.next() * 100, ash });
  let t = 0, stopped = false;
  return {
    update(dt: number) {
      t += dt;
      if (!stopped) {
        for (let i = 0; i < 2; i++) if (R.chance(0.8 * D)) spark(R.range(X0 - 40, X1 + 40), R.range(BOTTOM - 10, BOTTOM + 40), R.range(-40, 40), -R.range(90, 240), R.range(2.2, 4.2));
        if (R.chance(0.22 * D)) cinder(R.range(X0, X1), R.range(-20, 20), -R.range(50, 110), R.range(3.5, 6), R.chance(0.3) ? 2 : 1, false);
        if (R.chance(0.05 * D)) cinder(R.range(X0, X1), R.range(-20, 20), -R.range(30, 60), R.range(5, 7), 1, true);
      }
      for (let i = cinders.length - 1; i >= 0; i--) {
        const c = cinders[i]!;
        if ((c.life -= dt) <= 0) { cinders.splice(i, 1); continue; }
        c.vx += noise(t * 0.9 + c.seed, 1) * 60 * dt;
        c.vx -= c.vx * 0.8 * dt;
        c.x += c.vx * dt + Math.sin(t * 2 + c.seed) * 10 * dt;
        c.y += c.vy * dt;
      }
      for (let i = sparks.length - 1; i >= 0; i--) {
        const p = sparks[i]!;
        if ((p.life -= dt) <= 0) { sparks.splice(i, 1); continue; }
        p.vy += (-60 + Math.sin(t * 3 + p.seed) * 40) * dt;
        p.vx += Math.cos(t * 2.3 + p.seed) * 90 * dt;
        p.vx -= p.vx * 1.6 * dt;
        p.vy -= p.vy * 1.6 * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
      }
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front" && (o.heat ?? true)) {
        const y1 = BOTTOM / PX, fade = stopped ? Math.min(1, sparks.length / 60) : 1;
        for (let x = Math.floor(X0 / PX) - 30; x < Math.ceil(X1 / PX) + 30; x++) {
          const h = (0.7 + 0.3 * noise(x * 0.02 + t * 0.6, 7)) * fade;
          for (let r = 0; r < 22; r++) dot(buf, x, y1 - 1 - r, DARK[r < 4 ? 0 : r < 10 ? 1 : 2]!, 0.6 * h * (1 - r / 22));
          if (x % 24 === 0) light.glow(x, y1 + 6, 80, HEAT, 0.26 * h);
        }
      }
      if (layer === "back") return;
      for (const c of cinders) {
        const k = c.life / c.max, x = c.x / PX, y = c.y / PX, a = Math.min(1, k * 3) * Math.min(1, (1 - k) * 8);
        if (c.ash) { dot(buf, x, y, ASH[0]!, a); dot(buf, x + (Math.sin(t * 3 + c.seed) > 0 ? 1 : 0), y + 1, ASH[1]!, a); continue; }
        const fl = 0.65 + 0.35 * noise(t * 9 + c.seed, 2), hot = k * fl;
        const core = hot > 0.55 ? HOT : hot > 0.35 ? YELLOW : ORANGE, rim = hot > 0.45 ? ORANGE : DEEP_ORANGE;
        if (c.s === 2) {
          dot(buf, x - 1, y, rim, a);
          dot(buf, x + 1, y, rim, a);
          dot(buf, x, y - 1, rim, a);
          dot(buf, x, y + 1, rim, a);
          dot(buf, x, y, core, a);
          light.glow(x, y, 9, ORANGE, 0.45 * a * fl);
        } else { dot(buf, x, y, core, a); dot(buf, x, y + 1, rim, a * 0.6); light.glow(x, y, 5, ORANGE, 0.35 * a * fl); }
      }
      for (const p of sparks) {
        const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX;
        const c = k > 0.5 ? (Math.sin(t * 22 + p.seed * 3) > -0.2 ? YELLOW : ORANGE) : k > 0.2 ? ORANGE : RED;
        buf.set(Math.floor(ax), Math.floor(ay), c);
        light.glow(ax, ay, 3, c, 0.3 * k);
      }
    },
    stop() { stopped = true; },
    done: () => stopped && sparks.length === 0 && cinders.length === 0,
  };
}
interface Spark { x: number; y: number; vx: number; vy: number; life: number; max: number; seed: number }
interface Cinder extends Spark { s: number; ash: boolean }
const HOT = hex("#fff3a6"), YELLOW = hex("#ffe26b"), ORANGE = hex("#ff8a2a"), DEEP_ORANGE = hex("#f2561d"), RED = hex("#c9281f");
const DARK = [RED, hex("#8a1f17"), hex("#4f1a13")], ASH = [hex("#5a5160"), hex("#3a3442")], HEAT = hex("#ff7832");
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
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > (BAYER[((py & 3) << 2) | (px & 3)]! + 0.5) / 16) buf.set(px, py, c);
}
function hex(h: string) { const v = parseInt(h.slice(1), 16); return (255 << 24) | ((v & 255) << 16) | (v & 0xff00) | ((v >> 16) & 255); }
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
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return hash(i, seed) * 2 - 1 + (hash(i + 1, seed) - hash(i, seed)) * 2 * u;
}
```
