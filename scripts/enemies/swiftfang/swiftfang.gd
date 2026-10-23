class_name Swiftfang
extends Hornling
## Light, fast melee archetype. No additional active ability.
func _draw() -> void:
	super._draw()
	var color := _status_body_color().lightened(0.2)
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * radius * 0.5, 3), Vector2(side * radius * 1.5, 7), Vector2(side * radius * 0.8, 10)]), color)
