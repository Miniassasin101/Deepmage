class_name IsAnyEnemyInRangeSkillCondition
extends SkillCondition

@export var threat_radius: float = 6.0

var ui_name: String = "EnemyInRange"

func check_condition(skill: Skill, _target: Unit) -> bool:
	var owner: Unit = skill.unit
	if owner == null:
		return false

	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == owner:
			continue
		# Treat "enemy" relative to owner
		if other_unit.is_enemy == owner.is_enemy:
			continue

		var distance_value: float = owner.global_transform.origin.distance_to(other_unit.global_transform.origin)
		if distance_value <= threat_radius:
			return true

	return false
