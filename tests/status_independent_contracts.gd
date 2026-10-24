extends SceneTree
## Independent swept-collision and victim-side status contracts.
var arena: RageArena
var checks := 0
var failures := 0
var events := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("STATUS CONTRACT: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.02, "%s actual=%s expected=%s" % [label, actual, expected])
func setup(element: String, rank := 3, extra: Dictionary = {}) -> void:
	if is_instance_valid(arena): arena.free()
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var ranks := {"element_type": element, "enchant_rank": 3, "element_skill_rank": rank}
	ranks.merge(extra, true)
	arena.apply_ranks(ranks)
	arena.stats.crit_chance = 0.0
	arena.stats.knockback = 0.0
	arena.rng.seed = 20261022
	arena.player.position = Vector2(300, 350)
	events = 0
func target(at := Vector2(600, 350), kind := "dummy") -> EnemyActor:
	var enemy := arena.spawn_enemy(kind, at)
	enemy.position = at
	enemy.radius = 3
	enemy.max_health = 100000
	enemy.health = enemy.max_health
	enemy.damaged.connect(func(_amount: float, _crit: bool, _at: Vector2) -> void: events += 1)
	return enemy
func collision(enemy: EnemyActor, secondary := false, scale := 1.0) -> float:
	var arrow := BowArrow.new()
	arrow.position = enemy.position - Vector2(30, 0)
	arrow.direction = Vector2.RIGHT
	arrow.enemies = arena.enemies
	arrow.arena_bounds = arena.bounds
	arrow.secondary = secondary
	arrow.damage_scale = scale
	arrow.enemy_hit.connect(arena.bow._relay_arrow_hit)
	arena.arrows.add_child(arrow)
	var before := enemy.health
	arrow._physics_process(40.0 / arrow.speed)
	return before - enemy.health
func burn(enemy: EnemyActor) -> BurnEffect:
	return arena.element_procs.burns.get(enemy.get_instance_id()) as BurnEffect
func sure_procs() -> void:
	arena.stats.element_skill.burn_chance_by_rank = PackedFloat32Array([0, 1, 1, 1])
	arena.stats.element_skill.shock_chance_by_rank = PackedFloat32Array([0, 1, 1, 1])
func ice_atomic() -> void:
	for rank in range(1, 4):
		setup("ice", rank)
		var enemy := target()
		for i in range(3): near(collision(enemy, i == 1), 30, "three ordinary collision packets")
		near(enemy.status.frozen_remaining, arena.stats.element_skill.parameter(arena.stats.element_skill.freeze_by_rank, rank), "freeze duration by rank")
		var prior := events
		var accounting := arena.total_damage
		var popup_count := arena.effects.get_child_count()
		arena.stats.combat_definition.total_crit_chance_cap = 1.0 # Isolate critical damage formula, not production chance.
		arena.stats.crit_chance = 1
		near(collision(enemy), 120, "atomic crit x shatter")
		check(events == prior + 1 and arena.crits == 1, "one HP signal and one crit for B+E")
		near(arena.total_damage - accounting, 120, "shatter accounting once")
		check(arena.effects.get_child_count() == popup_count + 2, "atomic packet produces exactly B and E popups")
		var base_popup := arena.effects.get_child(popup_count) as FloatingText
		var element_popup := arena.effects.get_child(popup_count + 1) as FloatingText
		check(base_popup.critical and element_popup.critical and base_popup.damage_kind == "base" and element_popup.element_type == "ice", "paired shatter crit popup typing")
		near(base_popup.displayed_amount + element_popup.displayed_amount, 120, "popup sum matches atomic HP loss")
		check(enemy.status.frost_stacks == 0 and not enemy.status.is_frozen(), "consumed hit does not rebuild frost")
		near(enemy.status.immunity_remaining, 2, "early thaw immunity")
		near(collision(enemy, true), 60, "same-frame second secondary can crit but cannot consume shatter twice")
		enemy.status.tick(2)
		arena.stats.crit_chance = 0
		for i in range(3): collision(enemy)
		near(collision(enemy, true, 0.6), 36, "secondary doubles its complete scaled B+E")
	setup("ice")
	var enemy := target()
	collision(enemy)
	near(enemy.status.movement_multiplier(), 0.8, "ordinary chill twenty percent")
	enemy.status.tick(2)
	collision(enemy)
	check(enemy.status.frost_stacks == 1, "expired frost stack cannot combine")
	collision(enemy)
	collision(enemy)
	var frozen := enemy.status.frozen_remaining
	arena.deal_element_damage(enemy, 7, "fire")
	near(enemy.status.frozen_remaining, frozen, "derived damage cannot consume freeze")
	enemy.status.tick(frozen + 0.1)
	near(enemy.status.immunity_remaining, arena.stats.element_skill.thaw_immunity - 0.1, "coarse natural thaw integrates immunity")
	setup("ice")
	var boss := target(Vector2(600, 350), "boss")
	for i in range(5): near(collision(boss), 30, "boss formation hit not doubled")
	check(boss.status.has_ice_mark() and not boss.status.is_frozen(), "boss mark never freezes")
	near(boss.status.movement_multiplier(), 0.9, "boss chill ten percent")
	arena.deal_element_damage(boss, 7, "lightning")
	check(boss.status.has_ice_mark(), "derived damage cannot consume boss mark")
	near(collision(boss), 60, "sixth boss collision consumes")
	check(boss.status.frost_stacks == 0 and boss.status.immunity_remaining == 0, "boss consumption no restack or immunity")
	for i in range(5): collision(boss)
	boss.status.tick(2)
	near(collision(boss), 30, "expired mark does not double")
func modes() -> void:
	# Use real bow-generated fan and burst arrows, not flags alone.
	for element: String in ["ice", "fire", "lightning"]:
		setup(element, 3, {"spread_arrow": 3, "burst": 3, "pierce": 3})
		sure_procs()
		var bait := target(Vector2(400, 350))
		arena.bow._physics_process(0)
		arena.bow.attack_clock = 100
		arena.bow._physics_process(1)
		bait.free()
		var primaries := arena.arrows.get_children()
		check(primaries.size() == arena.stats.burst_count * arena.stats.spread_arrow_count, element + " creates complete burst/fan")
		for arrow: BowArrow in primaries:
			var enemy := target(arrow.position + arrow.direction * 45)
			arrow._physics_process(50.0 / arrow.speed)
			check(enemy.status.frost_stacks == 1 if element == "ice" else (burn(enemy) != null if element == "fire" else enemy.status.shock_remaining > 0), element + " every burst/fan collision eligible")
			enemy.free()
		check(arena.bow.active_count(true) == 0, element + " impacts create no projectiles")
	# Fire intentionally stops on first direct; ice/lightning retain penetration.
	for element: String in ["ice", "lightning"]:
		setup(element, 3, {"pierce": 3})
		sure_procs()
		var first := target(Vector2(400, 350))
		var second := target(Vector2(470, 350))
		arena.bow.shoot()
		var arrow := arena.arrows.get_child(0) as BowArrow
		arrow._physics_process(200.0 / arrow.speed)
		check(arrow.hit_ids.size() == 2, element + " actual penetration two direct collisions")
		check(first.status.frost_stacks == 1 and second.status.frost_stacks == 1 if element == "ice" else first.status.shock_remaining > 0 and second.status.shock_remaining > 0, element + " later penetration eligible")
func proc_and_clock_contracts() -> void:
	for element: String in ["fire", "lightning", "ice"]:
		setup(element, 0)
		var enemy := target()
		for i in range(8): collision(enemy)
		check(burn(enemy) == null and enemy.status.shock_remaining == 0 and enemy.status.frost_stacks == 0 and not enemy.status.is_frozen(), element + " enchant alone has no status")
	for element: String in ["fire", "lightning"]:
		setup(element)
		arena.stats.element_skill.burn_chance_by_rank = PackedFloat32Array([0, 0, 0, 0])
		arena.stats.element_skill.shock_chance_by_rank = PackedFloat32Array([0, 0, 0, 0])
		var enemy := target()
		for i in range(12): collision(enemy)
		check(burn(enemy) == null and enemy.status.shock_remaining == 0, element + " zero proc probability")
	setup("lightning")
	sure_procs()
	var enemy := target()
	var chained := target(Vector2(650, 350))
	near(collision(enemy), 30, "triggering shock is not retroactive")
	near(chained.max_health - chained.health, 15, "triggering chain not retroactive")
	near(collision(enemy), 33, "shock increases only incoming E")
	near(chained.max_health - chained.health, 33, "source E not contaminated by victim shock")
	check(arena.element_procs.proc_counts.lightning == 2, "chains never recurse")
	setup("fire")
	sure_procs()
	enemy = target()
	collision(enemy)
	var state := burn(enemy)
	arena.element_procs._physics_process(0.1)
	collision(enemy, true, 0.1)
	check(state == burn(enemy), "refresh retains burn identity")
	near(state.dps, 6, "refresh retains immutable source snapshot")
	near(state.accrued, 0.1, "refresh preserves clock phase")
	var before := enemy.health
	var proc_before := arena.element_procs.proc_counts.duplicate()
	var hit_before := arena.hits
	arena.element_procs._physics_process(10)
	near(before - enemy.health, 18.6, "coarse refresh integral includes exactly remaining lifetime")
	check(burn(enemy) == null and arena.hits == hit_before and arena.element_procs.proc_counts == proc_before, "DOT expires without hit/recursive proc")
	# Future combination: apply shock at victim, burn snapshot remains unboosted.
	collision(enemy)
	var shock := ElementSkillDefinition.new()
	enemy.status.apply_shock(shock, 3)
	before = enemy.health
	arena.element_procs._physics_process(0.25)
	near(before - enemy.health, 1.8, "burn tick E receives victim shock exactly once")
	near(burn(enemy).dps, 6, "victim shock never changes source snapshot")
	arena.apply_ranks({"ice_enchant": 3, "ice_bow": 3})
	check(burn(enemy) == null and enemy.status.shock_remaining == 0, "element switch cleans both status stores")
func lifecycle_and_validation() -> void:
	for element: String in ["fire", "lightning"]:
		setup(element)
		var enemy := target()
		var applications := 0
		for i in range(100):
			enemy.status.clear()
			arena.element_procs.burns.clear()
			collision(enemy)
			if burn(enemy) != null or enemy.status.shock_remaining > 0: applications += 1
		check(applications > 10 and applications < 70, element + " fixed-seed default probability exercises success and failure")
	setup("fire")
	sure_procs()
	var enemy := target()
	collision(enemy)
	var before := enemy.health
	for i in range(180): arena.element_procs._physics_process(1.0 / 60.0)
	near(before - enemy.health, 18, "fine frames integrate exactly three-second burn")
	check(burn(enemy) == null, "fine frames expire burn")
	collision(enemy)
	enemy.health = 0.5
	enemy.is_dummy = false # Ordinary enemy for kill/XP accounting; training dummies grant neither.
	arena.practice = false
	var pickups := arena.pickups.size()
	var kills := arena.kills
	var damage := arena.total_damage
	arena.element_procs._physics_process(10)
	check(enemy.is_dead and arena.kills == kills + 1 and arena.pickups.size() == pickups + 1, "DOT death counts kill and XP exactly once")
	near(arena.total_damage - damage, 0.5, "DOT accounting caps actual overkill HP")
	check(burn(enemy) == null, "dead target loses pending DOT")
	var popup := arena.effects.get_child(arena.effects.get_child_count() - 1) as FloatingText
	check(popup.element_type == "fire" and popup.damage_kind == "element" and not popup.critical, "lethal DOT has elemental F popup without crit")
	setup("fire")
	sure_procs()
	enemy = target()
	collision(enemy)
	arena.clear_enemies()
	check(arena.element_procs.burns.is_empty(), "reset clears burn store")
	var definition := ElementSkillDefinition.new()
	definition.burn_duration = NAN
	definition.burn_tick_interval = -1
	definition.shock_duration = INF
	definition.burn_chance_by_rank = PackedFloat32Array([0, -1, NAN, 20])
	definition.shock_bonus_by_rank = PackedFloat32Array([0, NAN, -1, 0.2])
	var valid := definition.validated_copy()
	check(is_finite(valid.burn_duration) and is_finite(valid.shock_duration) and valid.burn_tick_interval > 0, "validation sanitizes nonfinite clocks")
	for chance in valid.burn_chance_by_rank: check(is_finite(chance) and chance >= 0 and chance <= 1, "validated chance bounded")
	for bonus in valid.shock_bonus_by_rank: check(is_finite(bonus) and bonus >= 0, "validated vulnerability finite nonnegative")
	var status := StatusEffects.new()
	status.apply_ice(valid, -1)
	status.apply_shock(valid, -1)
	check(status.frost_stacks == 0 and status.shock_remaining == 0, "invalid negative rank cannot apply status")
func pause_contract() -> void:
	setup("fire")
	sure_procs()
	var enemy := target()
	collision(enemy)
	var definition := ElementSkillDefinition.new()
	for i in range(3): enemy.status.apply_ice(definition, 3)
	enemy.status.apply_shock(definition, 3)
	var before := enemy.health
	var duration := burn(enemy).remaining
	var freeze := enemy.status.frozen_remaining
	var shock := enemy.status.shock_remaining
	arena.bow.enabled = false
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	for i in range(8): await process_frame
	near(enemy.health, before, "tree pause prevents DOT health loss")
	near(burn(enemy).remaining, duration, "tree pause preserves burn clock")
	near(enemy.status.frozen_remaining, freeze, "tree pause preserves freeze clock")
	near(enemy.status.shock_remaining, shock, "tree pause preserves shock clock")
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
func run() -> void:
	ice_atomic()
	modes()
	proc_and_clock_contracts()
	lifecycle_and_validation()
	await pause_contract()
	arena.free()
	await process_frame
	print("INDEPENDENT STATUS CONTRACTS: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
