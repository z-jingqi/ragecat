# VFX-17 verification

- Continuous geometry and rotated world containment use the same transformation as raster sampling.
- Circle, ring hole, sector direction and rectangle exact boundary checks.
- Visual styles never change authoritative geometry/countdown.
- 30/60/144 Hz deadline activation, no early or duplicate events, large-delta crossing.
- Callback replay is safe; cancel/reset clear; repeated reuse has bounded image storage.
- Locked origin, explicit follow offset, destroyed-follow-target cancellation.
- Invalid values normalized to documented supported bounds; all supported maximum geometry fits the logical canvas.
- Preview reset synchronizes controls, frame step, replay, shape and follow/lock behavior.

Native Godot 4.6.3 OpenGL preview reviewed at actual 1× and nearest 2×. Circle, ring, rotated sector and rectangle retain stable boundaries while fill advances. Cancel clears immediately. Four sampled stages have byte-exact nearest scaling. Final recording: VFX-17-boss-warning-v1.mp4, 841 frames at 60 fps (14.017 s), dark/light backgrounds. Native run has no script errors; driver emits only unsupported V-Sync warning.

Library preview: libfile_62da7cc924748191a0f8ca950f59cf0a.

