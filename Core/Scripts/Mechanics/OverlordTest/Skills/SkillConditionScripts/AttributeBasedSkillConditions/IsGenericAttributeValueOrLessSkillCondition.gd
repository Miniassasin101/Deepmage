class_name IsGenericAttributeValueOrLessSkillCondition
extends SkillCondition

# The name of the attribute or skill that is being checked
@export var attribute_name: String = "att_name"
@export var value: int = 0


var ui_name: String = "Attribute is [val] or less"



# Passes if the target is on the opposite team of the skill owner.
func check_condition(_skill: Skill, target: Unit) -> bool:
	var attribute: Attribute = target.get_attributes_container().get_attribute(attribute_name)
	if !attribute:
		push_error("Attribute not found in IsGenericAttributeValueOrLessSkillCondition")
		return false
	
	var current: int = attribute.get_current_modified_value()

	if current <= value:
		return true

	return false
