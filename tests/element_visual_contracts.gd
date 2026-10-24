extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var settings := ElementVisualDefinition.new()
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	var overlay := ElementStatusVisual.new()
	overlay.setup(enemy, settings)
	enemy.add_child(overlay)
	overlay.set_process(false)
	enemy.status.frozen_remaining = 1.0
	overlay._process(settings.freeze_growth_duration * 0.5)
	check(is_equal_approx(overlay.freeze_coverage, 0.5), "Frost grows halfway in configured half-duration")
	check(is_equal_approx(enemy.status.frozen_remaining, 1.0), "Cosmetics do not tick gameplay status")
	overlay._process(settings.freeze_growth_duration * 0.5)
	check(is_equal_approx(overlay.freeze_coverage, 1.0), "Frost reaches complete shell")
	enemy.status.consume_ice()
	overlay._process(0.001)
	check(overlay.freeze_coverage == 0.0, "Shatter cancels shell immediately")
	enemy.status.frozen_remaining = 1.0
	overlay._process(0.01)
	enemy.status.frozen_remaining = 0.0
	overlay._process(0.001)
	check(overlay.freeze_coverage == 0.0, "Early thaw cannot finish former growth")
	enemy.status.ice_mark_remaining = 2.0
	overlay._process(0.1)
	check(overlay.freeze_coverage == 0.0, "Boss ice mark never grows shell")
	var sprite := Sprite2D.new()
	enemy.add_child(sprite)
	var original := CanvasItemMaterial.new()
	sprite.material = original
	overlay.bind_sprite(sprite)
	var material := sprite.material as ShaderMaterial
	check(material != null, "Future transparent sprite accepts frost shader")
	var sprite2 := Sprite2D.new()
	root.add_child(sprite2)
	var overlay2 := ElementStatusVisual.new()
	overlay2.setup(enemy, settings)
	root.add_child(overlay2)
	overlay2.bind_sprite(sprite2)
	check(sprite2.material != sprite.material, "Sprite instances do not share animated material")
	overlay.unbind_sprite()
	check(sprite.material == original, "Detach restores previous sprite material")
	var source := Vector2(10, 20)
	var target := Vector2(200, 90)
	var bolt := ElementGeometry.bolt(source, target, settings, 3)
	check(bolt[0] == source and bolt[-1] == target, "Lightning geometry preserves exact gameplay endpoints")
	check(bolt == ElementGeometry.bolt(source, target, settings, 3), "Lightning cosmetic shape deterministic")
	check(bolt.size() == settings.bolt_segments + 1, "Lightning geometry is bounded")
	settings.bolt_segments = 999999
	settings.fire_sparks = 999999
	settings.freeze_growth_duration = NAN
	var validated := settings.validated_copy()
	check(validated.bolt_segments == 16 and validated.fire_sparks == 24, "Hostile visual resource cannot cause unbounded loops")
	check(is_finite(validated.freeze_growth_duration), "Nonfinite visual duration repaired")
	check(load("res://shaders/frost_overlay.gdshader").code.contains("source.a"), "Frost shader preserves sampled alpha")
	overlay2.free()
	sprite2.free()
	enemy.free()
	print("Element visual contracts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
