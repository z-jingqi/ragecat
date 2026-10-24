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
	tuned.rock_warning_color=Color(0.3,0.2,0.1,1)
	tuned.rock_warning_opacity=0.4
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
	check(rock.ground_warning.show_behind_parent,"dust footprint is beneath physical rock")
	check(rock.ground_warning.polygon.size()==4,"one bounded ground quad, no particle-node fanout")
	check(rock.ground_material.get_shader_parameter("hazard_radius")==44.0,"shader radius matches gameplay radius")
	check(rock.ground_material.get_shader_parameter("arena_rect")==Vector4(10,20,800,600),"natural footprint clips at actual arena edge")
	check(rock.ground_material.get_shader_parameter("dust_color")==tuned.rock_warning_color,"warning tint is configurable")
	check(is_equal_approx(rock.ground_material.get_shader_parameter("opacity"),0.4),"warning intensity is configurable")
	rock.radius=63.0
	check(rock.ground_warning.polygon[0]==Vector2(-63,-63),"runtime radius updates the ground footprint")
	check(rock.ground_material.get_shader_parameter("hazard_radius")==63.0,"runtime radius updates shader mask")
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
	check(rock.ground_warning.visible and not rock.impacted,"full original warning duration remains readable")
	rock._physics_process(0.01)
	check(not rock.ground_warning.visible and rock.impacted,"warning ends exactly at original impact")
	var shader_source:=FileAccess.get_file_as_string("res://shaders/rock_ground_warning.gdshader")
	check(not shader_source.contains("TIME"),"pause-safe shader uses simulation progress, not wall clock")
	check(shader_source.contains("1.0-edge_softness,1.0,r"),"soft boundary remains inside the actual attack radius")
	rock.queue_free()
	await process_frame
	check(not is_instance_valid(rock),"warning and its owned presentation nodes are released together")
	var enemy_source:=FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	var shock_visual:=enemy_source.split("func _draw_status_rings()")[1].split("if status.has_ice_mark()")[0]
	check(not shock_visual.contains("draw_arc"),"charged enemies use local filaments, not decorative foot circles")
	check(shock_visual.contains("draw_polyline"),"charged state retains visible local electrical feedback")
	VfxAtlasRenderer.library=original
	print("NATURAL HAZARD VISUALS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
