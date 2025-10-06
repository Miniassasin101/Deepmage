class_name SkillCondition
extends Resource



func check_condition(skill: Skill, target: Unit) -> bool:
	CombatLog.instance.add_log()
	return false
