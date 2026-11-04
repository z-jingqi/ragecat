# Sprite Fusion exact-reference Godot implementation

This independent workspace preserves all **25 official effects and 41 situations**
from [Sprite Fusion Pixel Art VFX](https://www.spritefusion.com/pixel-art-vfx).
It does not replace the existing Ragecat effects or their game-specific presets.
The required deliverable is a complete runnable Godot version, not a Canvas-only
viewer or pre-rendered animation substituted for effect code.

## Source preservation milestone

- `source/`: all 25 original TypeScript exports, unchanged. Each SHA256 matches the
  same `.ts` file in its official downloadable ZIP, including the final newline.
- `recipes/`: official effect recipes and integration information retained as
  reference, not as completed Godot implementation claims.
- `catalog.json`: all 25 effects, their 41 situations and original preview URLs.
- `source-manifest.json`: source hashes and ZIP verification facts.
- `LICENSE`: original MIT terms and Hugo Duprez's 2026 copyright. Original source
  headers remain intact. The official page identifies the exported code as MIT.

The source archive is a completed foundation step. **Godot ports are in progress**;
archiving source does not establish runnable parity or complete visual acceptance.

## Runnable accepted effects

- [Black Hole](godot/docs/black-hole.md): Singularity with the original native effect
  and procedural Canvas lens reconstruction. Six fixed complete lens samples and
  two disabled-background controls matched exactly in the actual Godot viewport.
  This CPU reference renderer is slow; performance and game integration remain separate.

- [Power Up](reports/power-up.md): Speed, with original-source behavior
  checks and independently inspected native presentation.

- [Holy Light](reports/holy-light.md): Pillar and Smite, with original-source behavior
  checks and independently inspected native presentation.

- [Shield](reports/shield.md): Dome, with original-source behavior
  checks and independently inspected native presentation.

- [Energy](reports/energy.md): Orb, Charge, Beam and Bolts, with original-source behavior
  checks and independently inspected native presentation.

- [Poison](reports/poison.md): Cloud, Puddle and Poisoned, with original-source behavior
  checks and independently inspected native presentation.

- [Ice](reports/ice.md): Nova, Spikes, Crystals, Shatter and Freeze, with
  complete baseline/stress comparisons and five-mode native viewport evidence.

- [Heal and Mana](reports/heal.md): both original restorative effects, exact
  baseline/stress fixtures, independent two-panel native rendering and a
  self-contained Heal-only installation check.

- [Bubbles](reports/bubbles.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Falling Leaves](reports/falling-leaves.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Fireflies](reports/fireflies.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Embers](reports/embers.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Fog](reports/fog.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Snow](reports/snow.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Rain](reports/rain.md): original configurable behavior, full baseline/stress
  comparisons and independently checked native viewport presentation.

- [Lightning](reports/lightning.md): Strike, Impact, Chain and Electrified,
  original timing/paths and four-mode native viewport verification.

- [Fire](reports/fire.md): source-faithful burning and decay, with exact native
  combined-frame rendering and preserved host visibility.

- [Sparkle](reports/sparkle.md): Glint and Twinkle, native combined-frame
  checks and unobstructed controls outside the effect canvas.

- [Movement](reports/movement.md): Dash and Blink, including original host cues,
  visible history, disappearance and reappearance.

- [Blood](reports/blood.md): source-faithful spray, stains and complete decay,
  retaining the original fixture clipping at the canvas edge.

- [Muzzle Flash](reports/muzzle-flash.md): exact repeated-shot flash, native
  burst timing and clear tail, with controls outside the effect area.

- [Slash](reports/slash.md): original two-hit slash and native host overlap.

- [Explosion](reports/explosion.md): source-preserving blast, smoke and ground
  trace, with baseline/stress and actual native composition checks.

- [Impact](reports/impact.md): native GDScript, portable original-source fixtures,
  one-Frame presentation, and real Compatibility renderer checks.
- [Pickup](reports/pickup.md): gem, coin and orb collection, exact source lifecycle,
  verified combined frames, and a fresh native recording.

Open `godot/project.godot` in Godot 4.6.3 and press F5 for the scene gallery.
Enter opens the focused effect, and Esc returns to the gallery. F6 on an
individual scene still works. Let the editor import scripts on first open so
its `class_name` index is built. No Node.js process is needed to run the project.
The gallery lists only installed scenes and shows the installed family count;
other families are being integrated independently.

New family releases are code-first. At the user's request, their original-source
comparison datasets and detailed capture evidence remain local rather than
being uploaded. The already published datasets remain untouched. Missing
comparison fixtures are not runtime dependencies; consult each family report
for which public checks are available.

For a fresh command-line checkout, import once before opening the gallery:

```sh
godot --headless --editor --import --path spritefusion_exact/godot --quit
godot --path spritefusion_exact/godot --rendering-method gl_compatibility
```

This import builds Godot's script index; it is not a substitute for rendered QA.
On the tested cloud software-rendering environment, native editor import hit a
missing Vulkan extension, while the headless import and actual Compatibility
gallery succeeded. That environment-specific failure is retained separately;
physical-device editor behavior has not been tested.

## Performance and presentation limits

[The guarded RGBA conversion and measured limits](reports/rgba-conversion.md)
separate exact output checks from performance. Dense atmospheric rasterization
remains CPU-heavy in this reference implementation. Fixed-frame preview videos
are not evidence of live 60 FPS, and the host does not skip source simulation
ticks to hide that cost.

[The no-recorder native baseline](reports/native-live-performance.md) measures
Glint, Fog and Embers with all original source ticks and full warmup retained.
It identifies raster execution, rather than presentation, as the main bottleneck.

[The guarded glow raster fast path](reports/glow-raster.md) preserves the tested
source output while reducing Glint and Embers live cost. Heavy effects remain
below real-time speed on the measured software renderer.

[The guarded alpha-blend packing path](reports/blend-packing.md) preserves all
17 installed families' tested source output and reduces Fog's measured elapsed
time by about 14% in a predeclared native comparison. Fog still remains slow.

## Godot implementation contract

The new standalone project lives under `godot/`. Common code belongs to
`godot/scripts/core/`, individual ports to `godot/scripts/effects/`, effect scenes
and tests to their corresponding folders. Ports must preserve the exported
algorithm, option defaults, callbacks, random-number sequence, fixed 60-Hz update
cadence, separate back/front draws, packed color/light buffers, pixel rounding and
compositing. They must not substitute Godot's default RNG or approximate geometric
primitives for the original rasterizer.

Every completed effect needs its own usable scene/parameters, numerical and pixel
comparison against the unmodified TypeScript at identical seeds/time/options,
lifecycle tests, real Godot rendering and a fresh video. Record exact passes and
remaining differences. A passing source checksum alone is not visual parity.

## Reference-art boundary

The official site plays recorded WebP previews; downloaded ZIPs contain only one
self-contained TypeScript export each, not the original demo host, actor or scene
code. The reference animations were inspected locally. They are not redistributed
here because their artwork is not explicitly covered by the code's MIT statement.
The catalog retains their official URLs.

Compare the effect's output buffers and callback behavior independently from the
unavailable demo host. A custom background/actor is not proof of full-scene pixel
identity, and any such mismatch must remain explicit rather than hidden. No
paid image-generation service is used for this implementation.
