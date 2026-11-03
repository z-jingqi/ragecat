# Heal & Mana (heal.ts)

Light spreading along the floor and bands of light climbing the character, with outlined pixel crosses rising and glinting for health, or elixir drops, bubbles and spiralling strands for mana.

Previews (animated WebP, 320 × 200 art pixels): Heal https://www.spritefusion.com/images/pixel-art-vfx/heal-heal.webp, Mana https://www.spritefusion.com/images/pixel-art-vfx/heal-mana-refill.webp

Page: https://www.spritefusion.com/pixel-art-vfx/heal. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/heal.zip

## Recipe
- **Palette:**
  - `palette`, 8 hex, light to dark. Steps 1–4 are used, plus white and an outline #1a1422 round crosses and drops.
    - Heal (default for `kind: "heal"`): #ffffff, #e6ffdc, #acff92, #62e26a, #30b55b, #20804c, #175237, #0f3125.
    - Mana (default for `kind: "mana"`): #ffffff, #e4f2ff, #a9d4ff, #64a4ff, #4170f0, #3449b8, #26307c, #171c4a.
  - Step 1: the floor glow's middle, the motes off it, the sweep's trail (its first 3 rows) and its outline, lit edges of crosses, drop highlights, streak heads, helix heads, bubbles' upper left, sparkles.
  - Step 2: the floor glow's sides and the row above its middle, the motes' tails, the rest of the sweep's trail and its glow, cross insides, drop bodies, streak bodies, the helix, bubble sides, sparkles, glyph glows.
  - Step 3: the floor glow's ends and its light glows, the shaded half of small crosses, drop shading, the helix's far side, the column glows.
  - Step 4: shaded edges of big crosses, drop darks, streak tails, bubble bottoms.
- **Shapes and motion** (both kinds): sizes in art px, positions and speeds in world units. Partial opacity is a 4 × 4 Bayer ordered dither; glows add colour × strength × (1 − d/r)² to the light buffer. Rates "per update" assume 60 updates a second.
  - Floor glow (a side view: no ellipse): the floor's top row lit either side of the feet, spreading to ±19.5 px over 0–0.45 s (outCubic). At u = |dx| / its half width: step 1 below 0.3, step 2 below 0.65, step 3 beyond, at opacity √(1 − u) × 1.04; the row above, below u = 0.75, step 2 then step 3 at 35% of that. Every 5 px a light glow r 10, step 3, 0.22 × (1 − u). 8 motes rise off it in loops: each climbs 22 px from 1 px above the floor at 0.9–1.5 cycles a second, anywhere along the glow, white for its first quarter then step 1, a step 2 pixel under it at 60%, opacity sin(phase × π).
  - Sweep, on the character (its pixels, read from `actor.silhouette()` on every draw): at 0.1, 0.65 and 1.2 s a band climbs from 2 px below its lowest pixel to 4 px above its highest in 0.4 s, carrying on to 0.52 s. Its pixels on the band's row (and the one above it) turn white at opacity 1.5; the 9 rows under it are trailed in step 1 (3 rows) then step 2, at opacity (1 − d/10) × 1.4. The 1 px just outside its outline on the band turns step 1. A light glow r 14, step 2, 0.5 × (1 − q/1.3) rides the band, at the character's mean x. All of it × a fade in over 0–0.25 s and the fade out.
  - Column: 13 light glows stacked every 6 px from the feet up to 72 px, r 22, step 3, strength 0.13 fading upward (× 1 − h/90). Fades in over 0–0.2 s.
  - Sparkles: 45% chance per update until 2 s, within ±34 units of the feet and up to 76 above them. Velocity ±8 sideways, 30–80 up; life 0.5–0.95 s; step 1 or 2. 30% are plus-shaped stars of size 1.6–2.6 (arms round(size × twinkle), tips at 75%, white centre), the rest single twinkling pixels. Drag 1.6 (v −= v·1.6·dt), rising 10 units/s².
  - Glyphs (crosses or drops) spawn round where the feet were at creation, within ±46 units across and 4–70 units above. They pop in one every 0.085 s from 0.06 s (+ 0–0.05 s each), rise at 50–90 units/s, sway by sin(4.5 × age + seed) × 16 units/s, live 1–1.4 s, and dither out over the last 40% of their life. 45% are big. Each has a light glow r 9 (12 big), step 2, 0.4.
  - The floor glow, the sweep, the column, the streaks and the helix fade out over 1.9–2.7 s.
- **Heal** (`kind: "heal"`):
  - **Timeline:** 0–0.45 s the floor glow spreads; the sweep climbs the character at 0.1, 0.65 and 1.2 s; 18 crosses pop in from 0.06 s to about 1.5 s; streaks climb throughout; 1.9–2.7 s it fades; `done()` after 2.8 s once the sparkles are gone, about 2.9 s.
  - **Layers:** "back": the column glows (light), 22 streaks. "front": the floor glow and its motes, the sweep (over the character), crosses and their glows, sparkles.
  - **Shapes and motion:**
    - Cross: a plus with arms L px each way, 1 px wide (small, L = 2) or 3 px wide (big, L = 4). It pops: L − 1 for 0.05 s, L + 1 until 0.1 s, then L. A 1 px outline (#1a1422) all round.
      - Big: top and left edges step 1, bottom and right edges step 4, inside step 2.
      - Small: the top and left halves step 1, the rest step 3.
      - Glint, while sin(14 × age + seed) > 0.75: the centre pixel white (big ones also the top-left pixel of the top arm).
    - Streaks: 22 vertical 5 px streaks, from the top (their head) down: step 1, step 2, step 2, step 4, step 4, fading toward the tail (× 1 − d/6). Each rises from 2 px above the feet to 76 px in 0.53–0.9 s and loops. Spread ±17 px, narrowing 30% as they rise. Opacity sin(phase × π).
- **Mana** (`kind: "mana"`):
  - **Timeline:** 0–0.45 s the floor glow spreads; the sweep climbs the character at 0.1, 0.65 and 1.2 s; 0–0.25 s the helix fades in; 14 drops pop in from 0.06 s to about 1.2 s; bubbles rise until 1.9 s; 1.9–2.7 s it fades; `done()` after 2.8 s once sparkles and bubbles are gone.
  - **Layers:** "back": the column glows (light), the helix's far side. "front": the floor glow and its motes, the sweep (over the character), the helix's near side and its glows, drops and their glows, bubbles, sparkles.
  - **Shapes and motion:**
    - Drops: pixel sprites, outlined #1a1422. A digit is a palette step, W white, `.` empty.
      - Big: `..1..`, `..2..`, `.122.`, `.1223`, `1W223`, `12223`, `22234`, `.334.`.
      - Small: `.1.`, `.2.`, `1W3`, `223`, `.3.`.
      - Every drop shows small for its first 0.05 s. Glint (its first 0.1 s, and while sin(14 × age + seed) > 0.75): all its step 1 pixels turn white.
    - Helix: 2 strands half a turn apart, each 4 comets a quarter cycle apart.
      - A comet rises from 3 px to 73 px above the feet in 2 s, circling 1.6 turns plus 2.4 rad/s on a radius narrowing 17 → 10 px. Its opacity is sin(phase × π).
      - It is 14 dots long, trailing below the head (0.7 px down and 0.13 rad back each), fading to the tail (× 1 − d/15).
      - Near side (sin θ ≥ 0), "front": head white, then 3 dots step 1, 4 step 2, the rest step 3; its first 6 dots doubled 1 px below (step 2, then step 3). Light glow r 6, step 2 at the head.
      - Far side, "back": 5 dots step 3, the rest step 4, at 75%.
    - Bubbles: 16% chance per update until 1.9 s, within ±30 units of the feet and up to 40 above. Rising 60–110 units/s, wobbling sin(7t) × 22 units/s, life 0.6–1.1 s.
      - A ring of radius 1 (the 8 pixels round a centre) or 2 (30%): upper left step 1, lower half step 4, the rest step 2. Fading out over its last 0.3 s. Light glow r 4 + 2 × radius, step 3, 0.25.
      - Pop, its last 0.07 s: only 4 diagonal pixels at radius + 1, step 1.
- **Feel:** none. It has no hooks and asks nothing of the camera or screen.

## Situations
- **Heal:** `heal({ actor: player })`: green crosses popping up and rising round the player, a glow spreading along the floor, a soft column, and bands of light climbing the player.
- **Mana:** `heal({ kind: "mana", actor: player, seed: 4 })`: blue elixir drops, bubbles and two strands spiralling up round the player, a glow along the floor and bands of light climbing the player.

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `kind` | `"heal" \| "mana"` | `"heal"` | Crosses and streaks, or drops, bubbles and a helix. |
| `x` | number (world units) | `640` | The feet's x, without an actor. |
| `y` | number (world units) | `600` | The feet's y, without an actor. |
| `actor` | `Actor` | none | Who it heals. See below. |
| `palette` | `string[]` (hex, light to dark) | heal: the green ramp; mana: the blue ramp | Its ramp. Steps 1–4 are used, so at least 5. |
| `count` | number | `18` (heal), `14` (mana) | How many crosses or drops rise. |
| `seed` | number | `1` | Random seed. |

## Actor, methods and hooks
- `actor`: `feet(): [number, number]` (world units). Read once at creation: the crosses and drops spawn round it and then rise on their own. Read every update and draw: the floor glow, column, streaks, helix, sparkles and bubbles follow it. `silhouette?(): { x, y, w, h, data } | null` (art px; `data` ABGR, alpha 0 where the character isn't) is read on every draw for the sweep; without it there is no sweep.
- No methods beyond update, draw and done.
- No hooks.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: heal.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { feet(): [number, number]; silhouette?(): { x: number; y: number; w: number; h: number; data: Uint32Array } | null }
export interface Options { kind?: "heal" | "mana"; x?: number; y?: number; actor?: Actor; palette?: string[]; count?: number; seed?: number }
export default function heal(o: Options = {}) {
  const MANA = o.kind === "mana";
  const L = (o.palette ?? (MANA ? ["#ffffff", "#e4f2ff", "#a9d4ff", "#64a4ff", "#4170f0", "#3449b8", "#26307c", "#171c4a"] : ["#ffffff", "#e6ffdc", "#acff92", "#62e26a", "#30b55b", "#20804c", "#175237", "#0f3125"])).map(hex);
  const R = new Rng(o.seed ?? 1);
  const feet = (): [number, number] => (o.actor ? o.actor.feet() : [o.x ?? 640, o.y ?? 600]);
  const [X0, Y0] = feet();
  const ps = new Particles(R);
  const glyphs = new Bits(), bubbles: Bubble[] = [];
  for (let i = 0; i < (o.count ?? (MANA ? 14 : 18)); i++) glyphs.add({ x: X0 + R.range(-46, 46), y: Y0 - R.range(4, 70), vy: -R.range(50, 90), life: R.range(1, 1.4), delay: 0.06 + i * 0.085 + R.range(0, 0.05), s: R.chance(0.45) ? 1 : 0, seed: R.next() * 1000 });
  const fade = (t: number) => 1 - smooth(1.9, 2.7, t);
  let t = 0;
  const floor = (buf: Px, light: Px, cx: number, fy: number) => {
    const k = fade(t), w = 19.5 * (1 - (1 - clamp(t / 0.45)) ** 3);
    for (let dx = -Math.ceil(w); dx <= w; dx++) {
      const u = Math.abs(dx) / Math.max(1, w), a = k * Math.sqrt(1 - Math.min(1, u)) * 1.04;
      dot(buf, cx + dx, fy, u < 0.3 ? L[1]! : u < 0.65 ? L[2]! : L[3]!, a);
      if (u < 0.75) dot(buf, cx + dx, fy - 1, u < 0.35 ? L[2]! : L[3]!, a * 0.35);
      if (dx % 5 === 0) light.glow(cx + dx, fy, 10, L[3]!, 0.22 * k * (1 - u));
    }
    for (let i = 0; i < 8; i++) {
      const ph = frac(t * (0.9 + hash(i, 1) * 0.6) + hash(i, 2)), x = cx + (hash(i, 3) - 0.5) * 2 * w, a = Math.sin(ph * Math.PI) * k;
      dot(buf, x, fy - 1 - ph * 22, ph < 0.25 ? WHITE : L[1]!, a);
      dot(buf, x, fy - ph * 22, L[2]!, a * 0.6);
    }
  };
  const sweep = (buf: Px, light: Px) => {
    const s = o.actor?.silhouette?.(), k = smooth(0, 0.25, t) * fade(t);
    if (!s || k <= 0) return;
    const inside = (i: number, j: number) => i >= 0 && j >= 0 && i < s.w && j < s.h && s.data[j * s.w + i]! >>> 24 > 0;
    let top = s.h, bot = -1, sx = 0, n = 0;
    for (let j = 0; j < s.h; j++) for (let i = 0; i < s.w; i++) if (inside(i, j)) (top = Math.min(top, j)), (bot = j), (sx += i), n++;
    for (const p of [0.1, 0.65, 1.2]) {
      const q = (t - p) / 0.4;
      if (q < 0 || q > 1.3 || bot < 0) continue;
      const yb = bot + 2 - q * (bot - top + 6);
      for (let j = top - 1; j <= bot + 1; j++) {
        const d = j - yb;
        if (d < -1 || d >= 10) continue;
        for (let i = -1; i <= s.w; i++)
          if (inside(i, j)) dot(buf, s.x + i, s.y + j, d < 1 ? WHITE : d < 4 ? L[1]! : L[2]!, k * (d < 1 ? 1.5 : (1 - d / 10) * 1.4));
          else if (d < 1.5 && (inside(i + 1, j) || inside(i - 1, j) || inside(i, j + 1) || inside(i, j - 1))) dot(buf, s.x + i, s.y + j, L[1]!, k);
      }
      light.glow(s.x + sx / n, s.y + yb, 14, L[2]!, 0.5 * k * (1 - q / 1.3));
    }
  };
  const helix = (buf: Px, light: Px, cx: number, fy: number, front: boolean) => {
    const k = fade(t) * smooth(0, 0.25, t);
    if (k <= 0) return;
    for (let s = 0; s < 2; s++)
      for (let i = 0; i < 4; i++) {
        const ph = frac(t * 0.5 + i / 4 + s * 0.125), a = Math.sin(ph * Math.PI) * k, rx = 17 - ph * 7;
        for (let d = 0; d < 14; d++) {
          const th = ph * TAU * 1.6 + s * Math.PI + t * 2.4 - d * 0.13, z = Math.sin(th);
          if (z >= 0 !== front) continue;
          const px = cx + Math.cos(th) * rx, py = fy - 3 - ph * 70 + d * 0.7, c = z < 0 ? (d < 5 ? L[3]! : L[4]!) : d < 1 ? WHITE : d < 4 ? L[1]! : d < 8 ? L[2]! : L[3]!, ad = a * (1 - d / 15) * (z < 0 ? 0.75 : 1);
          dot(buf, px, py, c, ad);
          if (d < 6 && z >= 0) dot(buf, px, py + 1, d < 3 ? L[2]! : L[3]!, ad);
        }
        if (front) light.glow(cx + Math.cos(ph * TAU * 1.6 + s * Math.PI + t * 2.4) * rx, fy - 3 - ph * 70, 6, L[2]!, 0.4 * a);
      }
  };
  return {
    update(dt: number) {
      t += dt;
      const [x, y] = feet();
      glyphs.step(dt);
      if (MANA && t < 1.9 && R.chance(0.16)) {
        const life = R.range(0.6, 1.1);
        bubbles.push({ x: x + R.range(-30, 30), y: y - R.range(0, 40), vy: -R.range(60, 110), life, max: life, r: R.chance(0.3) ? 2 : 1, seed: R.next() * 10 });
      }
      for (let i = bubbles.length - 1; i >= 0; i--) {
        const b = bubbles[i]!;
        if ((b.life -= dt) <= 0) bubbles.splice(i, 1);
        b.y += b.vy * dt;
        b.x += Math.sin(t * 7 + b.seed) * 22 * dt;
      }
      for (const b of glyphs.list) if (b.delay <= 0) b.x += Math.sin((b.max - b.life) * 4.5 + b.seed) * 16 * dt;
      if (t < 2 && R.chance(0.45)) ps.spawn(x + R.range(-34, 34), y - R.range(0, 76), R.range(-8, 8), -R.range(30, 80), R.range(0.5, 0.95), R.chance(0.5) ? L[1]! : L[2]!, R.chance(0.3) ? R.range(1.6, 2.6) : R.range(0.4, 0.9));
      ps.update(dt);
    },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      const [x, y] = feet(), cx = x / PX, fy = y / PX;
      if (layer !== "front") {
        const k = fade(t) * smooth(0, 0.2, t);
        for (let h = 0; h < 78; h += 6) light.glow(cx, fy - h, 22, L[3]!, 0.13 * k * (1 - h / 90));
        if (MANA) helix(buf, light, cx, fy, false);
        else
          for (let i = 0; i < 22; i++) {
            const ph = (t * (1.1 + hash(i, 3) * 0.8) + hash(i, 1)) % 1, sx = cx + (hash(i, 2) - 0.5) * 34 * (1 - ph * 0.3), sy = fy - 2 - ph * 74;
            const a = Math.sin(ph * Math.PI) * k;
            for (let d = 0; d < 5; d++) dot(buf, sx, sy + d, d === 0 ? L[1]! : d < 3 ? L[2]! : L[4]!, a * (1 - d / 6));
          }
      }
      if (layer !== "back") {
        floor(buf, light, cx, fy);
        sweep(buf, light);
        if (MANA) helix(buf, light, cx, fy, true);
        for (const b of glyphs.list) {
          if (b.delay > 0) continue;
          const age = b.max - b.life, k = b.life / b.max, glint = Math.sin(age * 14 + b.seed) > 0.75;
          if (MANA) drop(buf, b.x / PX, b.y / PX, age < 0.05 ? 1 : b.s ? 0 : 1, L, k < 0.4 ? k / 0.4 : 1, glint || age < 0.1);
          else {
            const big = b.s ? 4 : 2, Lc = age < 0.05 ? big - 1 : age < 0.1 ? big + 1 : big;
            cross(buf, b.x / PX, b.y / PX, Lc, b.s, L, k < 0.4 ? k / 0.4 : 1, glint);
          }
          light.glow(b.x / PX, b.y / PX, 9 + b.s * 3, L[2]!, 0.4 * Math.min(1, k * 2));
        }
        for (const b of bubbles) {
          const bx = b.x / PX, by = b.y / PX;
          if (b.life < 0.07) {
            for (let j = 0; j < 4; j++) buf.set(Math.round(bx + (j & 1 ? -1 : 1) * (b.r + 1)), Math.round(by + (j & 2 ? -1 : 1) * (b.r + 1)), L[1]!);
            continue;
          }
          bubble(buf, bx, by, b.r, L, Math.min(1, b.life / 0.3));
          light.glow(bx, by, 4 + b.r * 2, L[3]!, 0.25);
        }
        ps.draw(buf, light);
      }
    },
    done: () => t > 2.8 && ps.list.length === 0 && bubbles.length === 0,
  };
}
function cross(buf: Px, x: number, y: number, L: number, w: number, r: readonly number[], a = 1, glint = false) {
  const px = Math.round(x), py = Math.round(y);
  const ins = (dx: number, dy: number) => (Math.abs(dx) <= w && Math.abs(dy) <= L) || (Math.abs(dy) <= w && Math.abs(dx) <= L);
  for (let dy = -L - 1; dy <= L + 1; dy++)
    for (let dx = -L - 1; dx <= L + 1; dx++) {
      let c: number;
      if (ins(dx, dy)) {
        const top = !ins(dx, dy - 1), left = !ins(dx - 1, dy), bottom = !ins(dx, dy + 1), right = !ins(dx + 1, dy);
        c = w === 0 ? (dy < 0 || dx < 0 ? r[1]! : r[3]!) : top || left ? r[1]! : bottom || right ? r[4]! : r[2]!;
        if (glint && ((dx === 0 && dy === 0) || (w > 0 && dx === -w && dy === -L))) c = WHITE;
      } else if (ins(dx - 1, dy) || ins(dx + 1, dy) || ins(dx, dy - 1) || ins(dx, dy + 1)) c = OUTLINE;
      else continue;
      dot(buf, px + dx, py + dy, c, a);
    }
}
const DROP = [["..1..", "..2..", ".122.", ".1223", "1W223", "12223", "22234", ".334."], [".1.", ".2.", "1W3", "223", ".3."],];
function drop(buf: Px, x: number, y: number, s: number, r: readonly number[], a = 1, glint = false) {
  const m = DROP[s]!, h = m.length, w = m[0]!.length, x0 = Math.round(x) - (w >> 1), y0 = Math.round(y) - (h >> 1);
  const ins = (i: number, j: number) => j >= 0 && j < h && i >= 0 && i < w && m[j]![i] !== ".";
  for (let j = -1; j <= h; j++)
    for (let i = -1; i <= w; i++) {
      const ch = ins(i, j) ? m[j]![i]! : ins(i - 1, j) || ins(i + 1, j) || ins(i, j - 1) || ins(i, j + 1) ? "o" : "";
      if (!ch) continue;
      dot(buf, x0 + i, y0 + j, ch === "o" ? OUTLINE : ch === "W" || (glint && ch === "1") ? WHITE : r[+ch]!, a);
    }
}
function bubble(buf: Px, x: number, y: number, r: number, c: readonly number[], a = 1) {
  const px = Math.round(x), py = Math.round(y);
  for (let j = -r - 1; j <= r + 1; j++)
    for (let i = -r - 1; i <= r + 1; i++) {
      const d = Math.hypot(i, j);
      if (Math.abs(d - r) < 0.6 || (r === 1 && Math.abs(i) + Math.abs(j) === 1)) dot(buf, px + i, py + j, i < 0 && j < 0 ? c[1]! : j > 0 ? c[4]! : c[2]!, a);
    }
}
interface Bubble { x: number; y: number; vy: number; life: number; max: number; r: number; seed: number }
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
function hex(h: string) { const v = parseInt(h.replace("#", ""), 16); return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255); }
function scale(c: number, k: number) {
  return rgb(Math.min(255, (c & 255) * k), Math.min(255, ((c >>> 8) & 255) * k), Math.min(255, ((c >>> 16) & 255) * k), c >>> 24);
}
const WHITE = hex("#ffffff");
const OUTLINE = hex("#1a1422");
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
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function frac(x: number) { return x - Math.floor(x); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
interface P { x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  constructor(R: Rng) { this.R = R; }
  spawn(x: number, y: number, vx: number, vy: number, life: number, col: number, size: number) {
    this.list.push({ x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100 });
  }
  update(dt: number) {
    this.t += dt;
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i]!;
      if ((p.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      p.vx -= p.vx * 1.6 * dt;
      p.vy -= p.vy * 1.6 * dt + 10 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }
  draw(buf: Px, light: Px) {
    for (const p of this.list) {
      const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay);
      const tw = 0.6 + 0.4 * Math.sin(this.t * (8 + (p.seed % 5)) + p.seed);
      if (p.size < 1) { if (tw * k > 0.25) buf.set(px, py, tw > 0.8 ? WHITE : p.col); light.glow(ax, ay, 3, p.col, 0.4 * k * tw); continue; }
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
    }
  }
}
interface Bit { x: number; y: number; vy: number; life: number; max: number; s: number; seed: number; delay: number }
class Bits {
  list: Bit[] = [];
  add(b: Omit<Bit, "max">) { this.list.push({ ...b, max: b.life }); }
  step(dt: number) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const b = this.list[i]!;
      if (b.delay > 0) { b.delay -= dt; continue; }
      if ((b.life -= dt) <= 0) { this.list.splice(i, 1); continue; }
      b.y += b.vy * dt;
    }
  }
}
```
