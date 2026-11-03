# Fog (fog.ts)

Ground fog in dithered tones: banks at different depths drifting, the nearest passing in front of characters, their wispy tops breathing. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Night https://www.spritefusion.com/images/pixel-art-vfx/fog-night-fog.webp

Page: https://www.spritefusion.com/pixel-art-vfx/fog. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/fog.zip

## Recipe
- **Timeline:** no warm-up: it is at full strength from t = 0. It never cycles; it scrolls. Each bank drifts with the wind, its wisps curl, and it breathes up and down 2.4 art px with a period of about 18 s (sin 0.35t, offset along its length so it rises and falls unevenly). `stop()`: every bank's opacity falls linearly to 0 over 2.5 s, then `done()` is true.
- **Layers:** `layers` banks at depths d = 0 (farthest) to 1 (nearest), d = i / (layers − 1); a single bank gets d = 0.5. The nearest bank is drawn in "front" (it passes in front of characters' legs) and all the others in "back". A single bank goes in "back". Colour buffer only, alpha-blended at partial opacity so the scene shows through, dimmed. Nothing goes in the light buffer.
- **Palette:** light to dark: crest = `colors[2]` mixed toward white by 0.14 + 0.12d (#9499b4 far, #9ba0b9 mid, #a3a7be near); thick #8389a8 (`colors[2]`); mid #5a6185 (`colors[1]`); thin #3b3f63 (`colors[0]`). The thin tone is the bank's body edges and gaps, the thick tone its densest parts, and the crest a lit top on the thicker masses.
- **Shapes and motion:**
  - Field: a 256 × 128 value-noise texture baked once from `seed`. It has 4 octaves (lattices of 4, 8, 16 and 32 cells across, amplitudes 0.5, 0.25, 0.125, 0.0625, normalised), smoothstep-interpolated, sampled bilinearly and wrapping on both axes.
  - Geometry: H is the area's height and the ground is its bottom. A bank's top sits H × (1 − 0.62d) above the ground: the far bank fills the whole area, the near one its lowest 38%. Its bottom spills H × (0.03 + 0.16d) below the ground. Its vertical profile P rises by smoothstep from 0 at its top to 1 at 80% of the way down, then fades out over its last 4 px. Each end fades in over 40 art px (80 units) of the area by smoothstep, so extend the area 80 units past the screen edges if the ends should not show.
  - Per art pixel: a domain warp w = field(0.35x + 9c, 0.6y − 3c) − 0.5, with c = t × (0.6 + 0.5d), read every other column. Then n = field(x × (0.3 + 0.25d) − drift + 30w, (y + breath) × (1.5 + 0.8d) + 12w). The stretch makes long, flat banks, and the far ones are larger. Thickness f = (0.72P + 0.95 × (clamp(2.6(n − 0.5) + 0.5) − 0.5)) × (0.6 + 0.5 × density) × endFade.
  - Stepped ramp: f below 0.30 draws nothing. Tones begin at 0.30, 0.52 and 0.74, and each step is dithered with a 4 × 4 Bayer matrix across the 0.07 above its threshold. A tone-1 or tone-2 pixel whose f two pixels higher falls below its own threshold − 0.03 takes the crest colour, which gives a 2 px lit rim along the tops of the denser fog.
  - Opacity: α = (0.2 + 0.16d) × density × fade. The tones are blended at 0.6α, 0.8α and 1.0α, and the crest at 1.1α (on tone 1) or 1.25α (on tone 2).
  - Drift: in field space it is t × wind × (0.4 + 0.8d) / 2. Divided by the horizontal stretch, that puts the far, mid and near banks at about 29, 41 and 48 units/s on screen with the default wind of 22.
  - No particles.

## Situations
- **Night:** `fog({ area: { x: -80, y: 160, w: 800, h: 160 } })`: night fog in three banks along the ground at y 320. The area runs 80 units past each screen edge so the faded ends stay off screen.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 0, y: 470, w: 1280, h: 150 }` | Where it lies. Its bottom edge is the ground. The far bank fills its height and the near bank spills up to 19% of `h` below it. The ends fade over 80 units. |
| `density` | number | `1` | Multiplies every bank's opacity and scales its thickness by 0.6 + 0.5 × density, so more of it crosses the tone thresholds. |
| `colors` | `[string, string, string]` (hex) | `["#3b3f63", "#5a6185", "#8389a8"]` | The three tones, thin to thick. The crest is the thick one mixed 14–26% toward white. |
| `wind` | number (world units/s) | `22` | Drift strength, + to the right, scaled 0.4× (far) to 1.2× (near) per bank. |
| `layers` | number | `3` | Number of banks, clamped to 1–4. The nearest is drawn in "front" and the rest in "back"; a single bank goes in "back". |
| `seed` | number | `1` | Seeds the baked noise field. |

## Actor, methods and hooks
- `stop()`: call it when the fog should clear. The fog thins out over 2.5 s and `done()` turns true; calling it again does nothing. It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: fog.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  area?: { x: number; y: number; w: number; h: number };
  density?: number;
  colors?: [string, string, string];
  wind?: number;
  layers?: number;
  seed?: number;
}
export default function fog(o: Options = {}) {
  const A = o.area ?? { x: 0, y: 470, w: 1280, h: 150 }, D = o.density ?? 1, WIND = o.wind ?? 22, N = Math.max(1, Math.min(4, o.layers ?? 3));
  const TONES = (o.colors ?? ["#3b3f63", "#5a6185", "#8389a8"]).map(hex);
  const field = bake(o.seed ?? 1);
  const X0 = A.x / PX, X1 = (A.x + A.w) / PX, BOT = (A.y + A.h) / PX, H = A.h / PX;
  let t = 0, stopAt = Infinity, edges = new Float32Array(0), breaths = edges;
  const level = () => clamp(1 - (t - stopAt) / 2.5);
  function bank(buf: Px, d: number, i: number) {
    const top = BOT - H * (1 - 0.62 * d), base = top + (BOT - top) * 0.8, bottom = BOT + H * (0.03 + 0.16 * d);
    const sx = 0.3 + 0.25 * d, sy = 1.5 + 0.8 * d;
    const drift = (t * WIND * (0.4 + 0.8 * d)) / PX, curl = t * (0.6 + 0.5 * d);
    const alpha = (0.2 + 0.16 * d) * D * level(), off = i * 97.3;
    const y0 = Math.max(buf.oy, Math.floor(top)), y1 = Math.min(buf.oy + buf.h - 1, Math.ceil(bottom));
    const x0 = Math.max(buf.ox, Math.floor(X0)), x1 = Math.min(buf.ox + buf.w - 1, Math.ceil(X1));
    if (alpha <= 0.01 || y0 > y1 || x0 > x1) return;
    const crest = mix(TONES[2]!, WHITE, 0.14 + 0.12 * d), dense = 0.6 + 0.5 * D;
    const thick = (P: number, n: number) => (P * 0.72 + (clamp((n - 0.5) * 2.6 + 0.5) - 0.5) * 0.95) * dense;
    const prof = (y: number) => smooth(top, base, y) * (1 - smooth(bottom - 3, bottom + 1, y));
    if (edges.length < x1 - x0 + 1) (edges = new Float32Array(x1 - x0 + 1)), (breaths = new Float32Array(x1 - x0 + 1));
    for (let x = x0; x <= x1; x++) {
      edges[x - x0] = smooth(X0, X0 + 40, x) * (1 - smooth(X1 - 40, X1, x));
      breaths[x - x0] = 2.4 * Math.sin(t * 0.35 + x * 0.013 + i * 1.7);
    }
    for (let y = y0; y <= y1; y++) {
      const p = prof(y), pUp = prof(y - 2);
      if (p <= 0.02) continue;
      let wu = 0;
      for (let x = x0; x <= x1; x++) {
        const edge = edges[x - x0]!;
        if (edge <= 0.02) continue;
        if (((x - x0) & 1) === 0) wu = sample(field, x * 0.35 + curl * 9 + off, y * 0.6 - curl * 3) - 0.5;
        const breath = breaths[x - x0]!, u = x * sx - drift + wu * 30 + off;
        const f = thick(p, sample(field, u, (y + breath) * sy + wu * 12)) * edge;
        const b = (BAYER[((y & 3) << 2) | (x & 3)]! + 0.5) / 16;
        let c = -1;
        if (f > T2 + BW || (f > T2 && (f - T2) / BW > b)) c = 2;
        else if (f > T1 + BW || (f > T1 && (f - T1) / BW > b)) c = 1;
        else if (f > T0 + BW || (f > T0 && (f - T0) / BW > b)) c = 0;
        if (c < 0) continue;
        if (c >= 1 && thick(pUp, sample(field, u, (y - 2 + breath) * sy + wu * 12)) * edge < (c === 2 ? T2 : T1) - 0.03) {
          buf.blend(x, y, crest, alpha * (0.95 + 0.15 * c));
          continue;
        }
        buf.blend(x, y, TONES[c]!, alpha * (0.6 + 0.2 * c));
      }
    }
  }
  return {
    update(dt: number) { t += dt; },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color);
      for (let i = 0; i < N; i++) { if (layer === (N > 1 && i === N - 1 ? "back" : "front")) continue; bank(buf, N === 1 ? 0.5 : i / (N - 1), i); }
    },
    stop() { if (stopAt === Infinity) stopAt = t; },
    done: () => level() <= 0,
  };
}
const T0 = 0.3, T1 = 0.52, T2 = 0.74, BW = 0.07;
const FW = 256, FH = 128;
function bake(seed: number): Float32Array {
  const out = new Float32Array(FW * FH);
  let amp = 0.5, total = 0;
  for (const cells of [4, 8, 16, 32]) {
    const cs = FW / cells, rows = FH / cs;
    const h = (a: number, b: number) => hash((((a % cells) + cells) % cells) + (((b % rows) + rows) % rows) * 1000, seed * 31 + cells);
    for (let y = 0; y < FH; y++)
      for (let x = 0; x < FW; x++) {
        const gx = x / cs, gy = y / cs, ix = Math.floor(gx), iy = Math.floor(gy), u = gx - ix, v = gy - iy;
        const su = u * u * (3 - 2 * u), sv = v * v * (3 - 2 * v);
        const top = h(ix, iy) + (h(ix + 1, iy) - h(ix, iy)) * su, bot = h(ix, iy + 1) + (h(ix + 1, iy + 1) - h(ix, iy + 1)) * su;
        out[y * FW + x]! += (top + (bot - top) * sv) * amp;
      }
    total += amp;
    amp *= 0.5;
  }
  for (let i = 0; i < out.length; i++) out[i] = out[i]! / total;
  return out;
}
function sample(f: Float32Array, u: number, v: number) {
  const x = Math.floor(u), y = Math.floor(v), fx = u - x, fy = v - y;
  const x0 = x & (FW - 1), x1 = (x0 + 1) & (FW - 1), y0 = y & (FH - 1), y1 = (y0 + 1) & (FH - 1);
  const a = f[y0 * FW + x0]!, b = f[y0 * FW + x1]!, c = f[y1 * FW + x0]!, d = f[y1 * FW + x1]!;
  return a + (b - a) * fx + (c - a + (a - b - c + d) * fx) * fy;
}
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  blend(x: number, y: number, c: number, a: number) {
    const i = this.at(x, y);
    if (i < 0) return;
    const d = this.data[i]!, oa = a + ((d >>> 24) / 255) * (1 - a);
    if (oa <= 0) return;
    const k = a / oa, j = 1 - k, r = (c & 255) * k + (d & 255) * j, g = ((c >>> 8) & 255) * k + ((d >>> 8) & 255) * j, b = ((c >>> 16) & 255) * k + ((d >>> 16) & 255) * j;
    this.data[i] = ((oa * 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255);
  }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.slice(1), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
}
const WHITE = hex("#ffffff");
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
```
