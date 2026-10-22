class_name TextFit
extends RefCounted
## Event-driven glyph measurement in logical pixels. Never shrink beneath floors.
## Controls wrap/grow; their owning ScrollContainer is the final overflow fallback.
const BODY_MIN := 14
const ACTION_MIN := 16
var target: WeakRef
var maximum := 18
var minimum := BODY_MIN
var preferred_height := 0.0
var _pending := false
var _last_signature := ""

static func attach(control: Control, max_font: int = 18, min_font: int = BODY_MIN, height_budget: float = 0.0) -> void:
	if control.has_meta("text_fit"):
		var previous: TextFit = control.get_meta("text_fit")
		if control.resized.is_connected(previous.request_fit): control.resized.disconnect(previous.request_fit)
	var fitter := TextFit.new()
	fitter.target = weakref(control)
	fitter.maximum = maxi(max_font, min_font)
	fitter.minimum = min_font
	fitter.preferred_height = height_budget
	control.set_meta("text_fit", fitter)
	if control is Label:
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	elif control is Button:
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	control.resized.connect(fitter.request_fit)
	fitter.request_fit()

static func refit(control: Control) -> void:
	if control.has_meta("text_fit"):
		var fitter: TextFit = control.get_meta("text_fit")
		fitter.request_fit()

func request_fit() -> void:
	if _pending: return
	_pending = true
	call_deferred("_fit")

func _fit() -> void:
	_pending = false
	var control := target.get_ref() as Control
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	var width := control.size.x
	var padding := Vector2.ZERO
	var icon_height := 0.0
	if control is Button:
		var style := control.get_theme_stylebox("normal")
		padding = style.get_minimum_size()
		var icon_width := 0.0
		if control.icon != null:
			icon_width = control.icon.get_width()
			icon_height = control.icon.get_height()
		if control is CheckButton or control is CheckBox:
			for key in ["checked", "unchecked"]:
				var indicator := control.get_theme_icon(key)
				icon_width = maxf(icon_width, indicator.get_width())
				icon_height = maxf(icon_height, indicator.get_height())
		if icon_width > 0: padding.x += icon_width + control.get_theme_constant("h_separation")
		width -= padding.x
	if width <= 1.0: return
	var content := str(control.get("text"))
	var font := control.get_theme_font("font")
	var signature := "%s|%s|%s|%s|%s" % [content, width, maximum, minimum, preferred_height]
	if signature == _last_signature: return
	_last_signature = signature
	var chosen := maximum
	# Allow normal wrapping first, then reduce within the readable range only
	# when content exceeds its preferred height or a single glyph cannot fit.
	while chosen > minimum:
		var measured := font.get_multiline_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, width, chosen, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		if (preferred_height <= 0.0 or measured.y + padding.y <= preferred_height) and measured.x <= width + 1.0: break
		chosen -= 1
	control.add_theme_font_size_override("font_size", chosen)
	var measured := font.get_multiline_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, width, chosen, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	# Explicit height also handles the first frame before native wrap layout.
	control.custom_minimum_size.y = maxf(maxf(measured.y, icon_height) + padding.y, 44.0 if control is Button else 0.0)
