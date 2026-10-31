extends Resource
## Two distinct, finite visual recipes. No health, experience or actor state.
enum Mode { HEAL, LEVEL_UP }
@export_group("Mode")
@export_range(0,1,1) var mode: int = Mode.HEAL
@export_group("Shape")
@export_range(0.25,3,0.05) var size := 1.0
@export_range(-180,180,1) var direction_degrees := 0.0
@export_range(0.25,2,0.05) var intensity := 1.0
@export var seed_value := 307
@export_range(120,360,5) var height := 270.0
@export_range(65,180,5) var spread := 115.0
@export_range(12,50,1) var ribbon_width := 30.0
@export_range(0,2,0.05) var curl := 1.0
@export_range(0,7,1) var glyph_count := 5
@export_range(9,30,1) var glyph_size := 18.0
@export_range(0,2,0.05) var rise_speed := 1.0
@export_range(0,3,0.05) var flow_speed := 1.0
@export_group("Timing")
@export_range(0.4,2,0.05) var duration_scale := 1.0
@export_range(0.1,0.6,0.01) var gather_seconds := 0.25
@export_range(0.2,0.9,0.01) var bloom_seconds := 0.55
@export_range(0.15,1.5,0.01) var sustain_seconds := 0.65
@export_range(0.3,1,0.01) var release_seconds := 0.65
@export_group("Independent layers")
@export var show_arcs := true
@export var show_ribbons := true
@export var show_highlights := true
@export var show_glyphs := true
@export var show_chevrons := true
@export var show_star := true
@export var show_streaks := true
@export var show_motes := true
@export_group("Heal flat cel palette")
@export var heal_shadow_color := Color("319365")
@export var heal_body_color := Color("82cc95")
@export var heal_highlight_color := Color("edf5bc")
@export var heal_glyph_color := Color("f5f5c9")
@export_group("Level-up flat cel palette")
@export var level_shadow_color := Color("c18d31")
@export var level_body_color := Color("edbf55")
@export var level_highlight_color := Color("ffe9a4")
@export var level_glyph_color := Color("fff2bf")

func sanitize() -> void:
	mode = clampi(mode,Mode.HEAL,Mode.LEVEL_UP)
	glyph_count = clampi(glyph_count,0,7)
	for spec in [["size",0.25,3.0,1.0],["direction_degrees",-180.0,180.0,0.0],["intensity",0.25,2.0,1.0],["height",120.0,360.0,270.0],["spread",65.0,180.0,115.0],["ribbon_width",12.0,50.0,30.0],["curl",0.0,2.0,1.0],["glyph_size",9.0,30.0,18.0],["rise_speed",0.0,2.0,1.0],["flow_speed",0.0,3.0,1.0],["duration_scale",0.4,2.0,1.0],["gather_seconds",0.1,0.6,0.25],["bloom_seconds",0.2,0.9,0.55],["sustain_seconds",0.15,1.5,0.65],["release_seconds",0.3,1.0,0.65]]:
		var value: float = get(spec[0])
		set(spec[0],clampf(value,spec[1],spec[2]) if is_finite(value) else spec[3])
	for spec in [["heal_shadow_color",Color("319365")],["heal_body_color",Color("82cc95")],["heal_highlight_color",Color("edf5bc")],["heal_glyph_color",Color("f5f5c9")],["level_shadow_color",Color("c18d31")],["level_body_color",Color("edbf55")],["level_highlight_color",Color("ffe9a4")],["level_glyph_color",Color("fff2bf")]]:
		var color: Color = get(spec[0])
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): color = spec[1]
		set(spec[0],Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1.0))

func duration() -> float:
	return (gather_seconds+bloom_seconds+sustain_seconds+release_seconds+0.04)*duration_scale
