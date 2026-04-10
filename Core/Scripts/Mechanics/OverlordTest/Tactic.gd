class_name Tactic
extends Resource

@export var active_skills: Array[Skill] = []
@export var passive_skills: Array[Skill] = []

func make_skills_unique(owning_unit: Unit) -> void:
	var new_actives: Array[Skill] = []
	for original_skill in active_skills:
		if original_skill == null:
			continue
		var duplicated_skill: Skill = original_skill.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		duplicated_skill.unit = owning_unit
		duplicated_skill._invalidate_condition_caches()    # <-- add this
		new_actives.append(duplicated_skill)
	active_skills.assign(new_actives)

	var new_passives: Array[Skill] = []
	for original_passive in passive_skills:
		if original_passive == null:
			continue
		var duplicated_passive: Skill = original_passive.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		duplicated_passive.unit = owning_unit
		duplicated_passive._invalidate_condition_caches()  # <-- add this
		new_passives.append(duplicated_passive)
	passive_skills.assign(new_passives)

	# TODO: Consider a shared pool with reference counting if many units reuse identical skills.
	# TODO: Validate tags/conditions on duplication and log authoring errors once.


func set_all_skills(in_skills: Array[Skill]) -> void:
	for skill in in_skills:
		if skill.skill_type == skill.SkillCategory.ACTIVE:
			active_skills.append(skill)
		elif skill.skill_type == skill.SkillCategory.PASSIVE:
			passive_skills.append(skill)

func set_active_skills(in_askills: Array[Skill]) -> void:
	active_skills = in_askills

func set_passive_skills(in_pskills: Array[Skill]) -> void:
	passive_skills = in_pskills

func get_all_skills() -> Array[Skill]:
	return active_skills + passive_skills
	# TODO: Cache this concatenation if invoked frequently during a turn/frame.


func get_valid_active_skills() -> Array[Skill]:
	var ret_skills: Array[Skill] = []
	for skill in active_skills:
		if skill:
			ret_skills.append(skill)
	return ret_skills

func get_valid_passive_skills() -> Array[Skill]:
	var ret_skills: Array[Skill] = []
	for skill in passive_skills:
		if skill:
			ret_skills.append(skill)
	return ret_skills
	
