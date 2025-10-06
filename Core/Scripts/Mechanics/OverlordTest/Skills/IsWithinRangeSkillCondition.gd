class_name IsEnemyWithinRangeCondition
extends SkillCondition

@export var range: float = 2.0

func check_condition(skill: Skill, target: Unit) -> bool:

	if get_distance_to_unit(skill.unit, target) <= range:
		return true
	return false

## Distance helper from unit to a given unit.
func get_distance_to_unit(origin_unit: Unit, in_unit: Unit) -> float:
	return origin_unit.get_global_position().distance_to(in_unit.get_global_position())
