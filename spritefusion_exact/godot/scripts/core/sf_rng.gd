# Exact Sprite Fusion Mulberry32; never substitute Godot RandomNumberGenerator.
extends RefCounted
const JS = preload("res://scripts/core/sf_math.gd")
var s: int = 1

func _init(seed_value = 1) -> void:
	s = JS.u32(seed_value)
	if s == 0:
		s = 1

func next() -> float:
	s = (s + 0x6d2b79f5) & 0xffffffff
	var t: int = JS.u32(JS.imul(s ^ (s >> 15), s | 1))
	t = JS.u32(t ^ JS.u32(t + JS.imul(t ^ (t >> 7), t | 61)))
	return float(JS.u32(t ^ (t >> 14))) / 4294967296.0

func range(a: float, b: float) -> float:
	return a + (b - a) * next()

func integer(a: float, b: float) -> int:
	return int(floor(self.range(a, b + 1.0)))

func sign() -> int:
	return -1 if next() < 0.5 else 1

func chance(p: float) -> bool:
	return next() < p

func pick(values):
	return values[int(floor(next() * values.size()))]
