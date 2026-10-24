# Reproducible Archer dash source

Place this folder at `source/art/characters/archer/dash/`, inside the original complete licensed Archer source package. Do not move or replace the original model/textures. Defaults are the parent Archer folder for inputs and `generated/` next to these scripts for outputs. Override with `ARCHER_SOURCE_ROOT` and `ARCHER_DASH_OUTPUT`; the native serial queue also accepts `BLENDER_BIN` (default `/usr/bin/blender`).

## Minimal authoring files and dependencies

Required to author/render: `build_dash_sample.py`, `build_guard_move_recovery.py`, `dash_artifact_validation.py`.

Recommended reproducible batch tools: `render_all_directions.py`, `compute_gait_recommendations.py`. Optional import helper: `depth_edge_fill.py`.

Runtime: Blender 4.3.2 with its bundled Python, NumPy and mathutils. The native queue needs only Python 3 standard library; the numeric recommendation/import helpers need NumPy. No plugin, external animation library, paid resource, new identity model, or image rotation/mirroring is used.

Required unchanged parent-package inputs: `archer.blend`, relative `textures/`, `body_poses.json.gz`, `upper_poses.json.gz`, `body_manifest.json`, `camera_contract.json`, `layer_objects.json`, and `locomotion_solver.py`. Preserve the original license/source manifest. Generated cloth correction caches are isolated under each output tag, not written to the input package.

## Commands

Full serial 672-frame batch, two Blender CPU threads per job, 16 samples:
`python render_all_directions.py --workers 1`

After completion:
`python compute_gait_recommendations.py`

Single shooting body example:
`blender -b --disable-autoexec --python-exit-code 1 -t 2 -P build_dash_sample.py -- --render --cpu --camera east --relative-travel 2 --variant braced --shoot-mode shoot --layer body --samples 16 --skip-existing`

Single full guard example:
`blender -b --disable-autoexec --python-exit-code 1 -t 2 -P build_dash_sample.py -- --render --cpu --camera northwest --relative-travel 0 --variant follow --shoot-mode guard --layer full --samples 16 --skip-existing`

Three guarded moving-recovery frames:
`blender -b --disable-autoexec --python-exit-code 1 -t 2 -P build_guard_move_recovery.py -- --render --camera east --samples 16 --skip-existing`

## Contracts

Coverage is 64 body clips ×9, 8 full guard clips ×9, and 8 guard moving-recovery clips ×3 =672. Camera labels are east, southeast, south, southwest, west, northwest, north, northeast. Relative travel 0–7 means forward, forward-right, right, back-right, back, back-left, left, forward-left under the original camera contract. All poses use genuine direction-specific 3D IK, with anatomical knee poles and preserved bone lengths.

Dash samples are 0, .034, .072, .112, .156, .2 seconds. Stop recovery is .22666666, .25333334, .28 seconds. Guard moving recovery is instead sampled over 6.13333333, 12.26666667, 18.4 game pixels of actual travel. It does not require a fixed runtime duration. Use per-camera recommended exit gait phases; south/north use 6/16 and the others 5/16. Body gait entry recommendations preserve the newly landed foot.

Braced shooting keeps chest/clavicle anchors compatible with the original independent upper shooting cycle. It has real pelvis/lumbar movement, not a claimed whole-chest lean. Full non-shooting guard uses chest follow, two-arm IK and an attached tilted bow. Firing/volley events remain authoritative and must immediately supersede full guard, not be delayed by its animation.

The unchanged mechanics are dash duration 0.2 s, speed 760 and cooldown 2 s. Root motion is not baked. Common body/upper bob is metadata and must be applied exactly once. These source tools do not change gameplay, aim, input timing, or arrow speed 650.

Each image is 192×192 RGBA8 plus matching linear camera-space Z EXR. Keep fixed depth normalization 6.0551778793335–8.55949668884277m. Alpha-edge pixels can contain Blender background Z; `depth_edge_fill.py` fills only invalid covered depth from the nearest valid surface, without changing RGBA or renormalizing per frame.

## Resume and numerical safeguards

The queue checks `PAUSE_RENDER` before the next group. Wait for `queue_status=paused` and no running job before another renderer or Godot session. Remove the marker only after the other process has actually exited. `STOP_RENDER` stops at a group boundary. Only one full-resolution Blender process was safe in the measured environment; no concurrent rendering is assumed.

`--skip-existing` checks source/clip/frame identity, PNG/EXR hashes, the bound pose-metadata hash and exact render-relevant pose fingerprint. Per-frame pose checkpoints allow continuation after an interrupted group. Mere file existence does not count as completion. The fixed bone-length < 1e-6 m, connection < 3e-6 m and forward-knee gates are retained. A mathutils near-collinear foot-quaternion slerp defect is corrected only when its magnitude differs from 1 by more than 1e-6; this does not relax those gates.


## Godot atlas import

From the project root, create a verified manifest after the batch and gait recommendations finish:

`python tools/art/archer/build_dash_manifest.py SOURCE_OUTPUT MANIFEST_JSON`

Then run the deterministic native-resource importer:

`godot --headless --path . --script tools/art/archer/import_dash_atlases.gd -- MANIFEST_JSON res://assets/characters/archer/poses/dash res://resources/characters/archer/dash_motion.tres`

`godot --headless --path . --script tools/art/archer/verify_dash_pixels.gd -- MANIFEST_JSON res://resources/characters/archer/dash_motion.tres`

Atlas trimming preserves the logical canvas, pivot and every alpha/visible color pixel. Guard moving recovery shares its first six frames with the corresponding guard clip. Generated raw frames, cloth caches, logs and review media are not project runtime assets. Keep them outside version control. Run the project test suite and review real-time directional handoffs before publishing new artwork.
