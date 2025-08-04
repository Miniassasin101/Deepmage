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
func get_attribute(name: String) -> Attribute:
	if attributes_dict.has(name):
		return attributes_dict[name]
	return null

# Get current modified value of an attribute by name
func get_attribute_current_value(name: String) -> int:
	var att = get_attribute(name)
	if att:
		return att.get_current_modified_value()
	return 0

# Set current_value of an attribute by name
func set_attribute_current_value(name: String, value: int) -> bool:
	var att = get_attribute(name)
	if att:
		att.current_value = value
		emit_signal("attribute_changed", name, att.current_value)
		return true
	return false

# Add modifier to attribute by name
func add_attribute_modifier(name: String, modifier_value: int) -> bool:
	var att = get_attribute(name)
	if att:
		att.add_modifier(modifier_value)
		emit_signal("attribute_changed", name, att.get_current_modified_value())
		return true
	return false

# Remove modifier from attribute by name
func remove_attribute_modifier(name: String, modifier_value: int) -> bool:
	var att = get_attribute(name)
	if att:
		att.remove_modifier(modifier_value)
		emit_signal("attribute_changed", name, att.get_current_modified_value())
		return true
	return false

# Check if an attribute exists by name
func has_attribute(name: String) -> bool:
	return attributes_dict.has(name)

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
func remove_attribute(name: String) -> bool:
	if has_attribute(name):
		var att = attributes_dict[name]
		attributes.erase(att)
		attributes_dict.erase(name)
		emit_signal("attribute_changed", name, 0)
		return true
	return false

# Get all attribute names
func get_all_attribute_names() -> Array[String]:
	return attributes_dict.keys()
