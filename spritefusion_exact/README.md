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

- [Impact](reports/impact.md): native GDScript, portable original-source fixtures,
  one-Frame presentation, and real Compatibility renderer checks.

Open `godot/project.godot` in Godot 4.6.3 and press F6 on the individual scene,
  or F5 for the current completed-effect entry. Let the editor import scripts on
  first open so its `class_name` index is built. No Node.js process is needed to
  run the Godot project. Other families are being integrated independently.

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
