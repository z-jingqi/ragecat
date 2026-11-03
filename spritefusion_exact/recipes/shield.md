# Shield (shield.ts)

A true hemisphere of hex cells forming cell by cell over the character. Rounds spark off it and ripple through it before it breaks up into shards.

Previews (animated WebP, 320 × 200 art pixels): Dome https://www.spritefusion.com/images/pixel-art-vfx/shield-hex-dome.webp

Page: https://www.spritefusion.com/pixel-art-vfx/shield. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/shield.zip

## Recipe
- **Timeline:** sizes in art px, positions and speeds in world units. Rates "per update" assume 60 updates a second.
  - 0.05–0.73 s, build: hex cells appear from the ground up. A cell appears at 0.05 + 0.6 × (latitude / 90°) + 0–0.08 s and flashes for 0.1 s as it locks in. Until 0.75 s, 3 sparkles per update climb its front. The ground ring fades in over 0–0.15 s.
  - Until `hold` (2.75 s), it holds, a shimmer band sweeping over it.
  - Default rounds hit at 1.05, 1.38, 1.62 and 2.05 s. Each tracer flies in over the 0.12 s before its hit. Each hit sends a ripple over the dome for 0.7 s.
  - From `hold`, break-up: each cell goes at `hold` + 0–0.55 s, flashing for its last 0.08 s. The ring fades over `hold` − 0.05 → `hold` + 0.45. Until `hold` + 0.6, 4 stars or motes per update drift up off its surface.
  - `done()`: after `hold` + 0.6 once the particles are gone, about 4 s.
- **Layers:**
  - "back": the far half of the dome, its cell edges only (50% dither, step 4). No light.
  - "front": the near half (cell edges and a sparse dithered fill, so the character shows through), the front half of the ground ring, tracers, sparks, glints, sparkles and motes.
  - Light buffer, additive glows falling off as (1 − d/r)² × strength:
    - On the near side, one pixel in 32 (where `(x·7 + y·3) & 31 == 0`): r 7, step 3, 0.15 + 0.4 × ripple.
    - Over the whole dome: r 1.3 × radius, centred at half its height, step 3, 0.22 × the ring's opacity.
    - Each hit: r 40 shrinking to 22, step 2, 0.9 × k² over 0.18 s.
    - Each tracer r 8 (#ffd65a, 0.5); each spark r 3; each star r 3 + 2·arm; each mote r 2.5 + size; the hit glint r 7.
  - Colour buffer: opaque pixels. Partial opacity is a 4 × 4 Bayer ordered dither (a pixel is set when its opacity beats the threshold), never blended.
- **Palette:**
  - `colors`, light to dark, default the ice ramp: #ffffff, #dcfbff, #a6ecff, #62c8f4, #3a8bd8, #2c58aa, #212f6b, #151a3d. Steps 1–4 are used, plus white.
  - "rim" below is 1 − |z| on the sphere: 0 where the dome faces you, 1 at its outline.
  - White: cell edges while a cell flashes in or out, or under a strong ripple (> 0.6). Star centres.
  - Step 1: edges under a ripple (> 0.2), in the sweep band or near the outline (rim > 0.75). The fill while flashing or under a ripple (> 0.5).
  - Step 2: edges at rim 0.4–0.75. The ground ring. Hit lights.
  - Step 3: edges where it faces you (rim < 0.4). The fill near the outline (rim > 0.7). Its glows.
  - Step 4: the rest of the fill. The far side's edges.
  - Sparkles and motes pick white, step 1 or step 2.
  - Fixed warm colours, whatever `colors`:
    - Sparks: #fff3a6, then #ffe26b, then #ff8a2a as they cool; tail #f2561d.
    - Hit glint: #fff3a6 rimmed #f2561d.
    - Tracer: head pixel #fffbe8, body #ffd65a, tail #ff8a2a.
- **Shapes and motion:**
  - Dome: a hemisphere of `radius` (40 px) standing on the feet. For each art pixel of the half-disc above the feet, at (u, v) from its centre over the radius:
    - The sphere point: z = ±√(1 − u² − v²) (+ near side, − far side), longitude atan2(u, z), latitude asin(v).
    - A pointy-top hex grid of unit cells looked up at (longitude × 6.2, latitude × 7.13): about 11 cells across and 7 rows up, narrowing toward the outline. e is the distance to the cell's centre, 1 at its edge.
    - Each cell's own random h (0–1) staggers its appearing and its going.
    - Near side, edge pixels (e > 0.8): solid while flashing, under a ripple (> 0.2) or in the sweep band; otherwise dithered at 0.5 + rim (faint where it faces you, solid at the outline).
    - Near side, fill (e ≤ 0.8): dithered at 0.08 + 0.3 × rim² (0.7 while flashing), plus 0.6 × ripple.
    - Far side: edge pixels (e > 0.82) at 50%.
  - Sweep: the band where |frac(0.35 × longitude + 0.45 × latitude − 0.55 × t) − 0.5| < 0.04, sliding diagonally across.
  - Ripple from a hit: a ring running over the sphere from the hit point at 3.2 rad/s, 0.22 rad wide, strength 1 − age/0.7. Inside it, within 0.5 rad of the hit, 0.4 of that.
  - Ground ring: an ellipse rx = radius, ry = 3, 1 px thick, step 2, its lower (front) half only.
  - Tracer: flies from 170 px right and 30 px up of the hit point to it in 0.12 s (always from the right). Three pieces: a tail from (14, −2.5) to (6, −1) px behind the head, a body from there to the head, the head pixel.
  - Hit (world units/s):
    - A glint: a disc of radius 1.8 shrinking to 0.9 over 0.05 s.
    - 14 sparks fanned rightward over ±1 rad (0.6 rad more upward for hits above latitude 0.9), at 200–600 with 80 more upward, life 0.1–0.35 s.
    - Sparks fall at 855 units/s² with drag 2.2 (v −= v·2.2·dt), bouncing off `ground` at × 0.45 (vx × 0.7). Drawn as two-segment streaks along their motion, 1 + speed × 0.011 px long (max 9).
  - Build sparkles: stars on the front at a random longitude (±90°), at latitude min(t/0.65 × 90°, 1.5 rad). Velocity ±20 sideways, −30..+10 vertical; life 0.2–0.4 s; size 0.6–1.2.
  - Break-up: half stars, half motes, anywhere on longitude ±1.4 rad, latitude 0–1.4 rad. ±30 sideways, rising 20–80; life 0.3–0.7 s; size 0.6–1.4.
  - Stars: a twinkling plus, arms round(size × twinkle) px (twinkle 0.6–1 at 8–12 rad/s), tips at 75% brightness, diagonal corners once arms reach 3, a white centre. Under size 1 a single twinkling pixel. Drag 1.6, rising 10 units/s².
  - Motes: a streak along their motion, (0.5 + 0.013 × speed) × size px long (max 16), its back half at 55% brightness. Drag 0.6. They dither out over their last 35%.
- **Feel:** a camera shake of 0.18 at each hit. No flash, darkening or ripple hook.

## Situations
- **Dome:** `shield({ actor: player, ground: 300 })`: a hex dome builds over the player, takes four rounds that spark off it and ripple through it, and breaks up after 2.75 s.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `actor` | `Actor` | none | Who it's round: the dome stands on its feet and follows them. |
| `x` | number (world units) | `600` | The dome's centre x on the ground, without an actor. |
| `y` | number (world units) | `600` | The ground y under the dome, without an actor. |
| `radius` | number (art px) | `40` | The dome's radius. |
| `hold` | number (s) | `2.75` | When it starts breaking up. Pass `Infinity` to hold it until `drop()`. |
| `colors` | `string[]` (hex, light to dark) | the ice ramp above | Its ramp. Steps 1–4 are used, so at least 5. |
| `hits` | `{ t: number; lon: number; lat: number }[]` | 4 hits: `{ t: 1.05, lon: 0.75, lat: 0.55 }`, `{ t: 1.38, lon: 1.05, lat: 0.95 }`, `{ t: 1.62, lon: 0.5, lat: 0.25 }`, `{ t: 2.05, lon: 0.9, lat: 1.2 }` | Scripted rounds, each with a tracer from the right: when (s), longitude (rad, 0 facing you, + to the right) and latitude (rad, 0 at the ground, π/2 at the top). `[]` for none. |
| `ground` | `number \| ((x: number) => number)` (world y) | none | Where sparks bounce. Without it they fall through. |
| `seed` | number | `1` | Random seed. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |

## Actor, methods and hooks
- `actor`: `feet(): [number, number]` (world units), read every update and draw: the dome's centre on the ground, so it moves with the character.
- `hit(x: number, y: number)`: a round hitting the dome now at (x, y) in world units, mapped onto its surface (no tracer). On the next update it sparks, glints, lights up, shakes and sends a ripple through the dome. Use it with `hits: []` for your own bullets.
- `drop()`: breaks it up now (the break-up above starts at the current time).
- `shake(trauma: number)`: 0.18 at each hit, scripted or from `hit()`.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: shield.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { feet(): [number, number] }
export interface Options {
  actor?: Actor;
  x?: number;
  y?: number;
  radius?: number;
  hold?: number;
  colors?: string[];
  hits?: { t: number; lon: number; lat: number }[];
  ground?: number | ((x: number) => number);
  seed?: number;
  shake?(trauma: number): void;
}
export default function shield(o: Options = {}) {
  const R = new Rng(o.seed ?? 1), ground = (x: number) => groundAt(o.ground, x);
  const ps = new Particles(R, ground), lights: Light[] = [];
  const actor = o.actor ?? { feet: () => [o.x ?? 600, o.y ?? 600] as [number, number] };
  const RAD = o.radius ?? 40, C = o.colors ? o.colors.map(hex) : ICE, S3 = Math.sqrt(3), SPARKS = [WHITE, C[1]!, C[2]!];
  let GONE = o.hold ?? 2.75, t = 0;
  const hits = (o.hits ?? HITS).map((h) => ({ ...h, traced: true, done: false }));
  const centre = (): [number, number] => { const [x, y] = actor.feet(); return [x / PX, y / PX]; };
  const surf = (lon: number, lat: number): [number, number] => {
    const [cx, cy] = centre();
    return [cx + RAD * Math.sin(lon) * Math.cos(lat), cy - RAD * Math.sin(lat)];
  };
  const cell = (gx: number, gy: number): [number, number] => {
    const q = (S3 / 3) * gx - gy / 3, r = (2 / 3) * gy, s = -q - r;
    let rq = Math.round(q), rr = Math.round(r);
    const rs = Math.round(s), dq = Math.abs(rq - q), dr = Math.abs(rr - r), ds = Math.abs(rs - s);
    if (dq > dr && dq > ds) rq = -rr - rs;
    else if (dr > ds) rr = -rq - rs;
    const hx = S3 * (rq + rr / 2), hy = 1.5 * rr, dx = Math.abs(gx - hx), dy = gy - hy;
    return [(rq * 73856093) ^ (rr * 19349663), Math.max(dx, Math.abs(dx / 2 + (dy * S3) / 2), Math.abs(dx / 2 - (dy * S3) / 2)) / (S3 / 2)];
  };
  const ripple = (lon: number, lat: number) => {
    let hit = 0;
    for (const hh of hits) {
      const k = t - hh.t;
      if (k < 0 || k > 0.7 || !hh.done) continue;
      const d = Math.acos(clamp(Math.cos(lat) * Math.cos(hh.lat) * Math.cos(lon - hh.lon) + Math.sin(lat) * Math.sin(hh.lat), -1, 1)), front = k * 3.2;
      if (Math.abs(d - front) < 0.22) hit = Math.max(hit, 1 - k / 0.7);
      else if (d < front && d < 0.5) hit = Math.max(hit, 0.4 * (1 - k / 0.7));
    }
    return hit;
  };
  function dome(buf: Px, light: Px, far: boolean) {
    const [cx, cy] = centre(), GRID = 6.2;
    for (let y = Math.floor(cy - RAD - 1); y <= cy; y++)
      for (let x = Math.floor(cx - RAD - 1); x <= Math.ceil(cx + RAD + 1); x++) {
        const u = (x + 0.5 - cx) / RAD, v = (cy - y - 0.5) / RAD, q = u * u + v * v;
        if (q > 1 || v < 0) continue;
        const z = Math.sqrt(1 - q) * (far ? -1 : 1), lon = Math.atan2(u, z), lat = Math.asin(clamp(v, 0, 1));
        const [id, e] = cell(lon * GRID, lat * GRID * 1.15);
        const h = hash(id & 0xffff, id >>> 16), appear = 0.05 + (lat / (Math.PI / 2)) * 0.6 + h * 0.08, gone = GONE + h * 0.55;
        if (t < appear || t > gone) continue;
        const age = t - appear, end = gone - t, rim = 1 - Math.abs(z), hit = ripple(lon, lat);
        const flash = age < 0.1 || end < 0.08;
        const sweep = Math.abs(frac(lon * 0.35 + lat * 0.45 - t * 0.55) - 0.5) < 0.04;
        if (far) { if (e > 0.82 && bayer(x, y) < 0.5) buf.set(x, y, C[4]!); continue; }
        if (e > 0.8) {
          const c = flash || hit > 0.6 ? WHITE : hit > 0.2 || sweep || rim > 0.75 ? C[1]! : rim > 0.4 ? C[2]! : C[3]!;
          if (flash || hit > 0.2 || sweep || 0.5 + rim > bayer(x, y)) buf.set(x, y, c);
        } else {
          const a = (flash ? 0.7 : 0.08 + 0.3 * rim * rim) + hit * 0.6;
          if (a > bayer(x, y)) buf.set(x, y, flash || hit > 0.5 ? C[1]! : rim > 0.7 ? C[3]! : C[4]!);
        }
        if (((x * 7 + y * 3) & 31) === 0) light.glow(x, y, 7, C[3]!, 0.15 + 0.4 * hit);
      }
    const a = smooth(0, 0.15, t) * (1 - smooth(GONE - 0.05, GONE + 0.45, t));
    if (!far && a > 0) ringE(buf, cx, cy, RAD, 3, 1, C[2]!, a, (ang) => Math.sin(ang) > 0);
    if (!far) light.glow(cx, cy - RAD * 0.5, RAD * 1.3, C[3]!, 0.22 * a);
  }
  return {
    update(dt: number) {
      t += dt;
      if (t < 0.75)
        for (let i = 0; i < 3; i++) {
          const [x, y] = surf(R.range(-Math.PI / 2, Math.PI / 2), Math.min((t / 0.65) * (Math.PI / 2), 1.5));
          ps.spawn(K.STAR, x * PX, y * PX, R.range(-20, 20), R.range(-30, 10), R.range(0.2, 0.4), R.pick(SPARKS), R.range(0.6, 1.2));
        }
      for (const h of hits)
        if (t >= h.t && !h.done) {
          h.done = true;
          const [x, y] = surf(h.lon, h.lat);
          o.shake?.(0.18);
          lights.push({ x: x * PX, y: y * PX, r: 80, color: C[2]!, k: 0.9, life: 0.18, max: 0.18 });
          ps.spawn(K.GLINT, x * PX, y * PX, 0, 0, 0.05, WHITE, 1.8);
          for (let j = 0; j < 14; j++) {
            const a = R.range(-1, 1) + (h.lat > 0.9 ? -0.6 : 0), sp = R.range(200, 600);
            ps.spawn(K.SPARK, x * PX, y * PX, Math.cos(a) * sp, Math.sin(a) * sp - 80, R.range(0.1, 0.35));
          }
        }
      if (t > GONE - 0.05 && t < GONE + 0.6)
        for (let i = 0; i < 4; i++) {
          const [x, y] = surf(R.range(-1.4, 1.4), R.range(0, 1.4));
          ps.spawn(R.chance(0.5) ? K.STAR : K.MOTE, x * PX, y * PX, R.range(-30, 30), -R.range(20, 80), R.range(0.3, 0.7), R.pick(SPARKS), R.range(0.6, 1.4));
        }
      ps.update(dt);
      stepLights(lights, dt);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") dome(buf, light, true);
      if (layer === "back") return;
      dome(buf, light, false);
      for (const h of hits) {
        const k = (h.t - t) / 0.12;
        if (!h.traced || k < 0 || k > 1) continue;
        const [x1, y1] = surf(h.lon, h.lat), x = x1 + 170 * k, y = y1 - 30 * k;
        seg(buf, x + 14, y - 2.5, x + 6, y - 1, TRACER_TAIL);
        seg(buf, x + 6, y - 1, x, y, TRACER);
        buf.set(Math.floor(x), Math.floor(y), TRACER_CORE);
        light.glow(x, y, 8, TRACER, 0.5);
      }
      ps.draw(buf, light);
      drawLights(light, lights);
    },
    hit(x: number, y: number) {
      const [cx, cy] = centre();
      const lat = Math.asin(clamp((cy - y / PX) / RAD, 0, 1));
      hits.push({ t, lon: Math.asin(clamp((x / PX - cx) / RAD / Math.max(0.05, Math.cos(lat)), -1, 1)), lat, traced: false, done: false });
    },
    drop() { GONE = Math.min(GONE, t); },
    done: () => t > GONE + 0.6 && ps.list.length === 0,
  };
}
const HITS = [{ t: 1.05, lon: 0.75, lat: 0.55 }, { t: 1.38, lon: 1.05, lat: 0.95 }, { t: 1.62, lon: 0.5, lat: 0.25 }, { t: 2.05, lon: 0.9, lat: 1.2 },];
const TRACER = hex("#ffd65a"), TRACER_TAIL = hex("#ff8a2a"), TRACER_CORE = hex("#fffbe8");
function groundAt(g: number | ((x: number) => number) | undefined, x: number) { return g === undefined ? Infinity : typeof g === "number" ? g : g(x); }
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
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function scale(c: number, k: number) {
  return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24);
}
const WHITE = hex("#ffffff");
const HOT = hex("#fff3a6");
const YELLOW = hex("#ffe26b");
const ORANGE = hex("#ff8a2a");
const DEEP_ORANGE = hex("#f2561d");
const ICE = ["#ffffff", "#dcfbff", "#a6ecff", "#62c8f4", "#3a8bd8", "#2c58aa", "#212f6b", "#151a3d"].map(hex);
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
function smooth(a: number, b: number, x: number) { const t = (x - a) / (b - a); return x <= a ? 0 : x >= b ? 1 : t * t * (3 - 2 * t); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function frac(x: number) { return x - Math.floor(x); }
const K = { STAR: 0, MOTE: 1, GLINT: 2, SPARK: 3 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  ground: (x: number) => number;
  constructor(R: Rng, ground: (x: number) => number) { this.R = R; this.ground = ground; }
  spawn(k: K, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100 });
  }
  update(dt: number) {
    this.t += dt;
    const L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if ((p.life -= dt) <= 0) { L.splice(i, 1); continue; }
      switch (p.k) {
        case K.STAR:
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.6 * dt + 10 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case K.MOTE:
          p.vx -= p.vx * 0.6 * dt;
          p.vy -= p.vy * 0.6 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case K.GLINT:
          break;
        case K.SPARK: {
          p.vy += 1900 * 0.45 * dt;
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt;
          const g = this.ground(p.x), ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) { p.vy = -p.vy * 0.45; p.vx *= 0.7; p.y = g - 0.5; } else p.y = ny;
          break;
        }
      }
    }
  }
  draw(buf: Px, light: Px) { for (const p of this.list) this.drawOne(p, buf, light); }
  private drawOne(p: P, buf: Px, light: Px) {
    const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
    switch (p.k) {
      case K.STAR: {
        const tw = 0.6 + 0.4 * Math.sin(this.t * (8 + (p.seed % 5)) + p.seed);
        if (p.size < 1) { if (tw * k > 0.25) buf.set(px, py, tw > 0.8 ? WHITE : p.col); light.glow(ax, ay, 3, p.col, 0.4 * k * tw); break; }
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
        break;
      }
      case K.MOTE: {
        const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(16, 0.5 + sp * 0.013) * p.size;
        if (k < 0.35 && bayer(px, py) > k / 0.35) break;
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.35, ay - uy * len * 0.35, scale(p.col, 0.55));
        buf.line(ax - ux * len * 0.4, ay - uy * len * 0.4, ax, ay, p.col);
        light.glow(ax, ay, 2.5 + p.size, p.col, 0.4 * k);
        break;
      }
      case K.GLINT: {
        const r = p.size * (0.5 + k * 0.5);
        buf.disc(ax, ay, r + 0.8, DEEP_ORANGE);
        buf.disc(ax, ay, r, p.col === WHITE ? HOT : p.col);
        light.glow(ax, ay, p.size * 4, p.col, 0.6 * k);
        break;
      }
      case K.SPARK: {
        const hot = k > 0.6 ? HOT : k > 0.3 ? YELLOW : ORANGE;
        const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(9, 1 + sp * 0.011);
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? hot : DEEP_ORANGE);
        buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, hot);
        light.glow(ax, ay, 3, hot, 0.45 * k);
        break;
      }
    }
  }
}
interface Light { x: number; y: number; r: number; color: number; k: number; life: number; max: number }
function stepLights(lights: Light[], dt: number) { for (let i = lights.length - 1; i >= 0; i--) if ((lights[i]!.life -= dt) <= 0) lights.splice(i, 1); }
function drawLights(light: Px, lights: Light[]) {
  for (const l of lights) { const k = l.life / l.max; light.glow(l.x / PX, l.y / PX, (l.r / PX) * (0.55 + 0.45 * k), l.color, l.k * k * k); }
}
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
function seg(buf: Px, x0: number, y0: number, x1: number, y1: number, c: number, a = 1) {
  const n = Math.max(1, Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2));
  for (let i = 0; i <= n; i++) { const x = x0 + ((x1 - x0) * i) / n, y = y0 + ((y1 - y0) * i) / n; dot(buf, x, y, c, a); }
}
function ringE(buf: Px, cx: number, cy: number, rx: number, ry: number, thick: number, c: number, a = 1, keep?: (ang: number) => boolean) {
  const n = Math.ceil(Math.max(rx, ry) * TAU * 1.3);
  for (let j = 0; j < n; j++) {
    const ang = (j / n) * TAU;
    if (keep && !keep(ang)) continue;
    const ca = Math.cos(ang), sa = Math.sin(ang);
    for (let o = -thick / 2; o <= thick / 2; o += 0.5) dot(buf, cx + ca * (rx + o), cy + sa * (ry + o * (ry / Math.max(1, rx))), c, a);
  }
}
```
