class_name IsSelfSkillCondition
extends SkillCondition
# Pass only when the "target" is the skill owner (lets non-unit skills pass get_all_valid_units()).

func check_condition(skill: Skill, target: Unit) -> bool:
	if target == skill.unit:
		return true
	return false
