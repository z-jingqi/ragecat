# Ice acceptance

Open `res://scenes/effects/ice.tscn` after importing the Godot project, or choose
Ice in the F5 gallery. Left/Right selects Nova, Spikes, Crystals, Shatter or
Freeze. Space pauses time, R restarts and S requests stop. Original options
remain available through `configure(options)`. Camera hooks are recorded; the
preview explicitly does not apply generic flash, shake or darken responses.

## Source and current-core checks

- All five modes have baseline and stress coverage: 10 cases, 2,215 complete
  lifecycle frames and 8,860 four-buffer hash comparisons, with exact hooks,
  actor state and completion. Selected RGBA bytes are also compared directly.
- The frozen implementation from group-two commit
  `1719e686473648dc671e7aa3a8a465c18bb87abb` was rerun with the published shared
  core at `5860aa6fa081df5903cbd10cdc83ba309c9d464c`. The pixel-buffer runtime
  SHA256 is `8a71ff354706c45a571c72e908b3070a1e69b069707471d6e36fd305727c7c5f`.
  The same source results passed, alongside fresh original TypeScript replay.
- Reconfiguration, scene lifecycle and gallery navigation were checked with the
  other installed group-two variants. The portable footer test uses only UI
  inputs and needs no unavailable effect modules. No performance work was run.

## Native presentation

The frozen effect SHA256 is
`54948cbec4d25940dff5510f88d049715fd0b7f02eac3201e144ab3d1c10084f`.
The shared preview SHA256 is
`64f3dcd89ccc952803c64f339ded13383ec870da5a98c10d2ad81322ec0cb023`.
Independent Compatibility-renderer acceptance passed 55 sampled states across
the five modes: 110 original TypeScript combined color/light hashes and all
native viewport pixels matched. The complete 1,349-frame, 22.483-second,
960×684 recording was inspected, including each mode and its tail. Effect
and host files are unchanged from that capture. The later current-core checks
above are source-output compatibility checks, not a new viewport recording.

The gallery presents one mutable Frame in back → synthetic actor → front order,
then additive light before alpha color. Controls sit outside the original
640×400 stage. Original edge entry and actor coverage are preserved.

## Reproduce and limits

The original-source comparison fixtures, raw pixel samples, diagnostic images
and detailed run receipts are retained locally. They are not included in this
code-first release at the user's request. No runtime resource depends on them,
and the public per-family differential command is not available for Ice.
The already published Heal fixtures remain unchanged.

Run the standalone scene for an interactive check; its runtime requires only
the published shared core and Heal actor helper. The shared UI-only layout
check is `res://tests/group_two_layout.gd`; it does not load absent families.
Strict pixel claims above come from the retained lossless viewport RGBA, not
the compressed preview movie.

Evidence covers the declared finite inputs, not every possible parameter or
the unavailable website host and art. Native capture used Godot 4.6.3
Compatibility with Mesa llvmpipe and fixed-frame MovieWriter; it establishes
presentation, not real-time speed or physical-GPU validation.
