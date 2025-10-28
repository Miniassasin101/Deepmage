class_name IsSourceUserFactionSkillCondition
extends SkillCondition

enum FactionRelation { SELF, ALLY, ENEMY, ANY_NON_SELF }
@export var relation: FactionRelation = FactionRelation.ENEMY

func check_condition(skill: Skill, _target: Unit) -> bool:
	var reactor_unit: Unit = skill.unit
	var source_user: Unit = context.get("source_user", null)
	if reactor_unit == null or source_user == null:
		return false

	if relation == FactionRelation.SELF:
		return source_user == reactor_unit
	elif relation == FactionRelation.ALLY:
		return source_user.is_enemy == reactor_unit.is_enemy and source_user != reactor_unit
	elif relation == FactionRelation.ENEMY:
		return source_user.is_enemy != reactor_unit.is_enemy
	else:
		return source_user != reactor_unit
