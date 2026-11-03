# Impact (impact.ts)

A bullet's hit: a star stretched along the bounce breaking into shards, a ring, hot sparks, chips and dust in the surface's colour. Glancing shots ricochet in a hot streak. One call per shot.

Previews (animated WebP, 320 × 200 art pixels): Hits https://www.spritefusion.com/images/pixel-art-vfx/impact-hits-and-ricochets.webp

Page: https://www.spritefusion.com/pixel-art-vfx/impact. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/impact.zip

## Recipe
- **Timeline:** one call is one bullet. Values are for `size` 1, with S = `size`.
  - The star frames are windows on the effect's clock, not counted updates. Frame 1 is t ≤ 1/60 s, and includes a draw before the first update. Frame 2 is t ≤ 2/60 s. Keep them as time windows at any frame rate.
  - Frame 1 (0–0.017 s): a sharp 8-spike star: white core, hot body, deep orange rim, stretched along the bounce.
  - Frame 2 (to 0.033 s): the same star, 1.25× as long, 0.55× as thick and one ramp step cooler, so it flares and hollows out.
  - 0.033–0.13 s: the star is gone. Its 4 longest spikes break into crescent shards that fly out, cool, narrow and dither out.
  - 0.033–0.2 s: a ring races out from 8 to 20 art px, thinning and breaking up.
  - 0–~0.1 s: its light pops, decaying as e^(−t/0.05).
  - Sparks live 0.1–0.3 s (a ricochet's × 1.3).
  - On a surface:
    - Dust lives 0.35–0.7 s.
    - Chips fall, bounce and rest. They are gone by 0.8–1.4 s.
    - A smoke wisp starts at 0.05 s and rises for 0.8–1.3 s.
  - A ricochet:
    - 0–0.16 s: a hot streak races off along the bounce.
    - With `surface` only: a scrape behind the hit glows, cools to soot by 0.9 s, and is gone at 1.1 s.
  - `done()` turns true after 0.2 s (hit) or 1.1 s (ricochet), once particles are gone: about 0.3 s mid-air and 1.3–1.4 s on a surface.
- **Layers:**
  - "back": the ricochet's scrape, then chips, dust and smoke.
  - "front": the star, the shards, the ring, the ricochet's streak, the sparks.
  - Light buffer: additive glows that fall off as (1 − d/r)² × strength, with r in art px.
    - The pop (front): r 22S + 6 in C3 at 0.9·pop, and r 8S + 2 in C0 at 0.7·pop, with pop = e^(−t/0.05).
    - Each spark: r 3, 0.45 × life left.
    - The streak's head: r 9 in C2, 0.6 × (1 − t/0.16).
    - The scrape: r 4 every 3 px, in C3, 0.3 × heat × (1 − distance fraction).
  - Dust and smoke are alpha-blended discs. Everything else is opaque pixels.
- **Palette:** `ramp` is 6 colours, white-hot to dark. The default is warm: C0 #ffffff, C1 #fff3a6, C2 #ffe26b, C3 #ff8a2a, C4 #f2561d, C5 #c9281f.
  - Star, frame 1: core C0; inner C2 over the first 35% of each spike; body C1 beyond; rim C4. The centre disc is C0 inside a C2 ring.
  - Star, frame 2: core C1, inner C3, body C2, rim C4.
  - Shards: C2, then C3 from 40% of their life, then C4 from 70%.
  - Ring: C1, then C2 from 30%, then C3 from 60%.
  - Sparks: the head is C1 above 60% of life left, C2 above 30%, then C3. The tail matches the head in the first half of life and is C4 after.
  - Streak: its front 20% C0, the middle C1, its back 40% C3.
  - Scrape: C1 → C3 → C5 as it cools, then soot #0d0a12.
  - From `surface` (e.g. #4a3f69):
    - Chips: × 1.25 for half of them (#5c4e83), as is for a quarter, × 0.7 for a quarter (#332c49). A 2 px chip's lower pixel is × 0.8.
    - Dust: 35% toward #968c96 (#645978).
  - Smoke wisp: starts #6a6278 and mixes by age into #7b6f72, #5d5660, #433d48, #2b2630, #1a171e.
  - The preview's cyan ramp: #ffffff, #dffcff, #7ff3ff, #1ab8e6, #1a6fb8, #183a7a.
- **Shapes and motion:** sizes are in art px and speeds in world units/s. Gravity g = 1900 units/s². Drag is v −= v·drag·dt. Fades are 4 × 4 Bayer ordered dither unless alpha is stated.
  - The bounce direction: on a surface, `angle` mirrored in `normal`. Mid-air, `angle` itself: it flies on through.
  - Star: 8 spikes, evenly spaced from the bounce direction with ±0.18 rad of jitter. Each is a tapered kite.
    - Length: (7–10) × S.
      - × (1 + 1.8 × cos³) toward the bounce, or 2.6 instead of 1.8 for a ricochet.
      - × (1 + 0.6 × cos³) backwards.
      - × 0.3 for spikes pointing into the surface.
      - × 0.6 for a ricochet's side spikes (|sin| > 0.6), which makes it flatter and longer.
    - Half-width: (1.5–2.1) × S × (1 − d/L) × min(1, 0.5 + d/3), so it is narrow at the centre, widest about 1.5 px out, and pointed.
    - Drawn in 3 passes: rim (+0.8 px), body, then core (0.45 of the width, over the first 55% of the length).
    - A centre disc of radius 2.4S (frame 2: about 2.2S) with a 0.8 px ring.
  - Shards: 1.4 px-thick crescent arcs, tapering to the horns, 0.35–0.6 rad wide and narrowing by 40%. They start at 0.8 × their spike's length and fly out at 5–8 spike-lengths per second, at opacity 1 − progress. On a surface they come only off the open side.
  - Ring: radius (8 → 20) × S, ease-out cubic; 2S → 1 px thick; dithered at opacity 1.15 − progress. On a surface only the open side is drawn (cos(a − normal) > −0.25).
  - Sparks: 18 for a hit and 21 for a ricochet (round(6 or 10 + 12S)). Each is a two-segment streak, length 1 + speed × 0.011 (max 9).
    - Direction: on a surface, a cone ±0.85 rad around the bounce. Mid-air, ±0.6 rad, with 20% going back the way it came. A ricochet: ±0.3 rad.
    - Speed: 260–900 × (0.6 + 0.4S), × 1.2 for a ricochet, plus −60 vertical (ricochet −20).
    - 0.45g, drag 2.2. They bounce on `ground` at × 0.45.
  - Chips (surface): 8 for a hit, 7 for a ricochet (round(3 or 2 + 5S)). 1 px, or 30% of them 2 px wide with a darker pixel under.
    - Thrown along the normal ±0.8 rad (a ricochet: along the bounce ±0.48) at 150–420 × S.
    - Full gravity, drag 0.6.
    - On landing faster than 220 they bounce at × 0.3. Otherwise they rest and dither out within 0.5 s. Life 0.8–1.4 s.
  - Dust (surface): 7 puffs (round(3 + 4S)) thrown along the normal ±1 rad at 20–90 × S, drag 4. Each is an alpha disc of radius (1.4–2.8) × √S growing 1.5×, at opacity 0.7 × (life left)^1.3.
  - Smoke (surface): 1 wisp, 4 units out along the normal, radius (1.6–2.4) × √S, rising at 32 units/s² and swaying.
    - Opacity a = min(1, 12·age) × min(1, 2.4 × life left) × 0.5.
    - Drawn as two alpha discs: radius r at 0.45a, and 0.74r offset down-right at 0.62a.
  - Ricochet streak: a 1 px line along the bounce.
    - Its head starts 6S px out and runs at 750 px/s (1500 units/s).
    - Its tail trails (20 + 110t) px behind.
    - Its back 40% (the C3 part) dithers out over 0.16 s.
  - Ricochet scrape: a 1 px line 9S px long, along the surface, back the way the bullet came. Its heat is T = 1 − t/0.9, and its colour is C1 where T × (1 − k) > 0.5, C3 above 0.25, else C5, where k runs from 0 at the hit to 1 at the far end. It is dithered from full at the hit to 40% at its end.
- **Feel:** one camera shake of 0.03 × size at creation: a tick. No flash and no ripple: the light pop is the punch.

## Situations
- **Hits:** `impact({ kind: "hit", x: 470, y: 300, angle: 0.19, size: 0.6, surface: 0xff693f4a, ground: 300, seed: 5 })`: one bullet striking a stone floor at y 300. The preview fires seven calls, 0.3 s apart, from a gun 54 units above the floor:
  - hits of size 0.6 to 1;
  - `kind: "ricochet"` on every other shot;
  - a mid-air hit with no `surface`;
  - one with the cyan `ramp`.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `kind` | `"hit" \| "ricochet"` | `"hit"` | `"ricochet"`: a glancing hit. A flatter, longer star, sparks raking along the bounce, and a hot streak skipping off. With `surface`, it also leaves a scrape on the surface. |
| `x` | number (world units) | `760` | The hit point's x. |
| `y` | number (world units) | `600` | The hit point's y. |
| `angle` | number (rad) | `0.2` | The bullet's direction of travel (0 right, π/2 down). |
| `normal` | number (rad) | `-π/2` (up) | The surface's outward normal. It is used only with `surface`. <br>• The bounce is `angle` mirrored in it. <br>• Chips, dust and smoke leave along it. <br>• Spikes pointing into the surface are cut short. <br>• Shards and the ring are hidden on that side. |
| `size` | number (multiplier) | `1` (`0.9` for a ricochet) | 0.6 is a light tick. It scales the star, the shards, the ring, the light, the spark, chip and dust counts and speeds, the dust and smoke radius (√), the streak, the scrape and the shake. |
| `ramp` | `readonly number[]` (6 × ABGR) | warm: `#ffffff #fff3a6 #ffe26b #ff8a2a #f2561d #c9281f` | The hit's colours, white-hot to dark (roles under Palette). |
| `surface` | number (ABGR) | none (mid-air) | The colour of what was hit. Giving it makes this a surface hit: the bounce, chips, dust and smoke, and a ricochet's scrape. |
| `ground` | `number \| ((x: number) => number)` (world y) | none | The floor, where sparks and chips land and bounce. Without it they fall until they die. |
| `seed` | number | `1` | Random seed. Use a new one per shot. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |

## Actor, methods and hooks
- `shake(trauma: number): void`: called once, at creation, with 0.03 × size.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: impact.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Options {
  kind?: "hit" | "ricochet";
  x?: number;
  y?: number;
  angle?: number;
  normal?: number;
  size?: number;
  ramp?: readonly number[];
  surface?: number;
  ground?: number | ((x: number) => number);
  seed?: number;
  shake?(trauma: number): void;
}
export default function impact(o: Options = {}) {
  const kind = o.kind ?? "hit", glance = kind === "ricochet";
  const X = o.x ?? 760, Y = o.y ?? 600, A = o.angle ?? 0.2, S = o.size ?? (glance ? 0.9 : 1), C = o.ramp ?? WARM_RAMP;
  const R = new Rng(o.seed ?? 1);
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const ps = new Particles(R, groundAt, C);
  const ax = X / PX, ay = Y / PX, dx = Math.cos(A), dy = Math.sin(A);
  const onSurface = o.surface !== undefined, N = o.normal ?? -Math.PI / 2;
  const nx = Math.cos(N), ny = Math.sin(N), dn = dx * nx + dy * ny;
  const B = onSurface ? Math.atan2(dy - 2 * dn * ny, dx - 2 * dn * nx) : A;
  const spikes = Array.from({ length: 8 }, (_, i) => {
    const a = B + (i / 8) * TAU + R.range(-0.18, 0.18), cb = Math.cos(a - B);
    const into = onSurface ? Math.cos(a - N) < -0.2 : false;
    const len = (7 + R.range(0, 3)) * S * (1 + (glance ? 2.6 : 1.8) * Math.pow(Math.max(0, cb), 3) + 0.6 * Math.pow(Math.max(0, -cb), 3)) * (into ? 0.3 : 1) * (glance && Math.abs(Math.sin(a - B)) > 0.6 ? 0.6 : 1);
    return { a, len, w: (1.5 + R.range(0, 0.6)) * S };
  });
  const open = (a: number) => !onSurface || Math.cos(a - N) > -0.25;
  const shards = [...spikes].filter((p) => open(p.a)).sort((p, q) => q.len - p.len).slice(0, 4).map((s) => ({ a: s.a + R.range(-0.15, 0.15), r: s.len * 0.8, v: s.len * R.range(5, 8), arc: R.range(0.35, 0.6) }));
  let t = 0;
  const n = Math.round((glance ? 10 : 6) + 12 * S);
  for (let i = 0; i < n; i++) {
    const back = !onSurface && R.chance(0.2);
    const a = (back ? A + Math.PI : B) + R.range(-1, 1) * (glance ? 0.3 : onSurface ? 0.85 : 0.6), sp = R.range(260, 900) * (0.6 + 0.4 * S) * (glance ? 1.2 : 1);
    ps.spawn(PT.SPARK, X, Y, Math.cos(a) * sp, Math.sin(a) * sp - (glance ? 20 : 60), R.range(0.1, 0.3) * (glance ? 1.3 : 1));
  }
  if (onSurface) {
    const sc = o.surface!, dc = mix(sc, rgb(150, 140, 150), 0.35);
    for (let i = 0; i < Math.round((glance ? 2 : 3) + 5 * S); i++) {
      const a = (glance ? B : N) + R.range(-0.8, 0.8) * (glance ? 0.6 : 1), sp = R.range(150, 420) * S;
      ps.spawn(PT.CHIP, X, Y + ny * 2, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.8, 1.4), R.chance(0.5) ? scale(sc, 1.25) : R.chance(0.5) ? sc : scale(sc, 0.7), R.chance(0.3) ? 2 : 1);
    }
    for (let i = 0; i < Math.round(3 + 4 * S); i++) {
      const a = N + R.range(-1, 1), sp = R.range(20, 90) * S;
      ps.spawn(PT.DUST, X + nx * 3, Y + ny * 3, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.35, 0.7), dc, R.range(1.4, 2.8) * Math.sqrt(S));
    }
    ps.spawn(PT.SMOKE, X + nx * 4, Y + ny * 4, R.range(-8, 8), R.range(-30, -14), R.range(0.8, 1.3), SMOKE, R.range(1.6, 2.4) * Math.sqrt(S), 0.05);
  }
  o.shake?.(0.03 * S);
  const tx = Math.cos(B), ty = Math.sin(B), STREAK = 0.16, SPEED = 1500;
  const sx = Math.cos(N + Math.PI / 2) * Math.sign(Math.cos(A - (N + Math.PI / 2)) || 1), sy = Math.sin(N + Math.PI / 2) * Math.sign(Math.cos(A - (N + Math.PI / 2)) || 1);
  return {
    update(dt: number) { t += dt; ps.update(dt); },
    draw(fr: Frame, layer?: Layer) {
      const buf = new Px(fr, fr.color), light = new Px(fr, fr.light);
      if (layer !== "front") {
        if (glance && onSurface && t < 1.1) {
          const T = clamp(1 - t / 0.9), L = 9 * S;
          for (let d = 0; d <= L; d += 0.5) {
            const k = d / L, px = ax - sx * d, py = ay - sy * d;
            const c = T * (1 - k) > 0.5 ? C[1]! : T * (1 - k) > 0.25 ? C[3]! : T > 0 ? C[5]! : SOOT;
            dot(buf, px, py, c, 1 - k * 0.6);
            if (T > 0.2 && (d | 0) % 3 === 0) light.glow(px, py, 4, C[3]!, 0.3 * T * (1 - k));
          }
        }
        ps.draw(buf, light, "back");
      }
      if (layer === "back") return;
      const f = Math.max(1, Math.ceil(t * 60 - 1e-6));
      if (f === 1) star(buf, ax, ay, spikes, S, 1, 1, C[0]!, C[1]!, C[2]!, C[4]!);
      else if (f === 2) star(buf, ax, ay, spikes, S, 1.25, 0.55, C[1]!, C[2]!, C[3]!, C[4]!);
      if (f >= 3 && t < 0.13) {
        const k = (t - 2 / 60) / (0.13 - 2 / 60);
        for (const s of shards) crescent(buf, ax, ay, s.a, s.r + s.v * (t - 2 / 60), s.arc * (1 - 0.4 * k), k < 0.4 ? C[2]! : k < 0.7 ? C[3]! : C[4]!, 1 - k);
      }
      if (f >= 3 && t < 0.2) {
        const k = (t - 2 / 60) / (0.2 - 2 / 60), r = (8 + 12 * (1 - Math.pow(1 - k, 3))) * S, th = Math.max(1, 2 * (1 - k) * S), col = k < 0.3 ? C[1]! : k < 0.6 ? C[2]! : C[3]!;
        for (let j = 0, n = Math.ceil(r * TAU * 1.3); j < n; j++) {
          const a = (j / n) * TAU;
          if (!open(a)) continue;
          for (let o = -th / 2; o <= th / 2; o += 0.5) dot(buf, ax + Math.cos(a) * (r + o), ay + Math.sin(a) * (r + o), col, 1.15 - k);
        }
      }
      if (glance && t < STREAK) {
        const head = (SPEED * t) / PX + 6 * S, tail = Math.max(2, head - (40 + 220 * t) / PX), k = t / STREAK;
        for (let d = tail; d <= head; d += 0.5) {
          const u = (d - tail) / Math.max(1, head - tail);
          dot(buf, ax + tx * d, ay + ty * d, u > 0.8 ? C[0]! : u > 0.4 ? C[1]! : C[3]!, u > 0.4 ? 1 : 1 - k);
        }
        light.glow(ax + tx * head, ay + ty * head, 9, C[2]!, 0.6 * (1 - k));
      }
      ps.draw(buf, light, "front");
      const pop = Math.exp(-t / 0.05);
      if (pop > 0.02) { light.glow(ax, ay, 22 * S + 6, C[3]!, 0.9 * pop); light.glow(ax, ay, 8 * S + 2, C[0]!, 0.7 * pop); }
    },
    done: () => t > (glance ? 1.1 : 0.2) && ps.list.length === 0,
  };
}
function star(buf: Px, ax: number, ay: number, spikes: { a: number; len: number; w: number }[], S: number, sc: number, th: number, core: number, body: number, inner: number, rim: number) {
  for (const pass of [0, 1, 2])
    for (const s of spikes) {
      const c = Math.cos(s.a), sn = Math.sin(s.a), L = s.len * sc;
      for (let d = 0; d <= L; d += 0.5) {
        const hw0 = s.w * th * (1 - d / L) * Math.min(1, 0.5 + d / 3);
        const hw = pass === 0 ? hw0 + 0.8 : pass === 1 ? hw0 : hw0 * 0.45;
        if (pass === 2 && d > L * 0.55) break;
        for (let o = -hw; o <= hw; o += 0.5) buf.set(Math.floor(ax + c * d - sn * o), Math.floor(ay + sn * d + c * o), pass === 0 ? rim : pass === 1 ? (d < L * 0.35 ? inner : body) : core);
      }
    }
  const r = 2.4 * S * sc * Math.sqrt(th);
  buf.disc(ax, ay, r + 0.8, inner);
  buf.disc(ax, ay, r, core);
}
function crescent(buf: Px, ax: number, ay: number, a: number, r: number, arc: number, c: number, k: number) {
  const n = Math.ceil(r * arc * 2.2);
  for (let j = 0; j <= n; j++) {
    const u = j / n - 0.5, th = a + u * arc, w = 1.4 * (1 - Math.abs(u) * 2);
    for (let o = -w * 0.5; o <= w * 0.5 + 0.01; o += 0.5) dot(buf, ax + Math.cos(th) * (r + o), ay + Math.sin(th) * (r + o), c, k);
  }
}
function rgb(r: number, g: number, b: number, a = 255) { return ((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255); }
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
}
function scale(c: number, k: number) {
  return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24);
}
function ramp(stops: readonly number[], t: number) {
  const u = Math.max(0, Math.min(0.9999, t)) * (stops.length - 1), i = Math.floor(u);
  return mix(stops[i]!, stops[i + 1]!, u - i);
}
const SOOT = hex("#0d0a12");
const SMOKE_RAMP = ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"].map(hex);
const WARM_RAMP = ["#ffffff", "#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d", "#c9281f"].map(hex);
const SMOKE = hex("#6a6278");
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
  disc(cx: number, cy: number, r: number, c: number) {
    if (r <= 0.5) return this.set(Math.round(cx), Math.round(cy), c);
    const r2 = r * r;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const dx = x + 0.5 - cx; if (dx * dx + dy * dy <= r2) this.set(x, y, c); }
    }
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
  chance(p: number) { return this.next() < p; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
const GRAVITY = 1900;
const PT = { SPARK: 0, CHIP: 1, DUST: 2, SMOKE: 3 } as const;
type PT = (typeof PT)[keyof typeof PT];
interface Part { k: PT; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number; delay: number }
class Particles {
  list: Part[] = [];
  t = 0;
  R: Rng;
  ground: (x: number) => number;
  C: readonly number[];
  constructor(R: Rng, ground: (x: number) => number, C: readonly number[]) { this.R = R; this.ground = ground; this.C = C; }
  spawn(k: PT, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1, delay = 0) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100, delay });
  }
  update(dt: number) {
    this.t += dt;
    const t = this.t, R = this.R, L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if (p.delay > 0) { p.delay -= dt; continue; }
      if ((p.life -= dt) <= 0) { L.splice(i, 1); continue; }
      const g = this.ground(p.x);
      switch (p.k) {
        case PT.SPARK: {
          p.vy += GRAVITY * 0.45 * dt;
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt;
          const ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) { p.vy = -p.vy * 0.45; p.vx *= 0.7; p.y = g - 0.5; } else p.y = ny;
          break;
        }
        case PT.CHIP: {
          p.vy += GRAVITY * dt;
          p.vx -= p.vx * 0.6 * dt;
          const ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) {
            p.y = g - 0.5;
            if (p.vy > 220) (p.vy = -p.vy * 0.3), (p.vx = p.vx * 0.5 + R.range(-20, 20));
            else (p.vx = p.vy = 0), (p.life = Math.min(p.life, 0.5));
          } else p.y = ny;
          break;
        }
        case PT.DUST:
          p.vx -= p.vx * 4 * dt;
          p.vy -= p.vy * 4 * dt + 10 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case PT.SMOKE:
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
    const C = this.C;
    for (const p of this.list) {
      if (p.delay > 0 || (p.k === PT.SPARK) === (layer === "back")) continue;
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
      switch (p.k) {
        case PT.SPARK: {
          const hot = k > 0.6 ? C[1]! : k > 0.3 ? C[2]! : C[3]!;
          const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(9, 1 + sp * 0.011);
          buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? hot : C[4]!);
          buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, hot);
          light.glow(ax, ay, 3, hot, 0.45 * k);
          break;
        }
        case PT.CHIP:
          if (k > 0.25 || bayer(px, py) < k * 4) {
            buf.set(px, py, p.col);
            if (p.size >= 2) (buf.set(px + 1, py, p.col), buf.set(px, py + 1, scale(p.col, 0.8)));
          }
          break;
        case PT.DUST:
          buf.alphaDisc(ax, ay, p.size * (0.6 + (1 - k) * 0.9), p.col, Math.pow(k, 1.3) * 0.7);
          break;
        case PT.SMOKE: {
          const age = 1 - k, r = p.size * (0.65 + Math.min(1, age * 2.5) * 0.45 + age * 0.4);
          const a = Math.min(1, age * 12) * Math.min(1, k * 2.4) * 0.5, c = mix(p.col, ramp(SMOKE_RAMP, age), age);
          buf.alphaDisc(ax, ay, r, c, a * 0.45);
          buf.alphaDisc(ax + r * 0.05, ay + r * 0.06, r * 0.74, c, a * 0.62);
          break;
        }
      }
    }
  }
}
```
