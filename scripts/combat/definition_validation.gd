class_name DefinitionValidation
extends RefCounted
## Inspector hints are authoring aids; imported resources also need safe values.
static func nonnegative_floats(copy: Resource, defaults: Resource) -> void:
	for property: Dictionary in copy.get_property_list():
		if property.type != TYPE_FLOAT or not (int(property.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var value := float(copy.get(property.name))
		copy.set(property.name, maxf(0.0, value) if is_finite(value) else defaults.get(property.name))

static func rank_floats(values: PackedFloat32Array, maximum: float = INF) -> PackedFloat32Array:
	var result := values.duplicate()
	for index in range(result.size()):
		result[index] = clampf(result[index], 0.0, maximum) if is_finite(result[index]) else 0.0
	return result
