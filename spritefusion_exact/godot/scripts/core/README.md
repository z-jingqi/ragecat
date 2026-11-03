# Exact Sprite Fusion pixel core

Original effects: Sprite Fusion, MIT, © 2026 Hugo Duprez. The source TypeScript is the numerical authority, not Godot's stock particles or an interpretation of the written recipes.

## API and units

- `sf_math.gd`: static `u32`, `i32`, `ushr`, `shl`, `imul`, `js_round`, `rgb`, `hex`, `mix`, `ramp`, `smooth`, `hash`, `hash_muzzle`, `noise`, `bayer`. Packed colors are unsigned **0xAABBGGRR**. Colors truncate channels exactly like JS bitwise operations; they do not round.
- `sf_rng.gd`: `new(seed=1)`, `next()`, `range(a,b)`, `integer(a,b)` (inclusive), `sign()`, `chance(p)`, `pick(array)`. `s` is the uint32 state. `next()` is exact Mulberry32, including zero-seed fallback and wraparound. Do not replace it with Godot's RNG.
- `sf_frame.gd`: `new(w,h,ox=0,oy=0)`, `clear()`, `set_origin(x,y)`, `as_source()`. Width, height, and origin use art pixels. World coordinates use two units per art pixel (**PX=2**).
- `frame.color` and `frame.light` are mutable `sf_pixel_buffer.gd` objects. They expose `w,h,ox,oy,data`; `data` is a `PackedInt64Array` containing uint32 words.
- Pixel methods: `at`, `put` (the original `set` name conflicts with Object.set), `blend`, `add`, `disc(cx,cy,r,c,a=1)`, `alpha_disc`, `ring`, `line`, `glow`, `rgba_bytes`, `to_image`.
- Fire uses its own unchecked typed-array indexing for `add`, unlike every other effect. Use `add_fire` and `glow(..., true)` for fire, preserving even fractional-camera behavior. Its optional-alpha `disc` is supported; opaque discs are identical for other effects.
- `sf_fixed_clock.gd`: fixed `DT=1.0/60.0`, `step(update_callable, count=1)` for deterministic tests and `advance(elapsed, update_callable)` for a variable-rate host. No random calls or simulation ticks are dropped. Match the original update count, not merely total elapsed time.
- `sf_canvas.gd`: add a Node2D instance to the tree, then call `present(frame)`. It displays additive light **before** straight-alpha color, scaled exactly 2× using nearest filtering.

## Layer contract

Clear the frame once per presentation. Call each effect's `draw(frame,"back")`, write character pixels into the same color buffer, then `draw(frame,"front")`. Do not clear between these stages. The original `draw(frame, "")` draws both sides and is useful for an actor-free preview. Separate back/front frames are useful for tests, but flattening transparent layers independently is not equivalent to one shared color buffer.

## Source-compatible adapter

Mechanically translated effects may retain their original local Px and Rng classes. Pass `frame.as_source()`, which returns `{w,h,ox,oy,color,light}` with the actual packed array references. Godot 4.6.3 aliases indexed PackedInt64Array mutations, proven by the tests. Do not replace the arrays while an alias is retained. The JS adapter must coerce **writes** to these packed arrays to uint32 because Godot's int64 array does not perform Uint32Array's implicit coercion.

Never use Godot Vector2/Vector3 for simulation scalars: default-engine vectors store float32; JavaScript numbers and Godot scalar float are binary64. Never allow integer `/` where JS requires floating division. `Math.round` differs from Godot `round` at negative half values; `js_round` also avoids the naive `floor(x+0.5)` rounding edge cases. Signed `Math.imul` returns are deliberate; unsigned shifting must mask to 32 bits first.

## Validation

From `spritefusion_exact/`, run `tools/test_core.sh` (Godot 4.6.3). To regenerate expected vectors from authoritative originals, run `tools/test_core.sh /path/to/originals` with Node 24.

`generate_core_vectors.mjs` strips types from and executes the **original TS helpers**. It does not reproduce their algorithms. Golden data covers all 25 source files, three camera origins (including fractional/negative), 834 raster snapshots, 12,288 random output words over 12 seeds, byte ordering, conversion, channel clipping, blending, ring dithering, noise, and uint32 overflow. Every snapshot compares every pixel, not a visual similarity score.

Godot's JSON decimal parser differs by one binary64 ULP from standard JS parsing for some literals. Binary-exact scalar expectations and inputs therefore use little-endian IEEE754 hex. This is a fixture precision issue, not a permitted tolerance in pixel comparisons. Full effect state/order, hooks, lifecycles, and trig-heavy trajectories still require the separate complete-effect oracle; core success does not certify the 25 full ports.

## Native Px adapter for generated ports

Replace the generated source-local `C_Px` class with `const C_Px = preload("res://scripts/core/sf_px_source.gd")`. Fire must use `sf_px_fire_source.gd` instead. These adapters expose the transpiler's `_sf_f_w/h/ox/oy/data` getter fields and `_sf_m_at/set/blend/add/disc/alphaDisc/ring/line/glow` methods, with exactly the original signatures. Their constructor accepts `(source_frame_dictionary, PackedInt64Array)` and writes into the actual source frame. The 834 source snapshots are also tested independently through this adapter, including fire and fractional origins.

This removes compatibility dispatch from the inner raster loops; it does not change the source effect's update, geometry, spawn order, or draw order. Unsupported methods happen to exist on the shared adapter but ports must only call methods present in their corresponding original source.

## V8 trigonometric compatibility

`sf_v8_math.gd` exposes `sinv(x)` and `cosv(x)`, ported from V8 13.6.233's fdlibm kernels and full double-precision argument reduction, including the large-exponent path. It does not fall back to platform-native trigonometry. Coefficients are decoded from the source's authoritative IEEE754 hex words because Godot's long-decimal literal conversion can alter their values. The original Sun notice and V8 license are preserved.

This module addresses a demonstrated black-hole rendering difference: at baseline frame 55, one native `sin(tilt)` result differed by 1 ULP, propagating to an interpolated alpha of 254 instead of 255. Effects must be rechecked against their whole-frame oracle when adopting it. Other native math functions are not changed by this module.

`tools/generate_v8_trig_vectors.mjs` regenerates 32,941 deterministic scalar cases with Node 24/V8, including random complete binary64 exponent patterns, normal effect angles, neighbors around argument-reduction boundaries, signed zero, infinities, and extreme finite values. `tests/core/test_v8_math.gd` compares every finite result bit, including signed zero; NaN payloads are treated as equivalent, matching JS numeric semantics. This is 65,882 checks with zero differences, not an exhaustive enumeration of all binary64 values or a claim that other math functions are identical.
