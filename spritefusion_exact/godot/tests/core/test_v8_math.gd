extends SceneTree
const VectorReader = preload("res://tests/core/read_vectors.gd")
const V8 = preload("res://scripts/core/sf_v8_math.gd")

func bits(n: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, n)
	return b.hex_encode()

func _initialize() -> void:
	var input = VectorReader.read("res://tests/core/v8_trig_vectors.json")
	var failures := {"sin": 0, "cos": 0}
	var start: int = Time.get_ticks_usec()
	for c in input.cases:
		var a: float = c.a.hex_decode().decode_double(0)
		for method in failures:
			var actual: float = V8.sinv(a) if method == "sin" else V8.cosv(a)
			var expected: float = c[method].hex_decode().decode_double(0)
			# NaN payload is not observable in JS numeric semantics. Signed zero is.
			if not (is_nan(actual) and is_nan(expected)) and bits(actual) != c[method]:
				failures[method] += 1
				if failures[method] <= 4:
					printerr(method, " input=",c.a," actual=",bits(actual)," expected=",c[method])
	print("V8 TRIG: ",input.cases.size()," cases / ",input.cases.size() * 2," binary64 checks; differences=",failures," elapsed_ms=",(Time.get_ticks_usec()-start)/1000.0)
	quit(0 if failures.sin == 0 and failures.cos == 0 else 1)
