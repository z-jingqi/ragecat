extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena: RageArena = game.arena
	var player: CatPlayer = arena.player
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	await process_frame
	key(true)
	player._physics_process(0.0)
	check(player.dash_left == 0.2 and player.dash_cooldown == 2.0, "Physical Space press starts 0.2s dash and 2s cooldown together")
	await process_frame
	key(false)
	key(true)
	player._physics_process(0.1)
	check(is_equal_approx(player.dash_left,0.1) and is_equal_approx(player.dash_cooldown,1.9), "Repeated Space cannot reset active dash or bypass cooldown")
	await process_frame
	key(true,true)
	player._physics_process(0.1)
	check(player.dash_left <= 0.00001 and is_equal_approx(player.dash_cooldown,1.8), "Keyboard echo does not extend dash")
	await process_frame
	player._physics_process(1.81)
	check(player.dash_left == 0.0 and player.dash_cooldown == 0.0, "Holding Space through cooldown does not auto-dash")
	key(false)
	await process_frame
	key(true)
	player._physics_process(0.0)
	check(player.dash_left == 0.2 and player.dash_cooldown == 2.0, "Fresh press after cooldown starts a new dash")
	key(false)
	await process_frame
	player._physics_process(1.999)
	key(true)
	player._physics_process(0.0)
	check(player.dash_left == 0.0 and player.dash_cooldown > 0.0, "Space at 1.999s cannot bypass 2s cooldown")
	key(false)
	await process_frame
	player._physics_process(0.002)
	key(true)
	player._physics_process(0.0)
	check(player.dash_left == 0.2, "New press after 2 seconds is accepted")
	key(false)
	await process_frame
	game.update_hud()
	var dash_label: Label = game.get("dash_label") as Label
	check(dash_label != null and "2.0s" in dash_label.text, "HUD clearly shows remaining dash cooldown")
	player._physics_process(2.0)
	game.update_hud()
	check(dash_label != null and "READY" in dash_label.text, "HUD clearly shows dash READY")
	player.movement_enabled = false
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = 1.0
	await physics_frame
	await physics_frame
	player.dash_cooldown = 2.0
	for i in range(12): await physics_frame
	var normal_elapsed := 2.0 - player.dash_cooldown
	Engine.time_scale = 0.25
	await physics_frame
	await physics_frame
	player.dash_cooldown = 2.0
	for i in range(12): await physics_frame
	var slow_elapsed := 2.0 - player.dash_cooldown
	check(normal_elapsed > 0.15 and normal_elapsed < 0.23 and slow_elapsed > 0.045 and slow_elapsed < 0.055, "Dash cooldown follows normal/quarter-speed game time")
	paused = true
	var before := player.dash_cooldown
	for i in range(12): await process_frame
	check(is_equal_approx(player.dash_cooldown,before), "Pause freezes dash cooldown")
	paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame
	print("DASH COOLDOWN: %d checks, %d failures; engine delta normal=%.6f slow=%.6f" % [checks,failures,normal_elapsed,slow_elapsed])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
