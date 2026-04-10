class_name IsSelfOrAllySkillCondition
extends SkillCondition

# Passes if the target is on the opposite team of the skill owner.
func check_condition(skill: Skill, target: Unit) -> bool:
	if target.is_enemy == skill.unit.is_enemy:
		return true
	return false
	# TODO: Consider a generalized "HasFactionRelation(relation_type)" to cover ally/self/neutral.
