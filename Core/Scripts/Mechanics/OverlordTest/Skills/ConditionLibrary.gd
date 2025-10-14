class_name ConditionLibrary
extends Resource

@export var blueprints: Array[ConditionBlueprint] = []



func get_all() -> Array[ConditionBlueprint]:
	return blueprints.duplicate()

func find_by_name(in_name: String) -> ConditionBlueprint:
	for bp in blueprints:
		if bp != null and bp.display_name.to_lower() == in_name.to_lower():
			return bp
	return null

func by_category(category_filter: String) -> Array[ConditionBlueprint]:
	var results: Array[ConditionBlueprint] = []
	for bp in blueprints:
		if bp != null and bp.category_name == category_filter:
			results.append(bp)
	return results

func search(query_text: String, category_filter: String) -> Array[ConditionBlueprint]:
	var q: String = query_text.strip_edges().to_lower()
	var results: Array[ConditionBlueprint] = []
	for bp in blueprints:
		if bp == null:
			continue
		if category_filter != "" and bp.category_name != category_filter:
			continue
		if q == "" or bp.display_name.to_lower().find(q) >= 0:
			results.append(bp)
	return results

func sort_by_category_then_name(in_list: Array[ConditionBlueprint]) -> void:
	in_list.sort_custom(Callable(self, "_cmp_cat_name"))

func _cmp_cat_name(a_bp: ConditionBlueprint, b_bp: ConditionBlueprint) -> bool:
	if a_bp == null and b_bp == null:
		return false
	if a_bp == null:
		return false
	if b_bp == null:
		return true
	if a_bp.category_name != b_bp.category_name:
		return a_bp.category_name.nocasecmp_to(b_bp.category_name) < 0
	return a_bp.display_name.nocasecmp_to(b_bp.display_name) < 0




func get_unique_categories_sorted() -> Array[String]:
	var set_map: Dictionary = {}
	for bp in blueprints:
		if bp != null and bp.category_name.strip_edges() != "":
			set_map[bp.category_name] = true
	var temp_out_list: Array = set_map.keys()
	var out_list: Array[String] = []
	out_list.assign(temp_out_list)
	out_list.sort_custom(Callable(self, "_cmp_str"))
	return out_list

func _cmp_str(a_text: String, b_text: String) -> bool:
	return a_text.nocasecmp_to(b_text) < 0
