class_name TargetPackage
extends Resource


# Possible targets 
# A single combatant or creature.
var unit: Unit = null

# A global position in the world.
var position: Vector3

# Array of tags that describe the target type that are determined upon setting of the target.
var target_type_tags: Array[String] = []




# Functions for setting targets
func try_set_target(target: Variant) -> bool:
	var valid_target_found: bool = false
	if target is Unit:
		set_unit_target(target)
		valid_target_found = true
	
	if target is Vector3:
		set_position_target(target)
		valid_target_found = true
	
	return valid_target_found


func set_unit_target(in_unit: Unit) -> void:
	unit = in_unit
	add_tag("unit")

func set_position_target(pos: Vector3) -> void:
	position = pos
	add_tag("position")

func get_unit() -> Unit:
	return unit

# Functions for tag management
func add_tag(tag: String) -> void:
	if !target_type_tags.has(tag):
		target_type_tags.append(tag)


func has_tag(in_tag: String) -> bool:
	if target_type_tags.has(in_tag):
		return true
	return false
