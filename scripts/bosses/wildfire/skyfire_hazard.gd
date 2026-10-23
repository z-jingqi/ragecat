class_name SkyfireHazard
extends Node2D
signal impact(hazard: SkyfireHazard)
var radius: float = 120.0
var warning: float = 1.2
var impact_damage: float = 14.0
var burn_duration: float = 3.0
var burn_damage: float = 4.0
var elapsed: float = 0.0
var impacted := false
var ai_enabled := true
var splash := false

func _init() -> void:
	set_meta("boss_hazard", true)
	top_level = true

var arena_bounds: Rect2 = Rect2()

func _ready() -> void:
	var clipping := ShaderMaterial.new()
	clipping.shader = preload("res://shaders/boss_hazard_clip.gdshader")
	clipping.set_shader_parameter("arena_rect", Vector4(arena_bounds.position.x, arena_bounds.position.y, arena_bounds.size.x, arena_bounds.size.y))
	material = clipping

func _physics_process(delta: float) -> void:
	if not ai_enabled or not is_finite(delta) or delta < 0.0: return
	elapsed += delta
	if not impacted and elapsed >= warning:
		impacted = true
		impact.emit(self)
	if elapsed >= warning + burn_duration: queue_free()
	queue_redraw()

func contains(point: Vector2, target_radius: float) -> bool:
	return point.distance_to(global_position) <= radius + target_radius

func burning() -> bool:
	return impacted and elapsed < warning + burn_duration and not is_queued_for_deletion()

func _draw() -> void:
	if not impacted:
		var fraction := clampf(elapsed / maxf(0.01,warning),0,1)
		draw_circle(Vector2.ZERO,radius,Color(1,0.18,0.04,0.18))
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("ffcb78"),3)
		draw_arc(Vector2.ZERO,radius-5,-PI*.5,-PI*.5+TAU*fraction,64,Color("ff6842"),4)
		var meteor_radius := 12.0 + fraction * 14.0
		var meteor_center := Vector2(0, -120.0 * (1.0 - fraction))
		if not VfxAtlasRenderer.draw_clip(self, &"skyfire_fall", fraction, Rect2(meteor_center - Vector2.ONE * meteor_radius, Vector2.ONE * meteor_radius * 2.0), Color.WHITE, true, true):
			draw_circle(meteor_center, meteor_radius, Color("ffec9c"))
	else:
		var fade := clampf((warning+burn_duration-elapsed)/maxf(.01,burn_duration),0,1)
		draw_circle(Vector2.ZERO,radius,Color(0.85,0.12,0.02,0.2+fade*.15))
		if VfxAtlasRenderer.draw_clip(self, &"fire_ground", elapsed - warning, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color(1, 1, 1, fade), true):
			VfxAtlasRenderer.draw_clip(self, &"fire_burst", elapsed - warning, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color.WHITE, true)
			return
		for i in range(12):
			var angle := TAU*i/12.0
			var at := Vector2.from_angle(angle)*radius*.65
			var height := 9+6*sin(elapsed*9+i)
			draw_colored_polygon(PackedVector2Array([at+Vector2(-7,5),at+Vector2(0,-height),at+Vector2(7,5)]),Color(1,.46,.08,.7*fade))
