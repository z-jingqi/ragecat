extends RefCounted
# Host alpha/pose are not owned by this controller. Each host owns a material.
var duration := 0.11
var peak := 0.46
var hold := 0.018
var tint := Color("e1ebef")
var elapsed := 1.0
var active := false
var paused := false
func configure(values: Dictionary) -> void:
 for key in ["duration", "peak", "hold"]:
  if values.has(key) and (values[key] is float or values[key] is int) and is_finite(float(values[key])):
   match key:
    "duration": duration=clampf(float(values[key]),0.02,0.5)
    "peak": peak=clampf(float(values[key]),0.0,0.8)
    "hold": hold=clampf(float(values[key]),0.0,0.08)
 hold=minf(hold,duration*0.5)
 if values.has("color") and values.color is String and Color.html_is_valid(values.color): tint=Color(values.color)
func trigger() -> void:
 elapsed=0.0;active=true
func reset() -> void:
 elapsed=duration;active=false;paused=false
func tick(dt: float) -> void:
 if paused or not is_finite(dt) or dt<=0.0: return
 if active:
  elapsed=minf(duration,elapsed+dt)
  if elapsed>=duration: active=false
func amount() -> float:
 if not active: return 0.0
 if elapsed<=hold: return peak
 var t:=clampf((elapsed-hold)/maxf(0.001,duration-hold),0.0,1.0)
 return peak*(1.0-t)*(1.0-t)

func apply_color(base: Color) -> Color:
 # Geometry hosts opt in per body draw, so unrelated warnings/shadows stay intact.
 # Match the existing RGB-only flash shader; host transparency is never owned.
 var mixed := base.lerp(tint,amount())
 return Color(mixed.r,mixed.g,mixed.b,base.a)
