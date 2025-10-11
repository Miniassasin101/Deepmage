class_name IsSelfFullHealthSkillCondition
extends SkillCondition

@export var is_not_toggle: bool = false

# Passes if the target is on the opposite team of the skill owner.
func check_condition(skill: Skill, _target: Unit) -> bool:
	var health_attribute: Attribute = skill.unit.get_attributes_container().get_attribute("posture")
	var current_health: int = health_attribute.get_current_modified_value()
	var max_health: int = health_attribute.get_max_value()

	if current_health >= max_health:
		return true

	return false
