class_name BossActor
extends EnemyActor
signal attack_player(damage: float)
@export var boss_definition: BossDefinition = BossDefinition.new()
signal phase_transition_started(phase: int)
var transition_remaining: float = 0.0
var boss_identity: String = "boss"
var phase_number: int = 1
var choice_rng := RandomNumberGenerator.new()
var previous_ability: String = ""
var reserve_summons: Callable
var commit_summons: Callable
var cancel_summons: Callable
var _forced_phase: int = 0
var phase_two_pending: bool = false

func _ready() -> void:
	boss_definition = boss_definition.snapshot()
	radius = boss_definition.body_radius
	tint = boss_definition.body_color

func current_phase() -> BossPhaseDefinition:
	return boss_definition.phase_two if phase_number == 2 else boss_definition.phase_one

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if ai_enabled and not is_dead: transition_remaining = maxf(0.0, transition_remaining - delta)

func update_phase_at_boundary() -> bool:
	if _forced_phase > 0: phase_number = _forced_phase
	elif phase_number == 1 and (phase_two_pending or health <= max_health * boss_definition.phase_threshold):
		phase_number = 2
		phase_two_pending = false
		transition_remaining = boss_definition.transition_duration
		phase_transition_started.emit(phase_number)
	return transition_remaining <= 0.0

func force_phase_for_practice(value: int) -> void:
	_forced_phase = clampi(value, 1, 2)
	phase_number = _forced_phase
	reset_state()

func choose_ability(first: String, second: String, first_available: bool = true, second_available: bool = true) -> String:
	if not first_available and not second_available: return ""
	if not first_available:
		previous_ability = second
		return second
	if not second_available:
		previous_ability = first
		return first
	var distance := position.distance_to(target.position) if is_instance_valid(target) else boss_definition.near_distance
	var blend := clampf(inverse_lerp(boss_definition.near_distance, boss_definition.far_distance, distance), 0.0, 1.0)
	var first_weight := clampf(lerpf(boss_definition.near_first_weight, boss_definition.far_first_weight, blend), 0.0, 1.0)
	var second_weight := 1.0 - first_weight
	if previous_ability == first: first_weight *= boss_definition.repeat_weight
	if previous_ability == second: second_weight *= boss_definition.repeat_weight
	var result := first if choice_rng.randf() * (first_weight + second_weight) < first_weight else second
	previous_ability = result
	return result

func cleanup_owned_hazards() -> void:
	if cancel_summons.is_valid(): cancel_summons.call(self)
	for child in get_children():
		if child.get_meta("boss_hazard", false):
			remove_child(child)
			child.queue_free()

func reset_state() -> void:
	cleanup_owned_hazards()
	transition_remaining = 0.0
	clear_hit_reaction()
	clear_gravity(true)

func receive_damage(amount: float, crit: bool = false) -> void:
	if amount >= health and amount > 0.0: cleanup_owned_hazards()
	super.receive_damage(amount, crit)
	if not is_dead and phase_number == 1 and health <= max_health * boss_definition.phase_threshold: phase_two_pending = true

func health_bar_visible() -> bool: return true
func hit_movement_eligible() -> bool: return false
func knockback(_direction: Vector2, _force: float = 26.0) -> void: pass

func _exit_tree() -> void:
	cleanup_owned_hazards()
