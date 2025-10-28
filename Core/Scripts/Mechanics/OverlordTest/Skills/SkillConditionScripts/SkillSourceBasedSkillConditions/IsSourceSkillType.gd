class_name IsSourceSkillTypeSkillCondition
extends SkillCondition

@export var required_type: Skill.SkillType = Skill.SkillType.ATTACK

func check_condition(_skill: Skill, _target: Unit) -> bool:
	var src_skill: Skill = context.get("source_skill", null)
	if src_skill == null:
		return false
	if src_skill.skill_type == required_type:
		return true
	else:
		return false
