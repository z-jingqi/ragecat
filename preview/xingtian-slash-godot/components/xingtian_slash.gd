extends Node2D
## Optional composition. The host explicitly triggers a separate hit at a real contact.
const Arc = preload("copper_arc.gd")
const Particles = preload("hit_particles.gd")
var arc = Arc.new()
var sparks = Particles.new()
var blood = Particles.new()

func _init() -> void:
	blood.blood=true
	add_child(arc)
	add_child(sparks)
	add_child(blood)

func play(origin: Vector2,configuration:Resource=null) -> void:
	arc.play(origin,configuration)
	sparks.clear()
	blood.clear()

func play_hit(contact:Vector2,configuration:Resource=null) -> void:
	sparks.play(contact,configuration)
	blood.play(contact,configuration)

func advance(delta:float) -> void:
	for component in [arc,sparks,blood]: component.advance(delta)

func set_layer_enabled(layer:String,value:bool) -> void:
	match layer:
		"arc": arc.set_enabled(value)
		"sparks": sparks.set_enabled(value)
		"blood": blood.set_enabled(value)

func clear() -> void:
	for component in [arc,sparks,blood]: component.clear()

func stop() -> void:
	clear()
