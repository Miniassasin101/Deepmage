class_name IsSourceTargetSkillCondition
extends SkillCondition

# Source refers to the source skill, or the skill this skill is reacting to.
# Only works for passive skills
# Targets the target of the triggering skill



func check_condition(_skill: Skill, target: Unit) -> bool:

	var source_target_unit: Unit = context.get("source_target", null)

	
	if source_target_unit == target:
		return true
	return false
	
