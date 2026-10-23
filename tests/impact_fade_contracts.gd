extends SceneTree
## Real production event paths: no synthetic duplicate health or death rules.
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.player.invulnerable = false
	arena.set_sound_enabled(false)
	arena.stats.shields = 3
	var hp := arena.stats.hp
	for i in range(3):
		arena.player.receive_hit(999)
		check(arena.stats.shields == 2-i and arena.stats.hp == hp, "each accepted hit consumes one shield without health damage")
		check(arena.feedback.event_counts.get("shield_break",0) == i+1, "one visual event per shield including final shield")
		arena.player.receive_hit(999)
		check(arena.feedback.event_counts.get("shield_break",0) == i+1, "iframe rejects repeated shield effect")
		check(is_equal_approx(arena.player.health_state.invulnerability, arena.stats.hit_immunity), "shield immunity duration unchanged")
		arena.player.health_state.tick(arena.stats.hit_immunity)
	arena.player.receive_hit(1)
	check(arena.feedback.event_counts.shield_break == 3, "unshielded health damage has no shield burst")
	arena.feedback.clear()
	for kind in ["mob","ranged","swiftfang","elite_hornling","mountainbreaker","beastcaller","wildfire"]:
		var enemy := arena.spawn_enemy(kind, Vector2(420,320))
		var position_before := enemy.global_position
		var kills_before := arena.kills
		var rng_before := arena.rng.state
		enemy.receive_damage(enemy.health + 1)
		check(enemy.is_dead and enemy.is_queued_for_deletion(), kind+" dies immediately")
		check(arena.kills == kills_before+1, kind+" credits exactly once")
		check(arena.feedback.visuals.get_child_count() == 1, kind+" produces one independent death smoke")
		var smoke: FeedbackVisual = arena.feedback.visuals.get_child(0)
		check(smoke._atlas_key() == &"death_smoke" and smoke.color == arena.feedback.definition.death_color, kind+" shares neutral smoke not element/actor fragments")
		check(smoke.position == position_before and smoke.get_child_count() == 0, kind+" smoke has no actor/collision children")
		check(arena.rng.state == rng_before, kind+" death cosmetics do not advance combat RNG")
		enemy.receive_damage(9999)
		check(arena.kills == kills_before+1, kind+" duplicate lethal callback is harmless")
		smoke._process(smoke.duration+0.01)
		check(smoke.is_queued_for_deletion(), kind+" expires without actor lifetime dependency")
		arena.clear_enemies()
	var count_before := int(arena.feedback.event_counts.get("kill",0))
	for i in range(40): arena.spawn_enemy("mob", Vector2(350+i,300))
	arena.clear_enemies()
	check(arena.feedback.event_counts.kill == count_before and arena.feedback.visuals.get_child_count() == 0,"despawn/reset does not spray death effects")
	for i in range(40):
		var enemy := arena.spawn_enemy("mob",Vector2(350+i,300))
		enemy.receive_damage(enemy.health+1)
	check(arena.feedback.visuals.get_child_count() <= arena.feedback.definition.death_limit,"same-frame mass deaths respect smoke budget")
	check(arena.feedback.dropped_visuals > 0,"mass-death overload drops only cosmetics")
	arena.clear_enemies()
	check(arena.feedback.visuals.get_child_count() == 0,"scene cleanup removes all smoke immediately")
	var malformed := HitFeedbackDefinition.new()
	malformed.death_duration = INF
	malformed.shield_break_duration = NAN
	malformed.death_size_factor = 10000
	malformed.shield_size_factor = -5
	var safe := malformed.validated_copy()
	check(safe.death_duration <= 0.7 and safe.shield_break_duration <= 0.5 and safe.death_size_factor <= 4 and safe.shield_size_factor >= 1,"asset scale and duration remain bounded")
	var isolated := FeedbackController.new()
	root.add_child(isolated)
	isolated.shield_break(Vector2(100,100),16)
	var paused_visual: FeedbackVisual = isolated.visuals.get_child(0)
	var before_pause := paused_visual.remaining
	paused = true
	await create_timer(0.04, true).timeout
	check(paused_visual.remaining == before_pause,"pause freezes independent shield animation clock")
	paused = false
	await process_frame
	await process_frame
	check(paused_visual.remaining < before_pause,"unpause resumes independent animation clock")
	isolated.queue_free()
	arena.queue_free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("IMPACT FADE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
