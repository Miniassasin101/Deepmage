class_name IsUnitInRangeOfSourceTargetCondition
extends SkillCondition

## Passes when skill.unit is within [member cover_range] world units of
## context["source_target"] (the unit being attacked).
##
## Use this as a range gate on Cover passive skills so units only intercept
## attacks against allies that are close enough to reach.

@export var cover_range: float = 6.0


func check_condition(skill: Skill, _target: Unit) -> bool:
	var source_target: Unit = context.get("source_target", null)
	if source_target == null or skill.unit == null:
		return false
	return skill.unit.global_position.distance_to(source_target.global_position) <= cover_range
