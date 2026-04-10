@tool
class_name Attribute
extends Resource

## Represents an attribute or skill or stat as a class

@export var attribute_name: String = "":
	set(val):
		attribute_name = val
		change_resource_name_to_attribute()



@export_enum("Attribute", "Skill", "Stat", "Track") var attribute_type: int


# Values


@export var current_value: int = 0

@export var base_value: int = 0

@export var maximum_value: int = 1

@export var minimum_value: int = 0

@export var modifiers: Array[int]

@export var maximum_modifiers: Array[int] = []

@export var tags: Array[String] = []

var _mods_by_source: Dictionary = {}

var _max_mods_by_source: Dictionary = {}



var is_initiated: bool = false

func _init() -> void:
	# Ensures that when this resource is attached in a scene,
	# the scene owns its copy (editing one unit’s attribute won’t affect others).
	set_local_to_scene(true)


func change_resource_name_to_attribute() -> void:
	if !Engine.is_editor_hint():
		return
	var temp_attribute_name: String = attribute_name.to_pascal_case() if attribute_name != "" else "Unnamed"
	var temp_resource_name: String = temp_attribute_name# + "Attribute"
	set_name(temp_resource_name)


# -------------------------
# Value Queries
# -------------------------


func get_current_modified_value() -> int:
	var val: int = current_value + get_current_modifier()

	# For Track stats (HP/Posture/etc), keep the displayed/used current in range.
	if attribute_type == 3:
		val = clampi(val, get_min_value(), get_max_value())

	return val

func get_max_value() -> int:
	# IMPORTANT: this is now the MODIFIED maximum (base max + max modifiers)
	return maximum_value + get_max_modifier()

func get_min_value() -> int:
	return minimum_value


func get_current_modifier() -> int:
	var current_modifier: int = 0
	for mod in modifiers:
		current_modifier += int(mod)
	for v in _mods_by_source.values():
		current_modifier += int(v)
	return current_modifier


func get_max_modifier() -> int:
	var max_modifier: int = 0
	for mod in maximum_modifiers:
		max_modifier += int(mod)
	for v in _max_mods_by_source.values():
		max_modifier += int(v)
	return max_modifier


# -------------------------
# Modifiers API
# -------------------------

func add_modifier(in_modifier: int, affect_maximum: bool = false) -> void:
	if affect_maximum:
		maximum_modifiers.append(in_modifier)
	else:
		modifiers.append(in_modifier)
	_clamp_current_if_track()

func remove_modifier(in_modifier: int, affect_maximum: bool = false) -> void:
	if affect_maximum:
		maximum_modifiers.erase(in_modifier)
	else:
		modifiers.erase(in_modifier)
	_clamp_current_if_track()

func set_modifier(source_id: StringName, value: int, affect_maximum: bool = false) -> void:
	# Existing behavior: always affects current via source-based modifier
	_mods_by_source[source_id] = value

	# NEW behavior: optionally also affects maximum via source-based modifier
	if affect_maximum:
		_max_mods_by_source[source_id] = value
	else:
		# If the source used to affect max but no longer should, clean it up.
		_max_mods_by_source.erase(source_id)

	_clamp_current_if_track()

func clear_modifier(source_id: StringName) -> void:
	_mods_by_source.erase(source_id)
	_max_mods_by_source.erase(source_id)
	_clamp_current_if_track()

func _clamp_current_if_track() -> void:
	# Only clamp Track attributes (HP/Posture/etc).
	if attribute_type != 3:
		return

	# We adjust the *stored* current_value so that:
	# (current_value + current_mods) stays within [min..max_modified].
	var cur_mod: int = get_current_modifier()
	var desired: int = clampi(current_value + cur_mod, get_min_value(), get_max_value())
	current_value = desired - cur_mod


# Functions for tag management
func add_tag(tag: String) -> void:
	if !tags.has(tag):
		tags.append(tag)


func has_tag(in_tag: String) -> bool:
	return tags.has(in_tag)
