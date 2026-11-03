extends SceneTree
const VectorReader = preload("res://tests/core/read_vectors.gd")
const SourcePx = preload("res://scripts/core/sf_px_source.gd")
const FirePx = preload("res://scripts/core/sf_px_fire_source.gd")
const Frame = preload("res://scripts/core/sf_frame.gd")
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	var vectors = VectorReader.read("res://tests/core/core_vectors.json")
	for case in vectors.pixels:
		var f = Frame.new(int(case.frame.w), int(case.frame.h), case.frame.ox, case.frame.oy)
		var px = FirePx.new(f.as_source(), f.color.data) if case.source == "fire.ts" else SourcePx.new(f.as_source(), f.color.data)
		for snapshot in case.ops:
			var op: Array = snapshot.op
			px.callv("_sf_m_" + op[0], op.slice(1))
			for i in range(snapshot.expected.size()):
				assertions += 1
				if f.color.data[i] != int(snapshot.expected[i]):
					failures.append("%s origin=(%s,%s) %s pixel=%s got=%08x expected=%08x" % [case.source, f.ox, f.oy, op[0], i, f.color.data[i], int(snapshot.expected[i])])
					break
		assertions += 5
		if px._sf_f_w != f.w or px._sf_f_h != f.h or px._sf_f_ox != f.ox or px._sf_f_oy != f.oy or px._sf_f_data != f.color.data:
			failures.append("Source field getter mismatch")
	if failures.is_empty():
		print("SOURCE PX PASS: %s assertions, %s source/origin cases, 834 original TS raster snapshots" % [assertions, vectors.pixels.size()])
		quit(0)
	else:
		for failure in failures.slice(0, 30): printerr(failure)
		quit(1)
