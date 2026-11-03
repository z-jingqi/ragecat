# Falling Leaves (falling-leaves.ts)

Leaves of several shapes falling like pendulums onto a litter on the ground, in autumn colours or your own. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Autumn https://www.spritefusion.com/images/pixel-art-vfx/falling-leaves-autumn.webp

Page: https://www.spritefusion.com/pixel-art-vfx/falling-leaves. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/falling-leaves.zip

## Recipe
- **Timeline:**
  - Start: full from t = 0. All `leaves` are placed at random heights between the area's top and 20 units above the ground. The preview is recorded from 5 s.
  - One leaf's life: it falls swinging (a 2.2–3.5 s swing period) until it is within 2 units of the ground. It lies there 2.5–5 s, dithering out over its last 1 s, then respawns 0–40 units above the area's top with new random traits. A fall through 320 units takes about 6–9 s.
  - `stop()`: landed leaves stop respawning. The ones still in the air keep falling, land, lie and fade. `done()` turns true when the last one has faded, at most about (fall height / 34 units/s) + 5 s later. The litter stays at full strength until then.
- **Layers:** "back" holds the litter, then the far leaves (65%). "front" holds the near leaves (35%). Colour buffer only, opaque pixels; the resting fade is a 4 × 4 Bayer dither. Nothing goes in the light buffer.
- **Palette:** four palettes, each light to dark:
  - orange #ffc86a, #f08a2a, #b8521a, #5e240e
  - red #ff8a66, #d8382a, #9a1f22, #470f15
  - yellow #fff09a, #f0c83a, #b88a1c, #5a3f10
  - brown #c99a62, #9a6a3b, #6b4424, #33200f
  - In the sprites the steps are L (light, the upper-left lobes), B (body), S (shade, lower right) and D (dark: the 1 px outline). The rib R uses the shade colour and the stem T the dark one. Each leaf, litter leaf included, picks one palette at random.
- **Shapes and motion:**
  - Sprites: three pixel maps, rebuilt for each palette.
    - An oval leaf, 12 × 7, with its stem on the left and a rib along its length.
    - A round leaf, 9 × 8, with its stem below.
    - A maple leaf, 11 × 10, with three lobes and its stem below.
  - Rotation and squash: sprites are drawn rotated about their centre (at whole art px) by inverse-mapped nearest-neighbour sampling, so there are no holes and no smoothing. A horizontal squash is applied in the sprite's own frame.
  - Fall: vy is 34–56 units/s, scaled by 0.45 + 0.9 × |cos ph|. The leaf is quickest through the middle of its swing and slows at either end, averaging 1.02 × vy.
  - Swing: x = x0 + sin(ph) × amp. amp is 14–34 units, ph advances at 1.8–2.8 rad/s, and x0 drifts at `drift` units/s.
  - Tilt: cos(ph) × 0.75 rad (±43°), swinging with the leaf. Far leaves carry an extra 0.3 rad.
  - Flip: a flip phase drives the width scale 0.35 + 0.65 × |cos(flip)|, which turns the leaf edge-on and back. The phase advances at 0.4 rad/s, or 6 rad/s for about 25% of its (half-swing index, whole-unit x0) hash keys: quick, irregular flips.
  - Spawn spread: x0 is drawn from x − 40 to x + w.
  - Landed: the leaf lies on the ground (its bottom 1 px below the ground line) at 0.3 × its last tilt, without squash.
  - Litter: 40 leaves spread from 20 art px left of the area to 20 px past its right. Each has a random shape and palette and a tilt of ±0.3 rad, centred 1 px above the ground line, so about half sinks below it. The litter never moves.

## Situations
- **Autumn:** `fallingLeaves({ area: { x: 0, y: 0, w: 640, h: 320 } })`: 80 orange, red, yellow and brown leaves swinging down from above the screen onto a litter on the ground at y 320.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 300, y: 230, w: 680, h: 370 }` | Leaves enter 0–40 units above its top, across x − 40 to x + w. Its bottom (y + h) is the ground unless `ground` is given. |
| `ground` | `number` or `(x: number) => number` (world y, from world x) | area bottom | Where leaves land and the litter lies. |
| `leaves` | number | `80` | How many leaves are in the loop at once; each respawns at the top after resting. |
| `colors` | `[string, string, string, string][]` (hex) | the 4 palettes above (orange, red, yellow, brown) | The palettes, each [light, body, shade, dark]. Each leaf picks one at random. |
| `drift` | number (world units/s) | `12` | The breeze carrying the leaves sideways, + to the right. |
| `litter` | boolean | `true` | The 40 leaves already lying on the ground ("back"). |
| `seed` | number | `1` | Seeds every leaf's traits. |

## Actor, methods and hooks
- `stop()`: call it when the leaves should stop falling. The ones in the air land and fade, then `done()` turns true and the litter goes with it. It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: falling-leaves.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  area?: { x: number; y: number; w: number; h: number };
  ground?: number | ((x: number) => number);
  leaves?: number;
  colors?: [string, string, string, string][];
  drift?: number;
  litter?: boolean;
  seed?: number;
}
export default function fallingLeaves(o: Options = {}) {
  const A = o.area ?? { x: 300, y: 230, w: 680, h: 370 }, X0 = A.x, X1 = A.x + A.w, TOP = A.y;
  const groundAt = (x: number) => (o.ground === undefined ? A.y + A.h : typeof o.ground === "number" ? o.ground : o.ground(x));
  const R = new Rng(o.seed ?? 1), DRIFT = o.drift ?? 12;
  const pals = (o.colors ?? PALETTES).map((p) => { const [L, B, S, D] = p.map(hex) as [number, number, number, number]; return { L, B, S, D, R: S, T: D } });
  const LEAVES = SHAPES.map((rows) => pals.map((p) => sprite(rows, p)));
  const leaves: Leaf[] = [];
  const reset = (l: Leaf, top: boolean) => {
    l.x0 = R.range(X0 - 40, X1);
    l.y = top ? TOP - R.range(0, 40) : R.range(TOP, groundAt(l.x0) - 20);
    l.vy = R.range(34, 56);
    l.amp = R.range(14, 34);
    l.w = R.range(1.8, 2.8);
    l.ph = R.range(0, TAU);
    l.flip = R.range(0, TAU);
    l.near = R.chance(0.35);
    l.shape = R.int(0, 2);
    l.pal = R.int(0, pals.length - 1);
    l.rest = -1;
    l.ang = 0;
    l.x = l.x0;
  };
  for (let i = 0; i < (o.leaves ?? 80); i++) {
    const l: Leaf = { x0: 0, x: 0, y: 0, vy: 0, amp: 0, w: 0, ph: 0, flip: 0, shape: 0, pal: 0, near: false, rest: -1, ang: 0 };
    reset(l, false);
    leaves.push(l);
  }
  const litter = (o.litter ?? true) ? Array.from({ length: 40 }, (_, i) => ({ x: X0 / PX - 20 + hash(i, 1) * ((X1 - X0) / PX + 40), shape: Math.floor(hash(i, 2) * 3), pal: Math.floor(hash(i, 4) * pals.length), ang: (hash(i, 5) - 0.5) * 0.6 })) : [];
  let stopped = false;
  const again = (i: number) => (stopped ? leaves.splice(i, 1) : reset(leaves[i]!, true));
  const draw = (buf: Px, near: boolean) => {
    for (const l of leaves) {
      if (l.near !== near) continue;
      const s = LEAVES[l.shape]![l.pal]!;
      if (l.rest >= 0) blitRot(buf, s, l.x / PX, groundAt(l.x) / PX - s.h / 2 + 1, l.ang * 0.3, Math.min(1, l.rest));
      else blitRot(buf, s, l.x / PX, l.y / PX, l.ang, 1, 0.35 + 0.65 * Math.abs(Math.cos(l.flip)));
    }
  };
  return {
    update(dt: number) {
      for (let i = leaves.length - 1; i >= 0; i--) {
        const l = leaves[i]!;
        if (l.rest >= 0) { if ((l.rest -= dt) < 0) again(i); continue; }
        l.ph += l.w * dt;
        l.x0 += DRIFT * dt;
        l.x = l.x0 + Math.sin(l.ph) * l.amp;
        l.y += l.vy * (0.45 + 0.9 * Math.abs(Math.cos(l.ph))) * dt;
        l.ang = Math.cos(l.ph) * 0.75 + (l.near ? 0 : 0.3);
        l.flip += (hash(Math.floor(l.ph / Math.PI), Math.floor(l.x0)) < 0.25 ? 6 : 0.4) * dt;
        const g = groundAt(l.x);
        if (l.y >= g - 2) { l.y = g - 2; l.rest = R.range(2.5, 5); }
      }
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color);
      if (layer !== "front") { for (const l of litter) blitRot(buf, LEAVES[l.shape]![l.pal]!, l.x, groundAt(l.x * PX) / PX - 1, l.ang); draw(buf, false); }
      if (layer !== "back") draw(buf, true);
    },
    stop() { stopped = true; },
    done: () => stopped && leaves.length === 0,
  };
}
interface Leaf {
  x0: number;
  x: number;
  y: number;
  vy: number;
  amp: number;
  w: number;
  ph: number;
  flip: number;
  shape: number;
  pal: number;
  near: boolean;
  rest: number;
  ang: number;
}
const SHAPES = [
  ["......DDDD..", "...DDDLLLBD.", ".DDLLLRLBBBD", "TRRRRRRRRRRD", ".DDBBBBBRSSD", "...DDDSSSSD.", "......DDDD.."],
  ["...DDD...", "..DLLBD..", ".DLLLBBD.", "DLLRBBBSD", "DLBBRBSSD", ".DBBBRSD.", "..DDSSD..", "....T...."],
  [".....D.....", "....DLD....", ".DD.DLD.DD.", ".DLDDLDDLD.", "..DLLLBBD..", "DDDLLRBBDDD", ".DLLBRBSSD.", "..DDBRSDD..", "....DRD....", ".....T....."],
];
const PALETTES: [string, string, string, string][] = [
  ["#ffc86a", "#f08a2a", "#b8521a", "#5e240e"],
  ["#ff8a66", "#d8382a", "#9a1f22", "#470f15"],
  ["#fff09a", "#f0c83a", "#b88a1c", "#5a3f10"],
  ["#c99a62", "#9a6a3b", "#6b4424", "#33200f"],
];
const PX = 2;
class Px {
  w: number; h: number; ox: number; oy: number; data: Uint32Array;
  constructor(f: Frame, data: Uint32Array) { this.w = f.w; this.h = f.h; this.ox = f.ox; this.oy = f.oy; this.data = data; }
  at(x: number, y: number) { x = (x - this.ox) | 0; y = (y - this.oy) | 0; return x < 0 || y < 0 || x >= this.w || y >= this.h ? -1 : y * this.w + x; }
  set(x: number, y: number, c: number) { const i = this.at(x, y); if (i >= 0) this.data[i] = c; }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
interface Sprite { w: number; h: number; data: Uint32Array }
function sprite(rows: string[], pal: Record<string, number>): Sprite {
  const h = rows.length, w = Math.max(...rows.map((r) => r.length)), data = new Uint32Array(w * h);
  rows.forEach((r, y) => [...r].forEach((ch, x) => ch !== "." && (data[y * w + x] = pal[ch] ?? 0)));
  return { w, h, data };
}
function blitRot(buf: Px, s: Sprite, cx: number, cy: number, ang: number, a = 1, sx = 1) {
  const c = Math.cos(ang), sn = Math.sin(ang), r = Math.ceil(Math.hypot(s.w * Math.abs(sx), s.h) / 2) + 1, px0 = Math.round(cx), py0 = Math.round(cy);
  for (let y = -r; y <= r; y++)
    for (let x = -r; x <= r; x++) {
      const u = (c * x + sn * y) / (sx || 1e-3) + s.w / 2, v = -sn * x + c * y + s.h / 2, iu = Math.floor(u), iv = Math.floor(v);
      if (iu < 0 || iv < 0 || iu >= s.w || iv >= s.h) continue;
      const col = s.data[iv * s.w + iu]!, px = px0 + x, py = py0 + y;
      if (!(col >>> 24) || (a < 1 && a <= (BAYER[((py & 3) << 2) | (px & 3)]! + 0.5) / 16)) continue;
      buf.set(px, py, col);
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
```
