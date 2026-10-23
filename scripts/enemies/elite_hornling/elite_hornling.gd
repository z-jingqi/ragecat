class_name EliteHornling
extends Hornling
## Equipment is a cosmetic layer, not armor or a separate damage mitigation rule.
func _draw() -> void:
	super._draw()
	var r := radius
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7,-r * 0.5), Vector2(-r * 0.5,-r), Vector2(r * 0.5,-r), Vector2(r * 0.7,-r * 0.5)]), Color("91a1b4"))
	draw_line(Vector2(r * 1.1,-r * 0.6),Vector2(r * 0.8,r * 0.8),Color("866448"),3)
	draw_colored_polygon(PackedVector2Array([Vector2(r,-r * 0.8),Vector2(r * 1.6,-r * 0.5),Vector2(r * 1.4,0),Vector2(r,-r * 0.1)]),Color("c6d0d9"))
