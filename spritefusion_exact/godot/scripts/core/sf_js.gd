# Native Godot compatibility helpers for the mechanically ported Sprite Fusion VFX.
# Source algorithms: MIT License, Copyright (c) 2026 Hugo Duprez.
# This file does not evaluate JavaScript or require a JavaScript runtime.
extends RefCounted

static var _property_names: Dictionary = {}

static func _has_property(obj: Object, key: String) -> bool:
	var tag = obj.get_script()
	if tag == null: tag = obj.get_class()
	if not _property_names.has(tag):
		var names = {}
		for prop in obj.get_property_list(): names[prop.name] = true
		_property_names[tag] = names
	return _property_names[tag].has(key)

static func is_array(v) -> bool:
	return typeof(v) in [TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY]

static func getv(obj, key):
	if obj == null:
		return null
	if obj is Dictionary:
		return obj.get(key, null)
	if is_array(obj) or obj is String:
		if key is String and key == "length":
			return obj.size() if is_array(obj) else obj.length()
		if key is int or key is float or str(key).is_valid_int():
			var index = int(key)
			if float(index) != float(key) or index < 0 or index >= (obj.size() if is_array(obj) else obj.length()):
				return null
			return obj[index]
		return null
	if obj is Object:
		var field = "_sf_f_" + str(key)
		var method = "_sf_m_" + str(key)
		if _has_property(obj, field): return obj.get(field)
		if obj.has_method(method): return Callable(obj, method)
		if _has_property(obj, str(key)): return obj.get(str(key))
		if obj.has_method(str(key)): return Callable(obj, str(key))
		return null
	return null

static func setv(obj, key, value):
	if obj is Dictionary:
		obj[key] = value
	elif is_array(obj):
		if key is String and key == "length":
			obj.resize(maxi(0, int(value)))
		elif key is int or key is float or str(key).is_valid_int():
			var index = int(key)
			if index >= 0 and float(index) == float(key):
				if index >= obj.size() and obj is Array:
					obj.resize(index + 1)
				if index < obj.size():
					obj[index] = _typed_value(obj, value)
	elif obj is Object:
		var field = "_sf_f_" + str(key)
		obj.set(field if _has_property(obj, field) else str(key), value)
	return value

# JS calls may supply extra callback parameters. Godot lambdas reject those,
# so only the callable's declared arity is passed. Missing JS arguments are null.
static func invoke(fn, args: Array = []):
	if not fn is Callable or not fn.is_valid():
		return null
	var arity = fn.get_argument_count()
	var passed = args.duplicate()
	if passed.size() > arity:
		passed.resize(arity)
	return fn.callv(passed)

static func truthy(value) -> bool:
	match typeof(value):
		TYPE_NIL: return false
		TYPE_BOOL: return value
		TYPE_INT: return value != 0
		TYPE_FLOAT: return value != 0.0 and not is_nan(value)
		TYPE_STRING: return not value.is_empty()
		_: return true

static func orv(a, b):
	return a if truthy(a) else b

static func andv(a, b):
	return b if truthy(a) else a

static func nullish(a, b):
	return b if a == null else a

static func typeofv(v) -> String:
	match typeof(v):
		TYPE_NIL: return "undefined"
		TYPE_BOOL: return "boolean"
		TYPE_INT, TYPE_FLOAT: return "number"
		TYPE_STRING: return "string"
		TYPE_CALLABLE: return "function"
		_: return "object"

static func numeric(v) -> float:
	if v == null:
		return 0.0
	if v is bool:
		return 1.0 if v else 0.0
	if v is int or v is float:
		return float(v)
	var s = str(v).strip_edges()
	if s.is_empty():
		return 0.0
	if s == "Infinity" or s == "+Infinity":
		return INF
	if s == "-Infinity":
		return -INF
	if s.begins_with("0x") or s.begins_with("0X"):
		return float(parse_int(s, 16))
	return float(s) if s.is_valid_float() else NAN

static func roundv(v) -> float:
	var n = numeric(v)
	if not is_finite(n) or n == 0.0:
		return n
	var lower = floor(n)
	return lower + 1.0 if n - lower >= 0.5 else lower

static func u32(v) -> int:
	var n = numeric(v)
	if not is_finite(n) or n == 0.0:
		return 0
	# Integer inputs can be reduced without losing bits to a float conversion.
	if v is int:
		return v & 0xffffffff
	n = ceil(n) if n < 0.0 else floor(n)
	return int(fposmod(n, 4294967296.0))

static func i32(v) -> int:
	var n = u32(v)
	return n - 4294967296 if n >= 2147483648 else n

static func ushr(a, b) -> int:
	return u32(a) >> (u32(b) & 31)

static func shl(a, b) -> int:
	return i32(u32(a) << (u32(b) & 31))

static func shr(a, b) -> int:
	return i32(a) >> (u32(b) & 31)

static func imul(a, b) -> int:
	var aa = u32(a)
	var bb = u32(b)
	var lo = (aa & 65535) * (bb & 65535)
	var hi = (((aa >> 16) * (bb & 65535) + (aa & 65535) * (bb >> 16)) & 65535) << 16
	return i32(lo + hi)

static func opmod(a, b) -> float:
	var aa = numeric(a)
	var bb = numeric(b)
	if is_nan(aa) or is_nan(bb) or is_inf(aa) or bb == 0.0:
		return NAN
	if is_inf(bb) or aa == 0.0:
		return aa
	return fmod(aa, bb)

static func parse_int(value, radix = 0):
	var s = str(value).strip_edges()
	var sign_value = 1
	if s.begins_with("-") or s.begins_with("+"):
		sign_value = -1 if s.begins_with("-") else 1
		s = s.substr(1)
	var base = i32(radix)
	if base != 0 and (base < 2 or base > 36):
		return NAN
	if base == 0:
		base = 16 if s.to_lower().begins_with("0x") else 10
	if base == 16 and s.to_lower().begins_with("0x"):
		s = s.substr(2)
	var result = 0.0
	var digits = 0
	for ch in s.to_lower():
		var d = "0123456789abcdefghijklmnopqrstuvwxyz".find(ch)
		if d < 0 or d >= base:
			break
		result = result * base + d
		digits += 1
	return result * sign_value if digits > 0 else NAN

static func array_from(length_or_source, callback = null) -> Array:
	var source = length_or_source
	var length = 0
	if source is Dictionary:
		length = maxi(0, int(source.get("length", 0)))
	elif source is String:
		length = source.length()
	elif is_array(source):
		length = source.size()
	else:
		length = maxi(0, int(source))
	var result: Array = []
	for i in range(length):
		var value = getv(source, i) if is_array(source) or source is String else null
		result.append(invoke(callback, [value, i]) if callback != null else value)
	return result

static func _index(value, size: int) -> int:
	var n = numeric(value)
	if is_nan(n):
		return 0
	if n == INF:
		return size
	if n == -INF:
		return 0
	var i = int(n)
	return maxi(0, size + i) if i < 0 else mini(size, i)

static func _to_array(value) -> Array:
	if value is Array:
		return value
	var result: Array = []
	for item in value:
		result.append(item)
	return result

static func call_method(obj, key, args: Array = []):
	if obj == null:
		return null
	if obj is Dictionary:
		return invoke(obj.get(key, null), args)
	if obj is Callable and str(key) == "call":
		return invoke(obj, args.slice(1))
	if is_array(obj):
		return _array_call(obj, str(key), args)
	if obj is String:
		return _string_call(obj, str(key), args)
	if (obj is float or obj is int) and str(key) == "toFixed":
		return ("%.*f" % [int(args[0]) if not args.is_empty() else 0, float(obj)])
	if obj is Object:
		if obj.has_method("_sf_m_" + str(key)):
			return obj.callv("_sf_m_" + str(key), args)
		if _has_property(obj, "_sf_f_" + str(key)):
			return invoke(obj.get("_sf_f_" + str(key)), args)
		if obj.has_method("sf_" + str(key)):
			return obj.callv("sf_" + str(key), args)
		if obj.has_method(str(key)):
			return obj.callv(str(key), args)
		return invoke(obj.get(str(key)), args) if _has_property(obj, str(key)) else null
	return null

static func _array_call(obj, key: String, args: Array):
	match key:
		"push":
			for value in args: obj.append(value)
			return obj.size()
		"pop":
			return obj.pop_back() if obj.size() > 0 else null
		"unshift":
			for i in range(args.size() - 1, -1, -1): obj.insert(0, args[i])
			return obj.size()
		"shift":
			if obj.size() == 0: return null
			var value = obj[0]
			obj.remove_at(0)
			return value
		"splice":
			if args.is_empty(): return []
			var start = _index(args[0], obj.size())
			var remove_count = obj.size() - start if args.size() < 2 else mini(obj.size() - start, maxi(0, int(numeric(args[1]))))
			var removed: Array = []
			for i in range(remove_count):
				removed.append(obj[start])
				obj.remove_at(start)
			for i in range(2, args.size()): obj.insert(start + i - 2, args[i])
			return removed
		"slice":
			var start = _index(args[0], obj.size()) if args.size() > 0 else 0
			var end = _index(args[1], obj.size()) if args.size() > 1 else obj.size()
			var result: Array = []
			for i in range(start, maxi(start, end)): result.append(obj[i])
			return result
		"map", "filter", "forEach", "some", "every", "find", "findIndex":
			var result: Array = []
			var original_length = obj.size()
			for i in range(original_length):
				if i >= obj.size(): continue
				var value = obj[i]
				var mapped = invoke(args[0], [value, i, obj])
				if key == "map": result.append(mapped)
				elif key == "filter" and truthy(mapped): result.append(value)
				elif key == "some" and truthy(mapped): return true
				elif key == "every" and not truthy(mapped): return false
				elif key == "find" and truthy(mapped): return value
				elif key == "findIndex" and truthy(mapped): return i
			if key == "some": return false
			if key == "every": return true
			if key == "find": return null
			if key == "findIndex": return -1
			return null if key == "forEach" else result
		"entries":
			var result: Array = []
			for i in range(obj.size()): result.append([i, obj[i]])
			return result
		"keys":
			return range(obj.size())
		"values":
			return _to_array(obj).duplicate()
		"fill":
			var start = _index(args[1], obj.size()) if args.size() > 1 else 0
			var end = _index(args[2], obj.size()) if args.size() > 2 else obj.size()
			for i in range(start, maxi(start, end)): obj[i] = _typed_value(obj, args[0])
			return obj
		"reverse":
			obj.reverse()
			return obj
		"sort":
			# Stable insertion sort preserves equal elements, as ES2019 requires.
			var cmp = args[0] if not args.is_empty() else null
			for i in range(1, obj.size()):
				var value = obj[i]
				var j = i - 1
				while j >= 0:
					var c = numeric(invoke(cmp, [obj[j], value])) if cmp != null else (1.0 if str(obj[j]) > str(value) else -1.0)
					if is_nan(c) or c <= 0: break
					obj[j + 1] = obj[j]
					j -= 1
				obj[j + 1] = value
			return obj
		"includes", "indexOf", "lastIndexOf":
			var target = args[0]
			var start = 0
			if key == "lastIndexOf":
				start = obj.size() - 1 if args.size() < 2 else int(args[1])
				if start < 0: start = obj.size() + start
				start = mini(start, obj.size() - 1)
			else:
				start = int(args[1]) if args.size() > 1 else 0
				if start < 0: start = maxi(0, obj.size() + start)
			var indices = range(start, -1, -1) if key == "lastIndexOf" else range(start, obj.size())
			for i in indices:
				var equal = obj[i] == target
				if key == "includes" and obj[i] is float and target is float and is_nan(obj[i]) and is_nan(target): equal = true
				if equal: return true if key == "includes" else i
			return false if key == "includes" else -1
		"concat":
			var result = _to_array(obj).duplicate()
			for arg in args:
				if is_array(arg): result.append_array(_to_array(arg))
				else: result.append(arg)
			return result
		"join":
			var sep = str(args[0]) if not args.is_empty() else ","
			var parts = PackedStringArray()
			for arg in obj: parts.append("" if arg == null else str(arg))
			return sep.join(parts)
		"reduce":
			var start = 1 if args.size() < 2 else 0
			var acc = obj[0] if args.size() < 2 and obj.size() > 0 else (args[1] if args.size() > 1 else null)
			for i in range(start, obj.size()): acc = invoke(args[0], [acc, obj[i], i, obj])
			return acc
	return null

static func _string_call(obj: String, key: String, args: Array):
	match key:
		"replace":
			var pattern = str(args[0])
			var index = obj.find(pattern)
			return obj if index < 0 else obj.substr(0, index) + str(args[1]) + obj.substr(index + pattern.length())
		"replaceAll": return obj.replace(str(args[0]), str(args[1]))
		"slice":
			var start = _index(args[0], obj.length()) if not args.is_empty() else 0
			var end = _index(args[1], obj.length()) if args.size() > 1 else obj.length()
			return obj.substr(start, maxi(0, end - start))
		"substring":
			var a = clampi(int(args[0]), 0, obj.length()) if not args.is_empty() else 0
			var b = clampi(int(args[1]), 0, obj.length()) if args.size() > 1 else obj.length()
			return obj.substr(mini(a, b), absi(a - b))
		"charAt":
			var i = int(args[0]) if not args.is_empty() else 0
			return obj[i] if i >= 0 and i < obj.length() else ""
		"charCodeAt":
			var i = int(args[0]) if not args.is_empty() else 0
			return obj.unicode_at(i) if i >= 0 and i < obj.length() else NAN
		"split": return _to_array(obj.split(str(args[0]), true)) if not args.is_empty() else [obj]
		"includes": return obj.find(str(args[0]), int(args[1]) if args.size() > 1 else 0) >= 0
		"indexOf": return obj.find(str(args[0]), int(args[1]) if args.size() > 1 else 0)
		"startsWith": return obj.substr(int(args[1]) if args.size() > 1 else 0).begins_with(str(args[0]))
		"endsWith": return obj.substr(0, int(args[1]) if args.size() > 1 else obj.length()).ends_with(str(args[0]))
		"toLowerCase": return obj.to_lower()
		"toUpperCase": return obj.to_upper()
		"trim": return obj.strip_edges()
	return null

static func new_array(count) -> Array:
	if is_array(count): return _to_array(count).duplicate()
	var result: Array = []
	result.resize(maxi(0, int(count)))
	result.fill(0)
	return result

static func array_concat(arrays: Array) -> Array:
	var result: Array = []
	for array in arrays:
		result.append_array(_to_array(array))
	return result

static func object_merge(objects: Array) -> Dictionary:
	var result = {}
	for obj in objects:
		if obj is Dictionary: result.merge(obj, true)
	return result

static func set_length(array, length):
	array.resize(maxi(0, int(length)))
	return length

static func band(a, b) -> int:
	return i32(i32(a) & i32(b))

static func bor(a, b) -> int:
	return i32(i32(a) | i32(b))

static func bxor(a, b) -> int:
	return i32(i32(a) ^ i32(b))

static func bnot(a) -> int:
	return i32(~i32(a))

# V8's Math.hypot scales by the largest input and sums squared ratios.
# Keep the 2- and 3-argument paths distinct to match its operation order.
static func hypotv(args: Array) -> float:
	if args.is_empty(): return 0.0
	if args.size() == 1: return absf(numeric(args[0]))
	var values: Array = []
	var largest = 0.0
	var has_nan = false
	for arg in args:
		var value = absf(numeric(arg))
		values.append(value)
		if is_nan(value): has_nan = true
		elif value > largest: largest = value
	if is_inf(largest): return INF
	if has_nan: return NAN
	if largest == 0.0: return 0.0
	if values.size() == 2:
		var a = values[0] / largest
		var b = values[1] / largest
		return sqrt(a * a + b * b) * largest
	if values.size() == 3:
		var a = values[0] / largest
		var b = values[1] / largest
		var c = values[2] / largest
		var pa = a * a
		var pb = b * b
		var compensation = (pa + pb) - pa - pb
		var pc = c * c - compensation
		return sqrt(pa + pb + pc) * largest
	var total = 0.0
	var compensation = 0.0
	for value in values:
		var n = value / largest
		var summand = n * n - compensation
		var preliminary = total + summand
		compensation = (preliminary - total) - summand
		total = preliminary
	return sqrt(total) * largest

static func _words(value) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes

static func _from_words(high: int, low: int) -> float:
	var bytes = PackedByteArray()
	bytes.resize(8)
	bytes.encode_u32(0, low & 0xffffffff)
	bytes.encode_u32(4, high & 0xffffffff)
	return bytes.decode_double(0)

# Cube-root arithmetic adapted from V8 13.6's fdlibm implementation.
# Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
# Developed at SunSoft, a Sun Microsystems, Inc. business.
# Permission to use, copy, modify, and distribute this software is freely
# granted, provided that this notice is preserved.
# Modified significantly by Google Inc. Copyright 2016 the V8 project authors.
# https://github.com/v8/v8/blob/13.6.233/src/base/ieee754.cc
static func cbrtv(value) -> float:
	var x = numeric(value)
	var bytes = _words(x)
	var high = bytes.decode_u32(4)
	var low = bytes.decode_u32(0)
	var sign_bit = high & 0x80000000
	var hx = high ^ sign_bit
	if hx >= 0x7ff00000: return x + x
	var t = 0.0
	if hx < 0x00100000:
		if (hx | low) == 0: return x
		t = _from_words(0x43500000, 0) * x
		high = _words(t).decode_u32(4)
		t = _from_words(sign_bit | (floori(float(high & 0x7fffffff) / 3.0) + 696219795), 0)
	else:
		t = _from_words(sign_bit | (floori(float(hx) / 3.0) + 715094163), 0)
	var r = (t * t) * (t / x)
	t = t * ((1.87595182427177009643 + r * (-1.88497979543377169875 + r * 1.621429720105354466140)) + ((r * r) * r) * (-0.758397934778766047437 + r * 0.145996192886612446982))
	bytes = _words(t)
	var bits = (bytes.decode_s64(0) + 0x80000000) & -1073741824
	bytes.encode_s64(0, bits)
	t = bytes.decode_double(0)
	var s = t * t
	r = x / s
	var w = t + t
	r = (r - t) / (w + r)
	return t + t * r

static func maxv(values: Array) -> float:
	var result = -INF
	for value in values:
		var n = numeric(value)
		if is_nan(n): return NAN
		if n > result: result = n
	return result

static func minv(values: Array) -> float:
	var result = INF
	for value in values:
		var n = numeric(value)
		if is_nan(n): return NAN
		if n < result: result = n
	return result

static func math_max(values: Array) -> float:
	return maxv(values)

static func math_min(values: Array) -> float:
	return minv(values)

# GDScript reference counting does not collect the mutually capturing closures
# that JavaScript's tracing collector reclaims. Only explicitly marked factory
# scope dictionaries are cleared, and only after the effect is disposed.
static func release_scopes(value) -> void:
	var seen: Array = []
	var scopes: Array = []
	_collect_scopes(value, seen, scopes)
	for item in seen:
		if item is Object and item.has_method("_sf_release"):
			item.call("_sf_release")
	for scope in scopes:
		scope.clear()

static func _collect_scopes(value, seen: Array, scopes: Array) -> void:
	if not (value is Dictionary or value is Array or value is Object): return
	for prior in seen:
		if is_same(value, prior): return
	seen.append(value)
	if value is Dictionary:
		if value.get("_sf_capture_scope", false) == true: scopes.append(value)
		for child in value.values(): _collect_scopes(child, seen, scopes)
	elif value is Array:
		for child in value: _collect_scopes(child, seen, scopes)
	elif value is Object:
		for property in value.get_property_list():
			if str(property.name).begins_with("_sf_f_"):
				_collect_scopes(value.get(property.name), seen, scopes)

static func clear_property_cache() -> void:
	_property_names.clear()

static func _typed_value(array, value):
	if array is PackedInt64Array: return u32(value)
	if array is PackedInt32Array: return i32(value)
	if array is PackedByteArray: return u32(value) & 255
	if array is PackedFloat32Array or array is PackedFloat64Array: return numeric(value)
	return value

static func typed_array(kind: String, value: Variant = 0):
	var result
	match kind:
		"Uint32Array": result = PackedInt64Array()
		"Uint8Array": result = PackedByteArray()
		"Int32Array": result = PackedInt32Array()
		"Float32Array": result = PackedFloat32Array()
		"Float64Array": result = PackedFloat64Array()
		_: return new_array(value)
	if is_array(value):
		result.resize(value.size())
		for i in range(value.size()): result[i] = _typed_value(result, value[i])
	else:
		result.resize(maxi(0, int(value)))
		result.fill(0)
	return result
