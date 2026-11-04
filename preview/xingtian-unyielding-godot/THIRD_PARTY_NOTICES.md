# Reference use and retained notices

This is an original, deliberately restrained Godot design, not an exact port.
No ready-made images, sprite sheets, gallery assets, fonts, actor animation, or
upstream runtime package is included.

Actual reference use on 2026-11-04:

- Sprite Fusion MCP `list_vfx` and `get_vfx(power-up, blood, energy)` were called.
  The Power Up recipe's ground/body separation and short/held/decay layering
  informed the design. Native reference pixels were inspected. It is not a copy
  of the cyan Power Up effect, and it does not use its character flashes or actions.
  Sources: https://www.spritefusion.com/pixel-art-vfx/power-up
  and https://www.spritefusion.com/pixel-art-vfx/blood .
- Patch-gg/pixelfx commit `a84159688af3ca37a4be05a0d422b94451b2e24e`:
  `src/fx/status/rage.js`, `docs/AUTHORING.md`, and `skills/pixelfx/SKILL.md`
  were read. Its actual `tools/render.mjs status/rage --zoom 3` was run and its
  contact sheet inspected. Seeded jagged ground cracks and staged render/look/refine
  methodology informed the new implementation. The Rage character judder, angry
  face, steam, and attack choreography were intentionally not imported.
  Source: https://github.com/patch-gg/pixelfx/tree/a84159688af3ca37a4be05a0d422b94451b2e24e .

Godot geometry, lifecycle, raster helpers, UI, and tests are newly authored here.
The upstream notices are retained conservatively for the recipe-derived techniques:

MIT License

Copyright (c) 2026 Patch
Copyright (c) 2026 Hugo Duprez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
