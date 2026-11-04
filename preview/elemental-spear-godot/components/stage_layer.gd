extends Node2D
const Profile=preload("spear_profile.gd")
const Fire=preload("../modules/fire.gd")
var profile:Resource
var stage_name:String="form"
var age:float=0
var cleared:bool=true
var layer_enabled:bool=true
var renderer
func play(origin:Vector2,settings:Resource=null,phase_name:String="form") -> void:
	if not origin.is_finite() or phase_name not in Profile.PHASES: clear(); return
	profile=(settings if settings is Profile else Profile.new()).sanitized()
	stage_name=phase_name; position=origin; age=0; cleared=false; _load_renderer(); queue_redraw()
func _load_renderer() -> void:
	var stage=profile.phase(stage_name)
	var script=stage.renderer_override
	if script==null:
		var candidates=["res://modules/fire.gd","res://modules/lightning.gd","res://modules/ice.gd"]
		if not ResourceLoader.exists(candidates[stage.element]):
			renderer=null; push_warning("Requested element module is not installed"); return
		script=load(candidates[stage.element])
	renderer=script.new() if script.can_instantiate() else Fire.new()
	if not renderer.has_method("render"): renderer=Fire.new()
func seek(seconds:float) -> void:
	if cleared or not is_finite(seconds): return
	age=seconds; queue_redraw()
func advance(delta:float) -> void:
	if is_finite(delta) and delta>0: seek(age+delta)
func set_enabled(value:bool) -> void: layer_enabled=value; queue_redraw()
func stop() -> void: clear()
func clear() -> void: cleared=true; queue_redraw()
func sample() -> Dictionary:
	if cleared or profile==null: return {"active":false}
	var stage=profile.phase(stage_name); var duration=profile.phase_duration(stage_name)
	if not stage.enabled or not layer_enabled or stage.intensity<=0 or age<0 or age>=duration: return {"active":false}
	var q=clampf(age/duration,0,1)
	var axis=Vector2(sin(deg_to_rad(profile.angle_degrees)),cos(deg_to_rad(profile.angle_degrees)))
	var length_value=profile.spear_length*stage.size
	var center=-axis*length_value*0.5+Vector2(0,-profile.fall_height)
	var growth=1.0; var fade=1.0
	if stage_name=="form": growth=smoothstep(0.0,1.0,q)
	if stage_name=="hover": center.y+=sin(q*TAU)*1.25
	if stage_name=="descent": center.y+=profile.fall_height*q*q
	if stage_name=="dissolve": fade=1-q
	return {"active":true,"q":q,"age":age+profile.phase_duration("field") if stage_name=="dissolve" else age,"duration":duration,"axis":axis,"center":center,"length":length_value*growth,"width":profile.spear_width*stage.size,"growth":growth,"fade":fade,"radius":profile.field_radius*stage.size,"seed":profile.seed_value}
func _draw() -> void:
	var state=sample()
	if state.active and renderer!=null: renderer.render(self,stage_name,state,profile,profile.phase(stage_name))
