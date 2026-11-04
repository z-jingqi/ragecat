# Energy acceptance

Open `res://scenes/effects/energy.tscn` after importing the Godot project, or
choose Energy in the F5 gallery. The original situations are Orb, Charge, Beam and Bolts.
Left/Right selects a variant where available; Space pauses time, R restarts
and S requests stop. Original options remain available through
`configure(options)`. Camera hooks are recorded; generic flash, shake and
darken responses are explicitly not applied by this preview host.

## Verified source behavior

All 8 baseline/stress cases passed 1,681 complete lifecycle frames
and 6,724 four-buffer hash comparisons, exact hooks, actor state
and completion, with selected original RGBA bytes also checked directly.
Fresh original TypeScript replay reproduced the reference cases.

The frozen source from group-two commit
`1719e686473648dc671e7aa3a8a465c18bb87abb` was checked with the shared core
published at `5860aa6fa081df5903cbd10cdc83ba309c9d464c`. The pixel-buffer
SHA256 is `8a71ff354706c45a571c72e908b3070a1e69b069707471d6e36fd305727c7c5f`.
That integration also passed adapter reconfiguration, scene lifecycle and
gallery navigation. No performance work was performed.

## Native presentation

The effect SHA256 is `29314a73c0504ce5c7513629831ba3e679d6c348c5e9c9f4358b3d289eccc3f0`.
The shared host SHA256 is
`64f3dcd89ccc952803c64f339ded13383ec870da5a98c10d2ad81322ec0cb023`.
Historical native acceptance passed 43 sampled states with
86 original TypeScript combined color/light hashes
and zero native viewport pixel differences. The 989-frame,
16.483-second, 960×684 recording was visually inspected.
Effect and host files remain identical to that capture. The later current-core
checks above verify source output compatibility; they are not a new viewport
recording.

The gallery uses one mutable Frame, back → synthetic actor → front, followed
by additive light and alpha color. The footer is outside the original
640×400 stage. Original clipping, host coverage and end-state behavior are
not changed to make the preview look cleaner.

## Code-first delivery and limits

At the user's request, comparison datasets, raw pixel samples, diagnostic
media and detailed run receipts stay local. They are not included in this
code-first release and are not runtime dependencies. Already published
datasets remain untouched. Do not run a differential command for this family
without its locally retained fixtures.

The standalone scene is runnable using the published shared core and Heal
actor helper. `res://tests/group_two_layout.gd` is an available UI-only check
that does not load missing effect families. Strict pixel statements refer
to lossless viewport RGBA, not the compressed video.

The tests cover declared finite inputs, not all possible parameters or the
unavailable website host and art. Native capture used Godot 4.6.3 Compatibility
with Mesa llvmpipe and fixed-frame MovieWriter. It does not establish real-time
speed or physical-GPU validation.
