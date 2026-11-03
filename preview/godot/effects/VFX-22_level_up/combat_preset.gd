extends RefCounted
## Two-pixel output grid around a host up to76px tall; no new particle budget.
## The host's foot offset remains in host space, not multiplied by this scale.
const DRAW_SCALE := Vector2(2,2)
const OPTIONS := {
 "height":68.0,"radius":23.0,"column_width":7.0,"core_width":2.0,
 "intensity":0.82,"flicker_amount":0.25,"particles":18,"glints":5,
 "charge":0.10,"burst":0.65,"settle":0.85
}
