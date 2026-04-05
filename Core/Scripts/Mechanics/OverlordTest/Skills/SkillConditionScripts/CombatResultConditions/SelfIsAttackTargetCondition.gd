## [b]Condition:[/b] SelfIsAttackTargetCondition
## Passes when the owner of this skill is the unit being targeted by the
## currently-resolving attack.
##
## Use this on any BEFORE_HIT_RESOLVES or AFTER_HIT_RESOLVES passive skill
## so the skill only fires on the unit that is actually being hit, not on
## every unit in the initiative queue.
##
## Reads [code]context["source_target"][/code], which is set by
## [method TurnSystem.open_hit_reactions] when it builds the trigger context.
class_name SelfIsAttackTargetCondition
extends SkillCondition


func check_condition(skill: Skill, _target: Unit) -> bool:
	var attack_target: Unit = context.get("source_target", null)
	return attack_target != null and attack_target == skill.unit
