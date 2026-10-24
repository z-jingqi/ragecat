extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error("DASH MOTION: "+label)
func run()->void:
 var arena:=RageArena.new()
 arena.practice=true
 arena.sound_enabled=false
 arena.run_seed_override=89134
 root.add_child(arena)
 arena.process_mode=Node.PROCESS_MODE_DISABLED
 var p:ArcherPresentation=arena.player._presentation
 var motion:=p.appearance.dash_motion
 var state:=arena.rng.state
 var at:=arena.player.position
 var hp:=arena.stats.hp
 var arrows_before:=arena.arrows.get_child_count()
 var sample:={"clip":&"east/carry","phase":0.0}
 check(motion!=null,"Real appearance supplies dash motion data")
 check(motion.resource_path=="res://resources/characters/archer/dash_motion.tres","Default appearance loads external motion, not a stale embedded snapshot")
 check(motion.body.resource_path=="res://assets/characters/archer/poses/dash/dash_body.tres","Body library remains an explicit external resource")
 for required in [&"east/dash_0",&"east/dash_2",&"east/dash_4"]:
  check(not motion.body.sample(required,0.5).is_empty(),"Required reviewed dash cannot silently fall back: "+str(required))
 p.clock.direction_index=0
 p.posture.height=0
 p.adapter.fired_this_tick=false
 arena.player.dash_direction=Vector2.RIGHT
 arena.player.dash_left=arena.stats.dash_duration
 check(p._show_dash_pose(1.0/60,sample),"Non-shooting dash has real authored pose")
 check(p.view._pose_material.get_shader_parameter("single_layer"),"Guard uses its matched complete silhouette")
 arena.player.dash_left=arena.stats.dash_duration*0.5
 p.adapter.fired_this_tick=true
 sample={"clip":&"east/normal_release","phase":0.0}
 check(p._show_dash_pose(1.0/60,sample),"Actual release during guard selects shooting body immediately")
 check(not p._dash_guard and not p.view._pose_material.get_shader_parameter("single_layer"),"Guard cannot cover actual release")
 p.adapter.fired_this_tick=false
 p.clock.moving=true
 p.clock.gait_phase=0.7
 arena.player.dash_left=0
 check(not p._show_dash_pose(1.0/60,sample),"Moving shoot dash reconnects to locomotion")
 check(is_equal_approx(p.clock.gait_phase,motion.gait_entry_phases[&"east/dash_0"]),"Moving dash reconnects matching planted-foot phase")
 check(arena.player.position==at and arena.stats.hp==hp and arena.rng.state==state,"Presentation leaves position, health and combat RNG untouched")
 check(arena.arrows.get_child_count()==arrows_before,"Visual release does not create arrows")
 p.reset_pose()
 check(not p._dash_was_active and is_inf(p._dash_recovery_age),"Practice reset clears dash motion state")
 for step_distance in [230.0/60.0,460.0/60.0]:
  p.reset_pose()
  p.clock.direction_index=0
  p.clock.moving=true
  p.posture.height=0
  p.adapter.fired_this_tick=false
  arena.player.dash_left=arena.stats.dash_duration
  p._show_dash_pose(1.0/60,sample)
  arena.player.dash_left=0
  var presented_recovery:=false
  for frame in range(12):
   arena.player.position.x+=step_distance
   var shown:=p._show_dash_pose(1.0/60,sample)
   presented_recovery=presented_recovery or (shown and p._dash_move_recovery)
   if not shown:break
  check(presented_recovery,"Guard continues into a distance-driven moving recovery")
  check(not p._dash_move_recovery and is_equal_approx(p.clock.gait_phase,5.0/16),"Guard reconnects exact authored walking frame at both movement speeds")
 p.reset_pose()
 p.clock.direction_index=0
 p.clock.moving=true
 p.posture.height=0
 p.adapter.fired_this_tick=false
 arena.player.dash_left=arena.stats.dash_duration
 p._show_dash_pose(1.0/60,sample)
 arena.player.dash_left=0
 arena.player.position.x+=3.8
 p._show_dash_pose(1.0/60,sample)
 p.clock.moving=false
 for frame in range(12):p._show_dash_pose(1.0/60,sample)
 check(not p._dash_move_recovery and not p._show_dash_pose(1.0/60,sample),"Stopping during guard recovery cannot leave a stuck pose")
 for phase in [0.0,0.17,0.36,0.56,0.78,1.0,1.1333333,1.2666667,1.4]:
  var mapped:=motion.sample_phase(phase)
  check(mapped>=0 and mapped<=1,"Authored nonuniform dash timing maps inside clip")
 for library in [motion.body,motion.guard]:
  for clip in library.colors.get_animation_names():
   check(library.validate_clip(clip).is_empty(),"Packed trimmed dash frames preserve canvas")
   for i in library.colors.get_frame_count(clip):
    var entry:Dictionary=library.sample(clip,float(i)/(library.colors.get_frame_count(clip)-1))
    check(not entry.is_empty() and entry.color.canvas_region==entry.depth.canvas_region,"Trimmed color/depth agree")
 arena.free()
 await preload("res://tests/audio_teardown.gd").drain(self)
 print("ARCHER DASH MOTION: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
