extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var old_clip := VfxAtlasRenderer.library.find_clip(&"fire_burst")
	var clip := VfxAtlasRenderer.library.find_clip(&"fire_explosion")
	check(clip != null and clip.valid(), "Dedicated player fire explosion registered")
	check(clip.texture != old_clip.texture, "Player explosion cannot replace boss skyfire atlas")
	check(clip.frames == 24 and not clip.loop, "One shot 24-frame volume")
	var source := FileAccess.get_file_as_string("res://scripts/combat/element_flash.gd")
	check(source.contains('&"fire_explosion"') and not source.contains('&"fire_burst"'), "Player blast uses new clip only")
	var world := Node2D.new();root.add_child(world)
	seed(61233);var expected := randi();seed(61233)
	var rotations: Dictionary = {}
	for i in range(64):
		var effect := ElementFlash.new();effect.kind="blast";effect.radius=60;effect.duration=.25;effect.remaining=.25
		world.add_child(effect);effect.set_process(false)
		check(effect.radius == 60 and effect.duration == .25 and effect.remaining == .25, "Cosmetic variation never changes radius or lifetime")
		check(effect._blast_scale > 0 and effect._blast_scale <= 1, "Variation never enlarges damage-looking footprint")
		check(is_zero_approx(pow(0.0,effect._blast_time_power)) and is_equal_approx(pow(1.0,effect._blast_time_power),1.0), "Timing variation preserves instant start and exact finish")
		rotations[effect._blast_rotation]=true
		effect._process(.25)
		check(effect.is_queued_for_deletion(), "Explosion expires at existing duration")
	check(rotations.size()==64,"Successive impacts do not repeat same rotation")
	check(randi()==expected,"Presentation consumes no gameplay random stream")
	await process_frame
	check(world.get_child_count()==0,"Repeated blasts retain no nodes")
	world.queue_free();await process_frame
	print("FIRE_EXPLOSION_PRESENTATION: %d checks, %d failures"%[checks,failures]);quit(failures)
