extends SceneTree
const Death = preload("res://effects/VFX-15_monster_death/death.gd")
var checks := 0
var failed := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failed += 1; push_error(message)
func _initialize() -> void:
 var effect := Death.new(); root.add_child(effect)
 effect.configure({"host_mode":false,"duration":.25,"fragment_count":6,"residue_count":0,"residue_seconds":0,"tint":"b99889","ash_color":"a38b7f"})
 effect.play()
 check(effect.host_image==null and not effect.sprite.visible,"standalone has no invented host")
 check(effect.fragments.size()==6 and effect.residue.is_empty(),"bounded six-chip burst without ground debris")
 check(effect.total_lifetime()==.25,"no invisible residue lifetime")
 check(not effect.is_processing() and not effect.is_physics_processing(),"only caller advances time")
 effect.advance(-1);effect.advance(NAN)
 check(effect.elapsed==0,"invalid deltas ignored")
 effect.advance(.04)
 check(not effect.live_fragments().is_empty(),"fragments active at game speed")
 var snapshot:=effect.live_fragments().duplicate(true)
 effect.play();effect.advance(.04)
 check(effect.live_fragments()==snapshot,"deterministic replay at same age")
 effect.advance(.21)
 check(effect.finished and not effect.playing and effect.elapsed==.25,"exact quarter-second expiry")
 check(effect.live_fragments().is_empty() and effect.live_residue().is_empty(),"expiry clears all draw geometry")
 effect.play();effect.advance(10)
 check(effect.finished and effect.elapsed==.25,"large delta cannot retain leftovers")
 effect.play();effect.advance(.05);effect.reset()
 check(not effect.playing and effect.fragments.is_empty() and effect.residue.is_empty(),"cancel clears immediately")
 effect.play();var other:=Death.new();root.add_child(other)
 check(effect.shader_material!=other.shader_material,"instances own independent material")
 effect.free();other.free();print("STANDALONE DEATH: %d checks, %d failed" % [checks,failed]);quit(1 if failed else 0)
