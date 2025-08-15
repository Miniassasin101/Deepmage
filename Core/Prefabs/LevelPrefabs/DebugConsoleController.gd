class_name DebugConsoleController
extends Node


var last_pool: DicePool = DicePool.new()

var last_test: Test = Test.new()

func _ready() -> void:
	Console.add_command("hello", console_hello, 0, 0, "Prints Hello")
	Console.add_command("print_text", print_text_on_first_unit, 1, 1, "Prints Inputted Text on first Unit in manager")

	Console.add_command("dp_roll", dp_roll, ["pool_size","target_successes","success_threshold"], 0,"Rolls a new DicePool.  omit args to reuse previous values.")
	Console.add_command("dp_show", dp_show, [], 0,"Print summary (results, successes, level) of last pool.")
	Console.add_command("dp_counts", dp_counts, [], 0,"Show tally of faces (1–6) from last pool.")
	Console.add_command("dp_avg", dp_avg, [], 0,"Show average roll of last pool.")
	Console.add_command("dp_max", dp_max, [], 0,"Show max roll of last pool.")
	Console.add_command("dp_min", dp_min, [], 0,"Show min roll of last pool.")

	Console.add_command("attr_list", attr_list, ["unit_name"], 1, "List all attributes on the specified unit")
	Console.add_command("attr_get", attr_get, ["unit_name","attr_name"], 2, "Get current modified value of attribute on unit")
	Console.add_command("attr_set", attr_set, ["unit_name","attr_name","value"], 3, "Set current value of attribute on unit")
	Console.add_command("attr_mod_add", attr_mod_add, ["unit_name","attr_name","modifier"], 3, "Add modifier to attribute on unit")
	Console.add_command("attr_mod_remove", attr_mod_remove, ["unit_name","attr_name","modifier"], 3, "Remove modifier from attribute on unit")
	Console.add_command("attr_tags", attr_tags, ["unit_name","attr_name"], 2, "List tags for attribute on unit")
	Console.add_command("attr_add_tag", attr_add_tag, ["unit_name","attr_name","tag"], 3, "Add tag to attribute on unit")
	Console.add_command("attr_has_tag", attr_has_tag, ["unit_name","attr_name","tag"], 3, "Check if attribute has tag on unit")
	Console.add_command("test_run",test_run,["skill_rank","attribute_rank","limit_rank","threshold"],0,"Run a Test: skill+attr dice, limit, threshold. Omit args to reuse last settings.")
	Console.add_command("test_show",test_show,[],0,"Show summary of the last Test run.")
	Console.add_command("has_anim",has_anim,["unit_name", "animation_name"],2,"Return whether the unit has that animation.")


func console_hello() -> void:
	Console.print_line("Hello!", true)

func print_text_on_first_unit(text: String) -> void:
	
	var first_u: Unit = UnitManager.instance.get_first_unit()
	if !first_u:
		return
	
	Utilities.spawn_text_line(first_u, text)

#region Dice Pool Functions
func dp_roll(pool_size: String = "", target: String = "", threshold: String = "") -> void:
	# Determine pool size
	var ps: int = last_pool.dice_count
	if pool_size != "":
		ps = pool_size.to_int()

	# Determine target successes
	var tg: int = last_pool.target_successes
	if target != "":
		tg = target.to_int()

	# Determine success threshold
	var th: int = last_pool.success_threshold
	if threshold != "":
		th = threshold.to_int()

	# Create & roll a new pool
	last_pool = DicePool.new()
	last_pool.success_threshold = th
	last_pool.target_successes = tg
	last_pool.roll(ps)
	last_pool.evaluate()   # updates degree_of_success & success_level

	Console.print_line("→ Rolled %d d6 (≥%d) → target %d successes" %
		[ps, th, tg], true)
	Console.print_line(last_pool.to_str(), true)


func dp_show() -> void:
	Console.print_line(last_pool.to_str(), true)

func dp_counts() -> void:
	var counts = last_pool.get_result_counts()
	Console.print_line("Face counts: %s" % counts, true)

func dp_avg() -> void:
	Console.print_line("Average roll: %.2f" % last_pool.get_average(), true)

func dp_max() -> void:
	Console.print_line("Max roll: %d" % last_pool.get_max(), true)

func dp_min() -> void:
	Console.print_line("Min roll: %d" % last_pool.get_min(), true)
#endregion



#region Attributes Functions
func get_attributes_container_for_unit(unit_name: String) -> AttributesContainer:
	var unit = UnitManager.instance.get_unit_by_name(unit_name)
	if unit == null:
		Console.print_line("Unit '%s' not found." % unit_name, true)
		return null
	
	# Adjust this based on how you get AttributesContainer from unit
	if unit.has_method("get_attributes_container"):
		return unit.get_attributes_container()
	elif unit.has_node("AttributesContainer"):
		return unit.get_node("AttributesContainer")
	else:
		Console.print_line("Unit '%s' has no AttributesContainer." % unit_name, true)
		return null



func attr_list(unit_name: String) -> void:
	var ac: AttributesContainer = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	var names: Array[String] = ac.get_all_attribute_names()
	if names.is_empty():
		Console.print_line("Unit '%s' has no attributes." % unit_name, true)
		return
	Console.print_line("Attributes on %s: %s" % [unit_name, names], true)


func attr_get(unit_name: String, attr_name: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	if !ac.has_attribute(attr_name):
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	var val = ac.get_attribute_current_value(attr_name)
	Console.print_line("Unit '%s' attribute '%s' current modified value: %d" % [unit_name, attr_name, val], true)


func attr_set(unit_name: String, attr_name: String, value: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	if !ac.has_attribute(attr_name):
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	if ac.set_attribute_current_value(attr_name, value.to_int()):
		Console.print_line("Set unit '%s' attribute '%s' current value to %d" % [unit_name, attr_name, value.to_int()], true)
	else:
		Console.print_line("Failed to set attribute '%s' on unit '%s'." % [attr_name, unit_name], true)


func attr_mod_add(unit_name: String, attr_name: String, mod_value: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	if !ac.has_attribute(attr_name):
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	if ac.add_attribute_modifier(attr_name, mod_value.to_int()):
		var new_val = ac.get_attribute_current_value(attr_name)
		Console.print_line("Added modifier %d to '%s' on unit '%s'. New modified value: %d" % [mod_value.to_int(), attr_name, unit_name, new_val], true)
	else:
		Console.print_line("Failed to add modifier to '%s' on unit '%s'." % [attr_name, unit_name], true)


func attr_mod_remove(unit_name: String, attr_name: String, mod_value: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	if !ac.has_attribute(attr_name):
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	if ac.remove_attribute_modifier(attr_name, mod_value.to_int()):
		var new_val = ac.get_attribute_current_value(attr_name)
		Console.print_line("Removed modifier %d from '%s' on unit '%s'. New modified value: %d" % [mod_value.to_int(), attr_name, unit_name, new_val], true)
	else:
		Console.print_line("Failed to remove modifier from '%s' on unit '%s'." % [attr_name, unit_name], true)


func attr_tags(unit_name: String, attr_name: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	var att = ac.get_attribute(attr_name)
	if !att:
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	if att.tags.empty():
		Console.print_line("Attribute '%s' on unit '%s' has no tags." % [attr_name, unit_name], true)
		return
	Console.print_line("Tags for '%s' on unit '%s': %s" % [attr_name, unit_name, att.tags.join(", ")], true)


func attr_add_tag(unit_name: String, attr_name: String, tag: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	var att = ac.get_attribute(attr_name)
	if !att:
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	att.add_tag(tag)
	Console.print_line("Added tag '%s' to attribute '%s' on unit '%s'." % [tag, attr_name, unit_name], true)


func attr_has_tag(unit_name: String, attr_name: String, tag: String) -> void:
	var ac = get_attributes_container_for_unit(unit_name)
	if !ac:
		return
	var att = ac.get_attribute(attr_name)
	if !att:
		Console.print_line("Attribute '%s' not found on unit '%s'." % [attr_name, unit_name], true)
		return
	var has = att.has_tag(tag)
	Console.print_line("Attribute '%s' on unit '%s' %s tag '%s'." % [attr_name, unit_name, ("has" if has else "does not have"), tag], true)

func test_run(skill_s: String = "", attr_s: String = "", limit_s: String = "", threshold_s: String = "") -> void:
	# parse or fallback to last settings
	var skill = last_test.skill_rank
	if skill_s != "":
		skill = skill_s.to_int()

	var attr = last_test.attribute_rank
	if attr_s != "":
		attr = attr_s.to_int()

	var limit = last_test.limit_rank
	if limit_s != "":
		limit = limit_s.to_int()

	var th = last_test.threshold
	if threshold_s != "":
		th = threshold_s.to_int()

	# new Test(_skill, _attr, _limit, _threshold)
	last_test = Test.new(skill, attr, limit, th)
	var _passed = last_test.run_test()

	Console.print_line(
		"→ test_run: Skill %d + Attr %d → %d dice, Limit %d, Threshold %d"
		% [skill, attr, skill + attr, limit, th],
		true
	)
	Console.print_line(last_test.to_str(), true)

func test_show() -> void:
	if last_test == null or last_test.pool == null:
		Console.print_line("No Test has been run yet.", true)
	else:
		Console.print_line("Last Test summary:", true)
		Console.print_line(last_test.to_str(), true)
		# if you also want the raw dice:
		Console.print_line("Raw pool: " + last_test.pool.to_str(), true)


func has_anim(unit_name: String = "", anim_name: String = "") -> void:
	var unit = UnitManager.instance.get_unit_by_name(unit_name)
	if unit == null:
		Console.print_line("Unit '%s' not found." % unit_name, true)
		return
	
	if unit.animation_controller.has_animation(anim_name):
		Console.print_line("Animation Found: " + anim_name, true)
	else:
		Console.print_line("Animation Not Found", true)



#endregion
