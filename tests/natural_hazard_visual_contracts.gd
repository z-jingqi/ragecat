extends SceneTree
## Presentation-only regression checks. Actual rendered frame review remains required.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func run() -> void:
	var original := VfxAtlasRenderer.library
	var tuned := original.duplicate(true) as VfxAtlasLibrary
	tuned.rock_fall_start=0.5
	tuned.rock_fall_exponent=2.0
	VfxAtlasRenderer.library=tuned
	var rock:=RockWarning.new()
	rock.position=Vector2(120,150)
	rock.radius=44.0
	rock.warning_duration=0.85
	rock.arena_bounds=Rect2(10,20,800,600)
	root.add_child(rock)
	rock.set_physics_process(false)
	check(rock.get_child_count()==0,"simple landing warning creates no dust material or particle nodes")
	check(rock.material.get_shader_parameter("arena_rect")==Vector4(10,20,800,600),"simple landing cue clips at actual arena edge")
	rock.radius=63.0
	check(rock.radius==63.0,"runtime radius remains configurable")
	check(rock.visual_fall_progress(0.49)==0.0,"gathering stage does not reveal the falling stone")
	check(is_equal_approx(rock.visual_fall_progress(0.75),0.25),"authored acceleration is sampled from hazard clock")
	check(rock.visual_fall_progress(1.0)==1.0,"stone reaches impact on original damage deadline")
	seed(271)
	var expected:=randi()
	seed(271)
	for i in range(100): rock.visual_fall_progress(float(i)/100)
	check(randi()==expected,"presentation sampling leaves gameplay RNG untouched")
	rock.ai_enabled=false
	rock._physics_process(0.5)
	check(rock.elapsed==0.0,"stopped hazard also stops shader progress")
	rock.ai_enabled=true
	rock._physics_process(0.84)
	check(not rock.impacted,"full original warning duration remains readable")
	rock._physics_process(0.01)
	check(rock.impacted,"warning ends exactly at original impact")
	var rock_source:=FileAccess.get_file_as_string("res://scripts/bosses/mountainbreaker/rock_warning.gd")
	var warning_source:=rock_source.split("if not impacted:")[1].split("var fall_progress")[0]
	check(warning_source.contains("HazardWarningVisual.draw_circle_warning"),"landing uses the shared plain circle/countdown cue")
	var cue_source:=FileAccess.get_file_as_string("res://scripts/feedback/hazard_warning_visual.gd")
	check(cue_source.count("draw_arc")==2,"plain circle has an exact outline and countdown")
	check(not cue_source.contains("draw_clip") and not cue_source.contains("screen_texture"),"plain warnings never add baked or shader effects")
	check(not cue_source.contains("width <= 0.0") and cue_source.contains("draw_line(start,end,edge"),"zero-width damaging charge retains its centerline warning")
	check(not rock_source.contains("ground_warning"),"landing warning does not layer dust effects over the cue")
	rock.queue_free()
	await process_frame
	check(not is_instance_valid(rock),"warning and its owned presentation nodes are released together")
	var boss:=Mountainbreaker.new()
	boss.arena_bounds=Rect2(100,80,900,600)
	root.add_child(boss)
	boss.set_physics_process(false)
	check(boss._charge_warning_visual.material.get_shader_parameter("arena_rect")==Vector4(100,80,900,600),"plain charge is clipped even in an inset arena")
	check(boss._charge_warning_visual.show_behind_parent,"plain charge stays beneath the boss silhouette")
	boss._charge_warning_visual.visible=true
	boss.reset_state()
	check(not boss._charge_warning_visual.visible,"reset immediately hides the plain charge cue while paused")
	var cue_ref: WeakRef=weakref(boss._charge_warning_visual)
	boss.queue_free()
	await process_frame
	check(cue_ref.get_ref()==null,"plain charge cue is owned and released with boss")
	var enemy_source:=FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	var shock_visual:=enemy_source.split("func _draw_status_rings()")[1].split("if status.has_ice_mark()")[0]
	check(not shock_visual.contains("draw_arc"),"charged enemies use local filaments, not decorative foot circles")
	check(shock_visual.contains("draw_polyline"),"charged state retains visible local electrical feedback")
	VfxAtlasRenderer.library=original
	print("NATURAL HAZARD VISUALS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
