class_name GameLocale
extends RefCounted
## Translation keys are presentation metadata, never gameplay identities.
const SUPPORTED := ["en", "zh_CN"]

static func system_locale(locale: String = OS.get_locale()) -> String:
	return "zh_CN" if locale.replace("-", "_").to_lower().get_slice("_", 0) == "zh" else "en"

static func text(key: String, arguments: Array = []) -> String:
	var translated := String(TranslationServer.translate(key))
	return translated % arguments if not arguments.is_empty() else translated

static func element_name(element: String) -> String:
	return text("ELEMENT_" + element.to_upper()) if element in ["fire", "lightning", "ice", "dark"] else text("ELEMENT_NONE")

static func bind(control: Control, key: String, arguments: Array = []) -> void:
	control.set_meta("translation_key", key)
	control.set_meta("translation_arguments", arguments.duplicate())
	control.set("text", text(key, arguments))
	TextFit.refit(control)

static func refresh_tree(node: Node) -> void:
	if node is Control and node.has_meta("translation_key"):
		bind(node, str(node.get_meta("translation_key")), node.get_meta("translation_arguments", []))
	for child in node.get_children(): refresh_tree(child)
