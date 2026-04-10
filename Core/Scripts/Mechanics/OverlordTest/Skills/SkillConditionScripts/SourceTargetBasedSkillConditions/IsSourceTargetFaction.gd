class_name IsSourceTargetFactionSkillCondition
extends SkillCondition

# Source refers to the source skill, or the skill this skill is reacting to.
# Only works for passive skills

enum FactionRelation { SELF, ALLY, ENEMY, ANY_NON_SELF }
@export var relation: FactionRelation = FactionRelation.ENEMY

func check_condition(skill: Skill, _target: Unit) -> bool:
	var reactor_unit: Unit = skill.unit
	var target_unit: Unit = context.get("source_target", null)
	if reactor_unit == null or target_unit == null:
		return false

	if relation == FactionRelation.SELF:
		return target_unit == reactor_unit
	elif relation == FactionRelation.ALLY:
		return target_unit.is_enemy == reactor_unit.is_enemy and target_unit != reactor_unit
	elif relation == FactionRelation.ENEMY:
		return target_unit.is_enemy != reactor_unit.is_enemy
	else:
		# ANY_NON_SELF
		return target_unit != reactor_unit
