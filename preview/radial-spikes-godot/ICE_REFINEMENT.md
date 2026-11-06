# Ice Spikes: rigid fracture refinement

## Scope and provenance

Based on Ragecat `1e3f04b` (2026-11-06). This is an original game-adapted
Godot renderer, **not an exact Sprite Fusion port or a visually approved result**.
Reference inspected: `spritefusion_exact/source/ice.ts`, especially `spikes`,
its subsidiary crystals, short break flash and ballistic shard emission.
The existing Sprite Fusion MIT notice in `licenses/SpriteFusion-MIT.txt` remains
unchanged. No rendered Sprite Fusion assets, atlases or screenshots are used.
The exact-port tree and earth renderer are untouched.

## Observable changes

- Keep the existing 0.07-second emergence and restrained impulse. Do not accelerate
  layer switching as a substitute for fast individual emergence.
- A local, one-pixel jagged seam appears during the last 0.016 seconds of hold.
  It does not add an extra phase, a screen flash or a persistent white outline.
- Faceted triangles separate and rotate at fracture. During the first 76% of
  collapse their local geometry remains full-sized, rather than continuously
  shrinking into soft strips while airborne.
- At ground contact, the final shallow bounce tips fragments into a foreshortened
  resting pose. They stay still, then fade over the final quarter of the existing
  3.2-second residue lifetime. This is stylized 2D ground projection, not a rigid-body
  physics simulation.
- Deterministic reverse seeking, palette alpha, debris/residue controls, three
  range shapes and overlap timing remain shared with the existing component.
  No damage, collision, gameplay integration or balance changes.

## Reproduce

Run the existing project, choose ICE, and use Replay/slow speed/time scrubbing:

```sh
godot --path preview/radial-spikes-godot -- --element=1
```

Checks run with Godot 4.6.3 Standard:

```sh
godot --headless --editor --path preview/radial-spikes-godot --import --quit
for test in test_ice_rigidity test_radial test_workshop test_overlap test_geometry; do
  godot --headless --path preview/radial-spikes-godot --script tests/$test.gd
done
```

Passed: 20 + 39 + 65 + 32 + 5,348 assertions (5,504 total). The new test exercises
rigid-flight/ground-contact timing, the unchanged rapid rise and residue duration,
shape construction, deterministic seeking, and cleanup. These are state/geometry
checks, not pixel-level visual acceptance. No before-change failing run is claimed.

Native graphical checks/recording remain **not run** in this environment: no
usable display; Xorg cannot bind its required local Unix sockets (EPERM).
Headless uses a dummy renderer and cannot supply truthful rendered previews.
When a display is available, run the existing native tests and capture workflow:

```sh
RADIAL_CAPTURE_DIR=/absolute/output godot --path preview/radial-spikes-godot --script tests/render_residue.gd
RADIAL_CAPTURE_DIR=/absolute/output godot --path preview/radial-spikes-godot --script tests/render_radial.gd -- --element=ice
godot --path preview/radial-spikes-godot --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/ice.avi -- --capture --element=1
```

That existing 24-second capture covers circle, sector, multidirectional rectangles,
and a slow-motion circle. Validate the rigid break at native pixel scale before
calling the visual result approved. Logs/captures belong outside the repository.
