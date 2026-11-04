# Source and method provenance

This is a new Xing Tian visual study, not an exact Sprite Fusion port or a stock PixelFX effect.
No third-party sprites, sheets, textures, characters, weapons or fonts are shipped.
No glow, camera shake, hit-stop, damage hook or character attack animation is enabled.

## Sprite Fusion

Retrieved through the **SpriteFusion MCP `get_vfx`** tool on 2026-11-04:

- [Slash recipe and complete TypeScript source](https://www.spritefusion.com/pixel-art-vfx/slash).
  `copper_arc.gdshader` adapts the analytic crescent, fast exponential head,
  asymmetric taper and smooth chasing tail. Xing Tian changes the palette, angle,
  thickness, chipped contour and timing. White glints, large glow, shavings and
  residual threads were deliberately omitted for a copper-red, compact melee cut.
- [Blood recipe and complete TypeScript source](https://www.spritefusion.com/pixel-art-vfx/blood).
  The independent `hit_particles.gd` uses the recipe's directional short streaks,
  sparse two-pixel beads, falling movement, dark-to-red palette and seeded variation.
  It is newly implemented analytically in GDScript, not a full port of the simulated
  original. No wound, mist, long-lived stain, actor mutation or knockback is copied.

Original MIT copyright: **2026 Hugo Duprez**. The full MIT terms are retained in LICENSE.

## Patch-gg / PixelFX

Inspected and ran the official repository at revision
[`a84159688af3ca37a4be05a0d422b94451b2e24e`](https://github.com/patch-gg/pixelfx/tree/a84159688af3ca37a4be05a0d422b94451b2e24e).
Relevant source:

- `skills/pixelfx/SKILL.md` and `docs/AUTHORING.md`: code-first drafts,
  seeded local coordinates, hard palette bands, clean one-shot ending, and
  render / inspect / refine / render / check workflow.
- `src/fx/melee/heavy-cleave.js`: inspected its thick ember crescent, cooling bands,
  accelerated motion and particle separation as a quality reference. The ready-made
  cleave, ground cracks, dust, actor and whole attack were **not** copied.
- `src/fx/melee/sword-slash.js`: inspected its clear silhouette and trailing motion.

Tools actually used: `tools/render.mjs` on fire/torch (tool smoke check),
melee/heavy-cleave and melee/sword-slash (reference images); `tools/new.mjs`
to scaffold a new `melee/xingtian-copper`; `tools/render.mjs` and `tools/check.mjs`
on that original draft, followed by the real Godot render, tests and iterative review.
`tools/pixelfx-draft.js` retains the original draft for repeatable reference rendering.
It uses PixelFX's `fit`, `smooth`, `Rng`, `p.dot` and `p.line` primitives.
The runtime deliverable is the native Godot code, not a baked sheet or JS dependency.

To reproduce the optional draft outside this repository, use that pinned official
PixelFX checkout, copy the draft to `src/fx/melee/xingtian-copper.js`, then run:

```sh
node tools/render.mjs melee/xingtian-copper --all
node tools/check.mjs melee/xingtian-copper
```

PixelFX is MIT, copyright **2026 Patch** and **2026 Hugo Duprez**; full terms in LICENSE.
Its Patch Pixel gallery font is excluded by upstream NOTICE.md and is not included here.
No plugin, global skill, hook or background service was installed.

Source snapshots read from the MCP response were retained outside the delivery tree.
SHA-256 of the extracted UTF-8 TypeScript (with final newline):

- Slash: `2d6a996732290c3de502dac9127a39521476e865e3a7d226304a74b11d573d78`
- Blood: `850ddce9c8eed4591d4e3252b1a009376f3cc86545355274d1543894c1b59909`
