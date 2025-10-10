@tool
class_name AttributesContainer
extends Node

signal attribute_changed

@export_category("References")
@export var unit: Unit


@export_category("Initialization")
@export var profile: AttributesProfile:          # <- assign in the inspector per Unit
	set(val):
		profile = val if val is AttributesProfile else profile
		_on_profile_changed()

@export var auto_apply_profile_in_editor: bool = true
@export var auto_apply_profile_on_play: bool = true

@export_category("Runtime State (read-only at runtime)")
@export var starting_attributes: Array[Attribute] = []  # Inspector-visible snapshot


var attributes: Array[Attribute] = []
var attributes_dict: Dictionary[String, Attribute] = {}





func _ready() -> void:
	if Engine.is_editor_hint():
		# Keep the inspector experience smooth: if you assign a profile
		# and the Unit has no starting_attributes yet, populate them once.
		if auto_apply_profile_in_editor and profile != null:# and starting_attributes.is_empty():
			apply_profile_to_starting_attributes(true)
		# Listen for live edits to the profile in the editor
		if profile != null:
			profile.changed.connect(_on_profile_changed)
		return

	# Runtime: ensure we have a concrete set of attributes to operate on.
	if auto_apply_profile_on_play and profile != null and starting_attributes.is_empty():
		apply_profile_to_starting_attributes(true)

	_rebuild_runtime_cache()
	

func _on_profile_changed() -> void:
	# Editor-only: when you tweak the profile, refresh the snapshot for convenience
	if Engine.is_editor_hint() and auto_apply_profile_in_editor and profile != null:
		apply_profile_to_starting_attributes(true)
		print_debug("Profile Changed")


func apply_profile_to_starting_attributes(make_unique: bool) -> void:
	if profile == null:
		return
	starting_attributes.clear()
	if make_unique:
		starting_attributes = profile.make_unique_attribute_array()
	else:
		# Rare: keep shared refs (not recommended). Prefer unique.
		starting_attributes.assign(profile.attributes)
	_rebuild_runtime_cache()
	# Let the inspector refresh
	property_list_changed.emit()



func _rebuild_runtime_cache() -> void:
	attributes.clear()
	attributes_dict.clear()
	for attribute_resource in starting_attributes:
		# We keep the same instances to preserve inspector edits;
		# they are already unique and local to scene.
		attributes.append(attribute_resource)
		attributes_dict[attribute_resource.attribute_name] = attribute_resource






# ---------- Utility / Query API (unchanged semantics) ----------


func get_defence(_only_get_base: bool = false) -> int:
	var defence: int = 0
	defence += get_attribute_current_value("armor")
	defence += get_attribute_current_value("endurance")
	return defence



# Retrieve attribute by name, return null if not found
func get_attribute(in_name: String) -> Attribute:
	if attributes_dict.has(in_name):
		return attributes_dict[in_name]
	return null

# Get current modified value of an attribute by name
func get_attribute_current_value(in_name: String) -> int:
	var att = get_attribute(in_name)
	if att:
		return att.get_current_modified_value()
	return 0



# Set current_value of an attribute by name
func set_attribute_current_value(in_name: String, value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.current_value = value
		attribute_changed.emit(in_name, att.current_value)
		return true
	return false

func change_attribute_current_value_by(in_name: String, value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.current_value += value
		attribute_changed.emit(in_name, att.current_value)
		SignalBus.update_stat_bars.emit()
		return true
	return false


# Add modifier to attribute by name
func add_attribute_modifier(in_name: String, modifier_value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.add_modifier(modifier_value)
		emit_signal("attribute_changed", in_name, att.get_current_modified_value())
		attribute_changed.emit(in_name, att.get_current_modified_value())
		SignalBus.update_stat_bars.emit()
		return true
	return false

# Remove modifier from attribute by name
func remove_attribute_modifier(in_name: String, modifier_value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.remove_modifier(modifier_value)
		attribute_changed.emit(in_name, att.get_current_modified_value())
		SignalBus.update_stat_bars.emit()
		return true
	return false

# Check if an attribute exists by name
func has_attribute(in_name: String) -> bool:
	return attributes_dict.has(in_name)

# Add new attribute to container
func add_attribute(attribute: Attribute) -> bool:
	if has_attribute(attribute.attribute_name):
		return false # Already exists
	var copy = attribute.duplicate()
	attributes.append(copy)
	attributes_dict[copy.attribute_name] = copy
	attribute_changed.emit(copy.attribute_name, copy.get_current_modified_value())
	return true

# Remove attribute by name
func remove_attribute(in_name: String) -> bool:
	if has_attribute(in_name):
		var att = attributes_dict[in_name]
		attributes.erase(att)
		attributes_dict.erase(in_name)
		emit_signal("attribute_changed", in_name, 0)
		attribute_changed.emit(in_name, 0)
		return true
	return false

# Get all attribute names
func get_all_attribute_names() -> Array[String]:
	return attributes_dict.keys()
