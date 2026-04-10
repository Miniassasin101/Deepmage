class_name IsDownedSkillCondition
extends SkillCondition

## Passes only when the target unit is in the Downed state.
## Use this as an internal condition on revival or healing skills
## that should exclusively target units who are already knocked out.


func check_condition(_skill: Skill, target: Unit) -> bool:
	if target == null:
		return false
	return target.is_downed()
