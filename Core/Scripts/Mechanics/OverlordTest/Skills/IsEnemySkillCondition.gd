class_name IsEnemySkillCondition
extends SkillCondition




func check_condition(skill: Skill, target: Unit) -> bool:
	if target.is_enemy != skill.unit.is_enemy:
		return true
	return false
