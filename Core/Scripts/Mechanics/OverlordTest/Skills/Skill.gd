class_name Skill
extends Resource

signal on_skill_ended

@export var skill_name: String = "None"

@export var action: Action = null
@export var skill_conditions: Array[SkillCondition] = []
@export var target_preferences: Array[TargetPreference] = []

@export var tags: Array[String] = []

# Unit that owns the skill (set by Tactic when duplicating/assigning).
var unit: Unit = null

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


func end_skill() -> void:
	# Broadcast completion so action callers can resume.
	on_skill_ended.emit()


func can_activate_skill() -> bool:
	# Quick guards for missing components.
	if !action:
		return false
	if !unit:
		return false

	# True if at least one target unit satisfies all conditions.
	if check_conditions_against_units():
		return true

	return false


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
				var narrowed := pref.apply(self, pool)
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
	# Case-insensitive tag check (lowercasing the input tag).
	if tags.has(in_tag.to_lower()):
		return true
	return false
	# TODO: Normalize all tags to lowercase at authoring-time to avoid repeated lowercase calls.


func has_any_tag(in_tags: Array[String]) -> bool:
	# Returns true if any of the provided tags is present on this skill.
	for candidate_tag in in_tags:
		if tags.has(candidate_tag.to_lower()):
			return true
	return false
	# TODO: Use a Set for tags to speed up membership queries if tag counts grow.
