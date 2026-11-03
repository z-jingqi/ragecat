# Holy Light (holy-light.ts)

A gold column slamming down from the sky with a white core, shimmering fibres and halos, a ring along the ground and sparkles rising, narrowing to a thread. Or a short, narrow smite.

Previews (animated WebP, 320 × 200 art pixels): Pillar https://www.spritefusion.com/images/pixel-art-vfx/holy-light-pillar.webp, Smite https://www.spritefusion.com/images/pixel-art-vfx/holy-light-smite.webp

Page: https://www.spritefusion.com/pixel-art-vfx/holy-light. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/holy-light.zip

## Recipe
- **Timeline:** sizes in art px, positions and speeds in world units. Three moments: the slam at 0.42 s, narrowing at 0.42 + `hold` (2.55 s by default), out at narrowing + 0.5 (3.05 s). Rates "per update" assume 60 updates a second.
  - 0–0.42 s, wind-up:
    - The scene darkens to 0.35 by 0.4 s.
    - A 1 px guide line fades in from the top of the view down to the base.
    - A gold pool grows on the ground.
    - Sparks are drawn in to the base.
  - 0.42 s, the slam:
    - The column drops from the sky in 0.07 s at 1.35 × `width`, settling to `width` (× 1 + 0.35·e^(−9·t since the slam)).
    - A screen flash, a camera shake and a scene ripple.
    - A burst of light for 0.12 s. 50 stars thrown out sideways.
    - Two rings race out along the ground, 0.55 s each, the second 0.1 s later.
    - 8 feathers start drifting down from above.
  - 0.42–2.55 s, it stands: fibres shimmer, pulses run down it, a halo rises up it every 0.42 s, stars and bokeh rise inside it.
  - 2.55–2.95 s, it narrows to a 0.6 px thread.
    - The pool fades over 2.55–3.05 s; the column over 2.8–3.25 s; the darkness lifts over 2.55–3.25 s.
    - Rising sparkles stop at 3.05 s. Feathers land and fade out by about 3.4 s.
  - `done()`: after 3.55 s once the particles and feathers are gone, about 4 s. The smite (`width: 7, hold: 0.6`) narrows at 1.02 s and its column is gone by 1.72 s; its feathers keep falling until about 3 s.
- **Layers:**
  - "back": the ground pool, the guide line, the column with its fibres, pulses and halos.
  - "front": the ground rings, feathers, stars and bokeh, the slam's burst of light.
  - Light buffer, additive glows falling off as (1 − d/r)² × strength:
    - Pool: r 2.2 × its rx, step 3, 0.5 × its intensity.
    - Guide line (wind-up): r 40 at 10 px below the top of the view, step 3, up to 0.28.
    - Column: every 8 rows r 2.4 × half-width + 6, step 2, 0.32; at the top of the view r 70, step 3, 0.4. Both × its fade.
    - Slam: r 140, 20 px above the base, step 2, 1.2 falling linearly to 0 over 0.12 s.
    - Each star r 3 + 2·arm; each bokeh r 3 + 3 × size; each feather r 5, step 2, 0.2.
  - Colour buffer: opaque pixels; partial opacity is a 4 × 4 Bayer ordered dither. Only the bokeh are alpha-blended.
- **Palette:**
  - `colors`, light to dark, default #ffffff, #fffbe2, #fff0a6, #ffd862, #f6aa3c, #cf722b, #7e3c1f. Steps 1–4 are used, plus white.
  - Column, across its width: white core, step 1, step 2, step 3, then a dithered step 4 fringe. The pool the same from its centre out.
  - Guide line: step 1. Ground rings: white, then step 2. Halos: white, then step 1.
  - Feathers: their three rows white, step 1, step 2.
  - Stars and bokeh: white or steps 1–3; the wind-up sparks step 2.
  - Flash colour: rgb(255, 240, 196).
- **Shapes and motion:**
  - Column: from 2 px above the top of the view down to the base. At q = |dx| / w, w its current half-width:
    - White for q < 0.2, step 1 < 0.42, step 2 < 0.66, step 3 < 0.88, step 4 out to q = 1.3 with opacity (1.3 − q)/0.42.
    - 11 fibres: vertical bands at fixed offsets within ±0.85w, 0.04–0.11w wide, each wobbling by 0.05w at 1–3 rad/s. A pixel inside a fibre is one step brighter.
    - Pulses: bands 3.5 px tall every 50 px, running down at 95 px/s, one step brighter.
    - As it fades, the outer part dithers out first; the inner 66% only at the very end (its dither threshold × 0.2).
    - At the slam, its bottom end shoots from 12.5% of the way down to the base in 0.07 s (cubic ease-in).
    - Narrowing: w goes from `width` to 0.6 over 0.4 s (outCubic).
  - Guide line: 1 px wide at x, opacity up to 0.7 over 0–0.34 s, 0.4 of that at the top rising to all of it at the base.
  - Ground pool: a filled ellipse at the base. Wind-up: rx = 10 + 14t, ry 5, intensity rising to 0.5. After the slam: rx = 44 + 4·sin(5t), ry 8, intensity 1 until it fades. Bands by distance over intensity: step 1 within 35%, step 2 to 65%, step 3 to 90%, step 4 out to the rim. Solid within 0.7 × intensity, dithered beyond.
  - Ground rings: full ellipses at the base, rx 14 → 104 and ry 3 → 16 (the second × 0.7), outCubic over 0.55 s, 3.5 → 0.5 px thick, opacity 1.15 − progress.
  - Halos: an ellipse ring, rx 1.35w growing 30%, ry 2.2, 1 px thick, rising from 4 px above the base through 90% of the column in 0.9 s, fading.
  - Particles (world units/s):
    - Wind-up: 40% chance per update, a star on an ellipse 40–90 units round the base (flattened × 0.3), flying in at 2.5 × its distance sideways and 0.6 × vertically; life 0.38 s; size 0.6–1.2.
    - Slam: 50 stars from within 20 units of the base, 120–520 sideways and 40–260 up, life 0.4–1 s, size 0.8–2.2.
    - Standing: 2 tries per update, each 70% × (w / `width`): a star (70%) or a bokeh, within ±1.4w of the axis and up to 200 units above the base. Rising 60–170, ±10 sideways; life 0.6–1.3 s; size 0.7–2.
    - Stars: a twinkling plus, arms round(size × twinkle) px, tips at 75% brightness, diagonal corners from 3 px, a white centre; under size 1 a single pixel. Drag 1.6 (v −= v·1.6·dt), rising 10 units/s².
    - Bokeh: a disc of radius size in its colour at 45%, a white disc of half that at 50%, breathing (0.7–1), fading in over the first 20% of its life and out over the last third. Drag 0.8.
  - Feathers: 8 pixel sprites, 5 × 3, `.##..` / `#####` / `..###` or `..##.` / `#####` / `###..`. Spawned within ±120 units of x and 260–420 units above the base.
    - They fall at 28–50 units/s, swaying sideways by sin(2.4t + seed) × 34 units/s and tilting by 0.5 × sin(2.4t + seed − 0.6) rad.
    - They stop falling 4 units above the base (still swaying).
    - Life 2.2–3 s: fading in over 0.3 s and out over the last 0.6 s, dithered.
- **Feel:** the scene darkened by 0.35 while it stands. At the slam: a screen flash of 0.85, a camera shake of 0.55 and a scene ripple from radius 20 to 340 over 0.6 s.

## Situations
- **Pillar:** `holyLight({ x: 440, ground: 300 })`: the full column slamming down, standing 2.1 s with its halos and sparkles, then narrowing to a thread.
- **Smite:** `holyLight({ x: 440, ground: 300, width: 7, hold: 0.6, seed: 4 })`: a narrow column slamming down, standing 0.6 s and gone 1.3 s after the slam.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `790` | Where the column comes down. |
| `y` | number (world units) | `ground` at `x`, else `600` | The base's y: where the column ends, the pool, rings and particles start. |
| `ground` | `number \| ((x: number) => number)` (world y) | none | Only used to place `y` when it's left out. |
| `hold` | number (s) | `2.13` | How long it stands at full width after the slam (at 0.42 s) before narrowing. |
| `width` | number (art px) | `13` | The column's half-width; its dithered fringe reaches 1.3 × that. |
| `colors` | `number[]` (packed ABGR, `0xAABBGGRR`, light to dark) | the gold ramp above | Its ramp, as numbers, not hex strings: #ffd862 is `0xff62d8ff`. Steps 1–4 are used, so at least 5. |
| `seed` | number | `1` | Random seed. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |
| `flash` | `(k: number, rgb: string) => void` | none | Screen flash hook. |
| `ripple` | `(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number) => void` | none | Scene ripple hook. |
| `darken` | `(k: number) => void` | none | Scene darkening hook. |

## Actor, methods and hooks
- No actor, and no methods beyond update, draw and done.
- `darken(k: number)`: called every update with the darkness wanted this frame: 0.35 × smooth(0, 0.4, t) × (1 − smooth(narrowing, out + 0.2, t)). It rises to 0.35 by 0.4 s and falls back to 0 between 0.42 + `hold` and 1.12 + `hold`. Apply it to the scene for that frame only.
- `flash(k: number, rgb: string)`: once at the slam (0.42 s), (0.85, "255,240,196"). `rgb` is "r,g,b".
- `shake(trauma: number)`: once at the slam, 0.55.
- `ripple(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number)`: once at the slam, with (x, y − 20, 20, 340, 0.6, 0.18, 40). It asks for a ring that distorts the scene round (x, y): its radius goes from r0 to r1 world units over dur seconds, with strength amp and band width w.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: holy-light.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  x?: number;
  y?: number;
  ground?: number | ((x: number) => number);
  hold?: number;
  width?: number;
  colors?: number[];
  seed?: number;
  shake?(trauma: number): void;
  flash?(k: number, rgb: string): void;
  ripple?(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number): void;
  darken?(k: number): void;
}
export default function holyLight(o: Options = {}) {
  const R = new Rng(o.seed ?? 1), ps = new Particles(R);
  const X = o.x ?? 790, g = groundAt(o.ground, X), Y = o.y ?? (Number.isFinite(g) ? g : 600), cx = X / PX, cy = Y / PX;
  const H = o.colors ?? HOLY, W = o.width ?? 13, SPARKS = [WHITE, H[1]!, H[2]!, H[3]!];
  const SLAM = 0.42, NARROW = SLAM + (o.hold ?? 2.13), OUT = NARROW + 0.5;
  let t = 0, slammed = false, lastHalo = 0;
  const halos: number[] = [];
  const feathers: { x: number; y: number; vy: number; a: number; life: number; max: number; s: number; seed: number }[] = [];
  const width = (t: number) => (t < SLAM ? 0 : t < NARROW ? W * (1 + 0.35 * Math.exp(-(t - SLAM) * 9)) : lerp(W, 0.6, outCubic((t - NARROW) / 0.4)));
  const strands = Array.from({ length: 11 }, (_, i) => ({ o: (hash(i, 1) - 0.5) * 1.7, w: 0.04 + hash(i, 2) * 0.07, f: 1 + hash(i, 3) * 2 }));
  return {
    update(dt: number) {
      t += dt;
      o.darken?.(0.35 * smooth(0, 0.4, t) * (1 - smooth(NARROW, OUT + 0.2, t)));
      if (t >= SLAM && !slammed) {
        slammed = true;
        o.flash?.(0.85, "255,240,196");
        o.shake?.(0.55);
        o.ripple?.(X, Y - 20, 20, 340, 0.6, 0.18, 40);
        for (let i = 0; i < 50; i++) {
          const s = R.sign(), sp = R.range(120, 520);
          ps.spawn(K.STAR, X + s * R.range(0, 20), Y - 4, s * sp, -R.range(40, 260), R.range(0.4, 1), R.pick(SPARKS), R.range(0.8, 2.2));
        }
        for (let i = 0; i < 8; i++) {
          const life = R.range(2.2, 3);
          feathers.push({ x: X + R.range(-120, 120), y: Y - R.range(260, 420), vy: R.range(28, 50), a: 0, life, max: life, s: R.int(0, 1), seed: R.next() * 10 });
        }
      }
      const w = width(t);
      if (t > SLAM && t < OUT) {
        for (let i = 0; i < 2; i++) if (R.chance(0.7 * clamp(w / W))) ps.spawn(R.chance(0.7) ? K.STAR : K.BOKEH, X + R.range(-w, w) * PX * 1.4, Y - R.range(0, 200), R.range(-10, 10), -R.range(60, 170), R.range(0.6, 1.3), R.pick(SPARKS), R.range(0.7, 2));
        if (t - lastHalo > 0.42 && t < NARROW) { lastHalo = t; halos.push(t); }
      } else if (t < SLAM && R.chance(0.4)) {
        const a = R.range(0, TAU), d = R.range(40, 90);
        ps.spawn(K.STAR, X + Math.cos(a) * d, Y - 6 + Math.sin(a) * d * 0.3, -Math.cos(a) * d * 2.5, -Math.sin(a) * d * 0.6, 0.38, H[2]!, R.range(0.6, 1.2));
      }
      for (let i = feathers.length - 1; i >= 0; i--) {
        const f = feathers[i]!;
        if ((f.life -= dt) <= 0) feathers.splice(i, 1);
        if (f.y > Y - 4) f.vy = 0;
        f.x += Math.sin(t * 2.4 + f.seed) * 34 * dt;
        f.y += f.vy * dt;
        f.a = Math.sin(t * 2.4 + f.seed - 0.6) * 0.5;
      }
      ps.update(dt);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") {
        const gl = t < SLAM ? smooth(0, SLAM, t) * 0.5 : 1 - smooth(NARROW, OUT, t);
        if (gl > 0.01) {
          const rx = 10 + (t < SLAM ? 14 * t : 34 + 4 * Math.sin(t * 5)), ry = 3 + (t < SLAM ? 2 : 5);
          for (let y = Math.floor(cy - ry); y <= cy + ry; y++)
            for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
              const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, d = Math.sqrt(dx * dx + dy * dy);
              if (d > 1) continue;
              const u = d / Math.max(0.05, gl);
              if (d < 0.7 * gl || bayer(x, y) < gl * (1 - d) * 2.2) buf.set(x, y, u < 0.35 ? H[1]! : u < 0.65 ? H[2]! : u < 0.9 ? H[3]! : H[4]!);
            }
          light.glow(cx, cy, rx * 2.2, H[3]!, 0.5 * gl);
        }
        column(buf, light);
      }
      if (layer !== "back") {
        for (let i = 0; i < 2; i++) {
          const k = (t - SLAM - 0.1 * i) / 0.55, sc = i ? 0.7 : 1;
          if (k < 0 || k > 1) continue;
          const e = outCubic(k);
          ringE(buf, cx, cy, 14 + 90 * e * sc, 3 + 13 * e * sc, 3 * (1 - k) + 0.5, k < 0.25 ? WHITE : H[2]!, 1.15 - k);
        }
        if (t > SLAM && t < SLAM + 0.12) light.glow(cx, cy - 20, 140, H[2]!, 1.2 * (1 - (t - SLAM) / 0.12));
        for (const fe of feathers) {
          const a = Math.min(1, fe.life / 0.6, (fe.max - fe.life) / 0.3), sp = FEATHER[fe.s]!, fx = fe.x / PX, fy = fe.y / PX, ca = Math.cos(fe.a), sa = Math.sin(fe.a);
          for (let r = 0; r < 3; r++)
            for (let k = 0; k < 5; k++) {
              if (sp[r]![k] !== "#") continue;
              const lx = k - 2, ly = r - 1;
              dot(buf, fx + lx * ca - ly * sa, fy + lx * sa + ly * ca, r === 0 ? WHITE : r === 1 ? H[1]! : H[2]!, a);
            }
          light.glow(fx, fy, 5, H[2]!, 0.2 * a);
        }
        ps.draw(buf, light);
      }
    },
    done: () => t > OUT + 0.5 && ps.list.length === 0 && feathers.length === 0,
  };
  function column(buf: Px, light: Px) {
    const w = width(t), top = buf.oy - 2;
    if (t < SLAM) {
      const a = smooth(0, SLAM * 0.8, t) * 0.7;
      for (let y = top; y < cy; y++) dot(buf, cx, y, H[1]!, a * (0.4 + 0.6 * ((y - top) / (cy - top))));
      light.glow(cx, top + 10, 40, H[3]!, a * 0.4);
      return;
    }
    if (w <= 0.05 || t > OUT + 0.2) return;
    const fade = 1 - smooth(OUT - 0.25, OUT + 0.2, t);
    const yEnd = t - SLAM < 0.07 ? lerp(top, cy, inCubic(clamp((t - SLAM) / 0.07) * 0.5 + 0.5)) : cy;
    for (let y = top; y <= yEnd; y++) {
      const pulse = frac((y - top) * 0.02 - t * 1.9) < 0.07 ? 1 : 0;
      for (let x = Math.floor(cx - w * 1.3); x <= Math.ceil(cx + w * 1.3); x++) {
        const q = Math.abs((x + 0.5 - cx) / w);
        let lvl = q < 0.2 ? 0 : q < 0.42 ? 1 : q < 0.66 ? 2 : q < 0.88 ? 3 : 4;
        for (const s of strands) if (Math.abs((x + 0.5 - cx) / w - s.o - 0.05 * Math.sin(t * s.f + s.o * 9)) < s.w) lvl = Math.max(0, lvl - 1);
        lvl = Math.max(0, lvl - pulse);
        const a = (q < 0.88 ? 1 : (1.3 - q) / 0.42) * fade;
        if (a <= bayer(x, y) * (q < 0.66 ? 0.2 : 1)) continue;
        buf.set(x, y, lvl === 0 ? WHITE : H[lvl]!);
      }
      if ((y & 7) === 0) light.glow(cx, y, w * 2.4 + 6, H[2]!, 0.32 * fade);
    }
    light.glow(cx, top + 8, 70, H[3]!, 0.4 * fade);
    for (const h0 of halos) {
      const k = (t - h0) / 0.9;
      if (k < 0 || k > 1) continue;
      ringE(buf, cx, cy - 4 - k * (cy - top) * 0.9, w * 1.35 * (1 + k * 0.3), 2.2, 1, k < 0.3 ? WHITE : H[1]!, (1 - k) * fade);
    }
  }
}
const FEATHER = [[".##..", "#####", "..###"], ["..##.", "#####", "###.."],];
function groundAt(g: number | ((x: number) => number) | undefined, x: number) { return g === undefined ? Infinity : typeof g === "number" ? g : g(x); }
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
const HOLY = ["#ffffff", "#fffbe2", "#fff0a6", "#ffd862", "#f6aa3c", "#cf722b", "#7e3c1f"].map(hex);
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
  sign() { return this.next() < 0.5 ? -1 : 1; }
  chance(p: number) { return this.next() < p; }
  pick<T>(a: readonly T[]): T { return a[Math.floor(this.next() * a.length)]!; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
function inCubic(t: number) { return Math.pow(clamp(t), 3); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function frac(x: number) { return x - Math.floor(x); }
const K = { STAR: 0, BOKEH: 1 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  constructor(R: Rng) { this.R = R; }
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
        case K.BOKEH:
          p.vx -= p.vx * 0.8 * dt;
          p.vy -= p.vy * 0.8 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
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
      case K.BOKEH: {
        const br = 0.7 + 0.3 * Math.sin(this.t * (2 + (p.seed % 3)) + p.seed), a = Math.min(1, (1 - k) * 5) * Math.min(1, k * 3) * br;
        if (a < 0.05) break;
        buf.alphaDisc(ax, ay, p.size, p.col, 0.45 * a);
        buf.alphaDisc(ax, ay, p.size * 0.5, WHITE, 0.5 * a);
        light.glow(ax, ay, 3 + p.size * 3, p.col, 0.35 * a);
        break;
      }
    }
  }
}
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
function ringE(buf: Px, cx: number, cy: number, rx: number, ry: number, thick: number, c: number, a = 1) {
  const n = Math.ceil(Math.max(rx, ry) * TAU * 1.3);
  for (let j = 0; j < n; j++) {
    const ang = (j / n) * TAU;
    const ca = Math.cos(ang), sa = Math.sin(ang);
    for (let o = -thick / 2; o <= thick / 2; o += 0.5) dot(buf, cx + ca * (rx + o), cy + sa * (ry + o * (ry / Math.max(1, rx))), c, a);
  }
}
```
