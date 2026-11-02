# VFX-10 — Poison Cloud

Independent world-area poison: a readable dark puddle, low rolling lobes, rising bubbles, sparse pop flecks. Entirely procedural Godot drawing; no sprite-sheet animation, imported effect textures, Unity adapter or gameplay health mutation.

Run `godot --path preview/godot res://effects/VFX-10_poison/poison.tscn`.

## API

Create `poison.gd`, add it to a CanvasItem and call `play(local_position, overrides)`. Set `automatic=false` to drive `tick(delta)` externally. `stop()` cancels immediately. `active_finished` fires once at the configured gameplay duration; `finished` occurs after the harmless visual exit. Callbacks may safely restart/stop it. The component owns no targets and applies no damage; the game uses its own authoritative boundary and tick rules. The demo marker only shows horizontal footprint membership, not combat.

## Parameters

| Name | Default | Range / units |
|---|---:|---|
| radius | 40 | 12–52 logical pixels, horizontal footprint |
| duration | 3 | 0.3–30 seconds active |
| formation | 0.24 | 0.05–min(0.6,duration) seconds |
| exit | 0.5 | 0.1–1 seconds harmless drain |
| density | 16 | 0–24 gas lobes; 0 leaves pool/bubbles |
| flow | 1 | 0.3–2 motion multiplier |
| height | 26 | 8–40 pixels maximum gas rise |
| seed | 19 | 0–99999 stable layout seed |
| deep/shade/body/rim/light | green five-step palette | Color or HTML color string |

Parameters are snapshotted on play; replay to apply changes. Radius represents an ellipse of roughly 0.46 vertical aspect, with visual gas rising above it. Color/seed/flow do not change gameplay range. Non-finite numeric inputs restore defaults. The fixed five bubbles and bounded gas count prevent emitter accumulation.

The original task's **host-bound poison tint is not part of this world zone**. It belongs to the separate status-effect component and needs host alpha validation.

## Pixel rules

All shape fills use integer scanlines, not antialiasing or filtered textures. The preview shows the same low-resolution viewport at actual 1× and nearest 2×. Palette/light-background controls are diagnostic; source and output remain procedural.
