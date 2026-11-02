# Verification

- 572 state/fixture assertions: actual frame alpha, transparent holes, immutable historical frame, region crop, horizontal/vertical flip, pivot, rotation, fixed world poses, stationary suppression, capacity, stop decay, teleport reset, 100 pool cycles, 30/60/144Hz sample consistency, dead host and preview reset.
- 8258 real-render assertions: half-alpha source with half-alpha host is multiplied once, holes remain clear, old ghost stays in place when host moves, and final output is fully transparent.
- Native controls reviewed: pause, frame step, mode/replay, clear/reset, colour, light/dark backgrounds and lifetime.
- 721 captured Godot frames compared pixel-for-pixel: the 2× panel is the exact nearest resize of the 1× panel. The delivered 12-second video uses the first 720 frames at 60fps and shows four normal-speed paths/poses.
- No spritesheet production animation, engine adapter or Unity runtime code was added.

## Reference refinement

Iaido Slash and Shadow Dash public eight-moment strips were downloaded and visually inspected. The revision retains a generic dodge (no sword cut), with fast-onset compact demonstration motion and nonuniform short path-aligned speed accents. New tests cover accent direction, disabling, length/capacity, reset, teleport and 30/60/144 Hz lifetime consistency. GPU checks isolate the accent layer, verify visible crisp output and full reset cleanup. The new 12-second preview replaces the original preview version.
