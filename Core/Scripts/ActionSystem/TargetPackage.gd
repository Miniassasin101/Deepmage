class_name TargetPackage
extends Resource


# Possible targets 
# A single combatant or creature.
var unit: Unit = null

# A global position in the world.
var position: Vector3 = Vector3(-1.0, -1.0, -1.0)

# Skill for use first skill to be manually passed
var skill: Skill = null

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
	
	if target is TargetPackage:
		set_unit_target(target.get_unit())
		set_position_target(target.get_position())
		set_skill(target.skill)
		valid_target_found = true

	
	return valid_target_found


func set_unit_target(in_unit: Unit) -> void:
	if !in_unit:
		return
	unit = in_unit
	add_tag("unit")

func set_position_target(pos: Vector3) -> void:
	if pos == Vector3(-1.0, -1.0, -1.0):
		return
	position = pos
	add_tag("position")

func set_skill(in_skill: Skill) -> void:
	if !in_skill:
		return
	skill = in_skill
	add_tag("skill")

func get_unit() -> Unit:
	return unit

func get_position() -> Vector3:
	return position

func get_skill() -> Skill:
	return skill

# Functions for tag management
func add_tag(tag: String) -> void:
	if !target_type_tags.has(tag):
		target_type_tags.append(tag)


func has_tag(in_tag: String) -> bool:
	if target_type_tags.has(in_tag):
		return true
	return false
