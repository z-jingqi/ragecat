# Reference-led Xing Tian slash verification

Revision baseline: Ragecat `9bc2d56f6556ba8c8fccdec352e6bdf6efb41338`, after the separately
published removal of the two rejected independent studies. This revision changes only
`preview/xingtian-slash-godot/`. SpriteFusion exact ports and gameplay are unchanged.

## Reference and visible redesign

Read the already accepted Slash recipe, TypeScript and native translation, acceptance
report and real native keyframes. The redesign borrows the tilted ellipse, bright edge,
inner echo, seven discrete color bands and short dithered thread. Default sweep/hold/trail
is 0.06/0.06/0.24 seconds. Our copper colors, thicker cut, restrained glint/light and
independent hit blood remain a separate study, not an exact port or game integration.

## Evidence

- Focused failing-before defaults checks: 52 checks, 2 failures on the previous version.
- Current lifecycle/configuration/UI tests: 57 checks, 0 failures. Additional coverage
  verifies reference rhythm/geometry, new option sanitization, bounded thread lifetime and true horizontal facing (contact point and particle velocities).
- Real Compatibility transparent-viewport probe: 19 checks, 0 failures. Includes
  repeatable onset/peak/tail/end, direction/range, seven-band palette changes, optional
  echo/thread/glint, hard opaque blade pixels with light off, deliberate soft light with it
  on, zero intensity and independent sparse blood. No headless claim of visual parity.
- Native final pass: exit 0, 720 frames / 12 seconds / 1280×800 at fixed 60fps. Inspected
  default, late tail/blood, quarter-speed and Heavy half-speed states. No script/shader
  errors. Video speed labels show the actual playback rate.

- PixelFX revised primitive draft: 33 frames rendered and contact sheet inspected;
  official check passed (1 effect, 0 warnings). No ready-made effect or actor copied.
- Independent source/native-frame reviewer found no runtime blocker in the first pass.
  Its palette-test isolation finding is fixed by holding light strength equal. A separate
  horizontal mirror correction avoids the old 180-degree rotation behavior; the native
  image must exactly equal a horizontally flipped baseline. That assertion passes.
- Actual native UI: Mirror, pause, 0.100s timeline position, Clear followed by max range
  and timeline edits, then Replay at radius 88. The left cut stays above the figure,
  all visible layers fit their panels, and cleared effects do not resurrect. Window
  close exited normally.

## Boundaries

This is an independent visual study. No health, collision, damage, gameplay, hit-stop,
character attack animation, camera change or game integration. Blood/sparks occur only
on explicit host `play_hit`. Neutral figures are static geometry, not character art.

MovieWriter fixed 60fps is a presentation clock, not real-time performance evidence.
Native renderer is Mesa llvmpipe Compatibility. Physical GPU, exported devices and
actual game integration were not tested. User visual approval is separate. Logs,
capture frames, movies and temporary reviewer probes stay outside the repository.

# Compact contact revision

Baseline: `043c68f03d2075e0a1bf57359c831551b2315d39`. Scope stays entirely in
`preview/xingtian-slash-godot/`. The accepted `copper_arc.gd` and
`copper_arc.gdshader` have no changes. Exact ports and gameplay are unchanged.

## New visual contract

- Explicit `play_hit` adds a six-ray copper core (40ms, two beats), four detached
  fragments and two incomplete pressure crescents. The burst is empty at 160ms.
- Six seeded sparks cool from a short hot head. At most three thin blood roots
  detach within 75ms into the existing nine default drops. Blood has an independent
  toggle; count zero is completely empty. No mist, wound or long-lived blood stain.
- Core timing is in seconds. The default first bright beat survives a normal 60fps
  advance; a 30fps advance cannot skip the entire core. Short custom durations can
  intentionally reduce the number of visible frames.
- New `hit_preview.tscn` is the default. `preview.tscn` retains the old slash workbench.
  Native 1× fixture composition remains visible beside isolated 1–2× hit layers.

## Verification executed

- Focused pre-implementation regression: 2 checks, 2 expected failures (missing
  independent impact and impact configuration).
- `godot --headless --path preview/xingtian-slash-godot --script tests/test_hit.gd`:
  38 checks, 0 failures.
- `godot --headless --path preview/xingtian-slash-godot --script tests/test_slash.gd`:
  57 checks, 0 failures.
- Real Compatibility `tests/render_probe.gd`: 32 checks, 0 failures. New coverage
  includes first/second contact beats, thinning fragments, exact ending, replay,
  impact and early-blood horizontal image flips, maximum range/grid, and disabled
  contact/blood. The initial second-beat area failure was fixed by narrowing the
  second beat's dark rim; the assertion remains.
- PixelFX original primitive draft: all 30 frames rendered and inspected. The
  official checker passes 1 effect, 0 failures, 0 warnings. Corrected its blood
  colors to packed colors so the short-palette check also passes.
- Native interactive workbench: maximum impact radius 24, Mirror, paused timeline
  at 0.075s, Blood off, Hit/Miss, Clear followed by minimum-radius and timeline edits,
  then Replay. The large isolated hit switches to 1× and stays in its panel. Clear
  does not resurrect. Only this workbench's terminal process was stopped afterward.
- Final MovieWriter: 720 frames / 12 seconds / 1280×800 / fixed 60fps, exit 0.
  Four segments: normal, 0.25× slow motion, blood disabled, miss. Captured default
  contact core, fragments, residual blood, the no-blood case and the miss case.
- Independent read-only code review found no blocking lifecycle or scope issue.
  Its blood-cell mirror finding was fixed and covered by native flipped-image
  hashes. Its documentation finding was addressed in README and provenance.

Native renderer: Mesa llvmpipe / Godot 4.6.3 Compatibility. Fixed MovieWriter time
is a presentation clock, not a real-time performance result. Physical GPU, exported
devices and game integration are not verified. User visual approval is separate.
Logs, screenshots, movies, comparison data and PixelFX render products remain
outside the repository. Only reusable source, tests, presets and documentation
are committed.

# Multi-target presentation revision

Baseline: `6103cf00f55e04b5b05eeb00f41a9f04cdf5db61`, verified against remote main.
Only the standalone preview, reusable tests, documentation and an unchanged copy
of the already-approved portrait are added. `components/` and presets have no diff.

## Scope and observed result

Three simultaneous contacts, six contacts staggered by 35ms, and seven waves of
six contacts at a minimum 280ms separation. Each contact owns a separate existing
Slash instance; old tails survive subsequent waves. The left stage is 1x with the
existing 76px portrait crop and 32px geometric test enemies. The right stage shows
the same moment at 2x nearest-neighbor. Eight context enemies remain untouched.

The dense contact zone is intentionally crowded. Adjacent copper fragments and
blood drops overlap locally, while the brief cores and surrounding silhouettes
remain readable. No default effect strength, count or timing was reduced to hide
this overlap. The portrait is static, with no attack or hit animation; all contacts
are scheduled visual staging, not game collision, damage or combat integration.

## Verification executed

- Headless `tests/test_crowd.gd`: 29 checks, 0 failures. Covers independent instances,
  simultaneous/staggered/repeated contact scheduling, old-tail preservation, seek,
  clear/replay, blood preference, mirror, view synchronization and child cleanup.
- Two review findings were fixed: Clear followed by Resume at the loop boundary
  could restart; blood-off counted invisible old tails. A temporary isolated copy
  with those old behaviors restored fails three assertions; the final code passes
  all 29. The failing copy and logs are not committed.
- Existing `tests/test_hit.gd`: 38/38; `tests/test_slash.gd`: 57/57. Editor import exits0.
- Native Compatibility `tests/render_crowd.gd`: 21 checks, 0 failures. Includes
  1280x800 framebuffer, actual effect pixels in each 1x scenario, 2x changed-pixel
  mask agreement above 95%, exact repeat seeks, clear and clear/resume, blood toggle,
  mirror, final cleanup and the portrait's fixed-foot-anchor mirrored silhouette.
- Native visual inspection caught a negative-rectangle portrait mirror offset.
  Drawing in a reflected local transform fixed it; the new foot-anchor image check
  now covers that regression. Both directions were inspected at 1x and 2x.
- Native controls clicked: dense scenario, Clear, Resume, Mirror, timeline, Replay,
  Blood, Single hit and Multi-target preview return. Clear stayed clear, and both
  scenes remained usable. Only this task's window/process was closed.
- Final MovieWriter: 960 frames, 16 seconds, 1280x800, fixed60fps. Four segments:
  simultaneous, staggered, dense repeat, dense0.25x. Frames were inspected at 1x
  and 2x; active zones remain within their panels. Peripheral context enemies are
  intentionally cropped by the magnified viewport.
- Independent read-only review and follow-up found no remaining blocking issue.
  Its suggested portrait-anchor coverage was added after the screenshot review.

Renderer: Godot4.6.3 Standard, Mesa llvmpipe Compatibility. Concurrent short runs
are correctness/recording checks only, not real-time performance measurements.
Actual game, exported devices, real GPU performance and user visual approval remain
unverified. Movies, captures, runtime logs and comparison data stay outside Git.

# Heavy cleave and configurable pressure revision

Baseline: `93b7929d9fc8446d5c406e5fb799984bd9564dc3`. Original components and
presets have no modifications. New files add a HeavyProfile subclass, independent
procedural ground-pressure component, persistent preset, static fixture and preview.
The hit workbench gains only a navigation button. No game code changes.

## Result and controls

- The heavy blade reuses the approved shader with an independent art profile:
  radius70, thickness20, duration0.44s; the ordinary baseline remains52/12/0.36s.
- Default ground wave: radius72px, duration0.32s, strength0.85, RGB #e9a463,
  radial half-width 3px, squash0.34, eight grit fragments. Six contacts share one wave,
  split into far/near draw halves around the static actors.
- `presets/heavy_pressure.tres` is the actual default resource loaded by the preview.
  Range, duration, strength, RGB color, thickness, squash, grit, blade thickness
  and blood amount have live controls. Wave and blood have independent toggles.
- Actual-scale and magnified views show the same seeded moment. Heavy is visibly
  thicker than Normal; the short broken wave stays on the ground and clears.
  The six-target scenario remains a visual staging test, not combat integration.

## Executed verification

- Initial executable contract check: three expected missing-resource failures
  before implementation; no missing engine or parse error used as that red result.
- `tests/test_heavy.gd`: 53 checks, 0 failures. Configuration copying/sanitization,
  defaults, each meaningful parameter, independent lifetime, seeded replay,
  timestep equivalence, invalid inputs, clear/replay, layer toggles, six independent
  contacts sharing two depth halves, profile inheritance and UI state paths.
- Existing tests pass unchanged: slash57, hit38, crowd29. Editor import exits0.
- Native `tests/render_heavy.gd`: 26 checks, 0 failures. Actual pixel changes for
  radius, duration, strength, RGB color, width, squash and grit; strength0 empty;
  exact end/clear; exact full-cell horizontal mirror; native1x/2x correspondence;
  maximum radius112 + radial half-width6 + squash0.7 + grit16 + pixel grid3, both facings, with
  no changed effect pixels on the magnified panel edges near full expansion.
- Native UI: selected six targets, paused by timeline, set radius/duration/strength/
  width/squash to maximum, opened the actual color picker and entered #50bdde.
  The wave changed while the copper blade did not. Disabled Wave and Blood,
  mirrored, cleared, edited radius, reenabled Wave, dragged to loop end and hit
  Resume: no resurrection. Reset/Replay and Hit preview/Heavy navigation worked.
- Final MovieWriter: 1200 frames,20s,1280x800,fixed60fps, exit0. Five four-second
  segments: ordinary baseline, heavy single, heavy six-target, quarter-speed,
  and a104px/0.48s/1.1/blue-green configuration example. Final frames inspected.
- Independent read-only reference/code/visual review found no blocking issue.
  Its extreme-boundary coverage request was added; Normal now explicitly says
  the controls below adjust Heavy. Sampling rejects off-band pixels before angle
  and trigonometric calculations, without changing the waveform.

Renderer: Godot4.6.3 Standard, Mesa llvmpipe Compatibility. Native runs were short
correctness/recording sessions alongside the separately owned background recording.
No real-time performance claim is made: max settings and many real game instances
need target-device profiling. No actual combat, actor attack animation, export or
physical GPU testing. User visual acceptance is separate. All capture frames,
movies, logs and numerical comparison data remain outside the repository.
