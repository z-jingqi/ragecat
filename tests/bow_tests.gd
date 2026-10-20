extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.bow.set_physics_process(false)
	check(arena.bow.get_parent() == arena.player, "weapon is equipped as player child")
	check(arena.bow.scene_file_path == "res://scenes/weapons/bow.tscn", "weapon has independent scene")
	var dummy: EnemyActor = arena.spawn_enemy("dummy", arena.player.position + Vector2(150, 0))
	check(arena.bow.nearest_enemy() == dummy, "weapon acquires enemy")
	arena.bow.shoot()
	check(arena.arrows.get_child_count() == 1, "base weapon spawns one arrow")
	var arrow: CatArrow = arena.arrows.get_child(0) as CatArrow
	var before: float = dummy.health
	arrow.enemy_hit.emit(arrow, dummy)
	check(dummy.health < before and arena.hits == 1, "weapon relays hit to combat resolution")
	arena.apply_ranks({"spread_arrow": 3})
	var arrows_before: int = arena.arrows.get_child_count()
	arena.bow.shoot()
	check(arena.arrows.get_child_count() - arrows_before == 7, "equipped weapon reads live upgrades")
	arena.bow.enabled = false
	arena.bow.attack_clock = 0.0
	arrows_before = arena.arrows.get_child_count()
	arena.bow._physics_process(0.2)
	check(arena.arrows.get_child_count() == arrows_before, "disabled weapon does not fire")
	arena.free()
	print("BOW TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
