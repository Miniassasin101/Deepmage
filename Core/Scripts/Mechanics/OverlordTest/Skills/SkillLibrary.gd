class_name SkillLibrary
extends Resource

@export var skills: Array[Skill] = []

func get_all_skills_copy() -> Array[Skill]:
	var skills_copy: Array[Skill] = skills.duplicate()
	return skills_copy

func get_skills_sorted_by_category_type_name() -> Array[Skill]:
	var out_array: Array[Skill] = skills.duplicate()
	out_array.sort_custom(Callable(self, "_compare_category_type_name"))
	return out_array

func get_skills_by_category(in_category: int) -> Array[Skill]:
	var results: Array[Skill] = []
	for lib_skill in skills:
		if lib_skill != null and int(lib_skill.skill_category) == in_category:
			results.append(lib_skill)
	return results

func get_skills_by_type(in_type: int) -> Array[Skill]:
	var results: Array[Skill] = []
	for lib_skill in skills:
		if lib_skill != null and int(lib_skill.skill_type) == in_type:
			results.append(lib_skill)
	return results

func find_by_name(in_name: String) -> Skill:
	for lib_skill in skills:
		if lib_skill != null and lib_skill.skill_name.to_lower() == in_name.to_lower():
			return lib_skill
	return null

func _compare_category_type_name(a_skill: Skill, b_skill: Skill) -> bool:
	if a_skill == null and b_skill == null:
		return false
	if a_skill == null:
		return false
	if b_skill == null:
		return true

	var a_cat: int = int(a_skill.skill_category)
	var b_cat: int = int(b_skill.skill_category)
	if a_cat != b_cat:
		return a_cat < b_cat

	var a_type: int = int(a_skill.skill_type)
	var b_type: int = int(b_skill.skill_type)
	if a_type != b_type:
		return a_type < b_type

	var name_compare: int = a_skill.skill_name.nocasecmp_to(b_skill.skill_name)
	if name_compare < 0:
		return true
	else:
		return false
