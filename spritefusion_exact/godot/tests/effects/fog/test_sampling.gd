extends SceneTree
# Compare the local fast path to the previous helper-based scalar expression.
# This is a focused regression, not a substitute for the saved-source full oracle.
const Fog = preload("res://scripts/effects/fog.gd")
const Frame = preload("res://scripts/core/sf_frame.gd")
const M = preload("res://scripts/core/sf_math.gd")
const BOUNDARY_BITS = [
	"000000000000f0ff",
	"00000000000040c3",
	"000000000000f0c1",
	"000020000000e0c1",
	"000000000000e0c1",
	"00000000000070c0",
	"00000000000060c0",
	"000000000000f0bf",
	"000000000000e0bf",
	"0000000000000080",
	"0000000000000000",
	"000000000000e03f",
	"000000000000f03f",
	"0000000000c05f40",
	"0000000000006040",
	"0000000000e06f40",
	"0000000000007040",
	"0000c0ffffffdf41",
	"000000000000e041",
	"000000000000f041",
	"0000000000004043",
	"000000000000f07f",
	"000000000000f87f",
	"010000000000e0c1",
	"ffffffffffffdfc1",
	"ffffbfffffffdf41",
	"0100c0ffffffdf41",
	"ffffffffffffdf41",
	"010000000000e041",
	"01000000000070c0",
	"ffffffffffff6fc0",
	"01000000000060c0",
	"ffffffffffff5fc0",
	"010000000000f0bf",
	"ffffffffffffefbf",
	"0100000000000080",
	"0100000000000000",
	"ffffffffffbf5f40",
	"0100000000c05f40",
	"ffffffffffff5f40",
	"0100000000006040",
	"ffffffffffdf6f40",
	"0100000000e06f40",
	"ffffffffffff6f40",
	"0100000000007040",
]
var failures: int = 0
var comparisons: int = 0
var state: int = 123456789

func next_word() -> int:
	state = (1664525 * state + 1013904223) & 0xffffffff
	return state

func bits(value: float) -> String:
	var bytes = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func same(a: float, b: float) -> bool:
	return (is_nan(a) and is_nan(b)) or bits(a) == bits(b)

func reference(field: PackedFloat32Array, u: float, v: float) -> float:
	var x: float = floor(u)
	var y: float = floor(v)
	var fx: float = u - x
	var fy: float = v - y
	var x0: int = M.i32(x) & (Fog.FW - 1)
	var x1: int = (x0 + 1) & (Fog.FW - 1)
	var y0: int = M.i32(y) & (Fog.FH - 1)
	var y1: int = (y0 + 1) & (Fog.FH - 1)
	var a: float = field[y0 * Fog.FW + x0]
	var b: float = field[y0 * Fog.FW + x1]
	var c: float = field[y1 * Fog.FW + x0]
	var d: float = field[y1 * Fog.FW + x1]
	return a + (b - a) * fx + (c - a + (a - b - c + d) * fx) * fy

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		if failures <= 8: printerr("FAIL ", label)

func compare(effect, u: float, v: float) -> void:
	comparisons += 1
	check(same(effect.sample_field(u, v), reference(effect.field, u, v)),
		"sample u=" + bits(u) + " v=" + bits(v))

func _initialize() -> void:
	var effect = Fog.new()
	var values = []
	for value in BOUNDARY_BITS: values.append(value.hex_decode().decode_double(0))
	for pattern in range(4):
		effect.field.resize(Fog.FW * Fog.FH)
		for i in range(effect.field.size()):
			match pattern:
				0: effect.field[i] = float(i) / 32768.0
				1: effect.field[i] = -1.0 if i & 1 else 1.0
				2: effect.field[i] = float(next_word()) / 4294967296.0
				3: effect.field[i] = (float(next_word()) / 4294967296.0 - 0.5) * 4096.0
		for u in values:
			for v in values: compare(effect, u, v)
		for i in range(4096):
			# Deterministic exact binary fractions, both normal and fallback domains.
			var scale: float = 1.0 if i & 1 else 1048576.0
			var u: float = (float(next_word()) - 2147483648.0) / 256.0 * scale
			var v: float = (float(next_word()) - 2147483648.0) / 512.0 * scale
			compare(effect, u, v)
	# Show the comparator rejects changed field contents rather than only NaNs.
	effect.field.fill(0.0)
	var before: float = effect.sample_field(0.0, 0.0)
	effect.field[0] = 1.0
	check(not same(before, effect.sample_field(0.0, 0.0)), "negative control")
	print("FOG_SAMPLING comparisons=", comparisons, " failures=", failures)
	quit(0 if failures == 0 else 1)
