class_name Tactic
extends Resource

@export var active_skills: Array[Skill] = []
@export var passive_skills: Array[Skill] = []

func make_skills_unique(owning_unit: Unit) -> void:
	# Deep-duplicate active skills and bind their owning unit.
	var new_actives: Array[Skill] = []
	for original_skill in active_skills:
		var duplicated_skill: Skill = original_skill.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		duplicated_skill.unit = owning_unit
		new_actives.append(duplicated_skill)
	active_skills.assign(new_actives)

	# Deep-duplicate passive skills and bind their owning unit.
	new_actives = []
	for original_passive in passive_skills:
		var duplicated_passive: Skill = original_passive.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		duplicated_passive.unit = owning_unit
		new_actives.append(duplicated_passive)
	passive_skills.assign(new_actives)

	# TODO: Consider a shared pool with reference counting if many units reuse identical skills.
	# TODO: Validate tags/conditions on duplication and log authoring errors once.


func get_all_skills() -> Array[Skill]:
	return active_skills + passive_skills
	# TODO: Cache this concatenation if invoked frequently during a turn/frame.
