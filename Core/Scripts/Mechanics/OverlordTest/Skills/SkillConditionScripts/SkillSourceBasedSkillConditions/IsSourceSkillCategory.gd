class_name IsSourceSkillCategorySkillCondition
extends SkillCondition

@export var required_category: Skill.SkillCategory = Skill.SkillCategory.ACTIVE

func check_condition(_skill: Skill, _target: Unit) -> bool:
	var src_skill: Skill = context.get("source_skill", null)
	if src_skill == null:
		return false
	if src_skill.skill_category == required_category:
		return true
	else:
		return false
