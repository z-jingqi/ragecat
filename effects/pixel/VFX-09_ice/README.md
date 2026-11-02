# VFX-09 · Ice Spikes

Procedural pixel ice crystals: a frost trace advances, faceted spikes grow in sequence, then **the same triangular facets** detach and tumble into chips. No spritesheet, image sequence, external texture, host sprite or Unity implementation.

This is the ice-spike / crystal-shatter subtype. A character frozen overlay is a separate host-dependent status effect; this component does not claim to freeze a character or apply damage.

Open `preview/godot/effects/VFX-09_ice/lab.tscn` in the Godot preview project. The left panel is actual logical size, the right is 2× nearest. Replay, pause, clear, single-step, palette presets, seed, rate, reset and background controls are available.

## Component contract

`ice.gd` exposes `play(world_position, config)`, `tick(delta)`, `seek(seconds)`, `replay()` and `clear()`. Set `auto_tick = false` for an external clock. Positions are snapped only for rendering; caller inputs are not changed. A new play replaces the previous instance. End and clear hide all geometry. Pause freezes age. Non-finite deltas are ignored. Invalid anchors clear the effect.

## Parameters

| Key | Default | Range / unit | Meaning |
|---|---:|---|---|
| count | 5 | 1–7 | Crystal count |
| spacing | 12 | 5–16 px | Ground-anchor spacing |
| height | 34 | 12–48 px | Tallest spike height |
| width | 5 | 2–8 px | Crystal half-width |
| grow | .14 | .06–.30 s | Growth per crystal |
| hold | .28 | 0–1 s | Solid crystal phase |
| shatter | .38 | .15–.70 s | Facet flight and retirement |
| stagger | .055 | 0–.12 s | Delay between crystal starts |
| speed | 42 | 10–70 px/s | Facet ejection speed |
| angle | 0 | −30–30 degrees | Crystal lean, not ground-line rotation |
| irregularity | .75 | 0–1 | Height/anchor/lean variation; asymmetric facets and side crystals remain structural |
| seed | 19 | 0–4095 | Deterministic shape/flight variation |
| lightHex / bodyHex / shadeHex / darkHex | preset | opaque RGB | Four discrete facet colors |

Total lifetime is `grow + hold + shatter + (count−1)×stagger`, default **1.02 s**. Values apply on play/replay, not mid-simulation. UI changes restart the preview. Radius/damage/freeze decisions belong to gameplay code.

## Reference study

[ MIMIC · Pixel Art Ice Spell Effects](https://mimicmart.itch.io/pixel-art-ice-spell-effects) is the primary refinement reference. The public Ice Spikes GIF was downloaded and frames 2–18 inspected: alternating heights, oblique root crystals, interrupted white edges, broad blue refractive planes, then spatial breakup. These informed irregular shoulders and off-axis facet junctions, attached side crystals, short internal cleavages and narrow interrupted highlights. No downloaded reference pixels are shipped.


[ParticleFX Glacial Spike Line](https://particlefx.studio/effects/glacial-spike-line) was reviewed using its actual poster and eight-time strip. Useful observations: advancing ground trace, staggered increasingly tall crystals, bright and dark facets, followed by angular shards. The implementation is original analytic geometry, with a shorter clean ending and no bloom or copied production assets. The eight stills are not a full-frame animation recording.

The original preview has a richer mist layer; here sparse frost chips keep the small-scale silhouette legible. Existing fire/lightning/host effects are not modified.
