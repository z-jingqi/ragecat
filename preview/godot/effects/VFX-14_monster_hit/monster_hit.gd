extends Node2D
## Per-host composition. No health, movement, or combat targeting is owned here.
const Flash = preload("res://effects/VFX-05_hit_flash/flash_state.gd")
const FlashShader = preload("res://effects/VFX-05_hit_flash/flash.gdshader")
const Impact = preload("res://effects/VFX-14_monster_hit/blood.gd")
var flash = Flash.new()
var host: Sprite2D
var original_material: Material
var owned_material: ShaderMaterial
var impacts: Array[Node2D] = []
var cursor := 0
var hit_serial := 0
var auto_tick := true
var paused := false
var impact_enabled := true
var flash_enabled := true
var impact_settings := Impact.sanitized({})
var flash_interval := 0.18
var flash_cooldown := 0.0

func _init()->void:
 flash.configure({"peak":0.2,"hold":0.008})

func bind(sprite: Sprite2D) -> void:
 clear()
 host = sprite

func configure(values: Dictionary) -> void:
 flash.configure(values)
 if values.has("flash_interval") and (values.flash_interval is float or values.flash_interval is int) and is_finite(float(values.flash_interval)):
  flash_interval=clampf(float(values.flash_interval),0.0,1.0)
 if values.has("impact_enabled"): impact_enabled = bool(values.impact_enabled)
 if values.has("flash_enabled"): flash_enabled = bool(values.flash_enabled)
 if values.has("impact") and values.impact is Dictionary:
  impact_settings = Impact.sanitized(values.impact)

func hit(world_contact: Vector2, incoming: Vector2) -> bool:
 if not is_instance_valid(host) or not world_contact.is_finite(): return false
 if flash_enabled and flash_cooldown<=0.0 and not flash.active:
  flash_cooldown=flash_interval
  if not flash.active:
   original_material = host.material
   owned_material = ShaderMaterial.new()
   owned_material.shader = FlashShader
   host.material = owned_material
  flash.trigger()
  _apply_flash()
 if impact_enabled:
  if impacts.size()<4:
   var player=Impact.new();add_child(player);impacts.append(player)
  var p=impacts[cursor % impacts.size()]
  # Contact is independent of the host. Impacts do not follow a moving target.
  var emission=impact_settings.duplicate()
  emission.seed=int(emission.seed)+hit_serial
  hit_serial+=1
  p.play(to_local(world_contact),incoming,emission)
  cursor=(cursor+1)%4
 return true

func _restore_material() -> void:
 if is_instance_valid(host) and host.material == owned_material:
  host.material = original_material
 owned_material=null
 original_material=null

func _apply_flash() -> void:
 if not is_instance_valid(host):
  flash.reset();_restore_material();return
 if owned_material != null:
  owned_material.set_shader_parameter("amount",flash.amount())
  owned_material.set_shader_parameter("flash_color",flash.tint)
 if not flash.active: _restore_material()

func tick(dt: float) -> void:
 if paused or not is_finite(dt) or dt<=0.0:return
 if not is_instance_valid(host):
  clear();return
 flash_cooldown=maxf(0,flash_cooldown-dt)
 flash.tick(dt);_apply_flash()
 for p in impacts:p.tick(dt)

func clear() -> void:
 flash.reset();_restore_material();paused=false;cursor=0;hit_serial=0;flash_cooldown=0.0
 for p in impacts:p.clear()

func active_count() -> int:
 var count:=0
 for p in impacts:
  if p.active:count+=1
 return count

func _process(dt:float)->void:
 if auto_tick:tick(dt)
func _exit_tree()->void:clear()
