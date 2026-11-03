# Rain (rain.ts)

Slanted rain in three depths, crowns of droplets and rings on the wet ground, a mist along the floor. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Rain https://www.spritefusion.com/images/pixel-art-vfx/rain-rain.webp

Page: https://www.spritefusion.com/pixel-art-vfx/rain. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/rain.zip

## Recipe
- **Timeline:** a loop. It needs no warm-up: when it's made, the drops are scattered from 200 units above the area's top down to the ground, so it's full on the first frame (the preview starts 3 s in).
  - One drop's cycle:
    - It enters 0–200 units above the area's top, at an x in [area.x, area.x + area.w + 180] whatever the slant.
    - It falls in a straight line along (slant, 1), normalised, at 760, 1050 or 1450 units/s (far, mid or near, ±10%).
    - Far drops vanish 10–140 units above the ground, as if behind it, without splashing.
    - Mid and near drops hit the ground. If the hit is within 40 units of the area horizontally, it leaves a splash (always for near drops, 60% of the time for mid ones) and droplets (3 for near, 0–2 for mid).
    - The drop then re-enters at the top.
  - Splashes last 0.4 s and droplets 0.18–0.32 s.
  - `stop()`: drops stop re-entering, and `done()` turns true once the last drops and droplets are gone.
- **Layers:**
  - "back": the far streaks, then the mid streaks, then the wet ground strip (mist and glints), then the splashes and droplets.
  - "front": the near streaks only, the long bright ones that pass in front of characters.
  - Everything is opaque pixels in the colour buffer, faded by 4 × 4 Bayer dithering. Nothing goes in the light buffer.
- **Palette:** fixed in the file (the `C` object; there is no option). Light to dark:
  - #d6e5ff: near drop heads, droplets.
  - #9ab0e0: mid drop heads, ground glints, splashes for their first 30%.
  - #6f86bd: near drop bodies.
  - #5f74ab: mid drop bodies, splashes after their first 30%.
  - #56659a: far drop heads.
  - #4b5a8c: the mist.
  - #38446e: far drop bodies.
- **Shapes and motion:** sizes are in art px.
  - Counts: 230 far, 120 mid and 34 near drops, × `density`.
  - Drop: a 1 px Bresenham line along the fall direction, 3, 6 or 12 px long (far, mid, near). The trailing 60% is in the body colour and the leading 40% (the lower end) in the head colour. With the default slant of −0.22, the direction is (−0.215, 0.977): leaning left as it falls.
  - Splash: the lower half of an ellipse (points with sin ≥ −0.2) on the ground under the hit, 1–2 px thick. It grows with rx = 1 + 5√u (1 to 6 px) and ry = rx/4. Its dithered opacity is 1 − u, over u = 0..1 in 0.4 s.
  - Droplets: single pixels thrown up from 1 unit above the ground, with vx −90 to +70 and vy −110 to −230 units/s, under 1900 units/s² of gravity. They are removed when they fall below the ground or their life ends.
  - Wet ground: over every art column from 30 px left of the area to 30 px right of it.
    - Mist: 9 px above the ground row, dithered #4b5a8c at opacity m·0.32·(1 − row/9). m = (noise(0.06x + 0.5t) + 0.5·noise(0.15x − 0.8t) + 1)/2.5 is 1-D value noise over art-px x, in two layers drifting opposite ways (about 8 and 5 px/s).
    - Glints: a #9ab0e0 pixel on the ground row on about 4% of columns, re-rolled 8 times a second.
- **Feel:** no hooks. It asks nothing of the camera or screen, and reads best over a darkened scene.

## Situations
- **Rain:** `rain({ area: { x: 0, y: 0, w: 640, h: 360 }, ground: 300 })`: slanted rain in three depths over the whole screen, splashing and misting on a floor at y 300.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 300, y: 230, w: 680, h: 370 }` | Where it rains. Drops enter above its top and are spread across its width (plus 180 units to the right). |
| `ground` | `number \| ((x: number) => number)` (world units) | the area's bottom (`y + h`) | The ground's y, a constant or per x: where drops splash and the mist and glints lie. |
| `density` | number (multiplier) | `1` | Scales the drop counts (230 far, 120 mid, 34 near). |
| `slant` | number | `-0.22` | Horizontal travel per unit fallen. Negative leans left. |
| `seed` | number | `1` | Random seed. |

## Actor, methods and hooks
- `stop()`: call it to end the rain. The drops in the air finish falling and none re-enter, then `done()` turns true.
- It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: rain.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  area?: { x: number; y: number; w: number; h: number };
  ground?: number | ((x: number) => number);
  density?: number;
  slant?: number;
  seed?: number;
}
export default function rain(o: Options = {}) {
  const A = o.area ?? { x: 300, y: 230, w: 680, h: 370 }, X0 = A.x, X1 = A.x + A.w, TOP = A.y;
  const groundAt = (x: number) => (o.ground === undefined ? A.y + A.h : typeof o.ground === "number" ? o.ground : o.ground(x));
  const R = new Rng(o.seed ?? 1), D = o.density ?? 1;
  const DX = o.slant ?? -0.22, DL = Math.hypot(DX, 1), ux = DX / DL, uy = 1 / DL;
  const drops: Drop[] = [];
  const splashes: { x: number; t: number }[] = [];
  const bits: { x: number; y: number; vx: number; vy: number; life: number }[] = [];
  const reset = (d: Drop, top: boolean) => {
    d.y = top ? TOP - R.range(0, 200) : R.range(TOP - 200, groundAt(d.x));
    d.x = R.range(X0, X1 + 180);
    d.sp = SPEED[d.layer]! * R.range(0.9, 1.1);
    d.stop = groundAt(d.x) - R.range(10, 140);
  };
  for (const [layer, n] of [[0, 230], [1, 120], [2, 34]] as const)
    for (let i = 0; i < Math.round(n * D); i++) { const d: Drop = { x: 0, y: 0, layer, sp: 0, stop: 0 }; reset(d, false); drops.push(d); }
  let t = 0, stopped = false;
  const again = (i: number) => (stopped ? drops.splice(i, 1) : reset(drops[i]!, true));
  const draw = (buf: Px, layer: number) => {
    const L = LEN[layer]!, c = BODY[layer]!, h = HEAD[layer]!;
    for (const d of drops) {
      if (d.layer !== layer) continue;
      const x = d.x / PX, y = d.y / PX;
      buf.line(x - ux * L, y - uy * L, x - ux * L * 0.4, y - uy * L * 0.4, c);
      buf.line(x - ux * L * 0.4, y - uy * L * 0.4, x, y, h);
    }
  };
  return {
    update(dt: number) {
      t += dt;
      for (let i = drops.length - 1; i >= 0; i--) {
        const d = drops[i]!;
        d.x += ux * d.sp * dt;
        d.y += uy * d.sp * dt;
        if (d.layer === 0 && d.y > d.stop) again(i);
        else if (d.y >= groundAt(d.x)) {
          if (d.x > X0 - 40 && d.x < X1 + 40) {
            if (d.layer === 2 || R.chance(0.6)) splashes.push({ x: d.x, t });
            for (let k = 0; k < (d.layer === 2 ? 3 : R.int(0, 2)); k++) bits.push({ x: d.x, y: groundAt(d.x) - 1, vx: R.range(-90, 70), vy: -R.range(110, 230), life: R.range(0.18, 0.32) });
          }
          again(i);
        }
      }
      for (let i = bits.length - 1; i >= 0; i--) {
        const b = bits[i]!;
        if ((b.life -= dt) <= 0 || b.y > groundAt(b.x)) { bits.splice(i, 1); continue; }
        b.vy += 1900 * dt;
        b.x += b.vx * dt;
        b.y += b.vy * dt;
      }
      for (let i = splashes.length - 1; i >= 0; i--) if (t - splashes[i]!.t > 0.4) splashes.splice(i, 1);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color);
      if (layer !== "front") {
        draw(buf, 0);
        draw(buf, 1);
        for (let x = Math.floor(X0 / PX) - 30; x < Math.ceil(X1 / PX) + 30; x++) {
          const fy = Math.round(groundAt(x * PX) / PX), m = (noise(x * 0.06 + t * 0.5, 3) + noise(x * 0.15 - t * 0.8, 4) * 0.5 + 1) / 2.5;
          if (hash(x, Math.floor(t * 8)) < 0.04) dot(buf, x, fy, C.midH);
          for (let r = 0; r < 9; r++) dot(buf, x, fy - r, C.mist, m * 0.32 * (1 - r / 9));
        }
        for (const s of splashes) {
          const u = (t - s.t) / 0.4, rx = 1 + 5 * Math.sqrt(u);
          splash(buf, s.x / PX, groundAt(s.x) / PX, rx, rx * 0.25, u < 0.3 ? C.midH : C.mid, 1 - u);
        }
        for (const b of bits) dot(buf, b.x / PX, b.y / PX, C.nearH);
      }
      if (layer !== "back") draw(buf, 2);
    },
    stop() { stopped = true; },
    done: () => stopped && drops.length === 0 && bits.length === 0,
  };
}
interface Drop { x: number; y: number; layer: number; sp: number; stop: number }
const C = { far: hex("#38446e"), farH: hex("#56659a"), mid: hex("#5f74ab"), midH: hex("#9ab0e0"), near: hex("#6f86bd"), nearH: hex("#d6e5ff"), mist: hex("#4b5a8c") };
const SPEED = [760, 1050, 1450], LEN = [3, 6, 12], BODY = [C.far, C.mid, C.near], HEAD = [C.farH, C.midH, C.nearH];
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
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
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > (BAYER[((py & 3) << 2) | (px & 3)]! + 0.5) / 16) buf.set(px, py, c);
}
function splash(buf: Px, cx: number, cy: number, rx: number, ry: number, c: number, a: number) {
  const n = Math.ceil(Math.max(rx, ry) * TAU * 1.3);
  for (let j = 0; j < n; j++) {
    const ang = (j / n) * TAU, ca = Math.cos(ang), sa = Math.sin(ang);
    if (sa < -0.2) continue;
    for (let o = -0.5; o <= 0.5; o += 0.5) dot(buf, cx + ca * (rx + o), cy + sa * (ry + o * (ry / Math.max(1, rx))), c, a);
  }
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
  int(a: number, b: number) { return Math.floor(this.range(a, b + 1)); }
  chance(p: number) { return this.next() < p; }
}
const TAU = Math.PI * 2;
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return hash(i, seed) * 2 - 1 + (hash(i + 1, seed) - hash(i, seed)) * 2 * u;
}
```
