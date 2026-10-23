class_name OfferRunState
extends RefCounted
## A run owns this object. Catalog/stat rebuilds and UI rendering must not own it.
const SEED_SALT: int = 0x524147454F464631
var profile: OfferWeightProfile = preload("res://resources/settings/offer_weights.tres")
var rng := RandomNumberGenerator.new()
var serial := 0
var misses: Dictionary = {}
var recent: Array = []
var pending: Dictionary = {}

func reset(run_seed: int) -> void:
	rng.seed = run_seed ^ SEED_SALT
	serial = 0
	misses.clear()
	recent.clear()
	pending.clear()

func resolve_offer() -> void:
	pending.clear()

func snapshot() -> Dictionary:
	return {"rng_state":rng.state, "rng_seed":rng.seed, "serial":serial, "misses":misses.duplicate(true), "recent":recent.duplicate(true), "pending":pending.duplicate(true)}

func restore(saved: Dictionary) -> void:
	rng.seed = int(saved.get("rng_seed", 0))
	rng.state = int(saved.get("rng_state", rng.state))
	serial = int(saved.get("serial", 0))
	misses = saved.get("misses", {}).duplicate(true)
	recent = saved.get("recent", []).duplicate(true)
	pending = saved.get("pending", {}).duplicate(true)
