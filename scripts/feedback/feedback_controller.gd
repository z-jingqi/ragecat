class_name FeedbackController
extends Node2D
## Bounded cosmetics with independent RNG. Saturation drops only presentation.
var definition: HitFeedbackDefinition = preload("res://resources/feedback/hit_feedback.tres")
var enabled: bool = true
var audio: FeedbackAudio
var event_counts: Dictionary = {}
var dropped_visuals: int = 0
var rng := RandomNumberGenerator.new()
var visuals := Node2D.new()

func _ready() -> void:
	definition = definition.validated_copy()
	enabled = definition.enabled
	rng.seed = 930713
	add_child(visuals)
	audio = FeedbackAudio.new()
	add_child(audio)
	# Player is z=3; shared feedback never paints over the player or UI.
	z_index = 1

func present(event: FeedbackEvent, enemy: EnemyActor) -> void:
	if event == null or event.actual_damage <= 0.0: return
	_count(FeedbackEvent.Source.keys()[event.source])
	if not enabled or not definition.enabled: return
	if event.source == FeedbackEvent.Source.DIRECT:
		_spawn("impact", event.position, definition.critical_color if event.critical else definition.element_color(event.element), event.direction, enemy.radius, event.critical)
		audio.play_event("critical" if event.critical else "hit")
		if event.shattered: status_event("shatter", enemy.global_position, enemy.radius)
	elif event.source in [FeedbackEvent.Source.BLAST, FeedbackEvent.Source.CHAIN]:
		_spawn("impact", event.position, definition.element_color(event.element), event.direction, enemy.radius, false, true)
	# BURN, GRAVITY and UNKNOWN deliberately have no impact sound or burst.

func status_event(kind: String, at: Vector2, radius: float = 16.0) -> void:
	_count(kind)
	if not enabled or not definition.enabled: return
	var color := definition.lightning_color if kind == "shock" else definition.ice_color
	_spawn(kind, at, color, Vector2.UP, radius)
	if kind in ["freeze", "mark"]: audio.play_event("freeze")
	elif kind == "shatter": audio.play_event("shatter")
	elif kind == "shock": audio.play_event("shock")

func skill_event(kind: String) -> void:
	_count(kind)
	if enabled and definition.enabled: audio.play_event(kind)

func launch(gravity: bool = false) -> void:
	_count("launch")
	if enabled and definition.enabled:
		audio.play_event("dark" if gravity else "launch")

func death(enemy: EnemyActor) -> void:
	_count("kill")
	if not enabled or not definition.enabled: return
	var deaths := 0
	for visual in visuals.get_children():
		if visual.kind == "death" and not visual.is_queued_for_deletion(): deaths += 1
	if deaths < definition.death_limit:
		var snapshot := _spawn("death", enemy.global_position, enemy._status_body_color(), Vector2.UP, enemy.radius)
		if snapshot != null:
			snapshot.actor_style = "boss" if enemy is BossActor else ("ranged" if enemy is RangedEnemy else "mob")
			snapshot.variant = enemy.variant
	else: dropped_visuals += 1
	audio.play_event("kill")

func _spawn(kind: String, at: Vector2, color: Color, direction: Vector2, radius: float, critical: bool = false, light: bool = false) -> FeedbackVisual:
	if visuals.get_child_count() >= definition.visual_limit:
		dropped_visuals += 1
		return null
	var visual := FeedbackVisual.new()
	visual.kind = kind
	visual.position = at
	visual.color = color
	visual.critical = critical
	visual.radius = radius
	visual.duration = definition.death_duration if kind == "death" else (definition.impact_duration if kind == "impact" else definition.accent_duration)
	visual.remaining = visual.duration
	visual.travel = definition.particle_travel * (0.65 if light else 1.0)
	var count := definition.critical_particles if critical else definition.particles
	if light: count = maxi(1, count / 2)
	for i in range(count):
		var angle := rng.randf_range(-1.2, 1.2) if kind == "impact" else rng.randf_range(-PI, PI)
		visual.directions.append(direction.rotated(angle) * rng.randf_range(0.6, 1.0))
	visuals.add_child(visual)
	return visual

func _count(kind: String) -> void:
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1

func clear() -> void:
	for child in visuals.get_children():
		visuals.remove_child(child)
		child.queue_free()
	if is_instance_valid(audio): audio.stop_all()

func set_audio_enabled(value: bool) -> void:
	if is_instance_valid(audio): audio.set_enabled(value)
