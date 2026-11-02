extends Node2D
## Per-host composition. No health, movement, or combat targeting is owned here.
const Flash = preload("res://effects/VFX-05_hit_flash/flash_state.gd")
const FlashShader = preload("res://effects/VFX-05_hit_flash/flash.gdshader")
const Impact = preload("res://effects/VFX-04_hit_impact/impact.gd")
var flash = Flash.new()
var host: Sprite2D
var original_material: Material
var owned_material: ShaderMaterial
var impacts: Array[Node2D] = []
var cursor := 0
var auto_tick := true
var paused := false
var impact_enabled := true
var flash_enabled := true
var impact_settings := {"size":0.62,"coreSize":4.0,"shardCount":4,"shardLength":6.0,"speed":65.0,"duration":0.16,"spreadDegrees":100.0,"seed":23}

func bind(sprite: Sprite2D) -> void:
 clear()
 host = sprite

func configure(values: Dictionary) -> void:
 flash.configure(values)
 if values.has("impact_enabled"): impact_enabled = bool(values.impact_enabled)
 if values.has("flash_enabled"): flash_enabled = bool(values.flash_enabled)
 if values.has("impact") and values.impact is Dictionary:
  impact_settings = Impact.sanitized(values.impact)

func hit(world_contact: Vector2, incoming: Vector2) -> bool:
 if not is_instance_valid(host) or not world_contact.is_finite(): return false
 if flash_enabled:
  if not flash.active:
   original_material = host.material
   owned_material = ShaderMaterial.new()
   owned_material.shader = FlashShader
   host.material = owned_material
  flash.trigger()
  _apply_flash()
 if impact_enabled:
  if impacts.size()<4:
   var player=Impact.new();player.auto_tick=false;add_child(player);impacts.append(player)
  var p=impacts[cursor % impacts.size()]
  # Contact is independent of the host. Impacts do not follow a moving target.
  p.play(to_local(world_contact),incoming,impact_settings)
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
 flash.tick(dt);_apply_flash()
 for p in impacts:p.tick(dt)

func clear() -> void:
 flash.reset();_restore_material();paused=false;cursor=0
 for p in impacts:p.clear()

func active_count() -> int:
 var count:=0
 for p in impacts:
  if p.active:count+=1
 return count

func _process(dt:float)->void:
 if auto_tick:tick(dt)
func _exit_tree()->void:clear()
