extends SceneTree
var arena: RageArena
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(a: float, b: float, label: String) -> void:
	check(absf(a - b) < 0.001, "%s: %s != %s" % [label, a, b])
func target(kind: String = "dummy") -> EnemyActor:
	var enemy := arena.spawn_enemy(kind, Vector2(600, 300))
	enemy.max_health = 100000
	enemy.health = enemy.max_health
	return enemy
func reset(element: String, rank: int = 3) -> void:
	arena.clear_enemies()
	arena.apply_ranks({"element_type": element, "enchant_rank": 3, "element_skill_rank": rank})
	arena.stats.crit_chance = 0.0
func hit(enemy: EnemyActor, secondary: bool = false, scale: float = 1.0) -> float:
	var arrow := BowArrow.new()
	arrow.secondary = secondary
	arrow.damage_scale = scale
	arrow.impact_position = enemy.position
	var before := enemy.health
	arena._on_arrow_hit(arrow, enemy)
	arrow.free()
	return before - enemy.health
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	for rank in range(1, 4):
		reset("ice", rank)
		var enemy := target()
		for i in range(3): near(hit(enemy, i == 1), 30.0, "stack hit never doubles")
		check(enemy.status.is_frozen(), "main and fragment stack to freeze")
		enemy.status.tick(0.1)
		var chill := enemy.status.chill_remaining
		near(hit(enemy, true, 0.6), 36.0, "noncrit fragment shatters full scaled B+E")
		check(not enemy.status.is_frozen() and enemy.status.frost_stacks == 0, "shatter consumes before proc")
		near(enemy.status.chill_remaining, chill, "shatter does not refresh chill")
		near(enemy.status.immunity_remaining, 2.0, "early break starts thaw immunity")
		near(hit(enemy), 30.0, "same-frame later hit not double")
		check(enemy.status.frost_stacks == 0, "thaw immunity blocks next stacks")
		enemy.status.tick(2.0)
		for i in range(3): hit(enemy)
		arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
		arena.stats.crit_chance = 1.0
		near(hit(enemy), 30.0 * 2.0 * arena.stats.crit_multiplier, "one crit and shatter multiply")
		check(arena.crits > 0, "actual crit remains crit")
	reset("ice")
	var boss := target("boss")
	for cycle in range(2):
		for i in range(5): near(hit(boss, i == 2), 30.0, "boss formation never doubles")
		check(not boss.status.is_frozen() and boss.status.has_ice_mark(), "five hits mark but never freeze boss")
		near(hit(boss), 60.0, "sixth boss hit consumes mark")
		check(boss.status.frost_stacks == 0 and boss.status.immunity_remaining == 0, "boss no restack or thaw immunity")
	for i in range(5): hit(boss)
	boss.status.tick(2.0)
	near(hit(boss), 30.0, "expired boss mark no double")
	check(boss.status.frost_stacks == 1, "new cycle after expiry")
	reset("ice", 0)
	var plain := target()
	for i in range(7): near(hit(plain, true), 30.0, "skillless fragments stay damage only")
	check(plain.status.frost_stacks == 0, "skillless no frost")
	reset("ice")
	var doomed := target()
	doomed.health = 1
	hit(doomed)
	check(doomed.is_dead and doomed.status.frost_stacks == 0 and doomed.status.chill_remaining == 0, "lethal impact leaves no ice")
	reset("lightning")
	var skill := arena.stats.element_skill
	skill.shock_chance_by_rank = PackedFloat32Array([0, 1, 1, 1])
	var primary := target()
	var chained := target()
	chained.position += Vector2(50, 0)
	near(hit(primary), 30.0, "shock triggering direct hit not amplified")
	near(chained.max_health - chained.health, 15.0, "shock triggering chain not amplified")
	check(primary.status.shock_remaining > 0 and chained.status.shock_remaining > 0, "direct and chain apply shock")
	near(hit(primary), 33.0, "only E amplified on next direct")
	near(chained.max_health - chained.health, 33.0, "chain source not amplified recursively")
	primary.status.tick(0.5)
	primary.status.apply_shock(skill, 1)
	near(primary.status.shock_bonus, 0.2, "refresh retains original shock potency")
	near(primary.status.shock_remaining, 2.0, "refresh duration only")
	for element: String in ["fire", "ice", "dark", "lightning"]:
		var before := primary.health
		arena.deal_element_damage(primary, 10.0, element)
		near(before - primary.health, 12.0, "all derived E amplified exactly once")
	primary.status.tick(2.0)
	near(hit(primary), 30.0, "shock expiration restores damage")
	arena.apply_ranks({"element_type": "ice", "enchant_rank": 3, "element_skill_rank": 3})
	check(primary.status.shock_remaining == 0 and chained.status.shock_remaining == 0, "switch clears shock")
	for i in range(3): hit(primary)
	var saved_frozen := primary.status.frozen_remaining
	arena.deal_element_damage(primary, 1.0, "ice")
	near(primary.status.frozen_remaining, saved_frozen, "derived ice cannot consume freeze")
	arena.apply_ranks({"element_type": "fire", "enchant_rank": 3, "element_skill_rank": 3})
	check(not primary.status.is_frozen(), "switch clears freeze")
	arena.free()
	await process_frame
	print("ICE SHATTER / SHOCK: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
