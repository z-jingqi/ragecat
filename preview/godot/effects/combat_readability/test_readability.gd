extends SceneTree
const Thunder := preload("../VFX-08_chain_lightning/fixed_path.gd")
const ThunderPreset := preload("../VFX-08_chain_lightning/combat_preset.gd")
const Level := preload("../VFX-22_level_up/level_up.gd")
const LevelPreset := preload("../VFX-22_level_up/combat_preset.gd")
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool,title: String):
 if ok: passed += 1
 else: failed += 1; push_error(title)
func run():
 var thunder := Thunder.new(); root.add_child(thunder)
 var points := PackedVector2Array([Vector2(50,200),Vector2(180,200),Vector2(310,200),Vector2(440,200),Vector2(570,200),Vector2(700,200)])
 thunder.play_path(points,ThunderPreset.OPTIONS)
 check(thunder.snapshot_points() == points,"presentation preset cannot reroute authoritative path")
 check(is_equal_approx(thunder.duration,.36) and thunder.config.width == 3,"explicit wider, longer presentation")
 var peaks := [0,0,0,0,0]
 for frame in range(22):
  thunder.seek(frame/60.0)
  for i in range(5):
   var bolt = thunder.links[i].bolt
   if bolt.visible and bolt.phase().strength >= .75 and bolt.phase().reach >= .999: peaks[i] += 1
 for peak_frames in peaks: check(peak_frames >= 3,"each of five links has several readable bright frames")
 var baseline_peaks := [0,0,0,0,0]
 thunder.play_path(points)
 for frame in range(11):
  thunder.seek(frame/60.0)
  for i in range(5):
   var bolt = thunder.links[i].bolt
   if bolt.visible and bolt.phase().strength >= .75 and bolt.phase().reach >= .999: baseline_peaks[i] += 1
 for i in range(5): check(peaks[i] >= baseline_peaks[i]+3,"each fully extended link improves measured bright-frame count over baseline")
 thunder.play_path(points,ThunderPreset.OPTIONS)
 thunder.seek(.36); check(thunder.done and not thunder.visible,"longer cosmetic still expires exactly")
 thunder.replay(); thunder.paused = true; thunder.advance(1)
 check(thunder.age == 0,"external pause remains exact")
 for repeat in range(50): thunder.play_path(points,ThunderPreset.OPTIONS)
 check(thunder.links.size() == 5 and thunder.get_child_count() == 5,"replay remains bounded")
 var level := Level.new(); level.automatic = false; root.add_child(level)
 var host := Node2D.new(); root.add_child(host); host.position = Vector2(161,301)
 level.scale = LevelPreset.DRAW_SCALE
 level.play(Vector2.ZERO,LevelPreset.OPTIONS,host,Vector2(0,15))
 check(level.config.height*level.scale.y == 136 and level.config.core_width*level.scale.x == 4,"world pillar136px with4px core")
 check(level.config.radius*level.scale.x == 46 and level.config.particles == 18,"wide foot radius with unchanged particle budget")
 check(level.to_global(level.anchor).distance_to(host.to_global(Vector2(0,15))) <= 1.5,"scaled output retains actual foot anchor within pixel grid")
 host.position += Vector2(7,9); level.tick(.2)
 check(level.to_global(level.anchor).distance_to(host.to_global(Vector2(0,15))) <= 1.5,"moving scaled cue follows host without scaling its foot offset")
 var age: float = level.age; level.tick(0)
 check(level.age == age,"caller pause remains exact")
 level.tick(10); check(not level.active and level.host == null,"cue clears host at finite expiry")
 check(Level.DEFAULTS.height == 88 and Level.DEFAULTS.core_width == 2 and is_equal_approx(Level.DEFAULTS.intensity,.62),"canonical lab defaults remain unchanged")
 check(Thunder.DEFAULTS.duration == .18 and Thunder.DEFAULTS.width == 1.25,"canonical lightning lab defaults remain unchanged")
 host.free(); level.free(); thunder.free()
 print("COMBAT READABILITY: ",passed," passed, ",failed," failed; peak_frames=",peaks," baseline=",baseline_peaks)
 quit(1 if failed else 0)
