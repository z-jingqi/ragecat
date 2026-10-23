extends SceneTree
## Canonical Chinese names and semantic English names share stable presentation keys.
var checks := 0
var failures := 0
const NAMES := {
	"NAME_ARCHER": ["Archer", "羿"],
	"NAME_MOUNTAINBREAKER": ["Mountainbreaker", "穷奇"],
	"NAME_HORNLING": ["Hornling", "土蝼"],
	"NAME_SPITTER": ["Spitter", "幼蛊雕"],
	"NAME_BEASTCALLER": ["Beastcaller", "讙"],
	"NAME_WILDFIRE": ["Wildfire", "毕方"],
	"NAME_SWIFTFANG": ["Swiftfang", "狡"],
	"NAME_ELITE_HORNLING": ["Elite Hornling", "精英土蝼"],
}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var font := load("res://resources/fonts/ragecat-ui-subset.otf") as FontFile
	font.allow_system_fallback = false
	var locales := ["en", "zh_CN"]
	for index in range(locales.size()):
		var locale: String = locales[index]
		var catalog := load("res://resources/localization/" + locale + ".po") as Translation
		TranslationServer.set_locale(locale)
		for key: String in NAMES:
			check(String(catalog.get_message(key)) == NAMES[key][index], locale + " exact canonical entity name " + key)
			check(GameLocale.text(key) == NAMES[key][index], locale + " resolves live entity name " + key)
		# Font coverage is checked across the entire shipped catalog, not just new names.
		var seen := {}
		for key in catalog.get_message_list():
			for character in String(catalog.get_message(key)):
				var cp := character.unicode_at(0)
				if cp <= 32 or seen.has(cp): continue
				seen[cp] = true
				check(font.has_char(cp), locale + " portable glyph U+%04X" % cp)
		for key in ["LAB_MOB", "LAB_RANGED", "LAB_BOSS"]:
			check(not catalog.get_message_list().has(key), "No duplicate entity name source " + key)
	check(ProjectSettings.get_setting("application/config/name") == "Rage Cat", "Game title is unchanged")
	print("ENTITY NAME LOCALIZATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
