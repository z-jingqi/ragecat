extends SceneTree
## Engine-driven deterministic encounter fixtures, not human-survival calibration.
## Practice invulnerability isolates lifecycle/caps and records attempted damage.
var failures := 0
var checks := 0
var arena: RageArena
var active_boss: BossActor
var elapsed := 0.0
var phases_seen: Dictionary = {}
var attempts := 0
var attempted_damage := 0.0
var peak_mobs := 0
var peak_hazards := 0
var fixtures := ["mountainbreaker", "beastcaller", "wildfire"]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for identity in fixtures:
		for phase in [1,2]:
			game.start_run(true)
			arena = game.arena
			arena.bow.enabled = false
			arena.set_enemy_ai(true)
			arena.practice_boss_phase = phase
			active_boss = arena.spawn_enemy(identity,arena.bounds.get_center()+Vector2(250,0))
			active_boss.choice_rng.seed = 7319 + phase
			active_boss.attack_player.connect(func(damage: float) -> void:
				attempts += 1
				attempted_damage += damage)
			elapsed = 0.0
			attempts = 0
			attempted_damage = 0
			peak_mobs = 0
			peak_hazards = 0
			phases_seen = {}
			while elapsed < 90.0:
				await physics_frame
				elapsed += 1.0 / Engine.physics_ticks_per_second
				var direction := Vector2.from_angle(elapsed * 0.3)
				Input.action_press("move_right",maxf(0,direction.x))
				Input.action_press("move_left",maxf(0,-direction.x))
				Input.action_press("move_down",maxf(0,direction.y))
				Input.action_press("move_up",maxf(0,-direction.y))
				phases_seen[active_boss.state] = true
				peak_mobs = maxi(peak_mobs,arena.enemies.get_child_count())
				peak_hazards = maxi(peak_hazards,active_boss.get_child_count())
				if not active_boss.position.is_finite(): check(false,"finite boss position"); break
			check(peak_mobs <= arena.definition.enemy_limit,"encounter respects mob cap")
			check(arena.enemy_bullets.get_child_count() <= arena.definition.enemy_projectile_limit,"projectile cap")
			check(active_boss.phase_number == phase,"forced phase remains stable")
			if identity == "mountainbreaker": check(phases_seen.has("charge") and phases_seen.has("rocks"),"both mountainbreaker patterns")
			elif identity == "beastcaller": check(phases_seen.has("summon") and phases_seen.has("projectile"),"both beastcaller patterns")
			else: check(phases_seen.has("skyfire_wait") and phases_seen.has("ring_warning"),"both wildfire patterns")
			print("ENCOUNTER ",identity," phase=",phase," simulated=",elapsed," states=",phases_seen.keys()," hit_attempts=",attempts," direct_hazard_damage_only=",attempted_damage," peak_mobs=",peak_mobs," peak_owned_nodes=",peak_hazards)
			arena.clear_enemies()
			await process_frame
			check(arena._reserved_summon_count() == 0,"clear cancels reservations")
			check(arena.enemy_bullets.get_child_count() == 0,"clear removes projectiles")
	for action in ["move_right","move_left","move_down","move_up"]: Input.action_release(action)
	game.queue_free()
	await process_frame
	print("BOSS ENCOUNTER SMOKE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
