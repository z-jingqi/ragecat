# VFX-14 validation

## Blood / restrained flash revision
- Reference: ParticleFX Hit Flash page and eight-time strip reviewed. Use its local blood-drop idea, not additive white sparks.
- Headless controller tests: **3925 assertions** passed, including 12 hosts × 240 continuous-hit frames, four-burst capacity, peak never exceeding 0.20, reset, host deletion, rebind, original/external material preservation and 30/60/144Hz completion.
- Actual OpenGL render probe: **4803 assertions** passed. All texture/modulation alpha preserved, untouched neighbor unchanged, 308 visible body pixels respond, finish and cancel restore exact baseline RGBA.
- Native review: normal-speed effect, six-host crowd mode and pause inspected. Outward spray direction selected to keep red flecks off the host face.
- New preview: **1009 frames, 16.8167 seconds, 640×360 at 60fps**. Actual 1× and exact nearest 2× on every frame, zero comparison mismatches.
- Preview includes separate targets, body-only, moving host, partial alpha, light background, then six targets hit simultaneously at 20 hits/s each.
- Preview Library identity retained, version **1**: `libfile_8c9e6ef3233881918cad1d9d0a3e5c3d`.
- No game damage/recoil system, Unity runtime, copied third-party frames or shared VFX-04/05 modifications.
