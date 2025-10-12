class_name IsNotFullHealthSkillCondition
extends SkillCondition

var ui_name: String = "NotMaxHP"

# Passes if the target is on the opposite team of the skill owner.
func check_condition(_skill: Skill, target: Unit) -> bool:
	var health_attribute: Attribute = target.get_attributes_container().get_attribute("posture")
	var current_health: int = health_attribute.get_current_modified_value()
	var max_health: int = health_attribute.get_max_value()

	if current_health < max_health:
		return true

	return false
