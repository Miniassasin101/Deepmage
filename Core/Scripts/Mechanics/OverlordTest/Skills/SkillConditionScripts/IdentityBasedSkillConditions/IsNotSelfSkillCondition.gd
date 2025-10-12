class_name IsNotSelfSkillCondition
extends SkillCondition
# Pass only when the "target" is NOT the skill owner

func check_condition(skill: Skill, target: Unit) -> bool:
	if target != skill.unit:
		return true
	return false
