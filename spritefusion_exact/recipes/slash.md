# Slash (slash.ts)

A blade's cut as light: a crescent smeared out in a few frames, its white-hot edge, an echo inside it, its tail sliding after its head and dissolving into a thread. Chain calls for combos.

Previews (animated WebP, 320 × 200 art pixels): Combo https://www.spritefusion.com/images/pixel-art-vfx/slash-slash.webp

Page: https://www.spritefusion.com/pixel-art-vfx/slash. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/slash.zip

## Recipe
- **Timeline:** one call is one cut. Times are for the defaults (`sweep` 0.06, `hold` 0.06, `trail` 0.24 s), with t from the call.
  - 0–0.06 s (sweep): the crescent smears out of nothing from `from` to `to`.
    - Its head moves on an exponential ease-out, 1 − 2^(−10·t/sweep), so most of the arc appears in the first two frames.
    - Its tail stays at the start.
    - A light follows the head.
  - 0.017 s: an echo (an inner, thinner, shorter copy) starts one frame behind.
  - 0.036 s (0.6 × sweep): a four-point glint pops at the end of the arc. It is full size within 0.05 s (with overshoot) and shrinks to nothing by 0.256 s.
  - 0.06 s, the cut lands:
    - 10 hot sparks fly off the end, on along the cut.
    - 16 motes of the blade's light are flung outward off the arc.
    - The camera shakes.
  - 0.06–0.12 s (hold): the whole crescent holds.
  - 0.12–0.36 s (trail): the tail slides round after the head (smoothstep) until they meet.
    - The crescent thins to 45% and steps down its ramp.
    - Its white edge is gone at 0.18 s.
    - Behind the tail, a 1 px thread is left along the arc, fading out by 0.56 s.
  - The echo holds 0.03 s and trails from 0.107 to 0.307 s.
  - The sweeping light fades out over 0–0.3 s.
  - `done()` turns true after 0.5 s, once particles are gone (about 0.6 s).
- **Layers:**
  - Everything is drawn on "front". "back" draws nothing.
  - Colour buffer, all opaque pixels: the echo, then the crescent and its thread, then the glint, then the sparks and motes.
  - Light buffer: additive glows that fall off as (1 − d/r)² × strength, with r in art px.
    - Along each crescent, every 0.3 rad: r 5 + W, in step 2 of its ramp, at 0.22 × (1 − age) × (position toward the head, 0 → 1).
    - The sweeping light at the head: r 40 × size, C3, at 0.5 × (1 − t/0.3).
    - The glint: r 4 + 2 × arm, C1, at 0.6.
    - Sparks: r 3, 0.45 × life left. Motes: r 3.1, 0.4 × life left.
- **Palette:**
  - `ramp` is 7 colours, from the cutting edge to the back. The default is steel: C0 #ffffff, C1 #e8f1ff, C2 #b8c9e8, C3 #62c8f4, C4 #3a8bd8, C5 #2c58aa, C6 #212f6b.
  - Crescent colour, per pixel:
    - The outer 22% of its thickness is C0 while age < 0.5. Age runs 0 → 1 over sweep + hold + trail, 0.36 s.
    - Elsewhere the step is round(q × (n − 1) × 0.75 + age × 2.4 − v × 0.8 + 0.4), clamped to the ramp, where n is the ramp's length (7, so q × 4.5). q runs from 0 at the outer edge to 1 at the inner, and v from 0 at the tail to 1 at the head.
    - So it is brightest at the edge and the head, and steps darker inward, toward the tail and with age. Each step is a flat band: no blending.
  - Echo: the same rule on the ramp without C0 (C1–C6, n = 6), so its edge is C1.
  - Thread: C5 (the second-to-last step).
  - Glint: centre #ffffff, arms C1, arm tips C3.
  - Motes: C2 or C3, with a tail at × 0.55.
  - Crescent glow: C2 (the echo's: C3).
  - Sparks: `sparkRamp` is 4 colours, default hot: #fff3a6, #ffe26b, #ff8a2a, #f2561d. The head is the 1st colour above 60% of life left, the 2nd above 30%, then the 3rd. The tail matches the head in the first half of life and is the 4th after.
- **Shapes and motion:** sizes are in art px (1 art px = 2 world units). Speeds are in world units/s. Fades are 4 × 4 Bayer ordered dither.
  - The arc: an ellipse around (`x`, `y`).
    - Radius 42 (`radius` 84 × size / 2), squashed to 0.6 vertically (`squash`), then rotated by `tilt` (−0.38 rad: rising to the right).
    - Angles are in screen space with y down: −π/2 is the top.
    - The default sweep goes from −2.55 to 0.95 rad: 3.5 rad, from the upper left, over the top, to the lower right, clockwise on screen. With `to` < `from` it sweeps the other way.
    - `facing` −1 mirrors it: each angle becomes π − angle, and the tilt is negated.
  - Crescent: the band from the arc's radius inward.
    - Its thickness at fraction v from tail to head is W × sin(π × v^2.2)^0.6, so it is pointed at both ends and thickest about 3/4 of the way to the head.
    - W = 12 (`width` 24 × size / 2), × (1 − 0.55 × tail progress).
    - Its last 40% toward the tail is dithered away.
  - Echo: radius × 33/42, thickness radius × 4.5/42. It starts 10% of the way into the arc and ends 15/350 of the arc short of the end (0.15 rad at the default 3.5 rad sweep).
  - Thread: 1 px dots on the arc, 0.5 px inside its radius, from the start of the arc to the tail. Opacity 0.7 × (0.4 → 1 toward the tail), dithered, fading out over trail + 0.2 s from the end of the hold.
  - Glint: a plus of 1 px arms up to 9 × size px long. Its 4 diagonal neighbours are added when an arm is ≥ 3 px, and the 4 pixels 2 px out diagonally when ≥ 6 px. A white centre.
  - Sparks: 10 (`sparks`) two-segment streaks from the arc's end, 0.3 W inside its radius.
    - Direction: along the sweep's tangent ±0.5 rad. Speed 300–800. Life 0.12–0.35 s.
    - 0.45 × 1900 units/s² gravity, drag 2.2/s (v −= v·drag·dt). They bounce on `ground` at × 0.45.
    - Streak length 1 + speed × 0.011 (max 9).
  - Motes: 16 short streaks from random points on the last 70% of the arc.
    - Flung straight out from the centre at 60–200, with −20 vertical. Drag 0.6. No gravity. Life 0.25–0.55 s.
    - Length (0.5 + speed × 0.013) × 0.6, at most 9.6. They dither out over their last 35%.
- **Feel:** one camera shake of 0.12 × size, when the cut lands (at `sweep`). No flash or ripple.

## Situations
- **Combo:** `slash({ x: 406, y: 234, radius: 64, squash: 0.55, tilt: -0.55, from: -2.7, to: 0.65, width: 17, seed: 3 })`, then 0.16 s later `slash({ x: 418, y: 226, radius: 64, squash: 0.55, tilt: 0.6, from: 0.55, to: -2.75, width: 17, seed: 4 })`: a character at x 250, with its feet on y 300, cuts down across its front, then back up the other way (`to` < `from`).

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `690` | The arc's centre x. |
| `y` | number (world units) | `530` | The arc's centre y. |
| `size` | number (multiplier) | `1` | Scales the radius, the width, the glint, the sweeping light and the shake. |
| `radius` | number (world units) | `84` | The arc's radius, × size. |
| `squash` | number (ratio) | `0.6` | The arc's vertical scale before tilting. 1 is a circle. |
| `tilt` | number (rad) | `-0.38` | The arc's rotation. Negative rises to the right. It is mirrored with `facing`. |
| `from` | number (rad) | `-2.55` | Where the cut starts on the arc. −π/2 is the top, and angles grow clockwise on screen. |
| `to` | number (rad) | `0.95` | Where it ends. Below `from`, it sweeps counter-clockwise. |
| `width` | number (world units) | `24` | The crescent's thickness at its thickest, × size. The echo's thickness follows `radius`, not `width`. |
| `facing` | number | `1` | −1 mirrors the cut horizontally, for a character facing left. |
| `sweep` | number (s) | `0.06` | How long the head takes to reach `to`. Sparks, motes and the shake come at its end. |
| `hold` | number (s) | `0.06` | How long the full crescent holds. The echo holds half this long. |
| `trail` | number (s) | `0.24` | How long the tail takes to catch the head. The echo's trail is 5/6 of this. |
| `sparks` | number (count) | `10` | Hot sparks thrown off the end. The 16 motes are fixed. |
| `ramp` | `readonly number[]` (7 × ABGR) | steel: `#ffffff #e8f1ff #b8c9e8 #62c8f4 #3a8bd8 #2c58aa #212f6b` | The blade's colours, from the cutting edge to the back (roles under Palette). |
| `sparkRamp` | `readonly number[]` (4 × ABGR) | hot: `#fff3a6 #ffe26b #ff8a2a #f2561d` | The sparks' colours as they cool. |
| `ground` | `number \| ((x: number) => number)` (world y) | none | The floor, where sparks bounce. |
| `seed` | number | `1` | Random seed for the sparks and motes. The cut's shape doesn't depend on it. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |

## Actor, methods and hooks
- `shake(trauma: number): void`: called once, when the cut lands (on the first update with t ≥ `sweep`), with 0.12 × size.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: slash.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  x?: number;
  y?: number;
  size?: number;
  radius?: number;
  squash?: number;
  tilt?: number;
  from?: number;
  to?: number;
  width?: number;
  facing?: number;
  sweep?: number;
  hold?: number;
  trail?: number;
  sparks?: number;
  ramp?: readonly number[];
  sparkRamp?: readonly number[];
  ground?: number | ((x: number) => number);
  seed?: number;
  shake?(trauma: number): void;
}
export default function slash(o: Options = {}) {
  const S = o.size ?? 1, F = o.facing ?? 1, C = o.ramp ?? STEEL, R = new Rng(o.seed ?? 1);
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const ps = new Particles(groundAt, o.sparkRamp ?? HOT);
  const RA = ((o.radius ?? 84) * S) / PX, a0 = o.from ?? -2.55, a1 = o.to ?? 0.95, ang = (a: number) => (F < 0 ? Math.PI - a : a);
  const A: Slash = { cx: (o.x ?? 690) / PX, cy: (o.y ?? 530) / PX, R: RA, sy: o.squash ?? 0.6, rot: (o.tilt ?? -0.38) * F, a0: ang(a0), a1: ang(a1), W: ((o.width ?? 24) * S) / PX, t0: 0, sweep: o.sweep ?? 0.06, hold: o.hold ?? 0.06, trail: o.trail ?? 0.24, ramp: C };
  const E: Slash = { ...A, R: RA * (33 / 42), W: RA * (4.5 / 42), a0: ang(a0 + (a1 - a0) * 0.1), a1: ang(a1 - (a1 - a0) * (0.15 / 3.5)), t0: 0.017, hold: A.hold * 0.5, trail: A.trail * (5 / 6), ramp: C.slice(1) };
  const end = slashEnd(A);
  let t = 0, landed = false;
  return {
    update(dt: number) {
      t += dt;
      if (!landed && t >= A.sweep) {
        landed = true;
        for (let i = 0; i < (o.sparks ?? 10); i++) {
          const a = Math.atan2(end.dy, end.dx) + R.range(-0.5, 0.5), sp = R.range(300, 800);
          ps.spawn(K.SPARK, end.x * PX, end.y * PX, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.12, 0.35));
        }
        shavings(ps, R, A, 16, C);
        o.shake?.(0.12 * S);
      }
      ps.update(dt);
    },
    draw(f: Frame, layer?: Layer) {
      if (layer === "back") return;
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      drawSlash(buf, light, E, t);
      drawSlash(buf, light, A, t);
      glint(buf, light, A, t, 9 * S, 0.22, C);
      if (t < 0.3) {
        const [x, y] = onArc(A.cx, A.cy, A.R - 4, A.sy, A.rot, A.a0 + (A.a1 - A.a0) * outExpo(t / A.sweep));
        light.glow(x, y, 40 * S, C[3]!, 0.5 * (1 - t / 0.3));
      }
      ps.draw(buf, light);
    },
    done: () => t > 0.5 && ps.list.length === 0,
  };
}
function onArc(cx: number, cy: number, R: number, sy: number, rot: number, a: number): [number, number] {
  const lx = Math.cos(a) * R, ly = Math.sin(a) * R * sy, c = Math.cos(rot), s = Math.sin(rot);
  return [cx + lx * c - ly * s, cy + lx * s + ly * c];
}
function crescent(buf: Px, light: Px, cx: number, cy: number, R: number, sy: number, rot: number, ta: number, L: number, W: number, ramp: readonly number[], age: number) {
  if (Math.abs(L) < 0.02 || W < 0.3) return;
  const dir = Math.sign(L), span = Math.abs(L), c = Math.cos(rot), s = Math.sin(rot), n = ramp.length, B = Math.ceil(R + 2);
  for (let py = Math.floor(cy - B); py <= Math.ceil(cy + B); py++)
    for (let px = Math.floor(cx - B); px <= Math.ceil(cx + B); px++) {
      const dx = px + 0.5 - cx, dy = py + 0.5 - cy;
      const lx = dx * c + dy * s, ly = (-dx * s + dy * c) / sy, r = Math.hypot(lx, ly);
      if (r > R + 0.5 || r < R - W - 1) continue;
      let u = (dir * (Math.atan2(ly, lx) - ta)) % TAU;
      if (u < 0) u += TAU;
      if (u > span) continue;
      const v = u / span, w = W * Math.pow(Math.sin(Math.PI * Math.pow(v, 2.2)), 0.6);
      if (w < 0.35) continue;
      const q = (R - r) / w;
      if (q < 0 || q > 1) continue;
      const f = Math.min(1, v / 0.4);
      if (f < 1 && f <= bayer(px, py)) continue;
      const ci = q < 0.22 && age < 0.5 ? 0 : Math.round(q * (n - 1) * 0.75 + age * 2.4 - v * 0.8 + 0.4);
      buf.set(px, py, ramp[Math.max(0, Math.min(n - 1, ci))]!);
    }
  for (let u = 0; u <= span; u += 0.3) {
    const [x, y] = onArc(cx, cy, R - W * 0.4, sy, rot, ta + dir * u);
    light.glow(x, y, 5 + W, ramp[2]!, 0.22 * (1 - age) * (u / span));
  }
}
interface Slash {
  cx: number;
  cy: number;
  R: number;
  sy: number;
  rot: number;
  a0: number;
  a1: number;
  W: number;
  t0: number;
  sweep: number;
  hold: number;
  trail: number;
  ramp: readonly number[];
}
function drawSlash(buf: Px, light: Px, s: Slash, t: number) {
  const u = t - s.t0;
  if (u < 0) return;
  const head = outExpo(u / s.sweep), tail = smooth(s.sweep + s.hold, s.sweep + s.hold + s.trail, u), span = s.a1 - s.a0;
  const age = clamp(u / (s.sweep + s.hold + s.trail));
  if (tail < 1) crescent(buf, light, s.cx, s.cy, s.R, s.sy, s.rot, s.a0 + span * tail, span * (head - tail), s.W * (1 - tail * 0.55), s.ramp, age);
  const th = 0.7 * (1 - clamp((u - s.sweep - s.hold) / (s.trail + 0.2)));
  if (tail > 0.02 && th > 0)
    for (let k = 0; k <= tail; k += 0.6 / (Math.abs(span) * s.R)) {
      const a = s.a0 + span * k;
      const [x, y] = onArc(s.cx, s.cy, s.R - 0.5, s.sy, s.rot, a);
      dot(buf, x, y, s.ramp[s.ramp.length - 2]!, th * (0.4 + 0.6 * k));
    }
}
function slashEnd(s: Slash) {
  const [x, y] = onArc(s.cx, s.cy, s.R - s.W * 0.3, s.sy, s.rot, s.a1), [x2, y2] = onArc(s.cx, s.cy, s.R - s.W * 0.3, s.sy, s.rot, s.a1 + Math.sign(s.a1 - s.a0) * 0.05);
  const l = Math.hypot(x2 - x, y2 - y) || 1;
  return { x, y, dx: (x2 - x) / l, dy: (y2 - y) / l };
}
function glint(buf: Px, light: Px, s: Slash, t: number, arm: number, life: number, C: readonly number[]) {
  const g = t - s.t0 - s.sweep * 0.6;
  if (g <= 0 || g >= life) return;
  const e = slashEnd(s);
  sparkle(buf, light, e.x, e.y, arm * outBack(Math.min(1, g / 0.05)) * (1 - g / life), C[1]!, C[3]!);
}
function shavings(ps: Particles, R: Rng, s: Slash, n: number, C: readonly number[]) {
  for (let i = 0; i < n; i++) {
    const a = s.a0 + (s.a1 - s.a0) * R.range(0.3, 1), [x, y] = onArc(s.cx, s.cy, s.R, s.sy, s.rot, a);
    const ox = x - s.cx, oy = y - s.cy, l = Math.hypot(ox, oy) || 1, sp = R.range(60, 200);
    ps.spawn(K.MOTE, x * PX, y * PX, (ox / l) * sp, (oy / l) * sp - 20, R.range(0.25, 0.55), C[2 + R.int(0, 1)]!, 0.6);
  }
}
function sparkle(buf: Px, light: Px, x: number, y: number, arm: number, c: number, tip: number) {
  const px = Math.round(x), py = Math.round(y), n = Math.round(arm);
  if (n < 1) return;
  for (let d = 1; d <= n; d++) {
    const cc = d > n * 0.6 ? tip : c;
    buf.set(px + d, py, cc);
    buf.set(px - d, py, cc);
    buf.set(px, py + d, cc);
    buf.set(px, py - d, cc);
  }
  if (n >= 3) for (const [dx, dy] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) buf.set(px + dx!, py + dy!, c);
  if (n >= 6) for (const [dx, dy] of [[2, 2], [2, -2], [-2, 2], [-2, -2]]) buf.set(px + dx!, py + dy!, tip);
  buf.set(px, py, WHITE);
  light.glow(x, y, 4 + n * 2, c, 0.6);
}
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function scale(c: number, k: number) {
  return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24);
}
const WHITE = hex("#ffffff");
const STEEL = ["#ffffff", "#e8f1ff", "#b8c9e8", "#62c8f4", "#3a8bd8", "#2c58aa", "#212f6b"].map(hex);
const HOT = ["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"].map(hex);
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
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function outExpo(t: number) { return t >= 1 ? 1 : 1 - Math.pow(2, -10 * clamp(t)); }
function outBack(t: number, s = 1.7) { const u = clamp(t) - 1; return 1 + (s + 1) * u * u * u + s * u * u; }
const GRAVITY = 1900;
const K = { SPARK: 0, MOTE: 1 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number }
class Particles {
  list: P[] = [];
  ground: (x: number) => number;
  sparks: readonly number[];
  constructor(ground: (x: number) => number, sparks: readonly number[]) { this.ground = ground; this.sparks = sparks; }
  spawn(k: K, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size });
  }
  update(dt: number) {
    const L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if ((p.life -= dt) <= 0) { L.splice(i, 1); continue; }
      if (p.k === K.SPARK) {
        p.vy += GRAVITY * 0.45 * dt;
        p.vx -= p.vx * 2.2 * dt;
        p.vy -= p.vy * 2.2 * dt;
        const g = this.ground(p.x), ny = p.y + p.vy * dt;
        p.x += p.vx * dt;
        if (p.vy > 0 && p.y <= g && ny >= g) { p.vy = -p.vy * 0.45; p.vx *= 0.7; p.y = g - 0.5; } else p.y = ny;
      } else { p.vx -= p.vx * 0.6 * dt; p.vy -= p.vy * 0.6 * dt; p.x += p.vx * dt; p.y += p.vy * dt; }
    }
  }
  draw(buf: Px, light: Px) {
    for (const p of this.list) {
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
      const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp;
      if (p.k === K.SPARK) {
        const S = this.sparks, head = k > 0.6 ? S[0]! : k > 0.3 ? S[1]! : S[2]!, len = Math.min(9, 1 + sp * 0.011);
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? head : S[S.length - 1]!);
        buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, head);
        light.glow(ax, ay, 3, head, 0.45 * k);
      } else {
        const len = Math.min(16, 0.5 + sp * 0.013) * p.size;
        if (k < 0.35 && bayer(px, py) > k / 0.35) continue;
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.35, ay - uy * len * 0.35, scale(p.col, 0.55));
        buf.line(ax - ux * len * 0.4, ay - uy * len * 0.4, ax, ay, p.col);
        light.glow(ax, ay, 2.5 + p.size, p.col, 0.4 * k);
      }
    }
  }
}
```
