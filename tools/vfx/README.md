# Baked presentation assets

These transparent flipbooks are rendered in Blender and sampled in Godot 4 Compatibility.
Authoring scripts are the editable source; no downloaded art, simulation cache, or generated
preview belongs in the repository. Each family README documents regeneration.

After regenerating a family, update its manifest and run:

    python tools/vfx/build_library.py

The registry at `resources/feedback/atlas/library.tres` contains the explicit texture/frame
layout, playback rate, opacity, scale and presentation budgets. The generated defaults are
intentional starting values: change the generator defaults too when tuning the registry.
Atlas dimensions include transparent padding. Only presentation is scaled; collision, warning
radii, projectile travel, status durations and damage are owned by the existing combat nodes.
Do not drive gameplay from animation frames. Existing hazard shaders still clip baked layers.

The renderer samples caller-owned clocks, so pausing, fixed simulation, and scene cleanup stay
with the gameplay node. One-shot events can normalize to the existing event duration. Looping
status layers use simulation age. Turning the library off restores procedural fallback.
Player and boss draw budgets are separate; exhausted decoration budgets never hide warning
geometry or suppress damage. A fire ring is one bounded triangle mesh with continuous arc-length
texture repeats and constant radial width; the owning canvas retains its mesh until replacement
or disposal. Never retain actors in a global presentation cache.

All atlas PNGs use straight alpha. Do not apply an additive material to their parent without an
explicit normal-blend child. The dynamic lightning path remains procedural; only endpoint sparks
are baked. Ice shell, shatter and thaw share registration and display scale. The moving dark
vortex remains attached to the arrow and does not spawn a stationary gameplay field.

## Verification

`tests/run_all.sh` includes atlas metadata, timing, UV, separate-budget, RNG-isolation and memory
contracts. `tests/blender_vfx_motion_fixture.gd` records production-node motion on a rendering
display, not headless. `tests/atlas_render_benchmark.gd` compares enabled/disabled layers on the
same rendered workload. Capture outputs must be outside the repository. Headless tests cannot
certify visual quality, display clipping, driver compatibility or performance on target hardware.

## Natural combat materials

Landing warnings for rocks and Skyfire retain simple boundary/countdown cues.
Their falling bodies, impacts and burning ground use the baked materials.
Charge warnings share the thin outline and low-opacity fill, with fixed direction chevrons.
Warning appearance is configured in the atlas library Resource, independently of combat. Summoning
uses condensed inward wisps. Orbs keep a compact body and short wake; lightning
retains its exact dynamic endpoints with restrained filaments. Fire ground and
rings have separate budget-independent material surfaces so saturated decorative
atlases cannot hide a dangerous footprint. The moving dark field distinguishes
its original attraction/core radii with matter density and inward motion.

All clocks come from simulation owners. Surfaces use the normal world layer with
`show_behind_parent`, never a negative Z that would put them behind the arena floor.
The atlas library Resource contains material opacity, motion and size controls.
Frost, shatter and thaw retain common registration. Blender regeneration scripts
and asset alpha/continuity checks live in each family directory.

For real-render stress and lifecycle checks, run `tests/vfx_production_stress.gd`
without `--headless`. It exercises dense real-arena elemental builds, scene pause,
lethal practice reset and node release, reporting measured frame times without
claiming those measurements represent target hardware. `atlas_render_benchmark.gd`
additionally covers three simultaneous complete fire bands and exhausted cosmetic
budgets. Capture outputs must remain outside the repository.
