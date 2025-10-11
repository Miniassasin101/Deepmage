class_name IsAllySkillCondition
extends SkillCondition
# Pass only when the "target" is the skill owner (lets non-unit skills pass get_all_valid_units()).

func check_condition(skill: Skill, target: Unit) -> bool:
	if target.is_enemy == skill.unit.is_enemy:
		if target != skill.unit:
			return true
	return false
