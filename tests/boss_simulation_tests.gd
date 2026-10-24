extends SceneTree
class Target:
	extends Node2D
	var radius := 16.0
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var target := Target.new()
	world.add_child(target)
	for type in [Mountainbreaker,Beastcaller,Wildfire]:
		for phase in [1,2]:
			var boss: BossActor = type.new()
			world.add_child(boss)
			boss.set_physics_process(false)
			boss.target = target
			boss.arena_bounds = Rect2(0,0,1200,800)
			boss.position = Vector2(600,400)
			boss.choice_rng.seed = 42
			boss.force_phase_for_practice(phase)
			if boss is Beastcaller:
				boss.reserve_summons = func(_points: Array[Vector2],_owner: BossActor) -> bool: return true
				boss.commit_summons = func(_owner: BossActor) -> void: pass
				boss.cancel_summons = func(_owner: BossActor) -> void: pass
			var peak := 0
			for step in range(3600):
				var time := step / 60.0
				target.position = Vector2(600,400) + Vector2(cos(time*.5)*380,sin(time*.7)*230)
				boss._physics_process(1.0/60.0)
				for child in boss.get_children():
					child.set_physics_process(false)
					if not child.is_queued_for_deletion() and child.has_method("_physics_process"): child._physics_process(1.0/60.0)
				peak = maxi(peak,boss.get_child_count())
				if step % 60 == 0: await process_frame
			check(boss.position.is_finite(),"finite position: "+boss.boss_identity)
			check(peak < 40,"bounded owned hazards: "+boss.boss_identity+" phase"+str(phase))
			check(boss.phase_number == phase,"practice phase remains fixed")
			boss.cleanup_owned_hazards()
			check(boss.get_children().filter(func(child: Node) -> bool: return child.get_meta("boss_hazard", false)).is_empty(),"cleanup removes every owned hazard after long combo stream")
			boss.queue_free()
			await process_frame
	world.queue_free()
	await process_frame
	print("Boss simulation tests: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
