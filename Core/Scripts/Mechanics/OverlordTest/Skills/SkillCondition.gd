@abstract
class_name SkillCondition
extends Resource


var context: Dictionary = {}


func set_context(in_ctx: Dictionary) -> void:
	context = in_ctx
	pass

# Base condition type. Derive and implement check_condition().
func check_condition(_skill: Skill, _target: Unit) -> bool:
	# NOTE: This base implementation returns false by default.
	return false
	# TODO: Add context object (time, distance, threat, objectives) for richer conditions.
