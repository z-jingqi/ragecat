extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var malformed := HitFeedbackDefinition.new()
	malformed.direct_pause = 1000.0
	malformed.derived_pause = INF
	malformed.reaction_cooldown = -1.0
	malformed.flash_duration = INF
	malformed.knockback_duration = -1.0
	malformed.knockback_speed_cap = NAN
	malformed.visual_limit = 10000
	malformed.particles = 10000
	malformed.critical_particles = 10000
	var safe := malformed.validated_copy()
	check(safe.direct_pause <= 0.1 and safe.reaction_cooldown >= safe.direct_pause*4.0,"hostile pause resource preserves duty-cycle bound")
	check(is_finite(safe.flash_duration) and is_finite(safe.derived_pause) and is_finite(safe.knockback_speed_cap),"NaN/infinite feedback values become finite defaults")
	check(safe.knockback_duration >= 0.02 and safe.visual_limit == 128 and safe.particles == 16 and safe.critical_particles == 20,"hostile duration and work budgets are clamped")
	check(malformed.visual_limit == 10000 and malformed.knockback_duration == -1.0,"runtime validation never mutates authored resource")
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	var enemy := arena.spawn_enemy("mob", Vector2(400,300))
	enemy.health = 1000
	var invalid_origin := enemy.position
	enemy.knockback(Vector2(NAN, 0),45)
	enemy.knockback(Vector2.RIGHT,INF)
	enemy.knockback(Vector2.RIGHT,-2)
	enemy._physics_process(0.5)
	check(enemy.position == invalid_origin and enemy.knockback_remaining == 0.0,"non-finite/negative impulses are rejected")
	enemy.knockback(Vector2.RIGHT,45)
	enemy._physics_process(NAN)
	check(enemy.position == invalid_origin and enemy.knockback_remaining > 0,"invalid delta cannot poison or consume pending motion")
	enemy.clear_hit_reaction()
	var origin := enemy.position
	var event := FeedbackEvent.impact(FeedbackEvent.Source.DIRECT, origin - Vector2(21,0), Vector2.RIGHT)
	arena.deal_damage_packet(enemy, {"damage":20.0, "base_damage":10.0,"elemental_damage":10.0,"element":"fire","crit":true},event)
	check(arena.feedback.event_counts.get("DIRECT",0) == 1, "atomic B/E emits one direct impact")
	check(arena.feedback.visuals.get_child_count() == 1, "one crit visual, not separate B/E bursts")
	var visual: FeedbackVisual = arena.feedback.visuals.get_child(0)
	check(visual.position == event.position and visual.critical, "visual captures collision position and actual crit")
	enemy.knockback(Vector2.RIGHT,45)
	check(enemy.position == origin and visual.position == event.position, "no teleport or post-knockback impact origin")
	arena.feedback.clear()
	arena.deal_element_damage(enemy, 2, "fire", FeedbackEvent.Source.BURN)
	check(arena.feedback.visuals.get_child_count() == 0, "DOT has no impact burst")
	var popup: FloatingText = arena.effects.get_child(arena.effects.get_child_count()-1)
	check(popup.font_size == arena.definition.damage_feedback.dot_font_size, "DOT gets smaller typed damage text")
	var kills_before := arena.kills
	enemy.receive_damage(10000)
	check(enemy.is_dead and enemy.health == 0 and enemy.is_queued_for_deletion(), "gameplay death is immediate")
	check(arena.feedback.visuals.get_child_count() == 1, "independent death snapshot remains")
	visual = arena.feedback.visuals.get_child(0)
	check(visual.kind == "death" and visual.get_child_count() == 0, "snapshot has no actor, AI or children")
	enemy.receive_damage(10000)
	check(arena.kills == kills_before+1, "no duplicate kill reward while corpse fades")
	visual._process(0.16)
	check(visual.is_queued_for_deletion(), "short snapshot expires")
	arena.feedback.clear()
	for i in range(200): arena.feedback.status_event("shatter",Vector2(400,300))
	check(arena.feedback.visuals.get_child_count() <= arena.feedback.definition.visual_limit, "visual saturation is bounded")
	check(arena.feedback.dropped_visuals > 0, "saturation explicitly drops cosmetics")
	var survivor := arena.spawn_enemy("dummy",Vector2(500,300))
	var hp := survivor.health
	arena.deal_element_damage(survivor,5,"lightning",FeedbackEvent.Source.CHAIN)
	check(is_equal_approx(survivor.health,hp-5), "full visual pool never drops damage")
	arena.clear_enemies()
	check(arena.feedback.visuals.get_child_count() == 0, "clear removes cosmetics immediately")
	check(arena.feedback.audio.active_voice_count() == 0, "clear stops voices")
	var settings := DisplaySettings.new()
	settings.sound_enabled = false
	var path := "user://feedback_settings_test.cfg"
	check(settings.save_settings(path) == OK, "sound preference saves")
	var restored := DisplaySettings.new()
	restored.load_settings(path)
	check(not restored.sound_enabled, "sound mute persists independently of builds")
	DirAccess.remove_absolute(path)
	arena.set_sound_enabled(false)
	check(not arena.feedback.audio.play_event("hit"), "arena mute reaches audio subsystem")
	arena.queue_free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("FEEDBACK INTEGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
