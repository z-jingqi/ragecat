extends "../components/copper_arc.gd"
## Same geometry/timing interface, broader bright leading face for the approved design.
const ELEMENT_SHADER = preload("elemental_arc.gdshader")
func _rebuild() -> void:
	super._rebuild()
	surface.material.shader = ELEMENT_SHADER
