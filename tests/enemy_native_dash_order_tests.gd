extends SceneTree
class ProbeBullet extends EnemyBullet:
	var task: SceneTree
	func consume() -> void:
		if not consumed: task.call("record_bullet_contact")
		super.consume()
var arena: RageArena
var boss: Mountainbreaker
var ring: BossFireRing
var bullet: ProbeBullet
var expected_input_frame := -1
var bullet_frame := -1
var ring_frame := -1
var boss_frame := -1
var bullet_contacts := 0
var ring_contacts := 0
var boss_contacts := 0
var negative_control := false
var accepted_hits := 0
var checks := 0
var failures := 0
func _initialize() -> void:
	negative_control = "--negative-control" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE DASH ORDER FAIL: " + label)
func advance(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func record_bullet_contact() -> void:
	bullet_contacts += 1
	bullet_frame = Engine.get_physics_frames()
func arm_input() -> void:
	# Input.action_press stamps physics_frames+1 in Godot. Inject between
	# physics callbacks, not inside a physics callback that would be too late.
	expected_input_frame = Engine.get_physics_frames() + 1
	Input.action_press("dash")
	if is_instance_valid(bullet): bullet.ai_enabled = true
	if is_instance_valid(ring): ring.ai_enabled = true
func run() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	arena = RageArena.new()
	arena.practice = true
	arena.lab_ai = false
	arena.run_seed_override = 0
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.bow.enabled = false
	arena.player.invulnerable = false
	arena.stats.dash_grants_immunity = not negative_control
	arena.player.hit_received.connect(func(_amount: float) -> void: accepted_hits += 1)
	arena.player.position = Vector2(500, 400)
	arena.player.last_move = Vector2.LEFT
	check(is_equal_approx(arena.stats.dash_duration, 0.2) and is_equal_approx(arena.stats.dash_cooldown_duration, 2.0), "authored0.2s dash and2s cooldown remain unchanged")
	check(arena.player.process_physics_priority < -10 and arena.occupancy.process_physics_priority == -5, "player input precedes enemies, occupancy precedes ordinary damage")
	boss = arena.spawn_enemy("mountainbreaker", Vector2(470, 400)) as Mountainbreaker
	boss.ai_enabled = true
	boss.ability_mode = "charge"
	boss.attack_player.connect(func(_amount: float) -> void:
		boss_contacts += 1
		boss_frame = Engine.get_physics_frames())
	boss.charges_remaining = 1
	boss._start_charge_warning()
	bullet = ProbeBullet.new()
	bullet.task = self
	bullet.setup(arena.player.position, Vector2.RIGHT, arena.ranged_definition, arena.player)
	bullet.ai_enabled = false
	arena.enemy_bullets.add_child(bullet)
	ring = BossFireRing.new()
	ring.target = arena.player
	ring.arena_bounds = arena.bounds
	ring.position = Vector2(458, 400)
	ring.ai_enabled = false
	ring.hit.connect(func(amount: float) -> void:
		ring_contacts += 1
		ring_frame = Engine.get_physics_frames()
		arena.player.receive_hit(amount))
	arena.effects.add_child(ring)
	var guard := 0
	while boss.state == "warning" and guard < 120:
		await advance()
		guard += 1
	check(boss.state == "charge", "real warning prepares imminent attack")
	var hp := arena.stats.hp
	var shields := arena.stats.shields
	arm_input()
	await advance()
	Input.action_release("dash")
	check(arena.player.dash_left > 0.0, "Input.action_press is consumed in the intended next physics tick")
	print("DASH FRAME TRACE expected=", expected_input_frame, " boss=", boss_frame, " bullet=", bullet_frame, " ring=", ring_frame, " dash_left=", arena.player.dash_left, " boss_at=", boss.position, " player_at=", arena.player.position)
	check(boss_frame == expected_input_frame and bullet_frame == expected_input_frame and ring_frame == expected_input_frame, "all real attacks occur in the exact intended input physics frame")
	check(boss_contacts == 1 and bullet_contacts == 1 and ring_contacts == 1, "all three real attack sources reached player in the same input tick")
	if negative_control:
		check(arena.stats.hp < hp or arena.stats.shields < shields, "negative control same-frame sources cause real damage without dash immunity")
		check(accepted_hits == 1, "negative control shared damage iframe accepts exactly one of three contacts")
		print("NATIVE DASH NEGATIVE CONTROL: %d checks, %d failures" % [checks, failures])
		arena.free()
		await preload("res://tests/audio_teardown.gd").drain(self)
		quit(0 if failures == 0 else 1)
		return
	check(arena.stats.hp == hp and arena.stats.shields == shields, "same-tick dash blocks boss, enemy bullet and fire-ring damage without spending a shield")
	arena.clear_enemies()
	await advance(11)
	check(arena.player.dash_left > 0.0, "dash immunity remains active before the0.2s boundary")
	arena.player.receive_hit(1.0)
	check(arena.stats.hp == hp and arena.stats.shields == shields, "last full immunity tick still rejects damage")
	await advance()
	print("DASH BOUNDARY left=%.18f frames_since_input=%d" % [arena.player.dash_left, Engine.get_physics_frames() - expected_input_frame])
	check(arena.player.dash_left <= 0.0, "dash immunity ends at the configured fixed-step boundary, no residual extra tick")
	check(arena.player.dash_cooldown > 1.7 and arena.player.dash_cooldown < 1.9, "cooldown still counts from original2s input time")
	arena.player.receive_hit(1.0)
	check(arena.stats.hp < hp or arena.stats.shields < shields, "boundary tick accepts damage after dash immunity ends")
	await advance(107)
	check(arena.player.dash_cooldown > 0.0, "cooldown remains active one full tick before2s boundary")
	await advance()
	check(arena.player.dash_cooldown == 0.0, "cooldown arithmetic tail is zero at2s boundary")
	arena.player.dash_cooldown = 0.0
	arena.player.dash_left = 0.0
	var paused_at := arena.player.position
	paused = true
	Input.action_press("dash")
	await advance(3)
	check(arena.player.position == paused_at and arena.player.dash_left == 0.0, "paused input does not move or start dash")
	paused = false
	await advance()
	check(arena.player.dash_left == 0.0, "old paused press is not replayed after resume")
	Input.action_release("dash")
	arm_input()
	await advance()
	check(arena.player.dash_left > 0.0, "fresh post-resume press remains responsive")
	Input.action_release("dash")
	print("NATIVE DASH ORDER: %d checks, %d failures" % [checks, failures])
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
