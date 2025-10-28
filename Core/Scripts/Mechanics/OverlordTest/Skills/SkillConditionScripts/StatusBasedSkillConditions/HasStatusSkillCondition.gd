class_name HasStatusSkillCondition
extends SkillCondition

# Checks to see if the target candidate has a status with the same name

@export var status_name_snake: String = "block"
@export var min_level: int = 0

func check_condition(_skill: Skill, target: Unit) -> bool:
	var target_unit: Unit = target

	if target_unit == null:
		return false

	var controller: StatusController = target_unit.get_status_controller()

	if controller == null:
		return false

	var status_inst: Status = controller.get_status_by_name(status_name_snake)
	if status_inst == null:
		return false

	if status_inst.status_level >= min_level:
		return true
	else:
		return false
