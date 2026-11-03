# Muzzle Flash (muzzle-flash.ts)

A shot's star and jet with a white-hot core and a dark rim, hot sparks, smoke curling off the barrel, and a casing tumbling out to lie on the ground. One call per shot.

Previews (animated WebP, 320 × 200 art pixels): Burst https://www.spritefusion.com/images/pixel-art-vfx/muzzle-flash-smg-burst.webp

Page: https://www.spritefusion.com/pixel-art-vfx/muzzle-flash. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/muzzle-flash.zip

## Recipe
- **Timeline:** one call is one shot. Values are for `size` 1, with S = `size`.
  - The flash frames are windows on the effect's clock, not counted updates. Frame 1 is t ≤ 1/60 s, and includes a draw before the first update. Frame 2 is t ≤ 2/60 s. Keep them as time windows at any frame rate.
  - Frame 1 (0–0.017 s): the full star: a forward jet, a body, two forward petals and two short back petals, with a white-hot core.
  - Frame 2 (to 0.033 s): smaller (lengths × 0.6, widths × 0.7, no back petals) and one step cooler.
  - From 0.033 s on, no flash. Its light pops, decaying as e^(−t/0.03), and is gone by about 0.12 s.
  - 0–0.15 s: 7 sparks.
  - 0–0.9 s: 4 smoke puffs blown forward off the muzzle.
  - At 0.04, 0.09, 0.14 and 0.19 s, 4 wisps are released one by one. They curl up off the barrel and live 0.9–1.4 s each.
  - 0 s to 3.6–4.6 s: a casing is ejected up and back, tumbles, bounces with a glint, slides to rest lying flat, and dithers out over the last 0.6 s of its life.
  - With an `actor` (and no `x`), the flash and its light stay on `actor.hand()` for the first 0.08 s.
  - `done()` turns true after 0.2 s, once particles and the casing are gone: about 3.6–4.6 s, or about 1.5 s with `casing: false`.
- **Layers:**
  - "back": smoke, then the casing and its landing glint.
  - "front": the flash, then the sparks.
  - Light buffer: additive glows that fall off as (1 − d/r)² × strength, with r in art px.
    - The pop (front), with pop = e^(−t/0.03):
      - #ffb060, r 18S + 8, 4S px out along the barrel, at 0.85·pop.
      - #ffffff, r 6S + 3, 2 px out, at 0.6·pop.
    - Each spark: r 3, 0.45 × life left.
    - The casing's glint: r 4, #e9b54a, 0.5 → 0 over 0.06 s.
  - Smoke is alpha-blended discs. Everything else is opaque pixels.
- **Palette:**
  - Flash, frame 1: core #ffffff, inner #fff3a6, body #ffe26b, rim #f2561d.
  - Flash, frame 2: core #fff3a6, inner #ffe26b, body #ff8a2a, rim #c9281f.
  - Sparks: the head is #fff3a6 above 60% of life left, #ffe26b above 30%, then #ff8a2a. The tail matches the head in the first half of life and is #f2561d after.
  - Smoke: puffs start #5b5566 and wisps #7a7186. Both mix by age into #7b6f72, #5d5660, #433d48, #2b2630, #1a171e.
  - Casing: #e9b54a and #9b6a22, with a #ffffff glint pixel.
- **Shapes and motion:** sizes are in art px, in the barrel's frame (along it and across it). Speeds are in world units/s. Gravity g = 1900 units/s². Drag is v −= v·drag·dt.
  - Flash lobes. Each lobe starts `off` px along the barrel, points `a` rad from it, is `len` long, and is `wid` at its widest half-width. Its core runs over the first `core` fraction of its length. All × S.

    | Lobe | off | a (rad) | len | wid | core |
    | --- | --- | --- | --- | --- | --- |
    | body | 0.5 | 0 | 9 | 2.4 | 0.55 |
    | jet | 2 | 0 | 21 × (0.8–1.2) | 1.15 | 0.4 |
    | 2 petals | 2 | ±0.72 | 8.5 × (0.8–1.2) | 1.35 | 0.3 |
    | 2 back petals (frame 1 only) | 1 | ±2.2 | 4 × (0.8–1.2) | 1.1 | 0 |

    - Each shot turns its petals by up to ±0.14 rad, from `seed`.
    - A lobe's half-width at fraction k of its length is wid × (1 − k)^0.8 × min(1, 0.45 + 3k): narrow at the muzzle, widest a fifth along, then pointed.
  - The flash, per pixel:
    - Inside a lobe's core length and within half its half-width, or within 1.1 px of the muzzle knot (a disc of radius 1.6 at 0.5 px out): core.
    - Deeper than 0.4 × half-width inside the edge: inner.
    - Otherwise inside: body.
    - Up to 0.85 px outside the edge: rim.
    - Edges jitter by up to ±0.25 px from a per-pixel hash that is re-rolled every frame.
  - Sparks: 7 (round(4 + 3S)) two-segment streaks.
    - They start 2 px out along the barrel and fly within ±0.32 rad of it at 300–760 × (0.7 + 0.3S). Life 0.05–0.15 s.
    - 0.45g, drag 2.2. They bounce on `ground` at × 0.45.
    - Streak length 1 + speed × 0.011 (max 9).
  - Smoke puffs: 4 (round(1 + 2.5S)).
    - They start 1.5 px out and fly within ±0.5 rad of the barrel at 20–90 × S, with −10 vertical.
    - Radius (1.2–2.2) × √S. Life 0.45–0.9 s.
  - Wisps: 4, starting 1 px out.
    - Along the barrel at 40, 30, 20 and 10 × S (±6 in x), plus 14, 23, 31 and 40 upward.
    - Radius (0.9–1.4) × √S. Life 0.9–1.4 s.
  - Smoke motion and drawing:
    - It rises at 32 units/s², sways, and has drag 1.6 in x and 1.2 in y.
    - Opacity a = min(1, 12·age) × min(1, 2.4 × life left) × 0.58.
    - Drawn as three alpha discs: radius r at 0.45a; 0.74r offset down-right at 0.62a; and in the first half of life a lit top of 0.5r up-left, mixed 12% toward white, at 0.4a × (1 − 2·age).
    - r = size × (0.65 + 0.45 × min(1, 2.5·age) + 0.4·age).
  - Casing: 2 pixels, #e9b54a and #9b6a22. The dark one sits one pixel along the casing's spin angle, so it tumbles at 22–34 rad/s; at rest it snaps flat.
    - It starts 14S units behind the muzzle, along the barrel.
    - It is thrown out of the barrel's top side at 170–260 and backward at 50–130.
    - 0.9g, drag 0.4 in x.
    - It bounces while landing faster than 160: × 0.42 vertical, × 0.55 horizontal, × 0.6 spin. Then it rests, and slides to a stop (x drag 6).
    - Each landing shows a white pixel above it and a glow for 0.06 s.
- **Feel:** one camera kick of (−cos(angle), −sin(angle)) × 1.6 × size, opposite the shot, at creation. It only happens when `size` ≥ 1. No shake or flash.

## Situations
- **Burst:** `muzzleFlash({ actor: player, ground: 300, seed: 31 })`: an SMG burst from a gun held by a character standing on y 300. One call per shot: 9 shots, 0.085 s apart, with seed 31 + shot index. Each flash sits on the muzzle given by `player.hand()`, and the casings pile up on the floor.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `actor.hand().x`, else `620` | The muzzle's x. When given, the flash no longer follows the actor. |
| `y` | number (world units) | `actor.hand().y`, else `540` | The muzzle's y. |
| `angle` | number (rad) | `actor.hand().a`, else `0` | The firing direction (0 right, π/2 down). |
| `size` | number (multiplier) | `1` | Scales the flash lobes, its light, the spark and smoke counts and speeds, the smoke radius (√), the casing's start and the kick. Below 1 there is no kick. |
| `sparks` | number (count) | `round(4 + 3 × size)` (7) | Spark count. |
| `casing` | boolean | `true` | `false`: no casing. |
| `smoke` | boolean | `true` | `false`: no puffs or wisps. |
| `actor` | `{ hand(): { x: number; y: number; a: number } }` | none | The gun: its muzzle and aim (see below). |
| `ground` | `number \| ((x: number) => number)` (world y) | none | The floor, where sparks and the casing land. Without it they fall until they die. |
| `seed` | number | `1` | Random seed: the petals' turn, the lobe lengths, sparks, smoke and casing. Use a new one per shot. |
| `kick` | `(dx: number, dy: number) => void` | none | Camera kick hook. |

## Actor, methods and hooks
- `actor`: `hand(): { x: number; y: number; a: number }` returns the muzzle in world units and the barrel's angle in radians.
  - It is read once, at creation, for the default `x`, `y` and `angle`.
  - It is read again on every "front" draw during the first 0.08 s, if `x` is not given, so the flash and its light stay on a moving gun.
  - Sparks, smoke and the casing keep their spawn point from creation.
- `kick(dx: number, dy: number): void`: called once, at creation, only if size ≥ 1, with (−cos(angle) × 1.6 × size, −sin(angle) × 1.6 × size). It asks for a camera lurch opposite the shot that springs back.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: muzzle-flash.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { hand(): { x: number; y: number; a: number } }
export interface Options {
  x?: number;
  y?: number;
  angle?: number;
  size?: number;
  sparks?: number;
  casing?: boolean;
  smoke?: boolean;
  actor?: Actor;
  ground?: number | ((x: number) => number);
  seed?: number;
  kick?(dx: number, dy: number): void;
}
export default function muzzleFlash(o: Options = {}) {
  const h0 = o.actor?.hand();
  const X = o.x ?? h0?.x ?? 620, Y = o.y ?? h0?.y ?? 540, A = o.angle ?? h0?.a ?? 0, S = o.size ?? 1;
  const R = new Rng(o.seed ?? 1);
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const ps = new Particles(R, groundAt);
  const c = Math.cos(A), s = Math.sin(A);
  const spin = R.range(-0.35, 0.35), jit = Array.from({ length: 9 }, () => R.range(0.8, 1.2));
  const shape = [1, 2].map((f) => lobes(S, f, spin, jit));
  let t = 0, casing: Casing | null = null;
  for (let i = 0, n = o.sparks ?? Math.round(4 + 3 * S); i < n; i++) {
    const a = A + R.range(-1, 1) * 0.32, sp = R.range(300, 760) * (0.7 + 0.3 * S);
    ps.spawn(K.SPARK, X + c * 4, Y + s * 4, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.05, 0.15));
  }
  if (o.smoke !== false) {
    for (let i = 0, n = Math.round(1 + S * 2.5); i < n; i++) {
      const a = A + R.range(-0.5, 0.5), sp = R.range(20, 90) * S;
      ps.spawn(K.SMOKE, X + c * 3, Y + s * 3, Math.cos(a) * sp, Math.sin(a) * sp - 10, R.range(0.45, 0.9), SMOKE, R.range(1.2, 2.2) * Math.sqrt(S));
    }
    for (let i = 0; i < 4; i++) {
      const k = i / 3;
      ps.spawn(K.SMOKE, X + c * 2, Y + s * 2, c * (40 - 30 * k) * S + R.range(-6, 6), s * (40 - 30 * k) * S - (14 + 26 * k), R.range(0.9, 1.4), WISP, R.range(0.9, 1.4) * Math.sqrt(S), 0.04 + i * 0.05);
    }
  }
  if (o.casing !== false) {
    const up = c >= 0 ? 1 : -1, nx = s * up, ny = -c * up;
    casing = { x: X - c * 14 * S, y: Y - s * 14 * S, vx: nx * R.range(170, 260) - c * R.range(50, 130), vy: ny * R.range(170, 260) - s * R.range(50, 130), a: R.range(0, TAU), va: R.range(22, 34) * R.sign(), life: R.range(3.6, 4.6), max: 0, rest: false, glint: 0 };
    casing.max = casing.life;
  }
  if (S >= 1) o.kick?.(-c * 1.6 * S, -s * 1.6 * S);
  return {
    update(dt: number) {
      t += dt;
      if (casing) {
        const k = casing;
        if ((k.life -= dt) <= 0) casing = null;
        else if (!k.rest) {
          k.vy += GRAVITY * 0.9 * dt;
          k.vx -= k.vx * 0.4 * dt;
          const ny = k.y + k.vy * dt, g = groundAt(k.x);
          k.x += k.vx * dt;
          k.a += k.va * dt;
          if (k.vy > 0 && k.y <= g && ny >= g) {
            k.y = g - 0.5;
            k.glint = 0.06;
            if (k.vy > 160) { k.vy = -k.vy * 0.42; k.vx *= 0.55; k.va *= 0.6; } else (k.rest = true), (k.vy = 0);
          } else k.y = ny;
        } else { k.x += k.vx * dt; k.vx -= k.vx * Math.min(1, 6 * dt); }
        if (casing) casing.glint = Math.max(0, casing.glint - dt);
      }
      ps.update(dt);
    },
    draw(fr: Frame, layer?: Layer) {
      const buf = new Px(fr, fr.color), light = new Px(fr, fr.light);
      if (layer !== "front") { ps.draw(buf, light, "back"); if (casing) drawCasing(buf, light, casing); }
      if (layer === "back") return;
      const f = Math.max(1, Math.ceil(t * 60 - 1e-6));
      const m = where(), ax = m.x / PX, ay = m.y / PX;
      if (f <= 2) flash(buf, ax, ay, m.a, f, shape[f - 1]!, t * 1000 + X);
      ps.draw(buf, light, "front");
      const pop = Math.exp(-t / 0.03);
      if (pop > 0.02) {
        light.glow(ax + Math.cos(m.a) * 4 * S, ay + Math.sin(m.a) * 4 * S, 18 * S + 8, WARM, 0.85 * pop);
        light.glow(ax + Math.cos(m.a) * 2, ay + Math.sin(m.a) * 2, 6 * S + 3, PAL.white, 0.6 * pop);
      }
    },
    done: () => t > 0.2 && ps.list.length === 0 && !casing,
  };
  function where() { if (o.actor && t < 0.08 && o.x === undefined) return o.actor.hand(); return { x: X, y: Y, a: A } }
}
interface Lobe { off: number; a: number; len: number; wid: number; core: number }
function lobes(S: number, f: number, spin: number, jit: number[]): Lobe[] {
  const k = f === 1 ? 1 : 0.6, w = f === 1 ? 1 : 0.7;
  const L: Lobe[] = [{ off: 0.5, a: 0, len: 9 * S * k, wid: 2.4 * S * w, core: 0.55 }, { off: 2, a: 0, len: 21 * S * k * jit[0]!, wid: 1.15 * S * w, core: 0.4 }];
  for (const side of [-1, 1]) {
    L.push({ off: 2, a: side * (0.72 + spin * side * 0.4), len: 8.5 * S * k * jit[side + 2]!, wid: 1.35 * S * w, core: 0.3 });
    if (f === 1) L.push({ off: 1, a: side * (2.2 - spin * side * 0.4), len: 4 * S * jit[side + 4]!, wid: 1.1 * S, core: 0 });
  }
  return L;
}
function profile(l: Lobe, u: number) { const k = u / l.len; return l.wid * Math.pow(Math.max(0, 1 - k), 0.8) * Math.min(1, 0.45 + k * 3); }
function flash(buf: Px, ax: number, ay: number, a: number, f: number, L: Lobe[], seed: number) {
  const c = Math.cos(a), s = Math.sin(a);
  let ext = 2;
  for (const l of L) ext = Math.max(ext, l.off + l.len + 2);
  const core = f === 1 ? PAL.white : PAL.hot, body = f === 1 ? PAL.yellow : PAL.orange, inner = f === 1 ? PAL.hot : PAL.yellow, rim = f === 1 ? PAL.deepOrange : PAL.red;
  for (let py = Math.floor(ay - ext); py <= Math.ceil(ay + ext); py++)
    for (let px = Math.floor(ax - ext); px <= Math.ceil(ax + ext); px++) {
      const dx = px + 0.5 - ax, dy = py + 0.5 - ay, along = dx * c + dy * s, across = -dx * s + dy * c;
      let m = -9, hot = false, warm = false;
      for (const l of L) {
        const ca = Math.cos(l.a), sa = Math.sin(l.a), lu = (along - l.off) * ca + across * sa, lv = -(along - l.off) * sa + across * ca;
        if (lu < -1.5 || lu > l.len + 1) continue;
        const r = profile(l, Math.max(0, lu)), mm = r - Math.abs(lv);
        if (mm > m) m = mm;
        if (lu < l.len * l.core && Math.abs(lv) <= r * 0.5) hot = true;
        if (mm > r * 0.4) warm = true;
      }
      const dm = 1.6 - Math.hypot(along - 0.5, across);
      if (dm > m) m = dm;
      if (dm > 0.5) hot = true;
      m += (hash(px * 73 + py * 151, seed) - 0.5) * 0.5 * Math.min(1, ext / 14);
      if (m < -0.85) continue;
      buf.set(px, py, m < 0 ? rim : hot ? core : warm ? inner : body);
    }
}
interface Casing { x: number; y: number; vx: number; vy: number; a: number; va: number; life: number; max: number; rest: boolean; glint: number }
function drawCasing(buf: Px, light: Px, k: Casing) {
  const fade = Math.min(1, k.life / 0.6), px = Math.floor(k.x / PX), py = Math.floor(k.y / PX);
  const a = k.rest ? Math.round(k.a / Math.PI) * Math.PI : k.a, dx = Math.round(Math.cos(a)), dy = Math.round(Math.sin(a));
  const put = (x: number, y: number, c: number) => (fade >= 1 || fade > bayer(x, y)) && buf.set(x, y, c);
  put(px, py, BRASS);
  put(px + dx, py + dy, BRASS_DARK);
  if (k.glint > 0) { buf.set(px, py - 1, PAL.white); light.glow(px + 0.5, py, 4, BRASS, 0.5 * (k.glint / 0.06)); }
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
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
}
function ramp(stops: readonly number[], t: number) {
  const u = Math.max(0, Math.min(0.9999, t)) * (stops.length - 1), i = Math.floor(u);
  return mix(stops[i]!, stops[i + 1]!, u - i);
}
const PAL = { white: hex("#ffffff"), hot: hex("#fff3a6"), yellow: hex("#ffe26b"), orange: hex("#ff8a2a"), deepOrange: hex("#f2561d"), red: hex("#c9281f") };
const WARM = rgb(255, 176, 96);
const SMOKE = hex("#5b5566"), WISP = hex("#7a7186");
const BRASS = hex("#e9b54a"), BRASS_DARK = hex("#9b6a22");
const SMOKE_RAMP = [hex("#7b6f72"), hex("#5d5660"), hex("#433d48"), hex("#2b2630"), hex("#1a171e")];
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
  sign() { return this.next() < 0.5 ? -1 : 1; }
}
const TAU = Math.PI * 2;
function hash(n: number, k = 0) { return ((Math.imul((n | 0) + 1 + Math.floor(k) * 7919, 2654435761) >>> 0) % 100000) / 100000; }
const GRAVITY = 1900;
const K = { SPARK: 0, SMOKE: 1 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number; delay: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  ground: (x: number) => number;
  constructor(R: Rng, ground: (x: number) => number) { this.R = R; this.ground = ground; }
  spawn(k: K, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1, delay = 0) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100, delay });
  }
  update(dt: number) {
    this.t += dt;
    const t = this.t, L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if (p.delay > 0) { p.delay -= dt; continue; }
      if ((p.life -= dt) <= 0) { L.splice(i, 1); continue; }
      switch (p.k) {
        case K.SPARK: {
          p.vy += GRAVITY * 0.45 * dt;
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt;
          const ny = p.y + p.vy * dt, g = this.ground(p.x);
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) { p.vy = -p.vy * 0.45; p.vx *= 0.7; p.y = g - 0.5; } else p.y = ny;
          break;
        }
        case K.SMOKE:
          p.vy -= 32 * dt;
          p.vx += Math.sin(t * 1.3 + p.seed) * 16 * dt;
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.2 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
      }
    }
  }
  draw(buf: Px, light: Px, layer: Layer) {
    for (const p of this.list) {
      if (p.delay > 0 || (p.k === K.SMOKE) !== (layer === "back")) continue;
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX;
      switch (p.k) {
        case K.SMOKE: {
          const age = 1 - k, r = p.size * (0.65 + Math.min(1, age * 2.5) * 0.45 + age * 0.4);
          const a = Math.min(1, age * 12) * Math.min(1, k * 2.4) * 0.58, c = mix(p.col, ramp(SMOKE_RAMP, age), age);
          buf.alphaDisc(ax, ay, r, c, a * 0.45);
          buf.alphaDisc(ax + r * 0.05, ay + r * 0.06, r * 0.74, c, a * 0.62);
          if (age < 0.5) buf.alphaDisc(ax - r * 0.22, ay - r * 0.3, r * 0.5, mix(c, PAL.white, 0.12), a * 0.4 * (1 - age * 2));
          break;
        }
        case K.SPARK: {
          const hot = k > 0.6 ? PAL.hot : k > 0.3 ? PAL.yellow : PAL.orange;
          const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(9, 1 + sp * 0.011);
          buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? hot : PAL.deepOrange);
          buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, hot);
          light.glow(ax, ay, 3, hot, 0.45 * k);
          break;
        }
      }
    }
  }
}
```
