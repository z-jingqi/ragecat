# Range eruption algorithm

1. Sanitize and deep-copy the profile. Geometry.sample(profile, seed) creates reproducible sites.
2. Construct each band in unsquashed ground coordinates. Circle/sector sites are angular sectors;
   lanes are transverse samples along each specified heading. A multi-layer starting distance is
   min(inner_radius, extent/2), so short footprints still advance instead of stacking at the end.
3. Independent per-band random streams jitter positions, dimensions and spawn times. Outer edges
   are inset and clamped inside Geometry.outlines(profile), the same contours used by the range guide.
   Roughly one quarter of sites are major shapes; the others have weaker strength and smaller height.
4. Spawn is onset_delay + band × stride + local stagger. Stagger is min(.07, rise×.25)×irregularity.
   Span is rise+hold+fade+stagger; stride is span−overlap+delay. Overlap is capped by fade and 49% of
   span. New bands start during earlier-band collapse, with at most two active eruption bands.
5. Project ground anchors and headings by ground_squash; upward visual height stays uncompressed.
   Nested y-sort compares each anchor with the neutral host actor. Range contours describe anchor
   sampling, not particle travel, tall silhouettes, gameplay hitboxes or collision.
6. Earth rises with restrained overshoot, then clips its original outline into four thick strata.
   Pieces tip outward, fall and flatten into angular ground slabs. Ice divides three faceted branches
   into 15 thin angular fragments with a shallow bounce. A deterministic subset persists as residue.
7. Residue age starts at each site's rise+hold+fade. It holds its ground pose, then fades in the final
   quarter of residue_lifetime. Density0 or lifetime0 disables the persistent tail. Flying debris,
   ground marks and retained fragments use separate controls. No mutable particle history is stored.
8. wave_lifetime() ends the moving eruption; lifetime() includes the optional earth/ice residue tail.
   active_layers() reports only the eruption phases. clear() frees all canvases immediately; finished
   emits once after the last residual pixel expires. Reverse seek reconstructs the same state.

## Electrical hierarchy

Strength≥.6 produces a main channel; lesser sites only emit sparse dim local crawls. Outward/inward
mode uses the projected site heading, while vertical mode starts above the landing point. Endpoints
and seed-based elbows remain stable across the event: fast leader, bright stroke, dark gap, weaker
anchored re-strike and dotted cooldown. One short branch has 32% of main energy. Sparks originate
at the landing, not everywhere along the channel. No whole-screen flashing or camera movement.

## Fire

A fast warm-white core sits inside orange/red tongue layers. Several seeded tongues bend along
outward force, pinch away from their roots and detach. Cool embers and sparse smoke finish within
its visual envelope. It creates no persistent ground residue or gameplay burning state.

All geometry is procedural Godot drawing. No sprite sheets, upstream rendered assets, physics,
collision, damage, knockback, camera shake or persistent services are used.
