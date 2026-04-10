class_name IsSourceSkillTagSkillCondition
extends SkillCondition

@export var required_tag: String = "none"

func check_condition(_skill: Skill, _target: Unit) -> bool:
	var src_skill: Skill = context.get("source_skill", null)
	if src_skill == null:
		return false
	if src_skill.has_tag(required_tag):
		return true
	else:
		return false
