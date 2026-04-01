class_name IsSourceUserSkillCondition
extends SkillCondition

# Passes only when the candidate target unit is the same unit that used the
# triggering skill (source_user in context).  Use this on passive attack skills
# to ensure retaliation is directed at the specific unit that triggered them,
# not just any enemy that happens to be valid.
# Only meaningful for passive skills (requires context to be set first).

func check_condition(_skill: Skill, target: Unit) -> bool:
	var source_user: Unit = context.get("source_user", null)
	if source_user == null:
		return false
	return source_user == target
