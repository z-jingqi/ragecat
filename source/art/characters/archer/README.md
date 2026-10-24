# Editable Archer and deterministic layer rendering

This package contains the complete editable character, its dimensional recurve bow, and the right-shoulder quiver. All 13 textures are stored as unchanged original image bytes in `textures/` and referenced by project-relative paths. Keep the entire directory together when moving or opening the model; do not copy only `archer.blend`. The anatomical rig has 51 original bones plus 32 independent garment bones. Original anatomical rest lengths remain unchanged. Blender coordinates are metres, +Z up, with the physical firing axis along world -Y. Camera direction is changed without rotating or mirroring the rendered sprite.

The bow grip is `Bow_Prop_Root` / `Bow_Grip`; the real string slots are `Bow_Nock_Upper` and `Bow_Nock_Lower`. `Bow_Arrow_Rest` and `Physical_side_arrow_shelf` retain the actual arrow-height reference. The left hand is `hand.l`, the drawing hand is `hand.r`; shoulders and elbows are `clavicle.l/r`, `upperarm.l/r` and `forearm.l/r`. The quiver is physically bone-parented to `chest`. Animation is supplied as reproducible pose data, not as a finished animator-facing IK control rig.

Files:
- `archer.blend`: compressed editable model with relative texture paths, named meshes/materials, rig, editable bow DrawFlex and one local garment-clearance shape key per panel.
- `camera_contract.json`: eight measured orthographic cameras, fixed 192×192 canvas and canonical pivot.
- `layer_objects.json`: exact whole-mesh body/core and upper/prop partition.
- `body_manifest.json`: all body runtime clips, travel directions, physical/projected stride and shared bob metadata.
- `body_poses.json.gz`: normalized 83-bone poses. `cloth/*.npz` stores absolute local mesh coordinates for each sample, not deltas.
- `upper_poses.json.gz`: normalized shooting bones and actual bow/string/arrow/visibility states.
- `locomotion_solver.py`: continuous target-length foot, pelvis and actual 3D cloth-clearance solver, independent of the exported 16-pose budget.
- `render_archer_layer.py`: portable Blender CLI renderer using only this package and Blender's bundled Python/Numpy. No plugin or downloaded executable is needed.

Example body render:
blender -b --disable-autoexec -t 4 -P render_archer_layer.py -- --layer body --clip east/run_right --frame 0 --output preview

Example upper render:
blender -b --disable-autoexec -t 4 -P render_archer_layer.py -- --layer upper --clip east/short_release --frame 1 --output preview

Use `--assets` to point to this directory from elsewhere. Optional `--phase 0.123` on a body run clip recomputes an arbitrary continuous gait phase, including real 3D garment clearance; omitting it replays the exact stored export sample. This permits higher frame-rate re-exports without stretching bones or interpolating raw 4×4 matrices. Output is transparent RGBA PNG plus camera-space float32 metre Z EXR. Smaller depth is nearer; ignore depth wherever color alpha is zero. Never independently normalize a frame's depth.

Both layers use the same canonical pivot and texture-to-game scale. Rendered geometry excludes shared gait bob. Apply one identical per-frame screen shift to both layers, not once per layer plus again at the parent. `screen_bob_px` uses source texture pixels; `screen_bob_game_px` is already scaled. Gait phase follows actual distance/projected stride and is independent of shooting cadence.

Sideways locomotion uses limited pelvis rotation around its fixed spine attachment. Spine, upper spine, chest, neck, head and clavicle world matrices remain common to the independent upper layer. Tiny inherited arm-root hips weights were transferred to the fixed spine, preserving baseline surface positions within 0.36 micrometres. Backward clips use actual backward foot paths rather than reversed knee bend or mirrored images.

The source solver remains continuous in phase. Runtime images sample 16 poses per cycle as an intentional small-sprite export budget, not as a limitation of the rig. Direction changes currently select separate forward/backward movement branches; this package does not claim fully blended transitions between all directions.

The garment corrections are real local 3D mesh deformations, not sprite stretching, screen-space masking or hidden seams. Some original covered groin/inner-thigh and loose trouser surfaces intersect internally. No global zero-self-intersection claim is made; evaluated free garment surfaces and visible silhouette are the relevant render checks.

This package contains no downloaded animation actions or third-party motion libraries. Licensing and attribution of the human base, original reference imagery, hair/skin and leather textures are provided in the accompanying license manifest.
