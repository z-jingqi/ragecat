extends Node2D
const Profile = preload("slash_profile.gd")
var profile = Profile.new()
var elapsed := 0.0
var started := false
var enabled := true

func play(origin := Vector2.ZERO, configuration: Resource = null) -> void:
	if not origin.is_finite():
		clear()
		return
	position = origin
	profile = (configuration if configuration is Profile else Profile.new()).sanitized()
	elapsed = 0.0
	started = true
	_rebuild()
	_refresh()

func seek(seconds: float) -> void:
	if not started or not is_finite(seconds): return
	elapsed = maxf(0.0,seconds)
	_refresh()

func advance(delta: float) -> void:
	if is_finite(delta) and delta >= 0.0: seek(elapsed+delta)

func set_enabled(value: bool) -> void:
	enabled = value
	_refresh()

func clear() -> void:
	started = false
	elapsed = 0.0
	_refresh()

func stop() -> void:
	clear()

func lifetime() -> float:
	return profile.duration

func is_running() -> bool:
	return started and elapsed < lifetime()

func _rebuild() -> void:
	pass

func _refresh() -> void:
	visible = started and enabled and elapsed > 0.0 and elapsed < lifetime() and profile.intensity > 0.0
	queue_redraw()
