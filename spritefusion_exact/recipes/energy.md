# Energy (energy.ts)

Raw energy in one recolourable ramp: an orb charged at a hand and released, a sustained beam, a floating plasma orb with filaments and ground zaps, and bolts with tapering trails.

Previews (animated WebP, 320 × 200 art pixels): Orb https://www.spritefusion.com/images/pixel-art-vfx/energy-plasma-orb.webp, Charge https://www.spritefusion.com/images/pixel-art-vfx/energy-charge.webp, Beam https://www.spritefusion.com/images/pixel-art-vfx/energy-beam.webp, Bolts https://www.spritefusion.com/images/pixel-art-vfx/energy-bolts.webp

Page: https://www.spritefusion.com/pixel-art-vfx/energy. Download (ZIP): https://www.spritefusion.com/downloads/pixel-art-vfx/energy.zip

## Recipe
- **Palette:**
  - `colors`: one 8-step ramp, light to dark: a name from the file's exported `RAMPS`, or your own packed colours.
    - `"cyan"` (default): #ffffff, #d6ffff, #7ff3ff, #1ab8e6, #2b6fd2, #25449c, #1b2662, #0f1538.
    - `"gold"`: #fffbe8, #ffec92, #ffd243, #f4a923, #c9761b, #8c4716, #512611, #2c140b.
    - `"pink"`: #ffffff, #ffd8f5, #ff9ee4, #ff5fd0, #d43cc4, #8a2bb0, #4b1a7a, #250d42.
  - Step 0: white-hot cores, star centres, bolt trunks, the hottest beam layer.
  - Step 1: pale inner discs, rings, the flash colour.
  - Step 2: bodies, most glows.
  - Step 3: dark rims round discs; the colour of beam, trail and timed lights.
  - Step 4: outer rims; the beam's 5th layer.
  - Step 5: the beam's dithered fringe; the tails of motes behind the orb.
  - Step 6: the orb glass's edge and its outline. Step 7: the orb glass's tint.
  - Fixed, whatever `colors`:
    - The beam's molten ground, hot to cold: #ffffff, #fff3a6, #ffe26b, #ffc23d, #ff8a2a, #f2561d, #c9281f, #8a1f17, #4f1a13, #2a120e.
    - The beam's smoke: starts at #5b5566 mixed 45% toward step 3, ageing into #7b6f72, #5d5660, #433d48, #2b2630, #1a171e.
- **Shapes and motion** (all kinds): sizes in art px, positions and speeds in world units. Rates "per update" assume 60 updates a second.
  - Partial opacity is a 4 × 4 Bayer ordered dither; only smoke is alpha-blended. Glows add colour × strength × (1 − d/r)² to the light buffer. Timed lights shrink from r to 0.55r and fade as strength × (life left)².
  - Every hot thing is stacked discs: a dark rim, a body, a pale inside, a white-hot core.
  - Particles (drag is v −= v·drag·dt):
    - Mote: weightless, a streak along its motion, (0.5 + 0.013 × speed) × size px long (max 16), its back part at 55% brightness. Drag 0.6. It dithers out over its last 35%.
    - Star: a twinkling plus, arms round(size × twinkle) px, tips at 75% brightness, a step 0 centre; under size 1 a single pixel. Drag 1.6, rising 10 units/s².
    - Plasma: a streak up to 9 px (1 + speed × 0.011), step 0, then step 2, then step 3 as it cools. Falls at 855 units/s², drag 2.2, bounces off `ground` at × 0.45 (vx × 0.7).
    - Smoke ("back"): buoyant (rising 32 units/s², drag 1.2 vertical, 1.6 sideways, swaying). Two alpha-blended discs, the second 0.74× and offset down-right, growing as it ages, peak opacity 0.58.
    - Glint: a disc for a frame, rimmed step 3.
  - Lightning (crackles, filaments, discharges): midpoint displacement, halving segments until there are 2 + length/3 points, each midpoint pushed sideways ±jag × length, the offset × 0.52 each pass. Forks branch off thinner (× 0.55), up to 2 levels. Drawn every 0.5 px: a core pixel (step 0 on a trunk), body pixels right and below it, a dithered halo 1.5 px out on trunks, a glow every 3rd point.
  - Cross of light: a horizontal bar of half-length l and a vertical one of 0.7 l. Step 0 in the inner 30%, step 1 to 65%, step 2 beyond, dithering out toward the tips.
- **Orb** (`kind: "orb"`):
  - **Timeline:** it grows over 0–0.3 s, then loops. Its filaments are struck anew every other frame (15 a second). With `ground`, it discharges to the ground at 1.75 s, then every 1.1–1.5 s (`every`). `stop()` shrinks it away over 0.4 s; `done()` follows once the particles are gone.
  - **Layers:** "back": motes passing behind it; a light glow r 52 × pulse, step 3, 0.5 × pulse (pulse 0.8 + 0.2·sin(7t) + noise). "front": the glass, filaments, core, rim, highlight, front motes, discharges, particles. Other lights: core r 16 step 0 (0.55 × pulse); filaments r 5 step 3 (0.2); each filament tip r 6 step 2 (0.5); front motes r 5 step 2 (0.35); a discharge's ground light r 45, step 3, 0.7, 0.15 s.
  - **Shapes and motion:**
    - Glass: radius `radius` (20 px), bobbing ±3 px (sin 1.7t). Fill dithered at 0.15 + 0.55 × d² (d = distance / radius): step 7, step 6 beyond 0.8 radius. Clear in the middle, denser toward the edge; the scene shows through.
    - Rim: a 1 px ring step 3 at radius + 0.3, an outline step 6 at radius + 1.2.
    - Highlight: an arc on its upper left at radius − 2.2 (angles 3.5–4.6 rad; step 0 for 3.8–4.3, step 1 at its ends), a step 0 spot (radius 1) at (−0.42, −0.5) × radius, a step 2 dot at (0.5, 0.55) × radius.
    - Core: discs (2.4 + 1.2 × pulse) + 1.4 step 3, then step 1, then 0.55× step 0 (pulse 0.8 + 0.2·sin 7t).
    - 6 filaments: lightning (jag 0.2, forks 0.5) from the centre to 0.8 px inside the glass, each one's angle drifting. A 1 px offset shadow (step 4, 50%); the trunk step 0 within 0.4 radius of the centre, then step 1; forks step 2. At each tip a step 1 disc (radius 1.6) with a step 0 pixel.
    - 8 motes on tilted orbits: radius + 4–11 px, tilted ±0.7 rad, flattened × 0.28, 1.6–3 rad/s. In front, a 3 px comet (step 0, step 2, step 4 at 60%); behind, 2 dim px (step 4, step 5 at 60%).
    - 15% chance per update, a mote leaves the glass: 40 units/s outward and 20 up, life 0.4–0.8 s, step 2.
    - Discharge: a lightning bolt (jag 0.3, forks 0.5) from the bottom of the glass to the ground within ±30 px, shown 0.12 s, fading (core step 0, body step 2, halo step 4, glows step 3). 16 stars spray up where it lands: ±180 sideways, 60–260 up, life 0.25–0.6 s, size 0.6–1.4.
- **Charge** (`kind: "charge"`):
  - **Timeline:** it charges at the hand for `charge` (2.8 s), its level k = t / charge. Released at 2.8 s; the release shapes play over 2.8–3.4 s; `done()` after 3.8 s once the particles are gone.
  - **Layers:** everything "front". Light: the orb r 12 + 30k (step 2, 0.5 + 0.6k) and r 6 + 6k (step 0, 0.5 + 0.4k); crackles r 5 (step 2); the release glow and light below; particle glows.
  - **Shapes and motion:**
    - Orb, at the hand: radius r = 1.2 + 5.5k² + pulse × (0.6 + 1.2k), about 8.5 px at full. Discs r + 1.2 step 4, r step 2, 0.72r step 1 (shifted 0.12r up-left), 0.42r step 0.
      - Once r > 3: two opposite arcs (1.2 rad long) swirling inside it at 9 rad/s, step 0 then step 1, at 0.58–0.7r.
      - Past k = 0.2: a corona of 8 rays turning at 1.5 rad/s, (2 + 6k) px long flickering by noise, steps 1 and 2 alternating.
      - Past k = 0.8: it trembles sideways by up to 1 px, flipping 40 times a second.
    - Pulses: a phase advancing at 2 + 13k² a second. Each pulse is a 1 px ring closing from r + 2 + 16 × (0.5 + k) to r + 2 in 0.2 s (outCubic): step 1, then step 0, dithering out.
    - Streaks: 1 + floor(6k²) motes per update from 60–170 units out (× 1 − 0.35k), flying in with a swirl (0.4 tangential), arriving in 0.16–0.26 s; steps 0–2, size 1.
    - Crackles: past k = 0.4, a 25% × k chance per update of a small lightning bolt (jag 0.4, (6–12) × (0.5 + k) px, step 1) off the orb for 0.06 s.
    - Release, where the hand was:
      - A flash disc: step 2 rim, step 0, radius 12 → 4.8 over 0.07 s.
      - A cross of light, half-length 34 → 4 over 0.18 s.
      - A ring 4 → 84 px (outCubic over 0.6 s), 5 → 1 px thick, step 0 then step 1 after 0.12 s, dithered at 1.2 − progress.
      - A ring 2 → 46 px, 1.4× faster, 2 → 1 px thick, step 2.
      - A light glow r 52 → 130, step 2, 1.1 → 0 over 0.6 s; a timed light r 120, step 2, 1, 0.45 s.
      - 70 particles (65% motes, 35% stars) radially at 200–900, life 0.3–0.8 s, steps 0–2, size 0.8–2.
- **Beam** (`kind: "beam"`):
  - **Timeline:** it charges at the hand for `charge` (0.55 s). It fires at 0.55 s, reaching `to` in about 0.07 s (exponential ease-out), 1.35 × `width` settling (× 1 + 0.35·e^(−10·t since firing)). It holds until 0.55 + `hold` (2.5 s), then tapers to 0.4 px over 0.4 s (2.5–2.9 s). The molten ground heats at 1.2 a second while it fires and cools at 0.6 after. `done()` once it has cooled and the particles are gone, about 4.6 s.
  - **Layers:** "back": the molten ground (light glow r 30, #ff8a2a, 0.4 × heat) and the smoke. "front": the charge, the beam, the flare at the hand, the impact, plasma, lights. Light: 2 glows per 8 px along the beam (r 2.2w + 4, step 3, 0.3k, k = width / `width`); the flare r 26k + 8 (step 2, 0.9k); the impact r 50k + 10 (step 2, k) and r 14 (step 0, 0.7k); the charge's flickering lights.
  - **Shapes and motion:**
    - Charge (k = t / charge):
      - Plasma pulled in: 2 + floor(4k) per update from 34–96 units out (× 1 − 0.45k), arriving in about 0.1–0.14 s with a swirl.
      - A glint (step 2) with a 30–70% chance per update.
      - Two lights renewed every update: r 15 + 35k step 3 (0.5 + 0.7k) and r 7 + 9k step 0 (0.3k).
      - At the hand, discs r = 1 + 3.5k²: r + 1 step 3, r step 2, 0.5r step 0.
    - Beam, sampled every 0.5 px from the hand to `to`:
      - Half-width w = current width × (1 + 0.12·sin(0.35d − 42t)), narrowed near the hand (× min(1, (d + 3)/7)).
      - Across it, at q = |offset| / w: step 0 under 0.2, step 1 under 0.4, step 2 under 0.62, step 3 under 0.85, step 4 under 1, step 5 dithered out to 1.3.
      - Pulses: bands 2.8 px long every 40 px racing toward `to` at 136 px/s, one step brighter.
      - Two strands winding round it (offset 0.85w × sin(0.2d − 28t)), drawn on the near side only (cos > −0.2): step 0 nearest, else step 1.
    - Flare at the hand: discs (3 + 2k ± 0.6) + 1.5 step 3, then step 2, then 0.6× step 0; 4 spikes turning at 9 rad/s, (6 ± 3)k px, steps 0 and 2 alternating.
    - Impact at `to`: discs (4 + 2.5k ± 0.8) + 1.5 step 3, then step 1, then 0.55× step 0; a crown of 7 rays 0.32 rad apart, centred 0.5 rad left of straight up, (8–15)k px flickering, steps 2 and 1 alternating.
    - Splash: ceil(4k) plasma per update from the impact, at −90° − 0.4 rad + (−1.3…0.9) rad (up, leaning left), 150–560 units/s, life 0.15–0.5 s. The crown and splash lean left whichever way the beam points.
    - 20% chance per update, a smoke puff at the impact: size 3–5, rising 20–50, life 1–1.8 s.
    - 50% × k chance per update, a plasma spark somewhere along the beam.
    - Molten ground, only when `to` is within 30 units of `ground`: a strip ±18 px wide and 4 rows deep from the ground line, temperature heat × (1.15 − d) − noise × 0.3 (d = |dx|/18 + 0.22 × row), mapped onto the molten ramp (white-hot in the middle).
- **Bolt** (`kind: "bolt"`):
  - **Timeline:** it charges at the hand for `charge` (0.28 s), then flies to `to` at `speed` (1100 units/s, at least 0.05 s). The impact burst plays for 0.35 s; `done()` 0.4 s after impact once the particles are gone (about 1.1 s for a 350-unit shot).
  - **Layers:** everything "front". Light: the hand r 10 + 14k (step 2, 0.6k); the trail r 8u + 2 (step 3, 0.3u); the head r 26 (step 3, 0.7) and r 9 (step 0, 0.5); a muzzle light r 35 (step 2, 0.8, 0.1 s); an impact light r 75 (step 3, 0.9, 0.25 s).
  - **Shapes and motion:**
    - Charge: 70% chance per update, a mote flying into the hand from 20–50 units in 0.12 s (steps 0–2, size 0.8). At the hand, discs r = 0.8 + 2.6k: r + 1 step 3, r step 1, 0.5r step 0.
    - Head: discs of radius 4.2 step 4, 3.3 step 2, 2.3 step 1, 1.3 step 0; 4 rays turning at 22 rad/s from 3 px to 5 ± 1.5 px, step 1.
    - Trail: the head's last 7 positions (one per update). Along each segment, discs every 0.1 of it, radius 0.6 + 2.6 × (u − 0.1 + 0.1 × along), u = 1/7 … 1 toward the head: a step 3 disc where that's over 1.6, inside it a 0.55× disc (min 0.6), step 1 for the newest 40%, step 2 behind.
    - Flight: 70% chance per update, a mote shed from the head (±60, life 0.15–0.3 s, steps 1 and 2, size 0.7).
    - Impact, at `to`:
      - A flash disc: step 3 rim, step 0, radius 9 → 5 over 0.05 s.
      - A cross of light, half-length 21 → 3 over 0.14 s.
      - A ring 3 → 25 px (outCubic), 3 → 1 px thick, step 0 then step 2 after 0.1 s.
      - 26 plasma at 200–700: an upward fan (±1.4 rad) when it lands within 8 units of `ground`, else all round. Life 0.15–0.45 s.
      - 14 stars and motes at 80–300 (plus 120 up on the ground), life 0.25–0.6 s, steps 0–2, size 0.8–1.6.
- **Feel:**
  - Charge: a rumble growing with the level (trauma kept at least 0.08k²). At release a screen flash of 0.8 in step 1, a camera shake of 0.35, a scene ripple from radius 10 to 300 over 0.6 s.
  - Beam: as it fires, a flash of 0.45 in step 1, a shake of 0.15, a camera kick of 3 away from the target.
  - Bolt: a kick of 2 away from the target as it fires; at impact a shake of 0.12 and a flash of 0.15 in step 1.
  - Orb: nothing.

## Situations
- **Orb:** `energy({ kind: "orb", x: 440, y: 184, colors: "pink", ground: 300 })`: a pink plasma orb hovering 58 px above the ground, its filaments crackling, motes orbiting, discharging to the ground every second or so until `stop()`.
- **Charge:** `energy({ kind: "charge", actor: player })`: an orb swelling at the player's hand for 2.8 s, energy spiralling in, pulses quickening, then released in a flash, a cross of light, rings and a burst.
- **Beam:** `energy({ kind: "beam", actor: player, to: [560, 296], ground: 300 })`: a quick charge, then a beam from the player's hand to the ground ahead for 1.95 s, splashing plasma and smoke on molten ground, tapering off.
- **Bolts:** `energy({ kind: "bolt", actor: player, to: [560, 220], colors: "gold", ground: 300 })`: a gold bolt from the player's hand racing to its target with a tapering trail and bursting there; one call per bolt (the preview fires three, 0.42 s apart, at different targets).

## Options
| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `kind` | `"charge" \| "beam" \| "orb" \| "bolt"` | `"charge"` | Which situation. |
| `actor` | `Actor` | none | Charge, beam, bolt: where they start, from its hand. See below. The orb ignores it. |
| `x` | number (world units) | orb `760`; others `430` | Orb: its centre x. Others: the hand's x without an actor. |
| `y` | number (world units) | orb `484`; others `552` | Orb: its centre y (it bobs ±6 units round it). Others: the hand's y without an actor. |
| `to` | `[number, number]` (world units) | beam `[920, 596]`; bolt 420 units along the hand's angle | Where the beam lands or the bolt hits. |
| `colors` | `"cyan" \| "gold" \| "pink" \| number[]` | `"cyan"` | A ramp from `RAMPS`, or 8 packed ABGR numbers (`0xAABBGGRR`, light to dark; #ff5fd0 is `0xffd05fff`). |
| `ground` | `number \| ((x: number) => number)` (world y) | none | Plasma bounces on it. Beam: molten when `to` is within 30 units of it. Orb: discharges only when it's set. Bolt: an upward burst when it hits within 8 units of it. |
| `seed` | number | `1` | Random seed. |
| `charge` | number (s) | charge `2.8`, beam `0.55`, bolt `0.28` | Charging time before the release, the beam or the shot. |
| `hold` | number (s) | `1.95` | Beam: how long it fires at full width before tapering. |
| `width` | number (art px) | `6.5` | Beam: its half-width; its fringe reaches 1.3 × that. |
| `radius` | number (art px) | `20` | Orb: its glass's radius. |
| `every` | `[number, number]` (s) | `[1.1, 1.5]` | Orb: the random wait between discharges. |
| `speed` | number (world units/s) | `1100` | Bolt: its flight speed. |
| `shake` | `(trauma: number) => void` | none | Camera shake hook. |
| `kick` | `(dx: number, dy: number) => void` | none | Camera kick (recoil) hook. |
| `flash` | `(k: number, rgb: string) => void` | none | Screen flash hook. |
| `ripple` | `(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number) => void` | none | Scene ripple hook. |

## Actor, methods and hooks
- `actor`: `hand(): { x: number; y: number; a: number }`, the hand or muzzle in world units and its aim angle in radians. Charge, beam and bolt read it every update and draw: the charging orb and the beam's flare follow it, and the beam runs from it to `to` each frame. The bolt leaves from where it is when its charge ends, aimed along `a` when `to` is left out. The charge's release stays where the hand was at release.
- `stop()`: orb only: it shrinks away over 0.4 s, then `done()` turns true. The orb never ends without it. It does nothing for the other kinds.
- `shake(trauma: number)`: charge: every update while charging, the shortfall that keeps the camera's trauma at 0.08 × k² (it assumes trauma decays 1.7 a second), then 0.35 at release. Beam: 0.15 as it fires. Bolt: 0.12 at impact.
- `kick(dx: number, dy: number)`: beam as it fires, (−3 × sign(to.x − hand.x), 0); bolt as it fires, (−2 × sign(to.x − hand.x), 0).
- `flash(k: number, rgb: string)`: in step 1 as "r,g,b": charge release 0.8, beam firing 0.45, bolt impact 0.15.
- `ripple(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number)`: charge release only, at the hand with (x, y, 10, 300, 0.6, 0.18, 40). It asks for a ring that distorts the scene round (x, y): its radius goes from r0 to r1 world units over dur seconds, with strength amp and band width w.

## Using the file
- One TypeScript file, no imports, MIT licensed. Its default export makes the effect: `const fx = effect(options)`. Every frame: `fx.update(dt)` (seconds), then `fx.draw(frame, "back")` before drawing your characters and `fx.draw(frame, "front")` after them. Drop it once `fx.done()` is true; loops only finish after `fx.stop()`.
- `frame` is `{ w, h, ox, oy, color, light }`: your screen at its pixel art resolution as two `Uint32Array`s of `w * h` pixels in ABGR (an ImageData's bytes read as 32-bit words), and `ox, oy` the camera's top-left in art pixels. Clear both every frame. To show it, draw `light` with additive blending ("lighter"), then `color` over it with normal alpha blending (some of its pixels are partly transparent), scaled up without smoothing.
- Positions, sizes and speeds are in world units, 2 per art pixel. Times are in seconds.
- Hooks are optional callbacks into your game (camera shake, screen flash...): leave out any you don't have.
- In an engine that doesn't run TypeScript (Godot, Unity, GameMaker...), port the file to its language, or rebuild the effect from its recipe: its timings, layers, palette and numbers are what make it look right.

## Source: energy.ts

```ts
// Made by Sprite Fusion, to have full context over VFX, connect to the MCP: https://www.spritefusion.com/mcp
// MIT License
// Copyright (c) 2026 Hugo Duprez
export interface Frame { w: number; h: number; ox: number; oy: number; color: Uint32Array; light: Uint32Array }
export type Layer = "back" | "front";
export interface Actor { hand(): { x: number; y: number; a: number } }
export interface Options {
  kind?: "charge" | "beam" | "orb" | "bolt";
  actor?: Actor;
  x?: number;
  y?: number;
  to?: [number, number];
  colors?: keyof typeof RAMPS | number[];
  ground?: number | ((x: number) => number);
  seed?: number;
  charge?: number;
  hold?: number;
  width?: number;
  radius?: number;
  every?: [number, number];
  speed?: number;
  shake?(trauma: number): void;
  kick?(dx: number, dy: number): void;
  flash?(k: number, rgb: string): void;
  ripple?(x: number, y: number, r0: number, r1: number, dur: number, amp: number, w: number): void;
}
interface Ctx {
  o: Options;
  R: Rng;
  C: number[];
  ps: Particles;
  lights: Light[];
  groundAt: (x: number) => number;
  hand: () => { x: number; y: number; a: number };
}
interface Run { update(dt: number): void; back?(buf: Px, light: Px): void; front(buf: Px, light: Px): void; over(): boolean; stop?(): void }
export default function energy(o: Options = {}) {
  const R = new Rng(o.seed ?? 1), C = typeof o.colors === "object" ? o.colors : RAMPS[o.colors ?? "cyan"];
  const groundAt = (x: number) => (o.ground === undefined ? Infinity : typeof o.ground === "number" ? o.ground : o.ground(x));
  const ps = new Particles(R, groundAt, C), lights: Light[] = [];
  const hand = () => o.actor?.hand() ?? { x: o.x ?? 430, y: o.y ?? 552, a: 0 };
  const c: Ctx = { o, R, C, ps, lights, groundAt, hand };
  const kind = o.kind ?? "charge";
  const run = kind === "beam" ? beam(c) : kind === "orb" ? orb(c) : kind === "bolt" ? projectile(c) : charge(c);
  return {
    update(dt: number) { run.update(dt); ps.update(dt); stepLights(lights, dt); },
    draw(f: Frame, layer?: Layer) {
      const buf = new Px(f, f.color), light = new Px(f, f.light);
      if (layer !== "front") { run.back?.(buf, light); ps.draw(buf, light, "back"); }
      if (layer !== "back") { run.front(buf, light); ps.draw(buf, light, "front"); drawLights(light, lights); }
    },
    stop: () => run.stop?.(),
    done: () => run.over() && ps.list.length === 0 && lights.length === 0,
  };
}
function charge({ o, R, C, ps, lights, hand }: Ctx): Run {
  const REL = o.charge ?? 2.8, rumble = holder(o.shake);
  const sparks: { b: Bolt; t: number }[] = [];
  let t = 0, released = false, phase = 0, pulses: number[] = [], rel: [number, number] = [0, 0];
  const level = () => clamp(t / REL);
  return {
    update(dt) {
      t += dt;
      const k = level(), e = k * k, m = hand();
      if (t < REL) {
        for (let i = 0; i < 1 + Math.floor(e * 6); i++) {
          const a = R.range(0, TAU), d = R.range(60, 170) * (1 - 0.35 * k), life = R.range(0.16, 0.26), sp = (d / life) * 0.95;
          ps.spawn(K.MOTE, m.x + Math.cos(a) * d, m.y + Math.sin(a) * d, -Math.cos(a) * sp - Math.sin(a) * sp * 0.4, -Math.sin(a) * sp + Math.cos(a) * sp * 0.4, life, R.pick([C[0]!, C[1]!, C[2]!]), 1);
        }
        phase += (2 + 13 * e) * dt;
        if (phase >= 1) { phase -= 1; pulses.push(t); }
        if (k > 0.4 && R.chance(0.25 * k)) {
          const a = R.range(0, TAU), l = R.range(6, 12) * (0.5 + k), x0 = m.x / PX, y0 = m.y / PX;
          sparks.push({ b: bolt(R, x0, y0, x0 + Math.cos(a) * l, y0 + Math.sin(a) * l, 0.4, 0.3, 0.7), t });
        }
        rumble(0.08 * e, dt);
      } else if (!released) {
        released = true;
        rel = [m.x, m.y];
        o.flash?.(0.8, rgbString(C[1]!));
        o.shake?.(0.35);
        o.ripple?.(m.x, m.y, 10, 300, 0.6, 0.18, 40);
        lights.push({ x: m.x, y: m.y, r: 240, color: C[2]!, k: 1, life: 0.45, max: 0.45 });
        for (let i = 0; i < 70; i++) {
          const a = R.range(0, TAU), sp = R.range(200, 900);
          ps.spawn(R.chance(0.65) ? K.MOTE : K.STAR, m.x, m.y, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.3, 0.8), R.pick([C[0]!, C[1]!, C[2]!]), R.range(0.8, 2));
        }
      }
      pulses = pulses.filter((p) => t - p < 0.2);
      for (let i = sparks.length - 1; i >= 0; i--) if (t - sparks[i]!.t > 0.06) sparks.splice(i, 1);
    },
    front(buf, light) {
      const k = level();
      if (t < REL) {
        const m = hand(), jit = k > 0.8 ? (Math.floor(t * 40) % 2 ? 1 : -1) * ((k - 0.8) / 0.2) : 0, ox = m.x / PX + jit, oy = m.y / PX;
        const pr = Math.sin(phase * TAU) * 0.5 + 0.5, r = 1.2 + 5.5 * k * k + pr * (0.6 + 1.2 * k);
        orbBall(buf, ox, oy, r, t, k, C);
        for (const p of pulses) {
          const q = (t - p) / 0.2;
          buf.ring(ox, oy, r + 2 + 16 * (1 - outCubic(q)) * (0.5 + k), 1, q > 0.6 ? C[0]! : C[1]!, 1 - q * 0.6);
        }
        for (const sp of sparks) drawBolt(buf, light, sp.b, { core: C[0]!, body: C[1]!, halo: C[3]!, glow: C[2]! }, 1, 0.3);
        light.glow(ox, oy, 12 + 30 * k, C[2]!, 0.5 + 0.6 * k);
        light.glow(ox, oy, 6 + 6 * k, C[0]!, 0.5 + 0.4 * k);
      }
      if (t >= REL && t <= REL + 0.6) {
        const q = (t - REL) / 0.6, e = outCubic(q), ox = rel[0] / PX, oy = rel[1] / PX;
        if (q < 0.12) { buf.disc(ox, oy, 12 * (1 - q * 5) + 1.5, C[2]!); buf.disc(ox, oy, 12 * (1 - q * 5), C[0]!); }
        if (q < 0.3) cross(buf, ox, oy, (1 - q / 0.3) * 30 + 4, C);
        buf.ring(ox, oy, 4 + 80 * e, Math.max(1, 5 * (1 - q)), q < 0.2 ? C[0]! : C[1]!, 1.2 - q);
        buf.ring(ox, oy, 2 + 44 * outCubic(q * 1.4), Math.max(1, 2 * (1 - q)), C[2]!, 1 - q);
        light.glow(ox, oy, 130 * (0.4 + 0.6 * e), C[2]!, 1.1 * (1 - q));
      }
    },
    over: () => t > REL + 1,
  };
}
function orbBall(buf: Px, x: number, y: number, r: number, t: number, k: number, C: number[]) {
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * TAU + t * 1.5, l = (2 + 6 * k) * (0.5 + 0.5 * Math.abs(noise(t * 14 + i * 3, i)));
    if (k > 0.2) seg(buf, x + Math.cos(a) * (r + 1), y + Math.sin(a) * (r + 1), x + Math.cos(a) * (r + 1 + l), y + Math.sin(a) * (r + 1 + l), i % 2 ? C[2]! : C[1]!);
  }
  buf.disc(x, y, r + 1.2, C[4]!);
  buf.disc(x, y, r, C[2]!);
  buf.disc(x - r * 0.12, y - r * 0.12, r * 0.72, C[1]!);
  buf.disc(x, y, r * 0.42, C[0]!);
  if (r > 3)
    for (const s of [0, Math.PI])
      for (let a = 0; a < 1.2; a += 0.12) {
        const ang = t * 9 + s + a, rr = r * (0.58 + 0.12 * Math.sin(a * 3));
        dot(buf, x + Math.cos(ang) * rr, y + Math.sin(ang) * rr, a < 0.5 ? C[0]! : C[1]!);
      }
}
function cross(buf: Px, x: number, y: number, l: number, C: number[]) {
  for (let d = -l; d <= l; d++) {
    const a = Math.abs(d) / l, c = a < 0.3 ? C[0]! : a < 0.65 ? C[1]! : C[2]!;
    dot(buf, x + d, y, c, 1.15 - a);
    dot(buf, x, y + d * 0.7, c, 1.15 - a);
  }
}
function beam({ o, R, C, ps, lights, groundAt, hand }: Ctx): Run {
  const [IX, IY] = o.to ?? [920, 596], FIRE = o.charge ?? 0.55, TAPER = FIRE + (o.hold ?? 1.95), OFF = TAPER + 0.4, W = o.width ?? 6.5;
  const GY = groundAt(IX), molten = Number.isFinite(GY) && Math.abs(GY - IY) < 30, SMOKE_TINTED = mix(SMOKE_TINT, C[3]!, 0.45);
  let t = 0, fired = false, heat = 0;
  const width = (t: number) => (t < FIRE ? 0 : t < TAPER ? W * (1 + 0.35 * Math.exp(-(t - FIRE) * 10)) : lerp(W, 0.4, outCubic((t - TAPER) / (OFF - TAPER))));
  const on = (t: number) => t >= FIRE && t < OFF;
  return {
    update(dt) {
      t += dt;
      const m = hand();
      if (t < FIRE) gather(ps, lights, R, C, m.x, m.y, clamp(t / FIRE));
      if (t >= FIRE && !fired) { fired = true; o.flash?.(0.45, rgbString(C[1]!)); o.shake?.(0.15); o.kick?.(-3 * Math.sign(IX - m.x || 1), 0); }
      if (on(t)) {
        heat = Math.min(1, heat + dt * 1.2);
        const k = width(t) / W;
        for (let i = 0; i < 4 * k; i++) {
          const a = -Math.PI / 2 + R.range(-1.3, 0.9) - 0.4, sp = R.range(150, 560);
          ps.spawn(K.PLASMA, IX + R.range(-6, 6), IY - 2, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.15, 0.5));
        }
        if (R.chance(0.2)) ps.spawn(K.SMOKE, IX + R.range(-10, 10), IY - 6, R.range(-10, 10), R.range(-50, -20), R.range(1, 1.8), SMOKE_TINTED, R.range(3, 5));
        if (R.chance(0.5 * k)) {
          const u = R.next();
          ps.spawn(K.PLASMA, lerp(m.x, IX, u), lerp(m.y, IY, u), R.range(-60, 60), R.range(-90, 30), R.range(0.1, 0.25));
        }
      } else heat = Math.max(0, heat - dt * 0.6);
    },
    back(buf, light) {
      if (molten && heat > 0.02) {
        const cx = IX / PX, cy = Math.round(GY / PX);
        for (let y = cy; y <= cy + 3; y++)
          for (let x = Math.floor(cx - 18); x <= cx + 18; x++) {
            const d = Math.abs(x + 0.5 - cx) / 18 + (y - cy) * 0.22, T = heat * (1.15 - d) - hash(x * 13 + y) * 0.3;
            if (T > 0.05) buf.set(x, y, HEAT_RAMP[Math.min(HEAT_RAMP.length - 1, Math.floor((1 - Math.min(1, T)) * (HEAT_RAMP.length - 1)))]!);
          }
        light.glow(cx, cy, 30, HEAT_RAMP[4]!, 0.4 * heat);
      }
    },
    front(buf, light) {
      const m = hand(), ax = m.x / PX, ay = m.y / PX, bx = IX / PX, by = IY / PX;
      if (t < FIRE) {
        const k = t / FIRE, r = 1 + 3.5 * k * k;
        buf.disc(ax, ay, r + 1, C[3]!);
        buf.disc(ax, ay, r, C[2]!);
        buf.disc(ax, ay, r * 0.5, C[0]!);
        return;
      }
      if (!on(t)) return;
      const L0 = Math.hypot(bx - ax, by - ay), dx = (bx - ax) / L0, dy = (by - ay) / L0, nx = -dy, ny = dx;
      const L = L0 * outExpo((t - FIRE) / 0.07), w0 = width(t), k = w0 / W;
      for (let d = 0; d <= L; d += 0.5) {
        const w = w0 * (1 + 0.12 * Math.sin(d * 0.35 - t * 42)) * Math.min(1, (d + 3) / 7), x = ax + dx * d, y = ay + dy * d;
        const pulse = frac(d * 0.025 - t * 3.4) < 0.07 ? 1 : 0;
        for (let q0 = -w * 1.3; q0 <= w * 1.3; q0 += 0.5) {
          const q = Math.abs(q0) / Math.max(0.3, w), px = Math.floor(x + nx * q0), py = Math.floor(y + ny * q0);
          const lvl = Math.max(0, (q < 0.2 ? 0 : q < 0.4 ? 1 : q < 0.62 ? 2 : q < 0.85 ? 3 : q < 1 ? 4 : 5) - pulse);
          if (lvl === 5 && bayer(px, py) > (1.3 - q) / 0.3) continue;
          buf.set(px, py, C[lvl]!);
        }
        for (const s of [0, Math.PI]) {
          const ph = d * 0.2 - t * 28 + s, q0 = Math.sin(ph) * w * 0.85;
          if (Math.cos(ph) > -0.2) dot(buf, x + nx * q0, y + ny * q0, Math.cos(ph) > 0.5 ? C[0]! : C[1]!);
        }
        if ((Math.round(d * 2) & 11) === 0) light.glow(x, y, w * 2.2 + 4, C[3]!, 0.3 * k);
      }
      const fr = 3 + 2 * k + Math.sin(t * 50) * 0.6;
      buf.disc(ax, ay, fr + 1.5, C[3]!);
      buf.disc(ax, ay, fr, C[2]!);
      buf.disc(ax, ay, fr * 0.6, C[0]!);
      for (let i = 0; i < 4; i++) {
        const a = t * 9 + (i * TAU) / 4, l = (6 + 3 * Math.sin(t * 30 + i)) * k;
        seg(buf, ax, ay, ax + Math.cos(a) * l, ay + Math.sin(a) * l, i % 2 ? C[2]! : C[0]!);
      }
      light.glow(ax, ay, 26 * k + 8, C[2]!, 0.9 * k);
      if (L >= L0 - 0.5) {
        const ir = 4 + 2.5 * k + Math.sin(t * 60) * 0.8;
        buf.disc(bx, by, ir + 1.5, C[3]!);
        buf.disc(bx, by, ir, C[1]!);
        buf.disc(bx, by, ir * 0.55, C[0]!);
        for (let i = 0; i < 7; i++) {
          const a = -Math.PI / 2 + (i - 3) * 0.32 - 0.5, l = (8 + 7 * Math.abs(noise(t * 18 + i * 3, i))) * k;
          seg(buf, bx, by - 1, bx + Math.cos(a) * l, by + Math.sin(a) * l, i % 2 ? C[2]! : C[1]!);
        }
        light.glow(bx, by, 50 * k + 10, C[2]!, 1 * k);
        light.glow(bx, by, 14, C[0]!, 0.7 * k);
      }
    },
    over: () => t > OFF && heat <= 0,
  };
}
function gather(ps: Particles, lights: Light[], R: Rng, C: number[], x: number, y: number, k: number) {
  for (let i = 0; i < 2 + Math.floor(k * 4); i++) {
    const a = R.range(0, TAU), d = R.range(34, 96) * (1 - k * 0.45), sp = d * R.range(6, 9);
    ps.spawn(K.PLASMA, x + Math.cos(a) * d, y + Math.sin(a) * d, -Math.cos(a) * sp - Math.sin(a) * sp * 0.45, -Math.sin(a) * sp + Math.cos(a) * sp * 0.45, R.range(0.1, 0.14));
  }
  if (R.chance(0.3 + k * 0.4)) ps.spawn(K.GLINT, x + R.range(-3, 3), y + R.range(-3, 3), 0, 0, 0.03, C[2]!, 1 + k);
  lights.push({ x, y, r: 30 + 70 * k, color: C[3]!, k: 0.5 + 0.7 * k, life: 0.05, max: 0.05 });
  lights.push({ x, y, r: 14 + 18 * k, color: C[0]!, k: 0.3 * k, life: 0.04, max: 0.04 });
}
function orb({ o, R, C, ps, lights, groundAt }: Ctx): Run {
  const X = o.x ?? 760, Y0 = o.y ?? 484, RAD = o.radius ?? 20, [E0, E1] = o.every ?? [1.1, 1.5];
  const COLS = { core: C[0]!, body: C[2]!, halo: C[4]!, glow: C[3]! };
  const fils = Array.from({ length: 6 }, (_, i) => ({ a: (i / 6) * TAU, w: (0.5 + hash(i, 1) * 0.9) * (i % 2 ? 1 : -1), b: null as Bolt | null, end: [0, 0] as [number, number] }));
  const motes = Array.from({ length: 8 }, (_, i) => ({ a: hash(i, 4) * TAU, w: 1.6 + hash(i, 5) * 1.4, r: RAD + 4 + hash(i, 6) * 7, tilt: (hash(i, 7) - 0.5) * 1.4 }));
  let t = 0, zap: { b: Bolt; t: number } | null = null, struck = -1, nextZap = 1.75, stopAt = Infinity;
  const centre = (): [number, number] => [X / PX, Y0 / PX + Math.sin(t * 1.7) * 3];
  const size = () => (t < stopAt ? smooth(0, 0.3, t) : 1 - smooth(stopAt, stopAt + 0.4, t));
  const motePos = (m: (typeof motes)[number], cx: number, cy: number, s: number) => {
    const a = m.a + m.w * t, x = Math.cos(a) * m.r * s, z = Math.sin(a);
    return { x: cx + x * Math.cos(m.tilt), y: cy + x * Math.sin(m.tilt) + z * m.r * s * 0.28, z };
  };
  return {
    update(dt) {
      t += dt;
      const [cx, cy] = centre(), s = size(), rad = RAD * s, f = Math.floor(t * 30);
      if (f !== struck && f % 2 === 0 && s > 0.05) {
        struck = f;
        for (const [i, fl] of fils.entries()) {
          fl.a += fl.w * 0.07 + noise(t * 2 + i, i) * 0.12;
          fl.end = [cx + Math.cos(fl.a) * (rad - 0.8), cy + Math.sin(fl.a) * (rad - 0.8)];
          fl.b = bolt(R, cx, cy, fl.end[0], fl.end[1], 0.2, 0.5, 0.35);
        }
      }
      const G = groundAt(X);
      if (t >= nextZap && t < stopAt && Number.isFinite(G)) {
        nextZap = t + R.range(E0, E1);
        const x1 = cx + R.range(-30, 30);
        zap = { b: bolt(R, cx, cy + rad, x1, G / PX, 0.3, 0.5), t };
        for (let i = 0; i < 16; i++) ps.spawn(K.STAR, x1 * PX, G - 2, R.range(-180, 180), -R.range(60, 260), R.range(0.25, 0.6), R.pick([C[0]!, C[1]!, C[2]!]), R.range(0.6, 1.4));
        lights.push({ x: x1 * PX, y: G - 6, r: 90, color: C[3]!, k: 0.7, life: 0.15, max: 0.15 });
      }
      if (zap && t - zap.t > 0.12) zap = null;
      if (t < stopAt && R.chance(0.15)) {
        const a = R.range(0, TAU);
        ps.spawn(K.MOTE, (cx + Math.cos(a) * (rad + 1)) * PX, (cy + Math.sin(a) * (rad + 1)) * PX, Math.cos(a) * 40, Math.sin(a) * 40 - 20, R.range(0.4, 0.8), C[2]!, 0.8);
      }
    },
    back(buf, light) {
      const [cx, cy] = centre(), s = size();
      if (s <= 0.02) return;
      for (const m of motes) {
        const p = motePos(m, cx, cy, s);
        if (p.z >= 0) continue;
        dot(buf, p.x, p.y, C[4]!);
        dot(buf, p.x - Math.sign(m.w), p.y, C[5]!, 0.6);
      }
      const pl = 0.8 + 0.2 * Math.sin(t * 7) + 0.1 * noise(t * 20, 2);
      light.glow(cx, cy, 52 * pl * s, C[3]!, 0.5 * pl * s);
    },
    front(buf, light) {
      const [cx, cy] = centre(), s = size(), rad = RAD * s, pulse = 0.8 + 0.2 * Math.sin(t * 7);
      if (s > 0.02) {
        for (let y = Math.floor(cy - rad); y <= Math.ceil(cy + rad); y++)
          for (let x = Math.floor(cx - rad); x <= Math.ceil(cx + rad); x++) {
            const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) / rad;
            if (d > 1) continue;
            if (0.15 + 0.55 * d * d > bayer(x, y)) buf.set(x, y, d > 0.8 ? C[6]! : C[7]!);
          }
        for (const fl of fils) {
          if (!fl.b) continue;
          for (const p of fl.b.paths)
            for (let i = 0; i < p.pts.length - 1; i++) {
              const [x0, y0] = p.pts[i]!, [x1, y1] = p.pts[i + 1]!, u = Math.hypot(x0 - cx, y0 - cy) / rad;
              seg(buf, x0 + 1, y0, x1 + 1, y1, C[4]!, 0.5);
              seg(buf, x0, y0, x1, y1, p.w > 0.3 && u < 0.4 ? C[0]! : p.w > 0.3 ? C[1]! : C[2]!);
              if (i % 3 === 0) light.glow(x0, y0, 5, C[3]!, 0.2);
            }
          const [ex, ey] = fl.end;
          buf.disc(ex, ey, 1.6, C[1]!);
          buf.set(Math.floor(ex), Math.floor(ey), C[0]!);
          light.glow(ex, ey, 6, C[2]!, 0.5);
        }
        const cr = (2.4 + 1.2 * pulse) * s;
        buf.disc(cx, cy, cr + 1.4, C[3]!);
        buf.disc(cx, cy, cr, C[1]!);
        buf.disc(cx, cy, cr * 0.55, C[0]!);
        light.glow(cx, cy, 16, C[0]!, 0.55 * pulse * s);
        buf.ring(cx, cy, rad + 0.3, 1, C[3]!);
        buf.ring(cx, cy, rad + 1.2, 1, C[6]!);
        for (let a = 3.5; a < 4.6; a += 0.04) dot(buf, cx + Math.cos(a) * (rad - 2.2), cy + Math.sin(a) * (rad - 2.2), a > 3.8 && a < 4.3 ? C[0]! : C[1]!);
        buf.disc(cx - rad * 0.42, cy - rad * 0.5, 1, C[0]!);
        dot(buf, cx + rad * 0.5, cy + rad * 0.55, C[2]!);
        for (const m of motes) {
          const p = motePos(m, cx, cy, s);
          if (p.z < 0) continue;
          dot(buf, p.x, p.y, C[0]!);
          dot(buf, p.x - Math.sign(m.w), p.y, C[2]!);
          dot(buf, p.x - 2 * Math.sign(m.w), p.y, C[4]!, 0.6);
          light.glow(p.x, p.y, 5, C[2]!, 0.35);
        }
      }
      if (zap) drawBolt(buf, light, zap.b, COLS, 1 - (t - zap.t) / 0.15, 0.6);
    },
    over: () => t > stopAt + 0.4 && !zap,
    stop() { stopAt = Math.min(stopAt, t); },
  };
}
function projectile({ o, R, C, ps, lights, groundAt, hand }: Ctx): Run {
  const CH = o.charge ?? 0.28, SPEED = o.speed ?? 1100;
  const trail: [number, number][] = [];
  let t = 0, from: [number, number] | null = null, to: [number, number] = [0, 0], T = 1, hit = -1;
  const head = (): [number, number] => { if (!from) return [0, 0]; const u = clamp((t - CH) / T); return [lerp(from[0], to[0], u), lerp(from[1], to[1], u)]; };
  return {
    update(dt) {
      t += dt;
      const m = hand();
      if (t < CH) {
        if (R.chance(0.7)) {
          const a = R.range(0, TAU), d = R.range(20, 50), sp = d / 0.12;
          ps.spawn(K.MOTE, m.x + Math.cos(a) * d, m.y + Math.sin(a) * d, -Math.cos(a) * sp, -Math.sin(a) * sp, 0.12, R.pick([C[0]!, C[1]!, C[2]!]), 0.8);
        }
        return;
      }
      if (!from) {
        from = [m.x, m.y];
        to = o.to ?? [m.x + Math.cos(m.a) * 420, m.y + Math.sin(m.a) * 420];
        T = Math.max(0.05, Math.hypot(to[0] - from[0], to[1] - from[1]) / SPEED);
        o.kick?.(-2 * Math.sign(to[0] - from[0] || 1), 0);
        lights.push({ x: from[0], y: from[1], r: 70, color: C[2]!, k: 0.8, life: 0.1, max: 0.1 });
      }
      if (hit < 0) {
        const [x, y] = head();
        trail.push([x, y]);
        if (trail.length > 7) trail.shift();
        if (R.chance(0.7)) ps.spawn(K.MOTE, x, y, R.range(-60, 60), R.range(-60, 60), R.range(0.15, 0.3), R.pick([C[1]!, C[2]!]), 0.7);
        if (t - CH >= T) {
          hit = t;
          trail.length = 0;
          o.shake?.(0.12);
          o.flash?.(0.15, rgbString(C[1]!));
          const onGround = Math.abs(groundAt(x) - y) < 8;
          for (let i = 0; i < 26; i++) {
            const a = (onGround ? -Math.PI / 2 + R.range(-1.4, 1.4) : R.range(0, TAU)), sp = R.range(200, 700);
            ps.spawn(K.PLASMA, x, y - 1, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.15, 0.45));
          }
          for (let i = 0; i < 14; i++) {
            const a = R.range(0, TAU), sp = R.range(80, 300);
            ps.spawn(i % 2 ? K.STAR : K.MOTE, x, y, Math.cos(a) * sp, Math.sin(a) * sp - (onGround ? 120 : 0), R.range(0.25, 0.6), R.pick([C[0]!, C[1]!, C[2]!]), R.range(0.8, 1.6));
          }
          lights.push({ x, y, r: 150, color: C[3]!, k: 0.9, life: 0.25, max: 0.25 });
        }
      }
    },
    front(buf, light) {
      if (t < CH) {
        const m = hand(), k = t / CH, r = 0.8 + 2.6 * k;
        buf.disc(m.x / PX, m.y / PX, r + 1, C[3]!);
        buf.disc(m.x / PX, m.y / PX, r, C[1]!);
        buf.disc(m.x / PX, m.y / PX, r * 0.5, C[0]!);
        light.glow(m.x / PX, m.y / PX, 10 + 14 * k, C[2]!, 0.6 * k);
        return;
      }
      if (hit < 0 && from) {
        const [hx, hy] = head(), ax = hx / PX, ay = hy / PX;
        for (let i = 0; i < trail.length - 1; i++) {
          const [x0, y0] = trail[i]!, [x1, y1] = trail[i + 1]!, u = (i + 1) / trail.length;
          for (let d = 0; d <= 1; d += 0.1) {
            const x = lerp(x0, x1, d) / PX, y = lerp(y0, y1, d) / PX, w = 0.6 + 2.6 * (u - 0.1 + d * 0.1);
            if (w > 1.6) buf.disc(x, y, w, C[3]!);
            buf.disc(x, y, Math.max(0.6, w * 0.55), u > 0.6 ? C[1]! : C[2]!);
          }
          light.glow(x0 / PX, y0 / PX, 8 * u + 2, C[3]!, 0.3 * u);
        }
        for (let i = 0; i < 4; i++) {
          const a = t * 22 + (i * TAU) / 4, l = 5 + 1.5 * Math.sin(t * 50 + i);
          seg(buf, ax + Math.cos(a) * 3, ay + Math.sin(a) * 3, ax + Math.cos(a) * l, ay + Math.sin(a) * l, C[1]!);
        }
        buf.disc(ax, ay, 4.2, C[4]!);
        buf.disc(ax, ay, 3.3, C[2]!);
        buf.disc(ax, ay, 2.3, C[1]!);
        buf.disc(ax, ay, 1.3, C[0]!);
        light.glow(ax, ay, 26, C[3]!, 0.7);
        light.glow(ax, ay, 9, C[0]!, 0.5);
      }
      if (hit >= 0 && t - hit < 0.35) {
        const q = (t - hit) / 0.35, [x, y] = to, ax = x / PX, ay = y / PX;
        if (q < 0.15) { buf.disc(ax, ay, 9 * (1 - q * 3) + 1.5, C[3]!); buf.disc(ax, ay, 9 * (1 - q * 3), C[0]!); }
        if (q < 0.4) cross(buf, ax, ay, 18 * (1 - q / 0.4) + 3, C);
        buf.ring(ax, ay, 3 + 22 * outCubic(q), Math.max(1, 3 * (1 - q)), q < 0.3 ? C[0]! : C[2]!, 1.2 - q);
      }
    },
    over: () => hit >= 0 && t - hit > 0.4,
  };
}
function holder(shake?: (trauma: number) => void) {
  let held = 0;
  return (level: number, dt: number) => { held = Math.max(0, held - 1.7 * dt); if (level > held) { shake?.(level - held); held = level; } };
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
function dot(buf: Px, x: number, y: number, c: number, a = 1) {
  const px = Math.floor(x), py = Math.floor(y);
  if (a >= 1 || a > bayer(px, py)) buf.set(px, py, c);
}
function seg(buf: Px, x0: number, y0: number, x1: number, y1: number, c: number, a = 1) {
  const n = Math.max(1, Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2));
  for (let i = 0; i <= n; i++) dot(buf, x0 + ((x1 - x0) * i) / n, y0 + ((y1 - y0) * i) / n, c, a);
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
function rgbString(c: number) {
  return `${c & 255},${(c >>> 8) & 255},${(c >>> 16) & 255}`;
}
export const RAMPS = {
  cyan: ["#ffffff", "#d6ffff", "#7ff3ff", "#1ab8e6", "#2b6fd2", "#25449c", "#1b2662", "#0f1538"].map(hex),
  gold: ["#fffbe8", "#ffec92", "#ffd243", "#f4a923", "#c9761b", "#8c4716", "#512611", "#2c140b"].map(hex),
  pink: ["#ffffff", "#ffd8f5", "#ff9ee4", "#ff5fd0", "#d43cc4", "#8a2bb0", "#4b1a7a", "#250d42"].map(hex),
};
const HEAT_RAMP = ["#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4f1a13", "#2a120e"].map(hex);
const SMOKE_RAMP = ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"].map(hex);
const SMOKE_TINT = hex("#5b5566");
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
  chance(p: number) { return this.next() < p; }
  pick<T>(a: readonly T[]): T { return a[Math.floor(this.next() * a.length)]!; }
}
const TAU = Math.PI * 2;
function clamp(v: number, a = 0, b = 1) { return v < a ? a : v > b ? b : v; }
function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }
function smooth(a: number, b: number, x: number) { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function outCubic(t: number) { return 1 - Math.pow(1 - clamp(t), 3); }
function outExpo(t: number) { return t >= 1 ? 1 : 1 - Math.pow(2, -10 * clamp(t)); }
function frac(x: number) { return x - Math.floor(x); }
function hash(n: number, k = 0) { return ((Math.imul(n + 1 + k * 7919, 2654435761) >>> 0) % 100000) / 100000; }
function noise(x: number, seed = 0) {
  const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
  return lerp(hash(i, seed) * 2 - 1, hash(i + 1, seed) * 2 - 1, u);
}
const K = { MOTE: 0, STAR: 1, PLASMA: 2, SMOKE: 3, GLINT: 4 } as const;
type K = (typeof K)[keyof typeof K];
interface P { k: K; x: number; y: number; vx: number; vy: number; life: number; max: number; col: number; size: number; seed: number }
class Particles {
  list: P[] = [];
  t = 0;
  R: Rng;
  ground: (x: number) => number;
  C: number[];
  constructor(R: Rng, ground: (x: number) => number, C: number[]) { this.R = R; this.ground = ground; this.C = C; }
  spawn(k: K, x: number, y: number, vx: number, vy: number, life: number, col = 0, size = 1) {
    this.list.push({ k, x, y, vx, vy, life, max: life, col, size, seed: this.R.next() * 100 });
  }
  update(dt: number) {
    this.t += dt;
    const t = this.t, L = this.list;
    for (let i = L.length - 1; i >= 0; i--) {
      const p = L[i]!;
      if ((p.life -= dt) <= 0) { L.splice(i, 1); continue; }
      switch (p.k) {
        case K.MOTE:
          p.vx -= p.vx * 0.6 * dt;
          p.vy -= p.vy * 0.6 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case K.STAR:
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.6 * dt + 10 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case K.PLASMA: {
          p.vy += 1900 * 0.45 * dt;
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt;
          const g = this.ground(p.x), ny = p.y + p.vy * dt;
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
        case K.GLINT:
          break;
      }
    }
  }
  draw(buf: Px, light: Px, layer: Layer) { for (const p of this.list) if ((p.k === K.SMOKE) === (layer === "back")) this.drawOne(p, buf, light); }
  private drawOne(p: P, buf: Px, light: Px) {
    const k = p.life / p.max, ax = p.x / PX, ay = p.y / PX, px = Math.floor(ax), py = Math.floor(ay), C = this.C;
    switch (p.k) {
      case K.MOTE: {
        const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(16, 0.5 + sp * 0.013) * p.size;
        if (k < 0.35 && bayer(px, py) > k / 0.35) break;
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.35, ay - uy * len * 0.35, scale(p.col, 0.55));
        buf.line(ax - ux * len * 0.4, ay - uy * len * 0.4, ax, ay, p.col);
        light.glow(ax, ay, 2.5 + p.size, p.col, 0.4 * k);
        break;
      }
      case K.STAR: {
        const tw = 0.6 + 0.4 * Math.sin(this.t * (8 + (p.seed % 5)) + p.seed);
        if (p.size < 1) { if (tw * k > 0.25) buf.set(px, py, tw > 0.8 ? C[0]! : p.col); light.glow(ax, ay, 3, p.col, 0.4 * k * tw); break; }
        const arm = Math.max(1, Math.round(p.size * tw * Math.min(1, k * 3))), tip = scale(p.col, 0.75);
        for (let d = 1; d <= arm; d++) {
          const cc = d === arm && arm > 1 ? tip : p.col;
          buf.set(px + d, py, cc);
          buf.set(px - d, py, cc);
          buf.set(px, py + d, cc);
          buf.set(px, py - d, cc);
        }
        buf.set(px, py, C[0]!);
        light.glow(ax, ay, 3 + arm * 2, p.col, 0.5 * k * tw);
        break;
      }
      case K.PLASMA: {
        const hot = k > 0.5 ? C[0]! : k > 0.25 ? C[2]! : C[3]!;
        const sp = Math.hypot(p.vx, p.vy) || 1, ux = p.vx / sp, uy = p.vy / sp, len = Math.min(9, 1 + sp * 0.011);
        buf.line(ax - ux * len, ay - uy * len, ax - ux * len * 0.4, ay - uy * len * 0.4, k > 0.5 ? hot : C[3]!);
        buf.line(ax - ux * len * 0.45, ay - uy * len * 0.45, ax, ay, hot);
        light.glow(ax, ay, 3, hot, 0.45 * k);
        break;
      }
      case K.SMOKE: {
        const age = 1 - k, r = p.size * (0.65 + Math.min(1, age * 2.5) * 0.45 + age * 0.4);
        const a = Math.min(1, age * 12) * Math.min(1, k * 2.4) * 0.58;
        const c = p.col ? mix(p.col, ramp(SMOKE_RAMP, age), age) : ramp(SMOKE_RAMP, age * 1.05);
        buf.alphaDisc(ax, ay, r, c, a * 0.45);
        buf.alphaDisc(ax + r * 0.05, ay + r * 0.06, r * 0.74, c, a * 0.62);
        break;
      }
      case K.GLINT: {
        const r = p.size * (0.5 + k * 0.5);
        buf.disc(ax, ay, r + 0.8, C[3]!);
        buf.disc(ax, ay, r, p.col);
        light.glow(ax, ay, p.size * 4, p.col, 0.6 * k);
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
interface Bolt { paths: { pts: [number, number][]; w: number }[] }
function bolt(R: Rng, x0: number, y0: number, x1: number, y1: number, jag = 0.32, forks = 0.35, w = 1, depth = 0): Bolt {
  const out: Bolt = { paths: [] }, L = Math.hypot(x1 - x0, y1 - y0);
  let pts: [number, number][] = [[x0, y0], [x1, y1]], off = L * jag;
  while (pts.length < 2 + L / 3) {
    const nxt: [number, number][] = [pts[0]!];
    for (let i = 0; i < pts.length - 1; i++) {
      const [ax, ay] = pts[i]!, [bx, by] = pts[i + 1]!, l = Math.hypot(bx - ax, by - ay) || 1, o = R.range(-off, off);
      nxt.push([(ax + bx) / 2 + (-(by - ay) / l) * o, (ay + by) / 2 + ((bx - ax) / l) * o], [bx, by]);
    }
    pts = nxt;
    off *= 0.52;
  }
  out.paths.push({ pts, w });
  if (depth < 2)
    for (let i = 2; i < pts.length - 3; i++)
      if (R.chance(forks / (1 + depth) / Math.max(4, pts.length / 6))) {
        const [ax, ay] = pts[i]!, [bx, by] = pts[Math.min(pts.length - 1, i + 3)]!;
        const a = Math.atan2(by - ay, bx - ax) + R.sign() * R.range(0.35, 0.9), l = (L - (i / pts.length) * L) * R.range(0.25, 0.55);
        out.paths.push(...bolt(R, ax, ay, ax + Math.cos(a) * l, ay + Math.sin(a) * l, jag * 1.1, forks, w * 0.55, depth + 1).paths);
      }
  return out;
}
function drawBolt(buf: Px, light: Px, b: Bolt, cols: { core: number; body: number; halo: number; glow: number }, k = 1, glowK = 0.5) {
  for (const p of b.paths) {
    const thick = p.w >= 1;
    for (let i = 0; i < p.pts.length - 1; i++) {
      const [ax, ay] = p.pts[i]!, [bx, by] = p.pts[i + 1]!, l = Math.max(1, Math.hypot(bx - ax, by - ay));
      for (let d = 0; d <= l; d += 0.5) {
        const x = ax + ((bx - ax) * d) / l, y = ay + ((by - ay) * d) / l;
        if (k > 0.45 && thick) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) dot(buf, x + dx! * 1.5, y + dy! * 1.5, cols.halo, (k - 0.45) * 1.6);
        if (k > 0.25 && (thick || p.w > 0.4)) for (const [dx, dy] of [[1, 0], [0, 1]]) dot(buf, x + dx!, y + dy!, cols.body);
        buf.set(Math.floor(x), Math.floor(y), thick && k > 0.3 ? cols.core : cols.body);
      }
      if (i % 3 === 0) light.glow(ax, ay, (thick ? 9 : 5) * (0.5 + k * 0.5), cols.glow, glowK * k * p.w);
    }
  }
}
```
