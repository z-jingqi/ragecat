extends SceneTree
## Canonical upgrade selection, no direct mutation to emulate an upgrade.
var arena: RageArena
var checks := 0
var failures := 0
var transitions := 0
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.001, "%s: actual=%s expected=%s" % [label, actual, expected])
func reset(element: String, rank: int, skill: int) -> void:
	arena.clear_enemies()
	arena.apply_ranks({"element_type": element, "enchant_rank": rank, "element_skill_rank": skill})
func switch_matrix() -> void:
	for from: String in ELEMENTS:
		for to: String in ELEMENTS:
			if from == to: continue
			for rank in range(1, 4):
				for skill in range(4):
					transitions += 1
					reset(from, rank, skill)
					var label := "%s to %s enchant%d skill%d" % [from, to, rank, skill]
					for repeat in range(3):
						arena.select_upgrade(to + "_enchant")
						check(arena.stats.active_element == to, label + " active type changes")
						near(arena.stats.element_damage, rank * 5.0, label + " inherited enchant rank")
						check(arena.stats.element_skill_rank == skill, label + " inherited shared skill rank, no free skill")
						check(arena.stats.ranks.get("enchant_rank", -1) == rank, label + " no free level on switch")
						arena.select_upgrade(from + "_enchant")
						near(arena.stats.element_damage, rank * 5.0, label + " roundtrip retains level")
						check(arena.stats.element_skill_rank == skill, label + " roundtrip retains skill")
					var offers := arena.stats.catalog.eligible(arena.stats.ranks)
					check(offers.has(from + "_enchant") == (rank < 3), label + " current card caps")
					for other: String in ELEMENTS:
						if other != from: check(offers.has(other + "_enchant"), label + " switch remains possible to " + other)
					if rank < 3:
						arena.select_upgrade(from + "_enchant")
						near(arena.stats.element_damage, (rank + 1) * 5.0, label + " same type raises shared rank once")
						check(arena.stats.element_skill_rank == skill, label + " enchant rankup never grants skill")
	check(transitions == 144, "all12 ordered pairs x3 enchant ranks x4 skill ranks")

func transition_cleanup() -> void:
	reset("ice", 2, 3)
	var enemy := arena.spawn_enemy("dummy", Vector2(600, 350))
	enemy.max_health = 10000.0
	enemy.health = 10000.0
	arena.player.position = Vector2(450, 350)
	arena.bow.shoot()
	var source: CatArrow = arena.arrows.get_child(0)
	source._physics_process(170.0 / source.speed)
	check(enemy.status.movement_multiplier() < 1.0, "cleanup setup actually applied ice")
	arena.bow.shoot()
	check(arena.bow.active_count(false) > 0, "cleanup setup has live arrows")
	arena.bow.burst_remaining = 2
	arena.bow.attack_clock = 0.713
	arena.stats.hp = 50.0
	arena.xp = 9.0
	arena.bow.gravity_gap_remaining = 1.75
	var health_before := enemy.health
	var enemies_before := arena.enemies.get_child_count()
	var bullet := Node2D.new()
	arena.enemy_bullets.add_child(bullet)
	arena.select_upgrade("dark_enchant")
	check(arena.bow.active_count(false) == 0 and arena.bow.active_count(true) == 0, "switch clears active arrows and fragments")
	check(arena.bow.burst_remaining == 0, "switch cancels queued old element volley")
	near(arena.bow.attack_clock, 0.713, "switch cannot reset attack cooldown")
	near(arena.bow.gravity_gap_remaining, 1.75, "switch preserves shared dark cooldown")
	near(enemy.status.movement_multiplier(), 1.0, "switch clears ice control")
	check(not enemy.status.is_frozen(), "switch clears freeze")
	near(enemy.health, health_before, "switch preserves enemy health")
	check(arena.enemies.get_child_count() == enemies_before, "switch preserves enemies")
	check(is_instance_valid(bullet) and not bullet.is_queued_for_deletion(), "switch preserves enemy bullets")
	near(arena.stats.hp, 50.0, "switch preserves player hp")
	near(arena.xp, 9.0, "switch preserves xp")
	arena.select_upgrade("fire_enchant")
	arena.select_upgrade("dark_enchant")
	near(arena.bow.gravity_gap_remaining, 1.75, "switch away/back cannot bypass void cooldown")
	arena.bow._physics_process(0.0)
	check(arena.bow.active_count(false) == 0, "no queued volley survives switch")

func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	switch_matrix()
	transition_cleanup()
	arena.free()
	print("ELEMENT SWITCH CONTRACTS: %d transitions, %d checks, %d failures" % [transitions, checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
