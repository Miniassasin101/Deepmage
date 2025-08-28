class_name AttributesContainer
extends Node

signal attribute_changed

@export var unit: Unit

@export var starting_attributes: Array[Attribute] = []



var attributes: Array[Attribute] = []

var attributes_dict: Dictionary[String, Attribute] = {}


func _ready() -> void:
	
	_setup_starting_attributes()


func _setup_starting_attributes() -> void:
	attributes.clear()
	attributes_dict.clear()
	for att in starting_attributes:
		var copy = att.duplicate()
		attributes.append(copy)
		attributes_dict[copy.attribute_name] = copy

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
		emit_signal("attribute_changed", in_name, att.current_value)
		return true
	return false

# Add modifier to attribute by name
func add_attribute_modifier(in_name: String, modifier_value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.add_modifier(modifier_value)
		emit_signal("attribute_changed", in_name, att.get_current_modified_value())
		SignalBus.update_stat_bars.emit()
		return true
	return false

# Remove modifier from attribute by name
func remove_attribute_modifier(in_name: String, modifier_value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.remove_modifier(modifier_value)
		emit_signal("attribute_changed", in_name, att.get_current_modified_value())
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
	emit_signal("attribute_changed", copy.attribute_name, copy.get_current_modified_value())
	return true

# Remove attribute by name
func remove_attribute(in_name: String) -> bool:
	if has_attribute(in_name):
		var att = attributes_dict[in_name]
		attributes.erase(att)
		attributes_dict.erase(in_name)
		emit_signal("attribute_changed", in_name, 0)
		return true
	return false

# Get all attribute names
func get_all_attribute_names() -> Array[String]:
	return attributes_dict.keys()
