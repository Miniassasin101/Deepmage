@tool
class_name Skill
extends Resource

signal on_skill_ended

enum SkillType { ACTIVE, PASSIVE, FREE}


@export var skill_name: String = "None":
	set(val):
		skill_name = val
		change_resource_name_to_skill()

@export var action: Action = null
@export var skill_type: SkillType = SkillType.ACTIVE
@export var skill_cost: int = 1 # AP or PP cost
@export var skill_conditions: Array[SkillCondition] = []
@export var target_preferences: Array[TargetPreference] = []

@export var tags: Array[String] = []


# Unit that owns the skill (set by Tactic when duplicating/assigning).
var unit: Unit = null

func _init() -> void:
	if Engine.is_editor_hint():
		change_resource_name_to_skill()

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func set_unit(in_unit: Unit) -> void:
	unit = in_unit
	# TODO: Consider asserting non-null in release builds to catch setup bugs.


func activate_skill() -> void:
	# Acquire a random valid target unit (based on skill_conditions).
	var random_unit: Unit = get_random_valid_unit()
	if !random_unit:
		# If none found, log and bail (keeps behavior unchanged).
		push_error("No random unit in skills found")
		return

	CombatLog.instance.add_log("Random Skill Unit: " + random_unit.ui_name, true)

	# If the Skill is bound to an Action, invoke it via the owner's action container.
	if action:
		unit.character_sheet.action_container.use_action(action, random_unit)
		await SignalBus.on_action_ended

	# Finish the skill lifecycle.
	end_skill()
	pass


func change_resource_name_to_skill() -> void:
	if !Engine.is_editor_hint():
		return
	var temp_skill_name: String = skill_name.to_pascal_case() if skill_name != "" else "Unnamed"
	var temp_resource_name: String = temp_skill_name + "SkillResource"
	set_name(temp_resource_name)


func end_skill() -> void:
	# Broadcast completion so action callers can resume.
	on_skill_ended.emit()


func can_activate_skill() -> bool:
	# Quick guards for missing components.
	if !action:
		return false
	if !unit:
		return false
	
	check_ap_pp()
	
	# True if at least one target unit satisfies all conditions.
	if check_conditions_against_units():
		return true

	return false

# Checks to see if the unit has enough action points or passive points to cover the cost of the skill
func check_ap_pp() -> bool:
	var points_name: String = "None"
	
	match skill_type:
		SkillType.ACTIVE:
			points_name = "active_points"
		SkillType.PASSIVE:
			points_name = "passive_points"
	
	var points_attribute: Attribute = unit.get_attributes_container().get_attribute(points_name)
	if !points_attribute:
		return false
	
	var curr_val: int = points_attribute.get_current_modified_value()
	
	if curr_val > skill_cost:
		return false
	
	
	return true


# -----------------------------------------------------------------------------
# Targeting helpers
# -----------------------------------------------------------------------------
func get_random_valid_unit() -> Unit:
	# Returns a random valid unit or null if none are available.
	var chosen_unit: Unit = null
	var valid_units: Array[Unit] = get_all_valid_units()
	chosen_unit = select_preferred_target(valid_units)
	return chosen_unit
	# TODO: Consider excluding self as applicable, or add a "self-target" tag/condition.


func select_preferred_target(valid_units: Array[Unit]) -> Unit:
	# Applies ordered preferences only if there is more than one valid target.
	# If preferences cannot break ties, falls back to random among remaining.
	if valid_units.is_empty():
		return null

	if valid_units.size() == 1:
		return valid_units[0]

	var pool: Array[Unit] = valid_units.duplicate()

	if target_preferences.size() > 0:
		for pref in target_preferences:
			# Narrow only if more than one remains.
			if pool.size() > 1 and pref:
				var narrowed: Array[Unit] = pref.apply(self, pool)
				# Safety: Do not accept an empty result; keep prior pool if so.
				if narrowed.size() > 0:
					pool = narrowed

	# If we still have more than one, choose randomly (predictable with seeded RNG if desired).
	return pool.pick_random()

func get_all_valid_units() -> Array[Unit]:
	# Builds a list of all units that pass every condition in skill_conditions.
	var all_units: Array[Unit] = UnitManager.instance.get_all_units()
	var valid_units: Array[Unit] = []

	for test_unit in all_units:
		var conditions_passed: bool = true

		for condition in skill_conditions:
			if !condition:
				continue
			if !condition.check_condition(self, test_unit):
				conditions_passed = false
				break

		if conditions_passed:
			valid_units.append(test_unit)

	return valid_units
	# TODO: Cache and invalidate per-turn to avoid repeated global scans.
	# TODO: Support multi-step filters (e.g., prefilter faction, then range, then custom).


func check_conditions_against_units() -> bool:
	# Returns true if at least one unit passes all conditions.
	var valid_units: Array[Unit] = get_all_valid_units()
	return !valid_units.is_empty()


# -----------------------------------------------------------------------------
# Tags helpers
# -----------------------------------------------------------------------------
func has_tag(in_tag: String) -> bool:
	in_tag = in_tag.to_lower()
	# Case-insensitive tag check (lowercasing the input tag).
	if tags.has(in_tag):
		return true
	return false


func has_any_tag(in_tags: Array[String]) -> bool:
	# Returns true if any of the provided tags is present on this skill.
	for candidate_tag in in_tags:
		if tags.has(candidate_tag.to_lower()):
			return true
	return false
	# TODO: Use a Set for tags to speed up membership queries if tag counts grow.
