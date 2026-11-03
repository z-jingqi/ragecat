# Explosion (explosion.ts)

A blast out of the ground: a white-hot flash, a fireball cooling into smoke, earth and chunks thrown in arcs, dust rolling out, a shockwave and a scorch left behind. Size it from a grenade to a bomb.

Previews (animated WebP, 320 × 200 art pixels): Blast https://www.spritefusion.com/images/pixel-art-vfx/explosion-dirt.webp

Page: https://www.spritefusion.com/pixel-art-vfx/explosion. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/explosion.zip

## Recipe
- **Timeline:** everything is spawned in the call; the rest plays out by physics and lifetimes. Values are for `size` 1, where the blast radius is 36 world units (18 art px). The blast's heart is at `x`, kept at least 0.3 × radius (10.8 units) above the ground.
  - 0–0.06 s: the flash disc at the heart. A white light lasts 0.08 s, and a warm light fades over 0.7 s.
  - 0–0.08 s: the scorch on the ground opens to full width, white-hot. It cools unevenly through the heat ramp to soot over 2.49 s (1.2 + radius/28), then stays as soot until the effect ends.
  - 0–0.22 s and 0–0.34 s: an orange ring, then a wider yellow ring, race out through the air.
  - 0–0.5 s: a shockwave races along the ground, stepping through five colours, one every 0.1 s.
  - 0–0.3 s: 5 big core flames. 0.55–1.15 s: the fireball's flames fly out and rise, cooling from white to dark red. Many of them leave smoke as they die.
  - Sparks last 0.18–0.7 s and embers float for 1.2–3.2 s.
  - 0–2.2 s: earth is thrown up in a V and rains back down. Dust rolls out both ways along the ground (1.55–2.65 s) and rises in a column (1.6–2.8 s).
  - 0–3.2 s: rock chunks arc out, bounce, rest, and dither out over their last 0.5 s.
  - Smoke puffs start with delays of 0.06–0.45 s and live up to 3 s.
  - `done()` turns true once everything is gone: about 3.2–3.7 s. If the burning streamer lands while still alive, it lights a ground fire for 2.2–4.5 s, and the effect runs to about 6 s.
- **Layers:**
  - "back", in draw order: the scorch, then all smoke and dust (fireball smoke, black smoke, rolling dust, the earth's dust column, landing puffs), then the ground fire's flames, embers and base pixel, then the shockwave's far (upper) arc.
  - "front", in draw order: the shockwave's near (lower) arc, the chunks, the fireball flames, sparks, embers, grit and streamer, then the flash disc and the two air rings.
  - Light buffer: additive glows that fall off as (1 − d/r)² × strength, with r in art px.
    - Scorch: every 4th hot pixel, r 6, strength 0.18 × heat.
    - Flames: r 2.4 × the flame's current radius + 2, strength 0.18 × life left. Only flames on the 6 hottest steps glow.
    - Sparks: r 3, 0.45 × life left. Embers: r 3, 0.3 × life left.
    - Streamer: r 7, #ff8a2a, 0.45.
    - Ground fire: r 6 + 5k·power, #ff8a2a, 0.3k·power.
    - White light: #ffffff, r 28.8 shrinking to 55%, strength 0.6 × k² over 0.08 s (k = life left, 1 → 0).
    - Warm light: #ffb060, r 61.2 shrinking to 55%, strength 0.54 × k² over 0.7 s.
  - Smoke, dust and flames on their last step are alpha-blended discs. Everything else is opaque pixels.
- **Palette:**
  - Fire ramp, light to dark: #ffffff, #fff3a6, #ffe26b, #ffc23d, #ff8a2a, #f2561d, #c9281f, #8a1f17, #4a1712.
    - A flame's step is floor(min(0.999, age^0.62 + up to 0.1) × 8).
    - Its body is that step and its rim is 2 steps darker. Flames on steps ≤ 3 get a highlight one step lighter.
    - From step 7 (#8a1f17) on, a flame is drawn as a translucent disc (opacity 0.85 × min(1, 3 × life left)).
  - Heat ramp (scorch): the first 8 fire steps, then #4f1a13 and #2a120e. Soot is #0d0a12 in the inner half and #17121d outside it.
  - Smoke ramp, by age: #7b6f72, #5d5660, #433d48, #2b2630, #1a171e.
    - Untinted smoke follows the ramp.
    - Black smoke starts #221d26, and earth dust starts at the stone dust colour. Both mix into the ramp by their age.
  - Accents:
    - Flash: a #f2561d rim around a #fff3a6 disc with a #ffffff core. After 0.033 s the disc turns #ffe26b and the core #fff3a6.
    - Air rings: #ffe26b (wide) and #ff8a2a (small).
    - Sparks: the head is #fff3a6 above 60% of life left, #ffe26b above 30%, then #ff8a2a. The tail matches the head in the first half of life and is #f2561d after.
    - Embers: flicker #ffe26b/#ff8a2a, then #ff8a2a below 50% of life left, then #c9281f below 20%.
    - Streamer: a #f2561d disc with a #fff3a6/#ffe26b flicker.
    - Rock outline: #1a1422.
  - Stone, derived from `surface` (default #4a3f69):
    - light #6f6296 (× 1.35, then 8% toward white), body #4a3f69, shade #2f2843 (× 0.64).
    - dust #6a5e85 (× 1.2, then 30% toward #968c96). Landing puffs are #645978 (35% toward #968c96).
  - Shockwave, one colour per 0.1 s: #ffffff, #fff3a6, #ff8a2a, stone light, stone body.
- **Shapes and motion:** sizes are in art px and speeds in world units/s. Gravity g = 1900 units/s². Drag is v −= v·drag·dt. Fades are 4 × 4 Bayer ordered dither unless alpha is stated.
  - Flash: three filled discs, radius r + 1.2, r and 0.6r. r starts at 18.9 and shrinks to 80%.
  - Air rings: the yellow ring grows from 8.1 to 48.6 radius in 0.34 s, 3 px thick. The orange ring grows from 5.4 to 28.8 in 0.22 s, 1.8 px thick. Both ease out cubically, thin with life, and dither out over the last ~60% of life.
  - Shockwave: an ellipse 0.16 as tall as it is wide, centred on the ground line. Its half-width grows from 0 to 80 in 0.5 s (ease-out cubic). It is 4 → 1 px thick and dithered at opacity 1.15 − progress.
  - Scorch: a half-ellipse 22 px each side, 3 rows deep from the ground line down. A per-pixel hash makes it cool unevenly, and its soot edge is dithered.
  - Flames: each is stacked filled discs.
    - A rim disc of radius r, a body disc of 0.78r offset up-left, a tip disc of 0.42r above it (when r > 1.6), and a small highlight disc.
    - The radius is the flame's size × (0.55 → 1 over the first 1/7 of life) × (1 − 0.55 × age), so it swells, then shrinks to 45%.
    - Physics: they rise at 190 units/s², wobble, and have strong drag (5 in x, 3.2 in y).
    - Core flames: 5, size 7.2–9.9, life 0.18–0.3 s.
    - Fireball flames: 8 (round(28·power·`fire`)), size 4–8.3. They start up to 19.8 units out and fly at 72–378 units/s (vertical × 0.8, then −80). Life 0.55–1.15 s. 45% turn into big smoke when they die.
    - Column flames: 2 (round(5·`fire`)), size 4.3–6.5, shot up at 200–360. Life 0.8–1.3 s. 60% leave smoke.
  - Sparks: 72 two-segment streaks, length 1 + speed × 0.011 (max 9). They fly in all directions at 288–1080 with −140 vertical, under 0.45g with drag 2.2. They bounce on the ground at × 0.45. Life 0.18–0.7 s.
  - Embers: 11 single pixels that start 0.4 radius out and fly at 60–360 with −150 vertical. They float up and wobble. Life 1.2–3.2 s.
  - The blast's push: everything spawned with the blast within 93.6 units (2.6 × radius) is pushed outward and a little up, at up to 648 units/s. Smoke takes 0.35 of the push and flames are not pushed.
  - Streamer: 1 burning brand, a 1.6 px disc that trails small flames.
    - It is thrown within ±1.35 rad of straight up at 380–820, under 0.8g. Life 0.7–1.5 s.
    - Where it lands, a ground fire burns for 2.2–4.5 s, spawning (6 + 16 × intensity) small back-layer flames per second. It dwindles after the first 30% of its life.
  - Smoke: three alpha discs.
    - Opacity a = min(1, 12·age) × min(1, 2.4 × life left) × 0.7 for big puffs, or × 0.58 for small ones.
    - A skirt disc of radius r at 0.45a, a body disc of 0.74r offset down-right at 0.62a, and in the first half of life a lit top of 0.5r up-left, mixed 12% toward white, at 0.4a × (1 − 2·age).
    - r = size × (0.65 + 0.45 × min(1, 2.5·age) + 0.5·age), or + 0.4·age for small puffs. It rises at 46 units/s² (big) or 32 (small) and sways.
    - Black puffs: 5, size 2.7–4.7, start delay 0.06–0.2 s, life 0.9–1.5 s.
    - Heavy puffs: 9, size 4.7–7.9, start delay 0.12–0.45 s, life 1.8–3 s.
    - Dying flames add more smoke, at 0.85 (big) or 0.7 (small) of the flame's size, keeping 0.6 of its velocity.
  - Landing puffs: alpha discs, radius size × (0.6 → 1.5), opacity 0.7 × (life left)^1.3.
  - Earth:
    - Grit: 150 pixels (round(`earth` × radius × 2.6)). 45% are 2 × 2 clods, their right, lower and corner pixels at × 1, × 0.8 and × 0.7. The colour is stone light, body, body or shade.
      - Thrown in a V within ±0.5 rad of vertical at 216–684, the fastest straight up. Full gravity.
      - On landing faster than 260, 40% bounce once. The rest stop, and within 0.5 s they dither out.
    - Dust column: 19 puffs (round(`earth` × 12)), size 7.6–11.6, rising at 115–365.
    - Rolling dust: 18 puffs (round(0.5 × radius in units)), size 7–10, thrown sideways along the ground at 108–342.
    - All of the earth's dust is big smoke (above), starting at stone dust.
  - Chunks: 26 rocks with radius 1.35, 2.1 or 2.85, each slightly taller than wide.
    - A 1 px #1a1422 outline. The rock is split into light, body and shade along a direction that turns with its spin (±16 rad/s).
    - Thrown up at 378–864 and ±130 sideways, under full gravity.
    - They bounce at × 0.32 while landing faster than 140, puffing 3 dust bits when faster than 200, then rest. Life 2.4–3.2 s.
- **Feel:** one camera shake of 0.6 × min(1.3, √size), and one scene ripple from 18 to 234 units over 0.7 s with amplitude 0.14, all at creation. No screen flash: its own light does the lighting.

## Situations
- **Blast:** `explosion({ x: 320, y: 300, surface: 0xff693f4a })`: a shell bursting in a stone floor at y 300. A column of earth and grit, rock chunks, dust rolling both ways, a short low fireball with little fire, the shockwave along the floor, and a scorch cooling to soot.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `x` | number (world units) | `770` | The blast's x. |
| `y` | number (world units) | the ground at `x` | The blast's y. The fireball's heart is kept at least 0.3 × radius above the ground. It is also the ground when `ground` is not given, and the ripple's centre. |
| `size` | number (multiplier) | `1` | Scales the whole blast. <br>• Radius 36 × size units, which sets every spread, speed and particle size tied to it. <br>• Power 0.9 × size^0.8, which sets fireball, spark and ember counts and speeds. <br>• Shockwave and scorch widths. <br>• Chunk count × min(1.5, size). <br>• Shake and ripple. |
| `ground` | `number \| ((x: number) => number)` (world y) | `y`, else `600` | The floor: a flat y or a function of x. Grit, chunks, sparks and the streamer land on it. The scorch and the shockwave are drawn on it. |
| `surface` | number (ABGR) | `0xff693f4a` (#4a3f69) | The ground's colour. Chunks, grit, dust and the shockwave's last two steps are derived from it. |
| `fire` | number (multiplier) | `0.3` | How much fire. It multiplies the fireball flames (28 × power × fire), rising flames (5 × fire), embers (40 × power × fire) and burning streamers. 0.3 is a burst of earth; 1 is a full fireball. |
| `earth` | number (multiplier) | `1.6` | How much earth: grit (earth × radius × 2.6), dust-column puffs (earth × 12), and their speed. 0 means no earth column. |
| `chunks` | number (count) | `26` | Rock chunks thrown, × min(1.5, size). |
| `scorch` | number (art px) | `22` | The scorch's half-width, × size. |
| `shockwave` | number (art px) | `80` | The ground shockwave's reach (half-width), × size. |
| `seed` | number | `1` | Random seed: the same seed gives the same blast. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |
| `ripple` | `(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number) => void` | none | Scene ripple hook. |

## Actor, methods and hooks
- `shake(trauma: number): void`: called once, at creation, with 0.6 × min(1.3, √size). The value is camera trauma (0..1).
- `ripple(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number): void`: called once, at creation, with (x, y, 18·size, 234·size, 0.5 + 0.2·size, 0.14, 21.6·size). It asks for a ring that distorts the scene around (x, y). The ring's radius goes from r0 to r1 world units over dur seconds, with strength amp and band width w (world units).

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: explosion.ts

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
  ground?: number | ((x: number) => number);
  surface?: number;
  fire?: number;
  earth?: number;
  chunks?: number;
  scorch?: number;
  shockwave?: number;
  seed?: number;
  shake?(trauma: number): void;
  ripple?(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number): void;
}
export default function explosion(o: Options = {}) {
  const S = o.size ?? 1, RAD = 36 * S, POWER = 0.9 * Math.pow(S, 0.8), EARTH = o.earth ?? 1.6, RING = (o.shockwave ?? 80) * S, SCORCH = (o.scorch ?? 22) * S;
  const R = new Rng(o.seed ?? 1);
  const gr = o.ground ?? o.y ?? 600, groundAt = (x: number) => (typeof gr === "number" ? gr : gr(x));
  const X = o.x ?? 770, G = groundAt(X), Y = o.y ?? G;
  const ps = new Particles(R, groundAt), fx = new Fx(ps), rocks = new Bits(groundAt);
  const ST = stone(o.surface ?? STONE_BODY), gx = X / PX, gy = G / PX, cool = 1.2 + RAD / 28, thick = 2 + RAD / 18;
  const ringCols = [WHITE, PAL.hot, PAL.orange, ST.light, ST.body];
  let t = 0;
  fx.explosion(X, Math.min(Y, G - RAD * 0.3), RAD, POWER, o.fire ?? 0.3);
  o.shake?.(0.6 * Math.min(1.3, Math.sqrt(S)));
  o.ripple?.(X, Y, RAD * 0.5, RAD * 6.5, 0.5 + RAD / 180, 0.14, RAD * 0.6);
  for (let i = 0; i < Math.round(RAD * 0.5); i++) {
    const s = R.sign();
    ps.spawn(PT.SMOKE, X + s * R.range(0, RAD * 0.6), G - R.range(2, 10 + RAD * 0.08), s * R.range(3, 9.5) * RAD, -R.range(4, 30), R.range(1.1, 2.2) + RAD / 80, ST.dust, R.range(4, 7) + RAD / 12, R.range(0, 0.06), BIG);
  }
  for (let i = 0; i < (o.chunks ?? 26) * Math.min(1.5, S); i++) rocks.add(X + R.range(-0.4, 0.4) * RAD, G - 6, R.range(-9, 9) * RAD * 0.4, -R.range(7, 16) * RAD * 1.5, R.range(1.8, 2.6) + RAD / 60, R.range(0, TAU), R.range(-16, 16), R.int(1, 3));
  for (let i = 0; i < Math.round(EARTH * RAD * 2.6); i++) {
    const u = R.range(-1, 1), a = -Math.PI / 2 + u * 0.5, sp = R.range(6, 19) * RAD * (1 - 0.45 * Math.abs(u));
    ps.spawn(PT.GRIT, X + u * 0.25 * RAD, G - 2, Math.cos(a) * sp, Math.sin(a) * sp, R.range(1.2, 2.2), R.pick([ST.light, ST.body, ST.body, ST.shade]), R.chance(0.45) ? 2 : 1);
  }
  for (let i = 0; i < Math.round(EARTH * 12); i++) ps.spawn(PT.SMOKE, X + R.range(-0.3, 0.3) * RAD, G - R.range(4, RAD * 0.6), R.range(-30, 30), -R.range(120, 380) * Math.sqrt(S) * EARTH * 0.6, R.range(1.6, 2.8), ST.dust, R.range(5, 9) * Math.sqrt(S) + RAD / 14, R.range(0, 0.15), BIG);
  return {
    update(dt: number) { t += dt; rocks.step(dt, (b, sp) => sp > 200 && fx.dust(b.x, b.y, 3, 0.6, ST.body)); fx.update(dt); ps.update(dt); },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") {
        scorch(buf, light, gx, gy, t, SCORCH, cool);
        ps.draw(buf, light, "back");
        fx.drawBack(buf, light);
        floorRing(buf, gx, gy, t / 0.5, RING, thick, ringCols, true);
      }
      if (layer !== "back") {
        floorRing(buf, gx, gy, t / 0.5, RING, thick, ringCols, false);
        for (const b of rocks.list) rock(buf, b, ST);
        ps.draw(buf, light, "front");
        fx.drawFront(buf, light);
      }
    },
    done: () => t > 1 && ps.list.length === 0 && !fx.busy && rocks.list.length === 0,
  };
}
const STONE_BODY = hex("#4a3f69");
function stone(c: number) {
  return { light: mix(scale(c, 1.35), WHITE, 0.08), body: c, shade: scale(c, 0.64), dust: mix(scale(c, 1.2), rgb(150, 140, 150), 0.3) };
}
type Stone = ReturnType<typeof stone>;
function scorch(buf: Px, light: Px, cx: number, cy: number, t: number, rx0: number, cool: number) {
  const rx = rx0 * Math.min(1, t / 0.08), ry = 4;
  for (let y = Math.floor(cy); y <= cy + 2; y++)
    for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, d = Math.sqrt(dx * dx + dy * dy);
      if (d > 1) continue;
      const k = hash(x * 31 + y);
      const T = Math.pow(clamp(1 - t / cool), 1.4) * (1.25 - d) - k * 0.35;
      if (T > 0.06) {
        const c = HEAT_RAMP[Math.min(HEAT_RAMP.length - 1, Math.floor((1 - Math.min(1, T)) * (HEAT_RAMP.length - 1)))]!;
        buf.set(x, y, c);
        if ((x & 3) === 0) light.glow(x + 0.5, y, 6, c, 0.18 * T);
      } else if (d < 0.95 - k * 0.3 || bayer(x, y) < 1 - d) buf.set(x, y, d < 0.5 ? SOOT : SOOT2);
    }
}
function floorRing(buf: Px, x: number, gy: number, k: number, rx: number, thick: number, cols: readonly number[], back: boolean) {
  if (k >= 1 || k < 0) return;
  const r = rx * outCubic(k), col = cols[Math.min(cols.length - 1, Math.floor(k * cols.length))]!;
  ringE(buf, x, gy + 0.5, r, r * 0.16, Math.max(1, thick * (1 - k)), col, 1.15 - k, (a) => (back ? Math.sin(a) < 0 : Math.sin(a) >= 0));
}
function rock(buf: Px, b: Bit, st: Stone) {
  const x = b.x / PX, y = b.y / PX, r = 0.6 + b.s * 0.75, fade = Math.min(1, b.life / 0.5);
  const lx = Math.cos(b.a) * r * 0.4, ly = Math.sin(b.a) * r * 0.4;
  for (let py = Math.floor(y - r - 1); py <= Math.ceil(y + r + 1); py++)
    for (let px = Math.floor(x - r - 1); px <= Math.ceil(x + r + 1); px++) {
      const dx = px + 0.5 - x, dy = py + 0.5 - y, d = Math.hypot(dx * 1.15, dy);
      if (d > r + 0.9 || (fade < 1 && fade <= bayer(px, py))) continue;
      const lit = dx * lx + dy * ly;
      buf.set(px, py, d > r ? OUTLINE : lit < -0.4 ? st.light : lit > 0.6 ? st.shade : st.body);
    }
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
  ring(cx: number, cy: number, r: number, thick: number, c: number, alpha = 1) {
    const ro = r + thick * 0.5, ri = Math.max(0, r - thick * 0.5), ro2 = ro * ro, ri2 = ri * ri;
    for (let y = Math.floor(cy - ro); y <= Math.ceil(cy + ro); y++) {
      const dy = y + 0.5 - cy;
      for (let x = Math.floor(cx - ro); x <= Math.ceil(cx + ro); x++) {
        const dx = x + 0.5 - cx, d2 = dx * dx + dy * dy;
        if (d2 <= ro2 && d2 >= ri2 && (alpha >= 1 || alpha > bayer(x, y))) this.set(x, y, c);
      }
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
function mix(c1: number, c2: number, t: number) {
  const u = 1 - t, ch = (c: number, s: number) => (c >>> s) & 255;
  return rgb(ch(c1, 0) * u + ch(c2, 0) * t, ch(c1, 8) * u + ch(c2, 8) * t, ch(c1, 16) * u + ch(c2, 16) * t, ch(c1, 24) * u + ch(c2, 24) * t);
}
function ramp(stops: readonly number[], t: number) {
  const u = Math.max(0, Math.min(0.9999, t)) * (stops.length - 1), i = Math.floor(u);
  return mix(stops[i]!, stops[i + 1]!, u - i);
}
const WHITE = hex("#ffffff"), OUTLINE = hex("#1a1422"), SOOT = hex("#0d0a12"), SOOT2 = hex("#17121d"), WARM = rgb(255, 176, 96);
const PAL = { hot: hex("#fff3a6"), yellow: hex("#ffe26b"), gold: hex("#ffc23d"), orange: hex("#ff8a2a"), deepOrange: hex("#f2561d"), red: hex("#c9281f") };
const FIRE_RAMP = [WHITE, PAL.hot, PAL.yellow, PAL.gold, PAL.orange, PAL.deepOrange, PAL.red, hex("#8a1f17"), hex("#4a1712")];
const HEAT_RAMP = [...FIRE_RAMP.slice(0, 8), hex("#4f1a13"), hex("#2a120e")];
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
  int(a: number, b: number) { return Math.floor(this.range(a, b + 1)); }
  sign() { return this.next() < 0.5 ? -1 : 1; }
  chance(p: number) { return this.next() < p; }
  pick<T>(a: readonly T[]): T { return a[Math.floor(this.next() * a.length)]!; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
const GRAVITY = 1900;
const PT = { SPARK: 0, EMBER: 1, SMOKE: 2, FIRE: 3, BRAND: 4, DUST: 5, GRIT: 6 } as const;
type PT = (typeof PT)[keyof typeof PT];
const SMOKES = 1, BIG = 2, BACK = 4;
interface Part {
  k: PT;
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  col: number;
  size: number;
  seed: number;
  delay: number;
  flag: number;
}
class Particles {
  list: Part[] = [];
  t = 0;
  R: Rng;
  ground: (x: number) => number;
  onLand?: (x: number, y: number) => void;
  constructor(R: Rng, ground: (x: number) => number) { this.R = R; this.ground = ground; }
  spawn(k: PT, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1, delay = 0, flag = 0) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100, delay, flag });
  }
  impulse(x: number, y: number, r: number, force: number) {
    for (const p of this.list) {
      if (p.k === PT.FIRE) continue;
      const dx = p.x - x, dy = p.y - y, d = Math.hypot(dx, dy) || 1;
      if (d > r) continue;
      const f = force * (1 - d / r) * (p.k === PT.SMOKE || p.k === PT.DUST ? 0.35 : 1);
      p.vx += (dx / d) * f;
      p.vy += (dy / d) * f - f * 0.3;
    }
  }
  update(dt: number) {
    this.t += dt;
    const t = this.t, R = this.R, L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if (p.delay > 0) { p.delay -= dt; continue; }
      if ((p.life -= dt) <= 0) {
        if (p.k === PT.FIRE && p.flag & SMOKES) {
          const big = p.flag & BIG;
          this.spawn(PT.SMOKE, p.x, p.y, p.vx * 0.6, p.vy * 0.6 - 12, big ? R.range(1.3, 2.3) : R.range(0.8, 1.4), 0, p.size * (big ? 0.85 : 0.7), 0, big ? BIG : 0);
        }
        L.splice(i, 1);
        continue;
      }
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
        case PT.EMBER:
          p.vy += (-60 + Math.sin(t * 3 + p.seed) * 40) * dt;
          p.vx += Math.cos(t * 2.3 + p.seed) * 90 * dt;
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.6 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case PT.SMOKE: {
          const big = p.flag & BIG;
          p.vy -= (big ? 46 : 32) * dt;
          p.vx += Math.sin(t * 1.3 + p.seed) * 16 * dt;
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.2 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        }
        case PT.FIRE:
          p.vy -= 190 * dt;
          p.vx += Math.sin(t * 17 + p.seed) * 60 * dt;
          p.vx -= p.vx * 5 * dt;
          p.vy -= p.vy * 3.2 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case PT.DUST:
          p.vx -= p.vx * 4 * dt;
          p.vy -= p.vy * 4 * dt + 10 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case PT.GRIT: {
          p.vy += GRAVITY * dt;
          p.vx -= p.vx * 0.8 * dt;
          const ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) {
            p.y = g - 0.5;
            if (p.vy > 260 && R.chance(0.4)) (p.vy = -p.vy * 0.25), (p.vx = p.vx * 0.5 + R.range(-20, 20));
            else (p.vx = p.vy = 0), (p.life = Math.min(p.life, 0.5));
          } else p.y = ny;
          break;
        }
        case PT.BRAND: {
          p.vy += GRAVITY * 0.8 * dt;
          p.vx -= p.vx * 0.9 * dt;
          if (R.chance(0.9)) this.spawn(PT.FIRE, p.x, p.y, p.vx * 0.1 + R.range(-15, 15), p.vy * 0.1 - 20, R.range(0.16, 0.32), 0, R.range(0.9, 1.7) * (0.5 + (p.life / p.max) * 0.6), 0, R.chance(0.4) ? SMOKES : 0);
          const ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0 && p.y <= g && ny >= g) { this.onLand?.(p.x, g); L.splice(i, 1); } else p.y = ny;
          break;
        }
      }
    }
  }
  draw(buf: Px, light: Px, layer: Layer) {
    const back = layer === "back";
    if (back) for (const p of this.list) if (p.delay <= 0 && (p.k === PT.SMOKE || p.k === PT.DUST)) this.drawOne(p, buf, light);
    for (const p of this.list) if (p.delay <= 0 && p.k !== PT.SMOKE && p.k !== PT.DUST && !(p.flag & BACK) !== back) this.drawOne(p, buf, light);
  }
  private drawOne(p: Part, buf: Px, light: Px) {
    const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
    switch (p.k) {
      case PT.SMOKE: {
        const age = 1 - k, big = p.flag & BIG;
        const r = p.size * (0.65 + Math.min(1, age * 2.5) * 0.45 + age * (big ? 0.5 : 0.4));
        const a = Math.min(1, age * 12) * Math.min(1, k * 2.4) * (big ? 0.7 : 0.58);
        const c = p.col ? mix(p.col, ramp(SMOKE_RAMP, age), age) : ramp(SMOKE_RAMP, age * 1.05);
        buf.alphaDisc(ax, ay, r, c, a * 0.45);
        buf.alphaDisc(ax + r * 0.05, ay + r * 0.06, r * 0.74, c, a * 0.62);
        if (age < 0.5) buf.alphaDisc(ax - r * 0.22, ay - r * 0.3, r * 0.5, mix(c, WHITE, 0.12), a * 0.4 * (1 - age * 2));
        break;
      }
      case PT.DUST:
        buf.alphaDisc(ax, ay, p.size * (0.6 + (1 - k) * 0.9), p.col, Math.pow(k, 1.3) * 0.7);
        break;
      case PT.GRIT:
        if (k > 0.25 || bayer(px, py) < k * 4) {
          buf.set(px, py, p.col);
          if (p.size >= 2) { buf.set(px + 1, py, p.col); buf.set(px, py + 1, scale(p.col, 0.8)); buf.set(px + 1, py + 1, scale(p.col, 0.7)); }
        }
        break;
      case PT.FIRE: {
        const age = 1 - k, heat = Math.min(0.999, Math.pow(age, 0.62) + (p.seed % 1) * 0.1);
        const idx = Math.min(FIRE_RAMP.length - 2, Math.floor(heat * (FIRE_RAMP.length - 1)));
        const r = p.size * (0.55 + 0.45 * Math.min(1, age * 7)) * (1 - age * 0.55), c = FIRE_RAMP[idx]!;
        if (idx >= FIRE_RAMP.length - 2) buf.alphaDisc(ax, ay, r, c, Math.min(1, k * 3) * 0.85);
        else {
          buf.disc(ax, ay, r, FIRE_RAMP[Math.min(FIRE_RAMP.length - 1, idx + 2)]!);
          buf.disc(ax - r * 0.16, ay - r * 0.22, r * 0.78, c);
          if (r > 1.6) buf.disc(ax, ay - r * 0.9, r * 0.42, c);
          if (idx <= 3 && r > 1.8) buf.disc(ax - r * 0.28, ay - r * 0.34, r * 0.36, FIRE_RAMP[Math.max(0, idx - 1)]!);
          if (idx < 6) light.glow(ax, ay, r * 2.4 + 2, c, 0.18 * k);
        }
        break;
      }
      case PT.BRAND:
        buf.disc(ax, ay, 1.6, PAL.deepOrange);
        buf.set(px, py, Math.sin(this.t * 40 + p.seed) > 0 ? PAL.hot : PAL.yellow);
        buf.set(px + 1, py, PAL.yellow);
        light.glow(ax, ay, 7, PAL.orange, 0.45);
        break;
      case PT.SPARK: {
        const hot = k > 0.6 ? PAL.hot : k > 0.3 ? PAL.yellow : PAL.orange;
        const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(9, 1 + sp * 0.011);
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? hot : PAL.deepOrange);
        buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, hot);
        light.glow(ax, ay, 3, hot, 0.45 * k);
        break;
      }
      case PT.EMBER: {
        const c = k > 0.5 ? (Math.sin(this.t * 22 + p.seed * 3) > -0.2 ? PAL.yellow : PAL.orange) : k > 0.2 ? PAL.orange : PAL.red;
        buf.set(px, py, c);
        light.glow(ax, ay, 3, c, 0.3 * k);
        break;
      }
    }
  }
}
interface Timed { x: number; y: number; life: number; max: number }
class Fx {
  flashes: (Timed & { r: number })[] = [];
  rings: (Timed & { r0: number; r1: number; thick: number; color: number })[] = [];
  lights: (Timed & { r: number; color: number; k: number })[] = [];
  blazes: (Timed & { acc: number; power: number })[] = [];
  ps: Particles;
  constructor(ps: Particles) { this.ps = ps; ps.onLand = (x, y) => this.blaze(x, y - 0.5, ps.R.range(2.2, 4.5), ps.R.range(0.55, 0.85)); }
  get busy() { return this.flashes.length + this.rings.length + this.lights.length + this.blazes.length > 0; }
  light(x: number, y: number, r: number, color: number, k: number, life: number) { this.lights.push({ x, y, r, color, k, life, max: life }); }
  ring(x: number, y: number, r0: number, r1: number, life: number, thick: number, color: number) {
    this.rings.push({ x, y, r0, r1, life, max: life, thick, color });
  }
  blaze(x: number, y: number, life: number, power: number) { this.blazes.push({ x, y, life, max: life, acc: this.ps.R.next(), power }); }
  update(dt: number) {
    for (const a of [this.flashes, this.rings, this.lights] as Timed[][]) for (let i = a.length - 1; i >= 0; i--) if ((a[i]!.life -= dt) <= 0) a.splice(i, 1);
    const ps = this.ps, R = ps.R;
    for (let i = this.blazes.length - 1; i >= 0; i--) {
      const b = this.blazes[i]!;
      if ((b.life -= dt) <= 0) { this.blazes.splice(i, 1); continue; }
      const k = b.life / b.max, intensity = b.power * (k > 0.7 ? 1 : 0.35 + (k / 0.7) * 0.65);
      for (b.acc += dt * (6 + 16 * intensity); b.acc > 1; b.acc--) {
        const s = R.range(1.2, 2.8) * intensity;
        ps.spawn(PT.FIRE, b.x + R.range(-3, 3), b.y - s * 0.6, R.range(-12, 12), R.range(-60, -25), R.range(0.28, 0.6), 0, s, 0, BACK | (R.chance(0.3) ? SMOKES : 0));
        if (R.chance(0.06)) ps.spawn(PT.EMBER, b.x, b.y - 3, R.range(-30, 30), R.range(-90, -30), R.range(0.6, 1.4), PAL.orange, 1, 0, BACK);
      }
    }
  }
  drawBack(buf: Px, light: Px) {
    for (const b of this.blazes) {
      const k = b.life / b.max, ax = b.x / PX, ay = b.y / PX;
      buf.set(Math.floor(ax), Math.floor(ay), k > 0.4 ? (Math.sin(b.life * 31 + b.x) > 0 ? PAL.yellow : PAL.orange) : PAL.red);
      light.glow(ax, ay, 6 + 5 * k * b.power, PAL.orange, 0.3 * k * b.power);
    }
  }
  drawFront(buf: Px, light: Px) {
    for (const f of this.flashes) {
      const k = f.life / f.max, ax = f.x / PX, ay = f.y / PX, r = f.r * (0.8 + 0.2 * k);
      buf.disc(ax, ay, r + 1.2, PAL.deepOrange);
      buf.disc(ax, ay, r, k > 0.45 ? PAL.hot : PAL.yellow);
      buf.disc(ax, ay, r * 0.6, k > 0.45 ? WHITE : PAL.hot);
    }
    for (const r of this.rings) {
      const k = r.life / r.max, e = 1 - Math.pow(k, 3);
      buf.ring(r.x / PX, r.y / PX, (r.r0 + (r.r1 - r.r0) * e) / PX, Math.max(1, r.thick * k + 0.4), r.color, Math.min(1, k * 1.6));
    }
    for (const l of this.lights) { const k = l.life / l.max; light.glow(l.x / PX, l.y / PX, (l.r / PX) * (0.55 + 0.45 * k), l.color, l.k * k * k); }
  }
  explosion(x: number, y: number, rad: number, power = 1, fire = 1) {
    const ps = this.ps, R = ps.R, ar = rad / PX;
    this.flashes.push({ x, y, r: ar * 1.05, life: 0.06, max: 0.06 });
    this.ring(x, y, rad * 0.45, rad * 2.7, 0.34, 3, PAL.yellow);
    this.ring(x, y, rad * 0.3, rad * 1.6, 0.22, 1.8, PAL.orange);
    this.light(x, y, rad * 3.4, WARM, 0.6 * power, 0.7);
    this.light(x, y, rad * 1.6, WHITE, 0.6, 0.08);
    for (let i = 0; i < 5; i++) ps.spawn(PT.FIRE, x + R.range(-5, 5), y + R.range(-5, 5), R.range(-40, 40), R.range(-80, -20), R.range(0.18, 0.3), 0, R.range(ar * 0.4, ar * 0.55));
    for (let i = 0; i < Math.round(28 * power * fire); i++) {
      const a = R.range(0, TAU), d = R.range(0, rad * 0.55), sp = R.range(80, 420) * power;
      ps.spawn(PT.FIRE, x + Math.cos(a) * d, y + Math.sin(a) * d, Math.cos(a) * sp, Math.sin(a) * sp * 0.8 - 80, R.range(0.55, 1.15), 0, R.range(ar * 0.22, ar * 0.46), 0, R.chance(0.45) ? SMOKES | BIG : 0);
    }
    for (let i = 0; i < 5; i++) {
      const a = R.range(0, TAU), d = R.range(rad * 0.1, rad * 0.5);
      ps.spawn(PT.SMOKE, x + Math.cos(a) * d, y + Math.sin(a) * d, Math.cos(a) * 60, Math.sin(a) * 40 - 60, R.range(0.9, 1.5), rgb(34, 29, 38), R.range(ar * 0.15, ar * 0.26), R.range(0.06, 0.2), BIG);
    }
    for (let i = 0; i < Math.round(5 * fire); i++) ps.spawn(PT.FIRE, x + R.range(-rad * 0.25, rad * 0.25), y, R.range(-25, 25), R.range(-360, -200), R.range(0.8, 1.3), 0, R.range(ar * 0.24, ar * 0.36), R.range(0, 0.1), R.chance(0.6) ? SMOKES | BIG : 0);
    for (let i = 0; i < Math.round(10 * power); i++) {
      const a = R.range(0, TAU), d = R.range(0, rad * 0.7), sp = R.range(30, 200);
      ps.spawn(PT.SMOKE, x + Math.cos(a) * d, y + Math.sin(a) * d, Math.cos(a) * sp, Math.sin(a) * sp * 0.6 - 70, R.range(1.8, 3), 0, R.range(ar * 0.26, ar * 0.44), R.range(0.12, 0.45), BIG);
    }
    for (let i = 0; i < Math.round(80 * power); i++) {
      const a = R.range(0, TAU), sp = R.range(320, 1200) * power;
      ps.spawn(PT.SPARK, x, y, Math.cos(a) * sp, Math.sin(a) * sp - 140, R.range(0.18, 0.7));
    }
    for (let i = 0; i < Math.round(40 * power * fire); i++) {
      const a = R.range(0, TAU), sp = R.range(60, 360);
      ps.spawn(PT.EMBER, x + Math.cos(a) * rad * 0.4, y + Math.sin(a) * rad * 0.4, Math.cos(a) * sp, Math.sin(a) * sp - 150, R.range(1.2, 3.2), PAL.orange);
    }
    for (let i = 0; i < Math.round(R.range(9, 14) * Math.max(0, power - 0.55) * fire); i++) {
      const a = -Math.PI / 2 + R.range(-1.35, 1.35), sp = R.range(380, 820);
      ps.spawn(PT.BRAND, x, y, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.7, 1.5));
    }
    ps.impulse(x, y, rad * 2.6, 720 * power);
  }
  dust(x: number, y: number, n: number, spread: number, color: number) {
    const R = this.ps.R, dc = mix(color, rgb(150, 140, 150), 0.35);
    for (let i = 0; i < n; i++) this.ps.spawn(PT.DUST, x + R.range(-3, 3), y - 1, R.sign() * R.range(20, 110) * spread, -R.range(5, 45), R.range(0.3, 0.65), dc, R.range(1.3, 2.8));
  }
}
interface Bit { x: number; y: number; vx: number; vy: number; life: number; a: number; va: number; s: number; rest: boolean }
class Bits {
  list: Bit[] = [];
  ground: (x: number) => number;
  constructor(ground: (x: number) => number) { this.ground = ground; }
  add(x: number, y: number, vx: number, vy: number, life: number, a: number, va: number, s: number) {
    this.list.push({ x, y, vx, vy, life, a, va, s, rest: false });
  }
  step(dt: number, onLand: (b: Bit, speed: number) => void) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const b = this.list[i]!;
      if ((b.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      if (b.rest) continue;
      b.vy += GRAVITY * dt;
      b.vx -= b.vx * 0.25 * dt;
      b.vy -= b.vy * 0.25 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.a += b.va * dt;
      const floor = this.ground(b.x);
      if (b.y >= floor && b.vy > 0) {
        const sp = b.vy;
        b.y = floor - 0.01;
        onLand(b, sp);
        if (sp > 140) { b.vy = -sp * 0.32; b.vx *= 0.7; b.va *= 0.6; } else { b.rest = true; b.vx = b.vy = 0; }
      }
    }
  }
}
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
function ringE(buf: Px, cx: number, cy: number, rx: number, ry: number, thick: number, c: number, a: number, keep: (ang: number) => boolean) {
  const n = Math.ceil(Math.max(rx, ry) * TAU * 1.3);
  for (let j = 0; j < n; j++) {
    const ang = (j / n) * TAU;
    if (!keep(ang)) continue;
    const ca = Math.cos(ang), sa = Math.sin(ang);
    for (let off = -thick / 2; off <= thick / 2; off += 0.5) dot(buf, cx + ca * (rx + off), cy + sa * (ry + off * (ry / Math.max(1, rx))), c, a);
  }
}
```
