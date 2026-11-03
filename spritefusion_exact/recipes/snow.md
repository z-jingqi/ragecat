# Snow (snow.ts)

Three depths of snow on a shifting breeze, a drift building along the ground, flakes landing and melting. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Snowfall https://www.spritefusion.com/images/pixel-art-vfx/snow-snowfall.webp

Page: https://www.spritefusion.com/pixel-art-vfx/snow. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/snow.zip

## Recipe
- **Timeline:** a loop. It needs no warm-up: when it's made, the flakes are scattered from the area's top down to the ground, so it's full on the first frame. Landed flakes pile up over the first seconds (the preview starts 3 s in).
  - The breeze is wind(t) = `wind` + 16·noise(0.3t): 1-D value noise, so with the default 14 it wanders between −2 and 30 units/s and changes over a few seconds.
  - One flake's cycle:
    - It enters 0–40 units above the area's top, at an x in [area.x − 60, area.x + area.w].
    - It falls at 26, 52 or 86 units/s (far, mid or near, × 0.75–1.25).
    - Its x moves at wind(t)·(0.5, 0.9 or 1.3) + cos(f·t + phase)·sway, with sway 8, 16 or 30 units/s × 0.6–1.2 and f 0.8–1.8 rad/s.
    - Past 40 units beyond the area's right edge it wraps back by area.w + 100. There is no wrap on the left.
    - Crossing a 360-unit area takes about 14 s far, 7 s mid and 4 s near.
  - Landing:
    - Far flakes vanish when they reach the ground. 40% of them (chosen per flake) vanish earlier, once within 30 units above it, as if beyond the ground's edge.
    - Mid and near flakes stop 1 unit above the ground and lie there for 1–2.6 s, dithering out over their last 0.8 s, then re-enter at the top.
  - `stop()`: flakes stop re-entering, and `done()` turns true once every flake has fallen or melted.
- **Layers:**
  - "back": the far flakes, then the drift, then the mid flakes (falling and lying).
  - "front": the near crystals (falling and lying).
  - Everything is opaque pixels in the colour buffer (the melting ones are Bayer-dithered). Nothing goes in the light buffer.
- **Palette:** fixed in the file (`FLAKE` and `DRIFT`; there is no option). Light to dark.
  - Flakes:
    - #ffffff (W): crystal centres, the mid flakes' top-left pixel, lying flakes.
    - #e3edff (w): crystal arms, the mid flakes' top-right and bottom-left pixels, the left pixel of a lying near flake.
    - #9fb1e6 (b): crystal tips, the mid flakes' bottom-right pixel, half the far flakes, the right pixel of a lying near flake.
    - #6c7cb8 (d): the other half of the far flakes.
  - Drift:
    - #e9f0ff: its top pixel.
    - #c3cff0: its body.
    - #8e9ccc: the shaded ground line under it.
- **Shapes and motion:** sizes are in art px.
  - Counts: 260 far, 150 mid and 30 near flakes, × `density`.
  - Far flake: 1 pixel, #6c7cb8 or #9fb1e6 (chosen per flake).
  - Mid flake: 2 × 2: W at the top left, w at the top right and bottom left, b at the bottom right.
  - Near flake: a hand-drawn crystal centred on the flake (pixel maps in `CRYSTAL`).
    - Two thirds of them turn: they alternate every 1/3 s between two 7 × 7 frames. One has 3 px arms and 2 px diagonals around a white centre pixel; the other has diagonals reaching the corners and a white 5 px plus at its centre.
    - One third are a still 5 × 5 diamond.
  - Lying flake: one W pixel on the row above the ground. A near one is 3 px wide (w, W, b).
  - Drift (when `drift` is on): every art column from 30 px left of the area to 30 px right of it gets a stack 1–5 px tall on the row above the ground. The height is 1 + round(1.6 + 1.4·noise(0.09x) + 0.6·noise(0.31x)), with x in art px. The top pixel is #e9f0ff and the rest #c3cff0. The ground row is #8e9ccc, and 30% of columns get one more #8e9ccc pixel below it. It is static, with no time term.
- **Feel:** no hooks. It asks nothing of the camera or screen.

## Situations
- **Snowfall:** `snow({ area: { x: 0, y: 0, w: 640, h: 360 }, ground: 300 })`: three depths of snow on a shifting breeze over the whole screen. A drift lies along a floor at y 300, and flakes land on it and melt.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 300, y: 230, w: 680, h: 370 }` | Where it snows. Flakes enter above its top across its width (from 60 units left of it), and the drift spans it. |
| `ground` | `number \| ((x: number) => number)` (world units) | the area's bottom (`y + h`) | The ground's y, a constant or per x: where flakes land and the drift lies. |
| `density` | number (multiplier) | `1` | Scales the flake counts (260 far, 150 mid, 30 near). |
| `wind` | number (world units/s) | `14` | The breeze's mean (positive blows right). It gusts ±16 around it and pushes far flakes 0.5×, mid 0.9× and near 1.3×. |
| `drift` | boolean | `true` | Draw the snow lying along the ground. |
| `seed` | number | `1` | Random seed. |

## Actor, methods and hooks
- `stop()`: call it to end the snowfall. Falling flakes finish, lying ones melt, none re-enter, then `done()` turns true.
- It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: snow.ts

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
  wind?: number;
  drift?: boolean;
  seed?: number;
}
export default function snow(o: Options = {}) {
  const A = o.area ?? { x: 300, y: 230, w: 680, h: 370 }, X0 = A.x, X1 = A.x + A.w, TOP = A.y;
  const groundAt = (x: number) => (o.ground === undefined ? A.y + A.h : typeof o.ground === "number" ? o.ground : o.ground(x));
  const R = new Rng(o.seed ?? 1), D = o.density ?? 1, WIND = o.wind ?? 14;
  const flakes: Flake[] = [];
  const reset = (f: Flake, top: boolean) => {
    f.x = R.range(X0 - 60, X1);
    f.y = top ? TOP - R.range(0, 40) : R.range(TOP, groundAt(f.x));
    f.vy = FALL[f.layer]! * R.range(0.75, 1.25);
    f.sway = SWAY[f.layer]! * R.range(0.6, 1.2);
    f.f = R.range(0.8, 1.8);
    f.ph = R.range(0, TAU);
    f.rest = -1;
    f.kind = R.int(0, 2);
  };
  for (const [layer, n] of [[0, 260], [1, 150], [2, 30]] as const)
    for (let i = 0; i < Math.round(n * D); i++) {
      const f: Flake = { x: 0, y: 0, vy: 0, sway: 0, f: 0, ph: 0, layer, rest: -1, kind: 0 };
      reset(f, false);
      flakes.push(f);
    }
  let t = 0, stopped = false;
  const again = (i: number) => (stopped ? flakes.splice(i, 1) : reset(flakes[i]!, true));
  const draw = (buf: Px, layer: number) => {
    for (const f of flakes) {
      if (f.layer !== layer) continue;
      const x = f.x / PX, y = f.y / PX;
      if (f.rest >= 0) {
        const a = Math.min(1, f.rest / 0.8), fy = groundAt(f.x) / PX;
        dot(buf, x, fy - 1, FLAKE.W, a);
        if (layer === 2) { dot(buf, x - 1, fy - 1, FLAKE.w, a); dot(buf, x + 1, fy - 1, FLAKE.b, a); }
        continue;
      }
      if (layer === 0) dot(buf, x, y, hash(Math.floor(f.ph * 100), 1) < 0.5 ? FLAKE.d : FLAKE.b);
      else if (layer === 1) {
        dot(buf, x, y, FLAKE.W);
        dot(buf, x + 1, y, FLAKE.w);
        dot(buf, x, y + 1, FLAKE.w);
        dot(buf, x + 1, y + 1, FLAKE.b);
      } else blitC(buf, CRYSTAL[f.kind === 2 ? 2 : Math.floor(t * 3 + f.ph) & 1]!, x, y);
    }
  };
  return {
    update(dt: number) {
      t += dt;
      const wind = WIND + 16 * noise(t * 0.3, 5);
      for (let i = flakes.length - 1; i >= 0; i--) {
        const f = flakes[i]!;
        if (f.rest >= 0) { if ((f.rest -= dt) < 0) again(i); continue; }
        f.y += f.vy * dt;
        f.x += (wind * (0.5 + f.layer * 0.4) + Math.cos(t * f.f + f.ph) * f.sway) * dt;
        const g = groundAt(f.x);
        if (f.y >= g - 1) { if (f.layer === 0) again(i); else { f.y = g - 1; f.rest = R.range(1, 2.6); } continue; }
        if (f.layer === 0 && f.y > g - 30 && hash(Math.floor(f.ph * 1000)) < 0.4) { again(i); continue; }
        if (f.x > X1 + 40) f.x -= X1 - X0 + 100;
      }
    },
    draw(fr: Frame, layer?: Layer) {
      const buf = new Px(fr, fr.color);
      if (layer !== "front") {
        draw(buf, 0);
        if (o.drift ?? true)
          for (let x = Math.floor(X0 / PX) - 30; x < Math.ceil(X1 / PX) + 30; x++) {
            const fy = Math.round(groundAt(x * PX) / PX), h = 1 + Math.round(1.6 + noise(x * 0.09, 11) * 1.4 + noise(x * 0.31, 12) * 0.6);
            for (let r = 0; r < h; r++) buf.set(x, fy - 1 - r, r === h - 1 ? DRIFT[0]! : DRIFT[1]!);
            buf.set(x, fy, DRIFT[2]!);
            if (hash(x, 13) < 0.3) buf.set(x, fy + 1, DRIFT[2]!);
          }
        draw(buf, 1);
      }
      if (layer !== "back") draw(buf, 2);
    },
    stop() { stopped = true; },
    done: () => stopped && flakes.length === 0,
  };
}
interface Flake { x: number; y: number; vy: number; sway: number; f: number; ph: number; layer: number; rest: number; kind: number }
const FALL = [26, 52, 86], SWAY = [8, 16, 30];
const FLAKE = { W: hex("#ffffff"), w: hex("#e3edff"), b: hex("#9fb1e6"), d: hex("#6c7cb8") };
const CRYSTAL = [
  sprite(["...b...", ".b.w.b.", "..bwb..", "bwwWwwb", "..bwb..", ".b.w.b.", "...b..."], FLAKE),
  sprite(["b..b..b", ".b.w.b.", "..wWw..", "bwWWWwb", "..wWw..", ".b.w.b.", "b..b..b"], FLAKE),
  sprite(["..b..", ".bwb.", "bwWwb", ".bwb.", "..b.."], FLAKE),
];
const DRIFT = [hex("#e9f0ff"), hex("#c3cff0"), hex("#8e9ccc")];
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > (BAYER[((py & 3) << 2) | (px & 3)]! + 0.5) / 16) buf.set(px, py, c);
}
interface Sprite { w: number; h: number; data: Uint32Array }
function sprite(rows: string[], pal: Record<string, number>): Sprite {
  const h = rows.length, w = Math.max(...rows.map((r) => r.length)), data = new Uint32Array(w * h);
  rows.forEach((r, y) => [...r].forEach((ch, x) => ch !== "." && (data[y * w + x] = pal[ch] ?? 0)));
  return { w, h, data };
}
function blitC(buf: Px, s: Sprite, cx: number, cy: number) {
  const x0 = Math.round(cx - s.w / 2), y0 = Math.round(cy - s.h / 2);
  for (let y = 0; y < s.h; y++)
    for (let x = 0; x < s.w; x++) { const c = s.data[y * s.w + x]!; if (c >>> 24) buf.set(x0 + x, y0 + y, c); }
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
}
const TAU = Math.PI * 2;
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return hash(i, seed) * 2 - 1 + (hash(i + 1, seed) - hash(i, seed)) * 2 * u;
}
```
