extends SceneTree
class Target:
	extends Node2D
	var radius := 16.0
var checks := 0
var failures := 0
var impacts := 0
var committed := 0
var cancelled := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var target := Target.new()
	world.add_child(target)
	target.position = Vector2(500,350)
	var breaker := Mountainbreaker.new()
	world.add_child(breaker)
	breaker.set_physics_process(false)
	breaker.target = target
	breaker.position = Vector2(300,350)
	breaker.force_phase_for_practice(2)
	breaker.ability_mode = "charge"
	breaker.phase_time = 0
	breaker._physics_process(.01)
	check(breaker.charges_remaining == 3, "phase two commits three charges")
	check(breaker.state == "warning", "first charge telegraph")
	breaker._physics_process(2)
	breaker._physics_process(2)
	check(breaker.state == "warning" and breaker.charges_remaining == 2, "second charge begins immediately with warning")
	check(is_equal_approx(breaker.phase_time,.3), "repeat warning configured")
	breaker.reset_state()
	breaker._start_rocks()
	check(breaker.rocks.size() == 1 and breaker.tracking_rocks_remaining == 7,"tracking rocks launch sequentially")
	var first := breaker.rocks[0].global_position
	target.position += Vector2(50,0)
	breaker._physics_process(.5)
	check(breaker.rocks.size() == 2 and breaker.rocks[0].global_position == first,"rock positions lock independently")
	check(breaker.rocks[1].global_position == target.global_position,"next rock tracks fresh position")
	breaker.cleanup_owned_hazards()
	check(breaker.get_child_count() == 0,"rocks cleanup immediate")
	var caller := Beastcaller.new()
	world.add_child(caller)
	caller.set_physics_process(false)
	caller.target = target
	caller.position = Vector2(350,350)
	caller.arena_bounds = Rect2(0,0,1400,1000)
	caller.reserve_summons = func(points: Array[Vector2], _owner: BossActor) -> bool: return points.size() > 0
	caller.commit_summons = func(_owner: BossActor) -> void: committed += 1
	caller.cancel_summons = func(_owner: BossActor) -> void: cancelled += 1
	check(caller._start_summon(),"cluster reservation")
	check(caller.summon_positions.size() == 3,"cluster count")
	caller._physics_process(1.1)
	check(committed == 1,"summon commit once")
	caller.force_phase_for_practice(2)
	check(caller._start_summon(),"ring reservation")
	check(caller.summon_positions.size() == 8,"ring has eight targets in roomy bounds")
	caller.cleanup_owned_hazards()
	check(cancelled > 0,"reservation cancellation")
	caller.phase_number = 1
	caller._forced_phase = 0
	caller.health = caller.max_health*.4
	check(not caller.update_phase_at_boundary(),"phase transition blocks next attack")
	check(caller.transition_remaining == 1.0 and caller.phase_number == 2,"phase transition duration and identity")
	caller._physics_process(.5)
	check(caller.transition_remaining > 0,"phase transition remains active")
	var fire := Wildfire.new()
	world.add_child(fire)
	fire.set_physics_process(false)
	fire.target = target
	fire.position = Vector2(300,350)
	fire.force_phase_for_practice(2)
	fire.skyfires_remaining = 2
	fire._next_skyfire()
	check(fire.hazards.size() == 1,"first main skyfire only")
	var h := fire.hazards[0]
	h.set_physics_process(false)
	var at := h.global_position
	fire.position += Vector2(60,0)
	check(h.global_position == at,"ground warning stays world anchored")
	fire._main_impact(h)
	check(fire.hazards.size() >= 2,"phase two splashes")
	fire._start_rings()
	check(fire.hazards.is_empty(),"ring clears own fireground")
	fire._release_ring()
	check(fire.rings_released == 1 and is_equal_approx(fire.phase_time,1.3),"ring release gap excludes following warning")
	fire._release_ring()
	check(is_equal_approx(fire.phase_time,2.3),"third ring configuredlonger gap")
	fire.cleanup_owned_hazards()
	check(fire.get_child_count() == 0,"all owned ring hazards removed")
	check(BossFireRing.swept_band_hit(Vector2(200,0),Vector2(200,0),100,300,20),"fast ring cannot tunnel")
	check(BossFireRing.swept_band_hit(Vector2(-200,0),Vector2(200,0),100,100,20),"fast player crossing band detected")
	check(not BossFireRing.swept_band_hit(Vector2(0,0),Vector2(10,0),100,150,20),"inside ring is safe")
	check(not BossFireRing.swept_band_hit(Vector2(500,0),Vector2(600,0),100,150,20),"outside ring safe")
	var config := BossDefinition.new()
	config.phase_two.charge_count = -9
	config.phase_two.ring_intervals = PackedFloat32Array([NAN,-1,3])
	var safe := config.snapshot()
	check(safe.phase_two.charge_count == 1 and safe.phase_two.ring_intervals.size() == 2,"phase validation")
	check(config.phase_two.charge_count == -9,"resource snapshot leaves source unchanged")
	# Paused AI preserves attack clocks; old telegraphs cannot ghost-spawn after death.
	var paused := Beastcaller.new()
	world.add_child(paused)
	paused.set_physics_process(false)
	paused.target = target
	paused.ai_enabled = false
	var before_clock := paused.phase_time
	paused._physics_process(5.0)
	check(paused.phase_time == before_clock, "AI pause holds boss attack clocks")
	paused.ai_enabled = true
	paused.health = paused.max_health * 0.4
	paused.update_phase_at_boundary()
	paused.receive_damage(paused.health + 1.0)
	check(paused.is_dead, "boss remains damageable during roar transition")
	var ringing := BossFireRing.new()
	world.add_child(ringing)
	ringing.set_physics_process(false)
	ringing.target = target
	ringing.global_position = target.global_position - Vector2(100,0)
	ringing.ring_radius = 50.0
	ringing.speed = 100.0
	ringing.hit.connect(func(_amount: float) -> void: impacts += 1)
	ringing._physics_process(1.0)
	ringing._physics_process(1.0)
	check(impacts == 1, "each ring hit consumed only once")
	ringing.ai_enabled = false
	var held_radius := ringing.ring_radius
	ringing._physics_process(1.0)
	check(ringing.ring_radius == held_radius,"AI pause holds expanding ring")
	var anchor := fire._create_skyfire(target.global_position,false)
	anchor.set_physics_process(false)
	fire.cleanup_owned_hazards()
	check(anchor.is_queued_for_deletion() and anchor.get_parent() == null,"cleanup immediately removes pending skyfire before queued free")
	world.queue_free()
	await process_frame
	print("Boss encounter tests: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
