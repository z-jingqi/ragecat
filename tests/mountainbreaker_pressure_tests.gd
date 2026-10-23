extends SceneTree
## Authored encounter pressure, not a claim about human difficulty or win rate.
const DT := 1.0 / 60.0
const SCENE := preload("res://scenes/bosses/mountainbreaker/mountainbreaker.tscn")
var checks := 0
var failures := 0
var world: Node2D
var player: Archer

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func make_boss(legacy := false) -> Mountainbreaker:
	var boss := SCENE.instantiate() as Mountainbreaker
	world.add_child(boss)
	boss.set_physics_process(false)
	boss.target = player
	boss.arena_bounds = Rect2(0, 0, 1280, 800)
	boss.attack_player.connect(player.receive_hit)
	if legacy:
		boss.warning_duration = 1.0
		boss.charge_width = 80.0
		boss.charge_speed = 680.0
		boss.recovery_duration = 1.15
		boss.rock_radius = 35.0
		boss.rock_count = 5
		boss.rock_min_warning_duration = 0.7
		boss.rock_warning_offset = 0.3
		boss.rock_recovery_delay = 0.3
	return boss

func reset_player(at: Vector2) -> void:
	player.position = at
	player.stats.hp = player.stats.max_hp
	player.stats.shields = 0
	player.health_state.invulnerability = 0.0
	player.dash_left = 0.0
	player.dash_cooldown = 0.0

func charge_probe(legacy: bool, response: float, use_dash := false, gap := 300.0) -> float:
	reset_player(Vector2(300 + gap, 400))
	var boss := make_boss(legacy)
	boss.position = Vector2(300, 400)
	boss.charges_remaining = 1
	boss._start_charge_warning()
	var dashed := false
	for step in range(180):
		var time := step * DT
		if use_dash and not dashed and time >= response:
			player.dash_direction = Vector2.UP
			player.dash_left = player.stats.dash_duration
			player.dash_cooldown = player.stats.dash_cooldown_duration
			dashed = true
		player._physics_process(DT)
		if not use_dash and time >= response:
			player.position.y -= player.stats.move_speed * DT
		boss._physics_process(DT)
		if boss.state == "recovery": break
	var damage := player.stats.max_hp - player.stats.hp
	boss.free()
	return damage

func rock_probe(legacy: bool, response: float, use_dash := false, phase := 1) -> float:
	reset_player(Vector2(640, 400))
	var boss := make_boss(legacy)
	boss.position = Vector2(200, 400)
	boss.force_phase_for_practice(phase)
	# Isolate one telegraphed circle, avoiding incidental neighbours in this reaction probe.
	boss.rock_count = 1
	boss.current_phase().tracking_rock_count = 1
	boss._start_rocks()
	var rock := boss.rocks[0]
	rock.set_physics_process(false)
	var dashed := false
	for step in range(110):
		var time := step * DT
		if use_dash and not dashed and time >= response:
			player.dash_direction = Vector2.UP
			player.dash_left = player.stats.dash_duration
			player.dash_cooldown = player.stats.dash_cooldown_duration
			dashed = true
		player._physics_process(DT)
		if not use_dash and time >= response: player.position.y -= player.stats.move_speed * DT
		rock._physics_process(DT)
		if rock.is_queued_for_deletion(): break
	var damage := player.stats.max_hp - player.stats.hp
	boss.free()
	return damage

func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	player = Archer.new()
	player.setup(preload("res://resources/characters/archer.tres").create_stats())
	player.arena_bounds = Rect2(0, 0, 1280, 800)
	world.add_child(player)
	player.set_physics_process(false)
	player.movement_enabled = false
	check(is_equal_approx(player.stats.dash_cooldown_duration, 2.0), "dash cooldown unchanged")
	var arena := preload("res://resources/settings/arena.tres")
	var authored := make_boss()
	check(authored.warning_duration == arena.boss_warning_duration and authored.charge_width == arena.boss_charge_width and authored.rock_radius == arena.boss_rock_radius, "arena and authored practice encounter use same geometry")
	check(authored.charge_distance == 940.0 and authored.attack_damage == 22.0 and authored.rock_damage_multiplier == 0.8, "range and damage unchanged")
	check(authored.current_phase().charge_count == 1, "first phase one charge")
	authored.force_phase_for_practice(2)
	check(authored.current_phase().charge_count == 3 and authored.current_phase().repeat_charge_warning >= 0.3, "three repeated charges keep readable warning")
	check(authored.current_phase().tracking_rock_interval == 0.5 and authored.current_phase().tracking_rock_count == 8, "tracking sequence count/cadence unchanged")
	check(is_equal_approx(authored.current_phase().tracking_rock_recovery + authored.recovery_duration, 1.05), "tracking end recovery reduced without a hidden second long pause")
	authored.free()
	var old_charge := charge_probe(true, 0.9)
	var new_charge := charge_probe(false, 0.9)
	print("PRESSURE charge delayed walk old/new damage: ", old_charge, "/", new_charge)
	check(old_charge == 0.0 and new_charge > 0.0, "late perpendicular walk no longer gets former large warning grace")
	check(charge_probe(false, 0.25) == 0.0, "timely walking still evades first charge")
	check(charge_probe(false, 0.9, true) == 0.0, "late dash avoids new charge using actual player immunity/motion")
	for gap in [40.0, 100.0, 300.0, 800.0]:
		check(charge_probe(false, 0.2, false, gap) == 0.0, "base speed timely walking at gap %s" % gap)
	var old_rock := rock_probe(true, 0.7)
	var new_rock := rock_probe(false, 0.7)
	print("PRESSURE rock delayed walk old/new damage: ", old_rock, "/", new_rock)
	check(old_rock == 0.0 and new_rock > 0.0, "late rock response has less excessive grace")
	check(rock_probe(false, 0.2) == 0.0, "timely walking escapes first-phase circle")
	check(rock_probe(false, 0.7, true) == 0.0, "late dash escapes first-phase circle")
	check(rock_probe(false, 0.15, false, 2) == 0.0, "tracking circle still walkable without repeated dashes")
	check(rock_probe(false, 0.5, true, 2) == 0.0, "dash can rescue late tracking response")
	# An immediate base-speed escape must exist even when the random cluster is near a wall.
	for at in [Vector2(640,400), Vector2(16,16), Vector2(1264,16), Vector2(16,784), Vector2(1264,784), Vector2(640,16)]:
		for seed_value in [1, 42, 7319, 38117]:
			reset_player(at)
			var boss := make_boss()
			boss.position = Vector2(400,300)
			boss.rock_rng.seed = seed_value
			boss._start_rocks()
			check(boss.rocks.size() <= 7 and boss.rocks.size() > 0, "bounded authored cluster")
			var escape_found := false
			for angle_index in range(64):
				var move := Vector2.from_angle(angle_index * TAU / 64.0)
				var destination: Vector2 = (at + move * player.stats.move_speed * (boss.rocks[0].warning_duration - 0.15)).clamp(Vector2(16,16), Vector2(1264,784))
				var safe := true
				for hazard in boss.rocks:
					if destination.distance_to(hazard.global_position) <= hazard.radius + player.radius: safe = false
				if safe: escape_found = true
			check(escape_found, "cluster admits 150ms reaction base-speed escape at %s seed%s" % [at,seed_value])
			boss.free()
	# Three-charge walking policies at centre and corners, without consuming any dash.
	for at in [Vector2(700,400),Vector2(80,80),Vector2(1200,80),Vector2(80,720),Vector2(1200,720)]:
		reset_player(at)
		var combo := make_boss()
		combo.position = Vector2(640,400)
		combo.force_phase_for_practice(2)
		combo.ability_mode = "charge"
		combo.phase_time = 0.0
		var warning_count := 0
		var previous_state := ""
		var move_direction := Vector2.ZERO
		var response_time := 0.0
		for step in range(900):
			combo._physics_process(DT)
			if combo.state == "warning" and previous_state != "warning":
				warning_count += 1
				response_time = 0.1
				var side := combo.charge_direction.orthogonal()
				var a := (player.position + side * 180.0).clamp(Vector2(16,16),Vector2(1264,784))
				var b := (player.position - side * 180.0).clamp(Vector2(16,16),Vector2(1264,784))
				move_direction = side if player.position.distance_to(a) >= player.position.distance_to(b) else -side
			previous_state = combo.state
			player._physics_process(DT)
			response_time -= DT
			if combo.state in ["warning", "charge"] and response_time <= 0.0:
				player.position = (player.position + move_direction * player.stats.move_speed * DT).clamp(Vector2(16,16),Vector2(1264,784))
			if combo.state == "recovery" and warning_count == 3: break
		check(warning_count == 3 and player.stats.hp == player.stats.max_hp, "three-charge sequence walkable without dash spam at %s" % at)
		check(combo.arena_bounds.grow(-combo.radius + 0.01).has_point(combo.position), "combo stays within walls")
		combo.free()
	world.free()
	await process_frame
	print("Mountainbreaker pressure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
