# Hero-state / geometry-dash QA

Godot 4.6.3, 2026-11-03. Local-only verification; this is not user visual acceptance or a publication claim.

## Passed

- Geometry dash: 1,038 assertions, including 30/60/144 Hz (six snapshots at each), actual historical segments, alpha input, immutable geometry, bounds, teleport, stationary suppression, long stalls, pause and 1,000 reset/reuse cycles.
- Hero state: 1,020 assertions, including active-state persistence, exact world/local follow, urgency, pause, event-ID deduplication, finite 0.58-second return, 30/60/144 Hz, immediate clear and 1,000 reuse cycles.
- Preview controls: Pause/resume, Clear, Replay and 50 repeated flows passed without node growth. Additional 30/60/144 Hz boundary checks prove the final actual dash endpoint is captured before stopping, with no post-dash captures. Ghost commands contain only the body circle and detached facing line.
- Original regression tests: dodge 572; elite aura 2,016; shield/heal 4,039. Combined headless assertions: 8,685. Import and preview startup passed; no script errors.
- Native Mesa llvmpipe OpenGL compatibility renderer: dash probe passed exact source-alpha multiplication, silhouette, pixel-identical world history under translated/scaled effect parent, pixel-identical pause, full tail expiry, 28 visible accent pixels and full reset cleanup.
- Native hero-state probe passed visible war and return pixels, clear host center, pixel-identical pause, immediate war cancel, complete finite revival cleanup and clear of both effects.

## Visual evidence

Inspected native canonical dodge, aura and heal previews and their public reference strips before finalizing the adapter. Final preview is rendered at the actual 640×360 logical resolution, then nearest-upscaled for delivery, rather than scaling the scene transform (which would change world-pixel effect constants). The wrapper presets were widened after native review found the broader circle body obscured the original narrow-sprite effects. Retested final presets show normal-speed dash, warm war energy following the actual moving geometry fixture and a finite green return cue. The live fixture retains the current Mountains body/face/facing geometry. Dash history contains only the actual body silhouette and detached facing marker, not the eyes, invulnerability arc or quantitative state rings.

Native renderer probes ran on these runtime SHA-256 values:

- `geometry_afterimage.gd`: `0464de3fb5461f8033246a47a230728e4fbde23fff5c5ef77666dd8e6cb8f9d4`
- `hero_state.gd`: `7e132215709e4c5882145777ebd4001421645645a09ddd9f19d4ca881d20adcf`
- `aura.gd`: `fbdeb78a736808340373bab4133cff562bbb61e4d538dfe842415b03062b043b`

## Scope limits

No Mountains gameplay files changed in this library work. The game integration must separately verify accepted dash timing, successful revival event ordering, arena clipping, warnings above effects, termination/death/restart cleanup, controls, actual gameplay visibility and unchanged combat values. No mobile/export or performance claim is made from desktop renderer tests.
