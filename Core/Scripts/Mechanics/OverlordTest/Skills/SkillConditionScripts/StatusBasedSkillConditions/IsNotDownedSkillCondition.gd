class_name IsNotDownedSkillCondition
extends SkillCondition

## Passes only when the target unit is NOT in the Downed state.
## Use this as an internal condition on skills that should never
## reach units who are already knocked out (attack, debuff, etc.).


func check_condition(_skill: Skill, target: Unit) -> bool:
	if target == null:
		return false
	return !target.is_downed()
