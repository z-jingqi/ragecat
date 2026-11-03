extends Node2D
## Caller-owned war state and one-shot revival decoration. No gameplay authority.
## Keep this folder beside VFX-20_shield_heal when copying the portable module.
const Aura := preload("aura.gd")
const Support := preload("../VFX-20_shield_heal/support.gd")
const WAR_PRESET := {"radius":29.0,"height":44.0,"thickness":1.0,"period":1.1,
	"particles":6,"rise_speed":.55,"brightness":.85,"enter":.12,
	"core":"e8c59c","body":"cf936d","edge":"82604f"}
const RETURN_PRESET := {"mode":"heal","radius":30.0,"height":34.0,"enter":.06,
	"sustain":.24,"exit":.28,"intensity":.78,"particles":10,"rise_speed":30.0,
	"plus_count":2,"plus_size":1,"body":"72bfa0","core":"d0e5b0","edge":"64a48a","plus":"b5e3b3"}
var aura := Aura.new()
var return_effect := Support.new()
var war_active := false
var paused := false
var last_revive_id := -1

func _init() -> void:
	aura.automatic = false
	aura.externally_sustained = true
	return_effect.automatic = false
	add_child(aura)
	add_child(return_effect)
	aura.set_process(false)
	return_effect.set_process(false)

func set_paused(value: bool) -> void:
	paused = value

func set_war(value: bool, world_anchor: Vector2, urgent: bool = false) -> void:
	if not value:
		war_active = false
		aura.clear()
		return
	if paused: return
	if not world_anchor.is_finite(): clear(); return
	if not war_active:
		return_effect.clear()
		aura.play(to_local(world_anchor),WAR_PRESET)
		war_active = true
	aura.anchor = to_local(world_anchor).round()
	# Subtle palette shift only. The game's quantitative meter remains authoritative.
	aura.config.body = "cb8469" if urgent else WAR_PRESET.body
	aura.config.core = "edb292" if urgent else WAR_PRESET.core
	aura.queue_redraw()

func revive(world_anchor: Vector2, event_id: int) -> bool:
	if paused or not world_anchor.is_finite() or event_id <= last_revive_id: return false
	last_revive_id = event_id
	war_active = false
	aura.clear()
	return_effect.play(to_local(world_anchor),RETURN_PRESET)
	return true

func tick(delta: float) -> void:
	if paused or not is_finite(delta) or delta <= 0: return
	aura.tick(delta)
	return_effect.tick(delta)

func clear() -> void:
	war_active = false
	paused = false
	last_revive_id = -1
	aura.clear()
	return_effect.clear()
