extends SceneTree
const State = preload("flash_state.gd")
var checks := 0
var failures := 0
func check(ok: bool,title: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(title)
func _initialize() -> void:
 var state := State.new()
 check(state.has_method("apply_color"),"pure geometry color API exists")
 if not state.has_method("apply_color"): quit(1); return
 state.configure({"duration":.1,"peak":.2,"hold":.018,"color":"#ffffff"})
 var base := Color(.3,.3,.3,.37)
 check(state.apply_color(base) == base,"idle equals exact original color")
 state.trigger()
 check(is_equal_approx(state.apply_color(base).r,.44),"game preset keeps white20percent peak")
 for alpha in range(101):
  var original := Color(.3,.5,.2,float(alpha)/100)
  check(state.apply_color(original).a == original.a,"preserve alpha%d" % alpha)
 state.tick(.018)
 check(is_equal_approx(state.apply_color(base).r,.44),"canonical hold retains restrained peak")
 state.tick(.032)
 var expected := .3+.7*.2*pow(1-(.05-.018)/(.1-.018),2)
 check(is_equal_approx(state.apply_color(base).r,expected),"geometry shares canonical quadratic decay")
 state.paused = true; var before: Color = state.apply_color(base); state.tick(4)
 check(state.apply_color(base) == before,"caller pause freezes geometry color")
 state.paused = false; state.trigger()
 check(is_equal_approx(state.apply_color(base).r,.44),"retrigger refreshes but never adds strength")
 state.tick(.1); check(state.apply_color(base) == base,"expiry restores exact base")
 state.trigger(); state.reset(); check(state.apply_color(base) == base,"reset restores exact base")
 state.configure({"color":"#ff000000"});state.trigger()
 check(state.apply_color(base).a == base.a,"tint alpha never changes host alpha")
 print("GEOMETRY FLASH: %d checks, %d failed" % [checks,failures]);quit(1 if failures else 0)
