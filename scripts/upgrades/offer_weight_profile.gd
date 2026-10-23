class_name OfferWeightProfile
extends Resource
## All offer tuning lives in an authored resource, not per-card evaluator branches.
@export var base_weights: Dictionary = {}
@export var affinities: Dictionary = {}
@export var utility_rules: Dictionary = {}
@export var opening_bias: Dictionary = {}
@export var late_bias: Dictionary = {}
@export var affinity_min := 0.85
@export var affinity_max := 1.40
@export var total_min := 0.25
@export var total_max := 2.40
@export var owned_rank_bias := 1.10
@export var catchup_per_miss := 0.05
@export var exclusive_catchup_per_miss := 0.10
@export var catchup_miss_cap := 10
@export var recent_once := 0.85
@export var recent_twice := 0.75
@export var enchant_mass_ratio := 0.22
@export var consumable_mass_ratio := 0.20
@export var heal_weight := 20.0
@export var refill_weight := 16.0
@export var heal_deficit_bonus := 1.0
@export var refill_deficit_bonus := 0.5
@export var phase_opening_fraction := 0.20
@export var phase_late_fraction := 0.80

## Prevent a three-pivot forced replacement when a useful non-switch exists.
@export var max_switches_with_alternative := 2
