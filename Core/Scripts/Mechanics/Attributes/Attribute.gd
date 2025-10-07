class_name Attribute
extends Resource

## Represents an attribute or skill or stat as a class

@export var attribute_name: String = ""

@export_enum("Attribute", "Skill", "Stat", "Track") var attribute_type: int


# Values


@export var current_value: int = 0

@export var base_value: int = 0

@export var maximum_value: int = 1

@export var minimum_value: int = 0

@export var modifiers: Array[int]

@export var tags: Array[String] = []


var is_initiated: bool = false

func _init() -> void:
	# Ensures that when this resource is attached in a scene,
	# the scene owns its copy (editing one unit’s attribute won’t affect others).
	set_local_to_scene(true)

func get_current_modified_value() -> int:
	return  current_value + get_current_modifier()

func get_max_value() -> int:
	return maximum_value

func get_min_value() -> int:
	return minimum_value


func get_current_modifier() -> int:
	var current_modifier: int = 0
	for mod in modifiers:
		current_modifier += mod
	return current_modifier

func add_modifier(in_modifier: int) -> void:
	modifiers.append(in_modifier)

func remove_modifier(in_modifier: int) -> void:
	if modifiers.has(in_modifier):
		modifiers.erase(in_modifier)


# Functions for tag management
func add_tag(tag: String) -> void:
	if !tags.has(tag):
		tags.append(tag)


func has_tag(in_tag: String) -> bool:
	if tags.has(in_tag):
		return true
	return false
