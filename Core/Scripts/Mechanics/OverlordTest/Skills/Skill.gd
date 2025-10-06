class_name Skill
extends Resource


@export var skill_name: String = "None"

@export var action: Action = null
@export var skill_conditions: Array[SkillCondition] = []

@export var tags: Array[String] = []

#Unit that owns the skill
var unit: Unit = null

func activate_skill() -> void:
	var random_unit: Unit = get_random_valid_unit()
	if !random_unit:
		push_error("No random unit in skills found")
		return
	
	CombatLog.instance.add_log("Random Skill Unit: " + random_unit.ui_name, true)
	
	if action:
		unit.character_sheet.action_container.use_action(action, random_unit)
	

	
	
	end_skill()
	pass

func end_skill() -> void:
	pass



func get_random_valid_unit() -> Unit:
	var ret_unit: Unit = null
	var valid_units: Array[Unit] = get_all_valid_units()
	
	ret_unit = valid_units.pick_random()
	

	
	return ret_unit


func get_all_valid_units() -> Array[Unit]:
	
	var all_units: Array[Unit] = UnitManager.instance.get_all_units()
	var valid_units: Array[Unit] = []

	for test_unit in all_units:
		var conditions_passed: bool = true
		for condition in skill_conditions:
			if !condition.check_condition(self, test_unit):
				conditions_passed = false
				break
		
		if conditions_passed:
			valid_units.append(test_unit)
	
	
	return valid_units


func can_activate_skill() -> bool:
	if !action:
		return false
	
	
	if check_conditions_against_units():
		return true
	
	
	return false


func check_conditions_against_units() -> bool:
	
	var valid_units: Array[Unit] = get_all_valid_units()
	return !valid_units.is_empty()









# Tags functions

func has_tag(in_tag: String) -> bool:
	if tags.has(in_tag.to_lower()):
		return true
	return false


func has_any_tag(in_tags: Array[String]) -> bool:
	for tag in in_tags:
		if tags.has(tag.to_lower()):
			return true
	return false
