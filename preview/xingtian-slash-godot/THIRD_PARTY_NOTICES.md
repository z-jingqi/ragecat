# Source and method provenance

This is a new Xing Tian visual study, not an exact Sprite Fusion port or a stock PixelFX effect.
No third-party sprites, sheets, textures, characters, weapons or fonts are shipped.
No camera shake, hit-stop, damage hook or character attack animation is enabled. A small optional warm head light and blade glint are part of this revision.

## Sprite Fusion

Retrieved through the **SpriteFusion MCP `get_vfx`** tool on 2026-11-04:

- [Slash recipe and complete TypeScript source](https://www.spritefusion.com/pixel-art-vfx/slash).
  This revision explicitly studies the already accepted Ragecat Slash port at baseline
  `662d321b60e95d48886684edd9dbac5087528829`: `spritefusion_exact/source/slash.ts`,
  `recipes/slash.md`, `godot/scripts/effects/slash.gd`, its acceptance report and
  retained `previews/slash/native-keyframes.png`. Those exact-port files are unchanged.
  `copper_arc.gdshader` is an independent adaptation of the tilted ellipse, exponential
  head, 2.2-power asymmetric taper, seven-step age-dependent palette, one-frame inner
  echo, Bayer tail and chasing residual thread. Default sweep/hold/trail match the
  source's 0.06/0.06/0.24 seconds. Geometry, warm palette, restrained head light,
  compact glint, minor chipped contour and shorter residual thread are our design.
  It is not a parity claim and has no dependency on the exact-port runtime.
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
`tools/pixelfx-draft.js` is updated to the reference-led geometry, echo and thread for repeatable primitive draft rendering. The shader is canonical; this draft is a visual design check rather than cross-engine bit parity.
It uses PixelFX's `fit`, `smooth`, `Rng`, `p.dot`, `p.line` and `p.glow` primitives.
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

## Compact contact revision

At Ragecat baseline `043c68f03d2075e0a1bf57359c831551b2315d39`, this revision also read
`spritefusion_exact/recipes/impact.md`, `source/impact.ts`, its native GDScript,
and `previews/impact/native-keyframes.png`, along with the corresponding Blood
recipe and native keyframes. [Sprite Fusion Impact](https://www.spritefusion.com/pixel-art-vfx/impact)
is MIT, copyright 2026 Hugo Duprez. The exact-port directory is unchanged.

`hit_impact.gd` is a new analytic pixel sampler, borrowing the two-beat core → detached
shards → broken ring sequence. The compact six-ray geometry, 40ms core, 160ms total,
four fragments, two partial pressure crescents and existing copper ramp are original
adaptations for this study. The accepted slash shader is unchanged. Tiny blood roots
detach within 75ms; blood still has no mist, wounds, long-lived stain or game hooks.

The pinned PixelFX checkout above was reused. `impacts/hit-spark.js` was read for its
lopsided silhouette, short hot core and cooling spark heads; `melee/heavy-cleave.js`
was read for layered short impact separation. Neither stock attack or actor is copied.
The new `tools/pixelfx-hit-draft.js` uses PixelFX `fit`, `Rng`, `p.dot` and `p.line`.
It was rendered and inspected, revised, and checked with the official tools.
No reference movie, comparison data, rendered sheet or PixelFX font is shipped.

## Multi-target fixture

The crowd presentation reuses the user-approved, unmodified Xing Tian PNG already
in this repository. See [assets/README.md](assets/README.md) for exact provenance
and digest. This is user artwork, not third-party stock or MIT-relicensed imagery.
The two earlier workbenches remain intact. The new enemy fixtures are elementary
geometric placeholders, explicitly labeled; no third-party enemy sprite is added.
