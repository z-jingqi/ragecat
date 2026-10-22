class_name FeedbackEvent
extends RefCounted
## Explicit damage provenance, never inferred from damage amount or popup label.
enum Source { UNKNOWN, DIRECT, BLAST, CHAIN, BURN, GRAVITY }
var source: Source = Source.UNKNOWN
var position := Vector2.ZERO
var direction := Vector2.RIGHT
var critical: bool = false
var element: String = ""
var shattered: bool = false
var actual_damage: float = 0.0
var enemy_id: int = 0

static func impact(kind: Source, at: Vector2, axis: Vector2 = Vector2.RIGHT) -> FeedbackEvent:
	var event := FeedbackEvent.new()
	event.source = kind
	event.position = at
	event.direction = axis.normalized() if axis.is_finite() and not axis.is_zero_approx() else Vector2.RIGHT
	return event

func has_movement_reaction() -> bool:
	return source in [Source.DIRECT, Source.BLAST, Source.CHAIN]

func is_dot() -> bool:
	return source in [Source.BURN, Source.GRAVITY]
