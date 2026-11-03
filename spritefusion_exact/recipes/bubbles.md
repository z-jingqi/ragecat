# Bubbles (bubbles.ts)

Underwater: bubbles wobbling and growing as they rise from vents, merging and popping at a shimmering surface, specks drifting, caustic light dancing on the floor. A loop filling any area.

Previews (animated WebP, 320 × 200 art pixels): Underwater https://www.spritefusion.com/images/pixel-art-vfx/bubbles-underwater.webp

Page: https://www.spritefusion.com/pixel-art-vfx/bubbles. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/bubbles.zip

## Recipe
- **Timeline:**
  - Start: full from t = 0. Each vent's stream is pre-placed from the ground up to the surface, spaced 18–46 units ÷ density, already at rise speed. The higher bubbles are up to 1.4× bigger, as if grown. The preview is recorded from 2 s.
  - Streams: each vent releases 2–5 bubbles/s (5 × density × 0.4–1.0, the factor a slow noise). This is accumulated over time, so it does not depend on frame rate.
  - Bursts: each vent bursts every 1.4–3.2 s, the first after 0.5–2.5 s. A burst is 5–10 bigger bubbles stacked 5 units apart plus 5 sand specks kicked up beside the vent.
  - A bubble rises until it is 2 units below the surface, then pops: a 0.2 s ring.
  - `stop()`: vents stop releasing and bursting. The bubbles rise out and pop; the slowest, smallest ones rise at about 53 units/s. `done()` turns true when no bubble and no pop is left. The water (tint, caustics, surface, vents, specks) keeps drawing until then and goes with it.
- **Layers:**
  - "back", in order: the water tint (colour, alpha-blended), the caustics (light buffer only), the surface (colour plus light), the vents, the far specks (70%), the far bubbles (65%) and the pops.
  - "front": the near bubbles (35%), then the near specks (30%).
  - Bubbles add a faint glow to the light buffer. Apart from the tint, every colour pixel is opaque.
- **Palette:**
  - Bubbles, light to dark:
    - #ffffff (`colors[0]`): highlight px, surface glints, a pop's first 0.1 s.
    - #c6f3ff (`colors[1]`): upper-left rim, the surface line, bright caustic lines, a pop's last 0.1 s, droplets, speck glints.
    - #68bfe6 (`colors[2]`): side rims, the row under the surface line, the bubble glow, faint caustic lines.
    - #2f7fb6 (`colors[3]`): lower-right rim, the surface's dithered underside.
    - Inside fill: #4b9fce, the 50/50 mix of `colors[2]` and `colors[3]`.
  - Water tint: #0b3550.
  - Specks: #7fa3a8, #5f8a9a (also the stirred-up sand), #4c6f86.
  - Vent, light to dark: #62788a (lit pebbles), #3c4a5a (pebbles), #1a1422 (outline), #0a1018 (mouth).
- **Shapes and motion:**
  - Bubble motion:
    - Radius r is in art px. A stream bubble is 0.5–1.4 (70%) or 1.4–2.6 (30%); a burst bubble is 0.9–3.2. It grows 0.12 px/s up to 5.
    - Its vy eases at 3/s toward −(40 + 26r) units/s, so bigger bubbles rise faster: 66 units/s at r 1, 170 at r 5.
    - It wobbles: x = x0 + sin(ph) × (1 + 1.6r) units, with ph advancing 4 + 2/r rad/s. x0 wanders with noise × 6 units/s.
    - Merging: two bubbles with r ≥ 1 merge when their centres are within 0.75 × (r1 + r2) art px. The result has radius cbrt(r1³ + r2³) at their mean x0 and wobbles (squash 0.25, decaying at 4/s).
  - Bubble drawing, by size:
    - r < 0.9: 1 px, #68bfe6 below r 0.7 and #c6f3ff above.
    - r < 1.5: a 2 × 2 block: #ffffff top-left, #c6f3ff top-right, #68bfe6 bottom-left, #2f7fb6 bottom-right. It adds a light glow of radius 3 px in #c6f3ff at 0.12.
    - Larger: an ellipse rx = r(1 + sq), ry = r(1 − sq), with sq = 0.1 sin(2ph) × min(1, (r − 1.5) / 2) + 0.25 × merge wobble.
      - Ring: the pixels at distance r − 0.6 to r + 0.5 from the centre. Each is shaded by its facing toward the upper left: #c6f3ff above 0.45, #2f7fb6 below −0.55, otherwise #68bfe6.
      - Inside: #4b9fce on only 2 of the 16 Bayer cells.
      - Highlight: a #ffffff px at (−0.45rx, −0.45ry). From r 2.5 there are also #c6f3ff px to its right and below it.
      - From r 2, a #c6f3ff glint at (+0.5rx, +0.5ry).
      - A light glow of radius 2.4r + 2 px in #68bfe6 at 0.14.
  - Pop: a ring of radius r + 1 + 3k (k from 0 to 1 over 0.2 s), flattened to half height, with only its upper part drawn (sin a < 0.2). It is #ffffff, then #c6f3ff after 0.1 s, dithered at 1 − k. Bubbles over r 1.5 also throw 2 #c6f3ff droplets that rise 4–5 px.
  - Surface: one row per art column at the area's top, offset by round(1.2 sin(0.11x + 1.6t) + 1.6 sin(0.043x − 0.9t)) px.
    - Rows: the line is #c6f3ff, or #ffffff where sin(0.37x − 2.3t) × sin(0.13x + 1.1t) > 0.55 (glints). Under it comes 1 row of #68bfe6, then 5 rows of #2f7fb6 dithered at a coverage falling from 0.36 to 0.08.
    - Light: every 4th column adds a glow of radius 7 px in #c6f3ff at 0.09 (0.2 on a glint).
  - Caustics (light buffer only): rows from the surface down to 6 px below the ground. The ground height is taken at the area's middle.
    - Pattern: two warped sine fields; their zero lines form a moving net of bright lines.
    - Steps: values above 1.05 add #c6f3ff × 0.3, and values above 0.45 add #68bfe6 × 0.15. Each step is dithered from 0.8 and from 0.3.
    - Strength: full on the ground (from 1 px above it down); in the water it runs from 0.5 under the surface to 0.18 near the ground.
  - Tint: #0b3550 alpha-blended over every pixel from the surface to 1 px below the ground, at 20% under the surface and 32% at the ground.
  - Specks: 110 × `specks` single px scattered through the water.
    - Motion: they sink 2–8 units/s and sway with noise × 8 units/s. On reaching the ground they wrap to the top at a new x; stirred-up sand is removed instead.
    - Twinkle: a speck shows when its Bayer cell ≤ 0.55 + 0.3 sin(1.3t + seed), and is drawn #c6f3ff when that sine is above 0.85.
  - Vent: a 9 × 3 px mound sitting on the ground at the vent's x. Its rows are `.OOO.OOO.` / `OLPPMPPLO` / `LPPMMMPPL`, with O = #1a1422, L = #62788a, P = #3c4a5a and M = #0a1018 (the mouth). Bubbles leave it 3 units above the ground, within ±4 units of its x.
  - Light glows have a quadratic falloff ((1 − d/r)²) and are added with saturation.
- **Feel:** it reads best with the scene dimmed and blue; the effect's own tint adds #0b3550 at 20–32%.

## Situations
- **Underwater:** `bubbles({ area: { x: 0, y: 40, w: 640, h: 280 }, vents: [110, 440, 580] })`: streams and bursts of bubbles rising from three vents to a shimmering surface at y 40, popping there, with caustics on the ground at y 320.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `area` | `{ x, y, w, h }` (world units) | `{ x: 300, y: 260, w: 680, h: 340 }` | The water. Its top (y) is the surface where bubbles pop; its bottom (y + h) is the ground unless `ground` is given. |
| `ground` | `number` or `(x: number) => number` (world y, from world x) | area bottom | The floor: the vents, the specks' floor, and (read at the area's middle) the caustics' floor and the tint's bottom. |
| `vents` | `number[]` (world x) | 3, one per third of the area, each jittered ±0.3 of a third | Where the streams rise from. |
| `density` | number | `1` | Scales each vent's stream rate (5 × density × 0.4–1.0 bubbles/s) and the starting streams' spacing. Bursts are not scaled. |
| `surface` | boolean | `true` | The shimmering surface at the area's top and the pops there. Without it, bubbles vanish at the top. |
| `caustics` | boolean | `true` | The net of light dancing on the ground and, faintly, through the water. |
| `tint` | boolean | `true` | The water's blue (#0b3550, 20–32%) over the scene. |
| `specks` | number | `1` | Multiplier on the 110 drifting specks. |
| `colors` | `[string, string, string, string]` (hex) | `["#ffffff", "#c6f3ff", "#68bfe6", "#2f7fb6"]` | Highlight, lit rim, rim, shadowed rim. They colour the bubbles, the surface, the pops and the caustics; the inside fill is a mix of the last two. |
| `seed` | number | `1` | Seeds the vents, the bubbles and the specks. |

## Actor, methods and hooks
- `stop()`: call it when the scene leaves the water or the vents should go quiet. The bubbles rise out and pop, then `done()` turns true and the water drawing ends with it. It takes no actor and calls no hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: bubbles.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  area?: { x: number; y: number; w: number; h: number };
  ground?: number | ((x: number) => number);
  vents?: number[];
  density?: number;
  surface?: boolean;
  caustics?: boolean;
  tint?: boolean;
  specks?: number;
  colors?: [string, string, string, string];
  seed?: number;
}
export default function bubbles(o: Options = {}) {
  const A = o.area ?? { x: 300, y: 260, w: 680, h: 340 }, X0 = A.x, X1 = A.x + A.w, TOP = A.y;
  const groundAt = (x: number) => (o.ground === undefined ? A.y + A.h : typeof o.ground === "number" ? o.ground : o.ground(x));
  const R = new Rng(o.seed ?? 1), D = o.density ?? 1, SURFACE = o.surface ?? true, NS = Math.round(110 * (o.specks ?? 1));
  const [HI, LIT, RIM, SHADE] = (o.colors ?? ["#ffffff", "#c6f3ff", "#68bfe6", "#2f7fb6"]).map(hex) as [number, number, number, number];
  const FILL = mix(RIM, SHADE, 0.5);
  const vents = (o.vents ?? Array.from({ length: 3 }, (_, i) => X0 + ((i + 0.5 + R.range(-0.3, 0.3)) / 3) * A.w)).map((x) => ({ x, acc: R.next(), burst: R.range(0.5, 2.5), seed: R.range(0, 100) }));
  const list: Bubble[] = [], pops: { x: number; y: number; r: number; t: number }[] = [];
  let t = 0, stopped = false;
  const spawn = (v: (typeof vents)[number], y: number, big: number) => {
    const r = big ? R.range(1.5, 3.2) * big : R.chance(0.7) ? R.range(0.5, 1.4) : R.range(1.4, 2.6);
    list.push({ x0: v.x + R.range(-4, 4), x: v.x, y, r, vy: 0, ph: R.range(0, TAU), wob: 0, near: R.chance(0.35) });
  };
  for (const v of vents)
    for (let y = groundAt(v.x) - 4; y > TOP; y -= R.range(18, 46) / D) {
      spawn(v, y, 0);
      const b = list[list.length - 1]!;
      b.r *= 1 + (1 - (y - TOP) / A.h) * 0.4;
      b.vy = -(40 + 26 * b.r);
    }
  const specks = Array.from({ length: NS }, () => ({ x: R.range(X0, X1), y: R.range(TOP, groundAt(X0)), seed: R.range(0, 100), c: R.int(0, 2), near: R.chance(0.3) }));
  function drawBubble(buf: Px, light: Px, b: Bubble) {
    const cx = b.x / PX, cy = b.y / PX, r = b.r;
    if (r < 0.9) { buf.set(Math.floor(cx), Math.floor(cy), r < 0.7 ? RIM : LIT); return; }
    if (r < 1.5) {
      const px = Math.floor(cx), py = Math.floor(cy);
      buf.set(px, py, HI);
      buf.set(px + 1, py, LIT);
      buf.set(px, py + 1, RIM);
      buf.set(px + 1, py + 1, SHADE);
      light.glow(cx + 0.5, cy + 0.5, 3, LIT, 0.12);
      return;
    }
    const sq = 0.1 * Math.sin(b.ph * 2) * Math.min(1, (r - 1.5) / 2) + b.wob * 0.25, rx = r * (1 + sq), ry = r * (1 - sq);
    for (let y = Math.floor(cy - ry - 1); y <= Math.ceil(cy + ry + 1); y++)
      for (let x = Math.floor(cx - rx - 1); x <= Math.ceil(cx + rx + 1); x++) {
        const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, d = Math.sqrt(dx * dx + dy * dy) * r;
        if (d > r + 0.5) continue;
        const lit = (-dx - dy) / Math.SQRT2 / Math.max(0.01, d / r);
        if (d > r - 0.6) buf.set(x, y, lit > 0.45 ? LIT : lit < -0.55 ? SHADE : RIM);
        else if (bayer(x, y) < 0.12) buf.set(x, y, FILL);
      }
    const hx = Math.round(cx - rx * 0.45), hy = Math.round(cy - ry * 0.45);
    buf.set(hx, hy, HI);
    if (r >= 2.5) buf.set(hx + 1, hy, LIT), buf.set(hx, hy + 1, LIT);
    if (r >= 2) buf.set(Math.round(cx + rx * 0.5), Math.round(cy + ry * 0.5), LIT);
    light.glow(cx, cy, r * 2.4 + 2, RIM, 0.14);
  }
  function drawSurface(buf: Px, light: Px) {
    const y0 = TOP / PX, x0 = Math.max(buf.ox, Math.floor(X0 / PX)), x1 = Math.min(buf.ox + buf.w - 1, Math.ceil(X1 / PX));
    for (let x = x0; x <= x1; x++) {
      const sy = Math.round(y0 + (Math.sin(x * 0.11 + t * 1.6) * 1.2 + Math.sin(x * 0.043 - t * 0.9) * 1.6));
      const glint = Math.sin(x * 0.37 - t * 2.3) * Math.sin(x * 0.13 + t * 1.1) > 0.55;
      buf.set(x, sy, glint ? HI : LIT);
      buf.set(x, sy + 1, RIM);
      for (let k = 2; k < 7; k++) if (bayer(x, sy + k) < 0.5 - k * 0.07) buf.set(x, sy + k, SHADE);
      if ((x & 3) === 0) light.glow(x, sy + 2, 7, LIT, glint ? 0.2 : 0.09);
    }
  }
  function drawCaustics(light: Px) {
    const gy = Math.round(groundAt((X0 + X1) / 2) / PX), top = Math.floor(TOP / PX);
    const x0 = Math.max(light.ox, Math.floor(X0 / PX)), x1 = Math.min(light.ox + light.w - 1, Math.ceil(X1 / PX));
    const y0 = Math.max(light.oy, top), y1 = Math.min(light.oy + light.h - 1, gy + 6);
    for (let y = y0; y <= y1; y++) {
      const k = y >= gy - 1 ? 1 : 0.18 + 0.32 * (1 - (y - top) / Math.max(1, gy - top));
      for (let x = x0; x <= x1; x++) {
        const u = x * 0.16 + 1.9 * Math.sin(y * 0.12 + t * 0.9), v = y * 0.19 + 1.9 * Math.sin(x * 0.1 - t * 0.7);
        const n1 = Math.sin(u) + Math.sin(v), n2 = Math.sin(x * 0.09 + y * 0.07 + 1.4 * Math.sin(y * 0.15 - t * 0.6)) + Math.sin(y * 0.11 - x * 0.05 + 1.4 * Math.sin(x * 0.13 + t * 0.8));
        const f = (Math.max(0, 1 - Math.abs(n1) * 3) + 0.7 * Math.max(0, 1 - Math.abs(n2) * 3)) * k, d = bayer(x, y);
        if (f > 1.05 || (f > 0.8 && d < (f - 0.8) / 0.25)) light.add(x, y, LIT, 0.3);
        else if (f > 0.45 || (f > 0.3 && d < (f - 0.3) / 0.15)) light.add(x, y, RIM, 0.15);
      }
    }
  }
  function tintWater(buf: Px) {
    const top = Math.floor(TOP / PX), gy = Math.ceil(groundAt((X0 + X1) / 2) / PX) + 1;
    const x0 = Math.max(buf.ox, Math.floor(X0 / PX)), x1 = Math.min(buf.ox + buf.w - 1, Math.ceil(X1 / PX));
    for (let y = Math.max(buf.oy, top); y <= Math.min(buf.oy + buf.h - 1, gy); y++) for (let x = x0; x <= x1; x++) buf.blend(x, y, WATER, 0.2 + 0.12 * ((y - top) / Math.max(1, gy - top)));
  }
  function drawSpeck(buf: Px, s: (typeof specks)[number]) {
    const x = Math.floor(s.x / PX), y = Math.floor(s.y / PX), tw = Math.sin(t * 1.3 + s.seed);
    if (bayer(x, y) > 0.55 + 0.3 * tw) return;
    buf.set(x, y, tw > 0.85 ? LIT : SPECKS[s.c]!);
  }
  function drawPop(buf: Px, p: (typeof pops)[number]) {
    const k = p.t / 0.2, x = p.x / PX, y = p.y / PX, r = p.r + 1 + k * 3;
    for (let a = 0; a < TAU; a += 0.5 / r) if (Math.sin(a) < 0.2) dot(buf, x + Math.cos(a) * r, y + Math.sin(a) * r * 0.5, k < 0.5 ? HI : LIT, 1 - k);
    if (p.r > 1.5) dot(buf, x - 2, y - 2 - k * 4, LIT, 1 - k), dot(buf, x + 2, y - 3 - k * 5, LIT, 1 - k);
  }
  return {
    update(dt: number) {
      t += dt;
      if (!stopped)
        for (const v of vents) {
          v.acc += dt * 5 * D * (0.7 + 0.3 * noise(t * 0.8 + v.seed, 3));
          for (; v.acc > 1; v.acc--) spawn(v, groundAt(v.x) - 3, 0);
          if ((v.burst -= dt) < 0) {
            v.burst = R.range(1.4, 3.2);
            for (let i = 0; i < R.int(5, 10); i++) spawn(v, groundAt(v.x) - 3 - i * 5, R.range(0.6, 1));
            for (let i = 0; i < 5; i++) specks.push({ x: v.x + R.range(-8, 8), y: groundAt(v.x) - R.range(2, 10), seed: R.range(0, 100), c: 0, near: false });
          }
        }
      for (let i = list.length - 1; i >= 0; i--) {
        const b = list[i]!;
        b.vy += (-(40 + 26 * b.r) - b.vy) * Math.min(1, dt * 3);
        b.y += b.vy * dt;
        b.ph += dt * (4 + 2 / b.r);
        b.x = b.x0 + Math.sin(b.ph) * (1 + b.r * 1.6);
        b.x0 += noise(t * 0.4 + i * 0.13, 5) * 6 * dt;
        b.r = Math.min(5, b.r + dt * 0.12);
        b.wob *= 1 - Math.min(1, dt * 4);
        if (b.y < TOP + 2) { if (SURFACE) pops.push({ x: b.x, y: TOP, r: b.r, t: 0 }); list.splice(i, 1); }
      }
      for (let i = 0; i < list.length; i++) {
        const a = list[i]!;
        if (a.r < 1) continue;
        for (let j = i + 1; j < list.length; j++) {
          const b = list[j]!;
          if (b.r < 1 || Math.hypot(a.x - b.x, a.y - b.y) / PX > (a.r + b.r) * 0.75) continue;
          a.r = Math.cbrt(a.r ** 3 + b.r ** 3);
          a.x0 = (a.x0 + b.x0) / 2;
          a.wob = 1;
          list.splice(j--, 1);
        }
      }
      for (let i = pops.length - 1; i >= 0; i--) if ((pops[i]!.t += dt) > 0.2) pops.splice(i, 1);
      for (let i = 0; i < specks.length; i++) {
        const s = specks[i]!;
        s.y += (5 + 3 * Math.sin(s.seed)) * dt;
        s.x += noise(t * 0.3 + s.seed, 9) * 8 * dt;
        if (s.y > groundAt(s.x) - 1) { if (i >= NS) specks.splice(i--, 1); else (s.y = TOP + 2), (s.x = R.range(X0, X1)); }
      }
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") {
        if (o.tint ?? true) tintWater(buf);
        if (o.caustics ?? true) drawCaustics(light);
        if (SURFACE) drawSurface(buf, light);
        for (const v of vents) {
          const cx = Math.round(v.x / PX), gy = Math.round(groundAt(v.x) / PX);
          for (const [dx, dy, c] of VENT) buf.set(cx + dx, gy + dy, c);
        }
        for (const s of specks) if (!s.near) drawSpeck(buf, s);
        for (const b of list) if (!b.near) drawBubble(buf, light, b);
        for (const p of pops) drawPop(buf, p);
      }
      if (layer !== "back") { for (const b of list) if (b.near) drawBubble(buf, light, b); for (const s of specks) if (s.near) drawSpeck(buf, s); }
    },
    stop() { stopped = true; },
    done: () => stopped && list.length === 0 && pops.length === 0,
  };
}
interface Bubble { x0: number; x: number; y: number; r: number; vy: number; ph: number; wob: number; near: boolean }
const WATER = hex("#0b3550");
const SPECKS = ["#5f8a9a", "#7fa3a8", "#4c6f86"].map(hex);
const VENT: [number, number, number][] = [];
[".OOO.OOO.", "OLPPMPPLO", "LPPMMMPPL"].forEach((r, y) => [...r].forEach((c, x) => c !== "." && VENT.push([x - 4, y - 3, hex({ O: "#1a1422", L: "#62788a", M: "#0a1018", P: "#3c4a5a" }[c]!)])));
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
function hex(h: string) { const v = parseInt(h.slice(1), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
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
  chance(p: number) { return this.next() < p; }
}
const TAU = Math.PI * 2;
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return hash(i, seed) * 2 - 1 + (hash(i + 1, seed) - hash(i, seed)) * 2 * u;
}
```
