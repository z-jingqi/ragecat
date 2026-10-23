extends SceneTree
## Independent black-box integration checks against real combat callbacks.
var checks := 0
var failures := 0
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INDEPENDENT FEEDBACK: " + label)
func near(actual: float, expected: float, label: String, epsilon: float = 0.001) -> void:
	check(absf(actual - expected) <= epsilon, "%s actual=%s expected=%s" % [label, actual, expected])
func setup(ranks: Dictionary = {}) -> void:
	if is_instance_valid(arena): arena.free()
	arena = RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.apply_ranks(ranks)
	arena.bow.enabled = false
	arena.player.position = Vector2(300, 350)
func target(kind: String = "chaser", at: Vector2 = Vector2(600,350)) -> EnemyActor:
	var enemy := arena.spawn_enemy(kind, at)
	enemy.max_health = 100000.0
	enemy.health = enemy.max_health
	enemy.ai_enabled = true
	enemy.speed = 0.0
	return enemy
func hit(enemy: EnemyActor, secondary: bool = false) -> float:
	var arrow := BowArrow.new()
	arrow.direction = Vector2.RIGHT
	arrow.secondary = secondary
	arrow.impact_position = enemy.position
	var before := enemy.health
	arena._on_arrow_hit(arrow, enemy)
	arrow.free()
	return before - enemy.health
func motion_contracts() -> void:
	setup()
	for parts in [1, 2, 5, 8, 16]:
		var enemy := target()
		var start := enemy.position
		enemy.knockback(Vector2.RIGHT, 45.0)
		check(enemy.position == start, "knockback never teleports on request")
		for i in range(parts): enemy._physics_process(0.08 / float(parts))
		near(enemy.position.x - start.x, 45.0, "45px exact knockback with %d partitions" % parts)
		enemy._physics_process(0.2)
		near(enemy.position.x - start.x, 45.0, "knockback has no residual velocity")
	var rapid := target()
	var origin := rapid.position
	rapid.knockback(Vector2.RIGHT, 45.0)
	rapid._physics_process(0.02)
	var intermediate := rapid.position
	check(intermediate.x > origin.x and intermediate.x < origin.x + 45, "knockback intermediate is smooth")
	rapid.knockback(Vector2.LEFT, 45.0)
	for i in range(8): rapid._physics_process(0.01)
	near(rapid.position.x, intermediate.x - 45.0, "replacement discards old remaining impulse")
	var edge := target("chaser", arena.bounds.end - Vector2(20, 100))
	edge.knockback(Vector2.RIGHT, 45.0)
	edge._physics_process(0.08)
	check(edge.position.x <= arena.bounds.end.x - edge.radius, "integrated movement remains bounded")
	for kind in ["dummy", "boss"]:
		var fixed := target(kind)
		fixed.ai_enabled = false
		var start := fixed.position
		fixed.knockback(Vector2.RIGHT, 45)
		fixed._physics_process(0.1)
		check(fixed.position == start, kind + " ignores knockback")
func reaction_contracts() -> void:
	setup()
	var enemy := target()
	enemy.speed = 100.0
	enemy.request_hit_reaction(true)
	near(enemy.flash_remaining, 0.05, "direct white flash duration")
	near(enemy.reaction_remaining, 0.05, "direct local translation stop duration")
	near(enemy.reaction_cooldown_remaining, 0.2, "shared reaction cooldown")
	var start := enemy.position
	enemy._physics_process(0.02)
	check(enemy.position == start, "reaction stops ordinary AI")
	enemy.request_hit_reaction(true)
	near(enemy.reaction_remaining, 0.03, "rapid request never refreshes local stop")
	near(enemy.flash_remaining, 0.03, "rapid request never refreshes flash")
	enemy._physics_process(0.06)
	near(start.x - enemy.position.x, 3.0, "long frame preserves post-reaction translation")
	near(Engine.time_scale, 1.0, "hit feedback never changes global time scale")
	check(not enemy.contact_damage_suppressed(), "reaction grants no contact immunity")
	enemy._physics_process(0.12)
	enemy.request_hit_reaction(true)
	near(enemy.reaction_remaining, 0.05, "reaction accepts next hit after cooldown")
	var frozen := target()
	frozen.speed = 100.0
	frozen.status.frozen_remaining = 0.03
	frozen.request_hit_reaction(true)
	start = frozen.position
	frozen._physics_process(0.08)
	near(start.x - frozen.position.x, 3.0, "freeze and reaction overlap rather than concatenate")
	check(not frozen.status.is_frozen(), "reaction does not extend freeze")
	var longer := target()
	longer.speed = 100
	longer.status.frozen_remaining = 0.4
	longer.request_hit_reaction(true)
	longer.knockback(Vector2.RIGHT,45)
	start = longer.position
	longer._physics_process(0.08)
	near(longer.position.x - start.x, 45.0, "freeze and reaction never suppress knockback")
	near(longer.status.frozen_remaining, 0.32, "reaction does not shorten freeze")
	var ranged := target("ranged", Vector2(350,350)) as Spitter
	ranged.speed = 100
	ranged.shot_pending = true
	ranged.warning_remaining = 0.02
	ranged.request_hit_reaction(true)
	start = ranged.position
	ranged._physics_process(0.03)
	check(ranged.position == start, "ranged retreat locally stops")
	check(not ranged.shot_pending and arena.enemy_bullets.get_child_count() > 0, "ranged pending attack continues during reaction")
	var boss := target("boss") as Mountainbreaker
	boss._start_charge_warning()
	var endpoint := boss.charge_end
	var phase := boss.phase_time
	hit(boss)
	near(boss.reaction_remaining, 0.0, "boss has no AI stop")
	check(boss.flash_remaining > 0 and boss.charge_end == endpoint, "boss direct flash preserves telegraph")
	boss._physics_process(0.01)
	near(boss.phase_time, phase - 0.01, "boss warning clock continues")
func element_invariants() -> void:
	for rank in range(1,4):
		setup({"element_type":"ice", "enchant_rank":3, "element_skill_rank":rank})
		arena.stats.crit_chance = 0.0
		var enemy := target("dummy")
		for i in range(3): near(hit(enemy), 30.0, "ice stack packet unchanged")
		near(enemy.status.frozen_remaining, [0.65,0.8,1.0][rank-1], "rank freeze duration unchanged")
		near(hit(enemy,true),60.0,"shatter doubles B+E once")
		near(enemy.status.immunity_remaining,2.0,"shatter thaw immunity unchanged")
		near(hit(enemy),30.0,"same-frame post-shatter hit normal")
	setup({"element_type":"dark", "enchant_rank":1, "element_skill_rank":1})
	var enemy := target()
	var field := GravityField.new()
	field.configure(arena.stats,arena.enemies,arena.deal_element_damage)
	arena.add_child(field)
	field.position = enemy.position + Vector2(80,0)
	field.attach_enemy(enemy)
	enemy.request_hit_reaction(true)
	var start := enemy.position
	enemy._physics_process(0.02)
	check(enemy.position.x > start.x,"gravity moves during local hit stop")
	field.deactivate()
	check(enemy.contact_damage_suppressed(),"gravity release preserves contact grace")
	enemy._physics_process(0.0) # Consume same-engine-frame release marker.
	enemy._physics_process(0.101)
	check(not enemy.contact_damage_suppressed(),"gravity grace still expires")
	start = enemy.position
	hit(enemy)
	enemy._physics_process(0.1)
	check(enemy.position == start,"dark skill direct arrow never adds knockback")
func rng_snapshot(enabled: bool, element: String) -> Array:
	setup({"element_type":element,"enchant_rank":3,"element_skill_rank":3})
	arena.feedback.enabled = enabled
	arena.rng.seed = 987654321
	seed(123456789)
	var a := target("dummy",Vector2(600,350))
	var b := target("dummy",Vector2(640,350))
	var c := target("dummy",Vector2(680,350))
	var damage: Array = []
	for i in range(30):
		damage.append(hit(a,i % 4 == 0))
		arena.element_procs._physics_process(0.2)
	return [damage,a.health,b.health,c.health,arena.total_damage,arena.crits,arena.element_procs.proc_counts.duplicate(),a.status.frost_stacks,a.status.frozen_remaining,a.status.shock_remaining,arena.rng.state,randi()]
func rng_contracts() -> void:
	for element in ["fire","lightning","ice","dark"]:
		var enabled := rng_snapshot(true,element)
		var disabled := rng_snapshot(false,element)
		check(enabled == disabled,element + " cosmetic enabled/disabled preserves damage, proc results and both RNG states")
func provenance_contracts() -> void:
	setup()
	for source in [FeedbackEvent.Source.BURN,FeedbackEvent.Source.GRAVITY,FeedbackEvent.Source.UNKNOWN]:
		var enemy := target()
		var before := enemy.health
		var event := FeedbackEvent.impact(source,enemy.position)
		arena.deal_damage_packet(enemy,{"damage":1000.0,"base_damage":0.0,"elemental_damage":1000.0,"element":"fire"},event)
		near(before-enemy.health,1000.0,"large DOT/unknown packet still damages")
		near(enemy.flash_remaining,0.0,"large DOT/unknown never white-flashes")
		near(enemy.reaction_remaining,0.0,"large DOT/unknown never pauses AI")
	for source in [FeedbackEvent.Source.BLAST,FeedbackEvent.Source.CHAIN]:
		var enemy := target()
		var event := FeedbackEvent.impact(source,enemy.position)
		arena.deal_damage_packet(enemy,{"damage":1.0},event)
		near(enemy.flash_remaining,0.0,"derived impact has no direct white flash")
		check(enemy.reaction_remaining > 0.0,"small explicitly derived impact can locally react")
	var atomic := target()
	var calls := [0]
	atomic.damaged.connect(func(_amount:float,_crit:bool,_at:Vector2): calls[0] += 1)
	arena.deal_damage_packet(atomic,{"damage":20.0,"base_damage":12.0,"elemental_damage":8.0,"element":"fire","crit":true},FeedbackEvent.impact(FeedbackEvent.Source.DIRECT,atomic.position))
	check(calls[0] == 1,"B+E packet emits one atomic damage signal")
	near(atomic.flash_remaining,0.05,"small direct atomic packet gets full direct flash")
	var rejected := target()
	for damage in [0.0,-1.0]:
		arena.deal_damage_packet(rejected,{"damage":damage},FeedbackEvent.impact(FeedbackEvent.Source.DIRECT,rejected.position))
	near(rejected.flash_remaining,0.0,"zero/negative packet has no flash")
	near(rejected.reaction_remaining,0.0,"zero/negative packet has no reaction")
	var dead := target()
	dead.health = 1.0
	var before_kills := arena.kills
	hit(dead)
	check(dead.is_dead,"lethal hit marks death synchronously")
	check(arena.kills == before_kills+1,"lethal hit awards kill once immediately")
	hit(dead)
	check(arena.kills == before_kills+1,"repeat lethal callback cannot award twice")
func audio_contracts() -> void:
	var audio := FeedbackAudio.new()
	root.add_child(audio)
	for kind: String in audio.definition.event_streams:
		var stream := audio.definition.event_streams[kind] as AudioStreamWAV
		check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS,kind + " has PCM16 sample")
		if stream == null: continue
		var energy := 0.0
		var peak := 0.0
		for offset in range(0,stream.data.size(),2):
			var sample := float(stream.data.decode_s16(offset)) / 32768.0
			energy += sample * sample
			peak = maxf(peak,absf(sample))
		check(stream.data.size() > 100 and energy > 0 and is_finite(energy) and peak < 1.0,kind + " nonempty finite unclipped waveform")
	seed(987123)
	var expected := randi()
	seed(987123)
	for kind: String in audio.definition.event_streams: audio.play_event(kind)
	check(randi() == expected,"audio pitch variation never consumes global RNG")
	var diagnostic := audio.get_diagnostics()
	check(audio.active_voice_count() <= int(diagnostic.pool_size) and int(diagnostic.pool_size) <= 8,"pooled audio bounded under event flood")
	check(float(diagnostic.last_pitch) >= 0.9 and float(diagnostic.last_pitch) <= 1.1,"pitch bounded")
	check(float(diagnostic.last_voice_volume_db) <= -3.0,"voice gain never exceeds safe configured ceiling")
	audio.set_enabled(false)
	check(audio.active_voice_count() == 0 and not audio.play_event("hit"),"mute stops active audio and rejects future audio")
	audio.set_enabled(true)
	check(audio.play_event("hit"),"unmute permits new sound")
	paused = true
	check(audio.active_voice_count() == 0 and not audio.play_event("hit"),"pause stops audio and prevents queued sound")
	paused = false
	check(audio.active_voice_count() == 0,"resume never replays old sounds")
	audio.play_event("hit")
	audio._process(10.0)
	check(audio.active_voice_count() == 0,"game-time lease expires")
	audio.play_event("critical")
	audio.stop_all()
	check(audio.active_voice_count() == 0,"explicit stop clears every voice")
	audio.free()
func saturation_contracts() -> void:
	setup({"element_type":"fire","enchant_rank":3,"element_skill_rank":3})
	arena.feedback.definition.visual_limit = 1
	arena.stats.crit_chance = 0.0
	var enemy := target("dummy")
	var secondary := target("dummy",Vector2(650,350))
	var before := enemy.health
	for i in range(100): hit(enemy)
	near(before-enemy.health,3000.0,"saturated cosmetics retain every direct damage packet")
	check(secondary.health < secondary.max_health,"saturated cosmetics retain blast damage")
	check(arena.element_procs.proc_counts.fire == 100,"saturated cosmetics retain every fire proc")
	check(arena.feedback.visuals.get_child_count() <= 1 and arena.feedback.dropped_visuals > 0,"visual saturation drops only cosmetics")
	check(arena.feedback.event_counts.get("DIRECT",0) == 100,"each atomic B+E hit dispatches one feedback event")
	var before_counts := arena.feedback.event_counts.duplicate()
	arena.deal_damage_packet(enemy,{"damage":0.0},FeedbackEvent.impact(FeedbackEvent.Source.DIRECT,enemy.position))
	check(before_counts == arena.feedback.event_counts,"rejected zero damage dispatches no feedback event")
	arena.clear_enemies()
	check(arena.feedback.visuals.get_child_count() == 0 and arena.feedback.audio.active_voice_count() == 0,"clear enemies removes feedback and stops voices")
func death_and_miss_contracts() -> void:
	setup()
	var enemy := target()
	enemy.health = 1.0
	var before := arena.feedback.event_counts.duplicate()
	var miss := BowArrow.new()
	miss.position = Vector2(400,500)
	miss.direction = Vector2.RIGHT
	miss.enemies = arena.enemies
	miss.arena_bounds = arena.bounds
	miss.enemy_hit.connect(arena._on_arrow_hit)
	arena.arrows.add_child(miss)
	miss._physics_process(0.01)
	check(before == arena.feedback.event_counts,"actual arrow miss emits no hit feedback")
	hit(enemy)
	check(arena.bow.nearest_enemy() == null,"dead enemy and death snapshot are immediately untargetable")
	var snapshot: FeedbackVisual
	for node in arena.feedback.visuals.get_children():
		if node.kind == "death": snapshot = node
	check(snapshot != null,"lethal impact creates cosmetic snapshot")
	if snapshot != null:
		near(snapshot.duration,arena.feedback.definition.death_duration,"smoke lifetime follows configuration")
		check(not snapshot.has_method("receive_damage") and snapshot.get_child_count() == 0,"snapshot has no actor or collision children")
		snapshot._process(snapshot.duration * 0.5)
		near(snapshot.remaining,snapshot.duration * 0.5,"smoke clock advances independently; atlas owns alpha")
		snapshot._process(snapshot.duration * 0.5)
		check(snapshot.is_queued_for_deletion(),"smoke expires at configured duration")
func run() -> void:
	motion_contracts()
	reaction_contracts()
	element_invariants()
	rng_contracts()
	provenance_contracts()
	audio_contracts()
	saturation_contracts()
	death_and_miss_contracts()
	arena.free()
	await create_timer(0.5).timeout # Allow audio mixer to release stopped playback references.
	print("INDEPENDENT FEEDBACK CONTRACTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
