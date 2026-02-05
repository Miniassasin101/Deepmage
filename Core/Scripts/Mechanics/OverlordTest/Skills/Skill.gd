@tool
class_name Skill
extends Resource

signal on_skill_ended

enum SkillCategory { ACTIVE, PASSIVE, FREE}
enum SkillType { ATTACK, SUPPORT, SABOTAGE, SPECIAL}

@export var skill_name: String = "None":
	set(val):
		skill_name = val
		change_resource_name_to_skill()

## The underlying action that the skill uses, and contains most of the operational logic
@export var action: Action = null

## Determines which resource is required to use the skill.
@export var skill_category: SkillCategory = SkillCategory.ACTIVE

@export var skill_type: SkillType = SkillType.ATTACK

@export var skill_trigger: SkillTriggerSystem.TriggerPhase = SkillTriggerSystem.TriggerPhase.NONE

## How many active points or passive points need to be spent to activate this skill.
@export var skill_cost: int = 1 # AP or PP cost

## Skill conditions that are inherent to the skill and not editable by players.
@export var internal_skill_conditions: Array[SkillCondition] = []

## Skill conditions that are fully editable by players.
@export var external_skill_conditions: Array[SkillCondition] = []

@export var external_condition_blueprints: Array[ConditionBlueprint] = []:
	set(value):
		external_condition_blueprints = value
		_invalidate_condition_caches()
		_setup_blueprint_listeners()

@export var target_preference_blueprints: Array[ConditionBlueprint] = []:
	set(value):
		target_preference_blueprints = value
		_invalidate_condition_caches()
		_setup_blueprint_listeners()

## Type of lighter skill condition that will narrow down the pool of unit targets, but never to zero.
@export var target_preferences: Array[TargetPreference] = []

@export var is_disabled: bool = false

@export_group("Skill Attributes")
@export var base_power: int = 100
@export var base_accuracy: int = 95
@export var crit_mod: int = 0

@export_group("Skill Effects")
@export_subgroup("Modifies Skill")
@export var skill_modifying_statuses: Array[Status] = []

@export_group("Magic")
@export var is_spell: bool = false
@export var mana_cost: int = 0
@export var magic_type: StringName = &""	# ex: &"fire"



@export_group("Description")
@export var trait_1: String = "Trait 1"
@export var trait_2: String = "Trait 2"
@export var trait_3: String = "Trait 3"


## Series of lines describing the behavior and/or effect of the skill.
@export var description: Array[String] = []

## Mark the skill in various ways so other combat elements know how to interact with it.
@export var tags: Array[String] = []


# --- in Skill.gd (private runtime caches) ---
var _external_conditions_cache: Array[SkillCondition] = []
var _target_preferences_cache: Array[TargetPreference] = []
var _condition_caches_built: bool = false



## Unit that owns the skill (set by Tactic when duplicating/assigning).
var unit: Unit = null

func _init() -> void:
	if Engine.is_editor_hint():
		change_resource_name_to_skill()

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func set_unit(in_unit: Unit) -> void:
	unit = in_unit
	_setup_blueprint_listeners()


func activate_skill(bypass_declare: bool = false) -> void:
	var chosen_target: Unit = get_random_valid_unit()
	if chosen_target == null:
		# IMPORTANT: always end the skill so awaits can proceed
		CombatLog.instance.add_log("No valid target for " + skill_name)
		await unit.get_tree().create_timer(0.5).timeout
		end_skill()
		return

	CombatLog.instance.add_log("Random Skill Unit: " + chosen_target.ui_name)
	var ctx: Dictionary = {
	"skill": self,
	"target": chosen_target,
	"skill_category": int(skill_category),
	"skill_type": int(skill_type)}
	
	if skill_category == SkillCategory.ACTIVE and !bypass_declare:
		
		SignalBus.on_skill_declared.emit(unit, ctx)
	# Declare Skill goes here
		await TurnSystem.instance.declare_skill(self, chosen_target)
		await unit.get_tree().create_timer(1.2).timeout # Visual Processing time
	else:
		pass
	
	var t_pack: TargetPackage = Utilities.make_target_package(chosen_target)
	t_pack.set_skill(self)
	
	if is_spell:
		_spend_mana()

	# If the Skill is bound to an Action, invoke it via the owner's action container.
	if action:
		var temp_action: Action = unit.character_sheet.action_container.use_action(action, t_pack, true)
		await temp_action.on_action_ended
	
	# Declare Skill End goes here
	if skill_category == SkillCategory.ACTIVE and !bypass_declare:
		#pass
		# Declare Skill goes here
		await TurnSystem.instance.after_skill_used(self, chosen_target)
		SignalBus.on_skill_end.emit(unit, ctx)
		# Finish the skill lifecycle.
		end_skill()
		return
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
	
	if is_disabled:
		return false
	
	if !check_ap_pp():
		return false
	
	if is_spell and !_has_enough_mana():
		return false

	
	# True if at least one target unit satisfies all conditions.
	if check_conditions_against_units():
		return true

	return false

# Checks to see if the unit has enough action points or passive points to cover the cost of the skill
func check_ap_pp() -> bool:
	var points_name: String = "None"
	
	match skill_category:
		SkillCategory.ACTIVE:
			points_name = "active_points"
		SkillCategory.PASSIVE:
			points_name = "passive_points"
		_:
			points_name = "active_points" # or whatever default you want for FREE
	
	var points_attribute: Attribute = unit.get_attributes_container().get_attribute(points_name)
	if !points_attribute:
		return false
	
	var curr_val: int = points_attribute.get_current_modified_value()
	
	if curr_val < skill_cost:
		return false
	
	
	return true



func can_trigger_passive_skill(t_phase: SkillTriggerSystem.TriggerPhase, ctx: Dictionary) -> bool:
	if skill_category != SkillCategory.PASSIVE:
		return false
	if t_phase == SkillTriggerSystem.TriggerPhase.NONE:
		return false
	if t_phase != skill_trigger:
		return false
	if is_disabled:
		return false
	
	# NEW: give conditions the triggering context
	_apply_context_to_all_conditions(ctx)
	
	# Enough PP?
	if !check_ap_pp():
		return false

	# Optional: validate conditions using context’s source/target, if your conditions support it.
	# If your conditions only evaluate Unit targets, keep existing check:
	if !check_conditions_against_units():
		return false

	# You can also stash ctx on the skill or action if your Action needs it:
	if action != null:
		action.set_context(ctx)  # add a no-op setter on Action if needed

	return true

func _apply_context_to_all_conditions(ctx: Dictionary) -> void:
	_ensure_condition_caches_built()

	for internal_condition in internal_skill_conditions:
		if internal_condition != null:
			internal_condition.set_context(ctx)

	for cached_condition in _external_conditions_cache:
		if cached_condition != null:
			cached_condition.set_context(ctx)




# -----------------------------------------------------------------------------
# Targeting helpers
# -----------------------------------------------------------------------------
## Returns a random valid unit or null if none are available.
func get_random_valid_unit() -> Unit:
	if skill_category == SkillCategory.PASSIVE:
		pass
	var chosen_unit: Unit = null
	var valid_units: Array[Unit] = get_all_valid_units()
	chosen_unit = select_preferred_target(valid_units)
	return chosen_unit
	# TODO: Consider excluding self as applicable, or add a "self-target" tag/condition.


## Applies ordered preferences only if there is more than one valid target.
## If preferences cannot break ties, falls back to random among remaining.
func select_preferred_target(valid_units: Array[Unit]) -> Unit:
	if valid_units.is_empty():
		return null
	if valid_units.size() == 1:
		return valid_units[0]

	var candidate_pool: Array[Unit] = valid_units.duplicate()
	var preferences: Array[TargetPreference] = get_target_preferences()

	if preferences.size() > 0:
		for preference_rule in preferences:
			if candidate_pool.size() > 1 and preference_rule != null:
				var narrowed_pool: Array[Unit] = preference_rule.apply(self, candidate_pool)
				if narrowed_pool.size() > 0:
					candidate_pool = narrowed_pool

	return candidate_pool.pick_random()



## Builds a list of all units that pass every condition in get_all_skill_conditions.
func get_all_valid_units() -> Array[Unit]:
	var all_units: Array[Unit] = UnitManager.instance.get_all_units()
	var valid_units: Array[Unit] = []

	for test_unit in all_units:
		var conditions_passed: bool = true

		for condition in get_all_skill_conditions():
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


## Returns true if at least one unit passes all conditions.
func check_conditions_against_units() -> bool:
	var valid_units: Array[Unit] = get_all_valid_units()
	return !valid_units.is_empty()


func _invalidate_condition_caches() -> void:
	_external_conditions_cache.clear()
	_target_preferences_cache.clear()
	_condition_caches_built = false

func _ensure_condition_caches_built() -> void:
	if _condition_caches_built:
		return

	# Build external conditions once
	for blueprint_item in external_condition_blueprints:
		if blueprint_item != null:
			var instance_condition: SkillCondition = blueprint_item.instantiate_condition()
			if instance_condition != null:
				_external_conditions_cache.append(instance_condition)

	# Build target preferences once
	for blueprint_item in target_preference_blueprints:
		if blueprint_item != null:
			var condition_instance: SkillCondition = blueprint_item.instantiate_condition()
			var preference_instance: TargetPreference = condition_instance as TargetPreference
			if preference_instance != null:
				_target_preferences_cache.append(preference_instance)

	_condition_caches_built = true


func _setup_blueprint_listeners() -> void:
	# Rebuild caches whenever authoring changes at edit/runtime.
	for blueprint_item in external_condition_blueprints:
		if blueprint_item != null and !blueprint_item.changed.is_connected(_on_blueprint_changed):
			blueprint_item.changed.connect(_on_blueprint_changed)
	for blueprint_item in target_preference_blueprints:
		if blueprint_item != null and !blueprint_item.changed.is_connected(_on_blueprint_changed):
			blueprint_item.changed.connect(_on_blueprint_changed)


func _on_blueprint_changed() -> void:
	_invalidate_condition_caches()



## Returns a combination of the internal and external skill conditions.
func get_all_skill_conditions() -> Array[SkillCondition]:
	_ensure_condition_caches_built()
	var all_conditions: Array[SkillCondition] = []
	all_conditions.append_array(internal_skill_conditions)
	all_conditions.append_array(_external_conditions_cache)
	return all_conditions


func get_external_skill_conditions() -> Array[SkillCondition]:
	_ensure_condition_caches_built()
	return _external_conditions_cache



func get_target_preferences() -> Array[TargetPreference]:
	_ensure_condition_caches_built()
	return _target_preferences_cache


func get_external_condition_blueprints() -> Array[ConditionBlueprint]:
	return external_condition_blueprints

func get_target_preference_blueprints() -> Array[ConditionBlueprint]:
	return target_preference_blueprints



# ------------------------------------------
# Magic Functions
# ------------------------------------------

func get_effective_mana_cost() -> int:
	if mana_cost <= 0:
		return 0
	if unit == null:
		return mana_cost
	var status_controller: StatusController = unit.get_status_controller()
	if status_controller != null and status_controller.has_method("modify_mana_cost"):
		return int(status_controller.modify_mana_cost(self, mana_cost))
	return mana_cost

func _has_enough_mana() -> bool:
	var cost: int = get_effective_mana_cost()
	if cost <= 0:
		return true
	var attrs: AttributesContainer = unit.get_attributes_container()
	var mana_att: Attribute = attrs.get_attribute("mana")
	if mana_att == null:
		return false
	return mana_att.get_current_modified_value() >= cost

func _spend_mana() -> void:
	var cost: int = get_effective_mana_cost()
	if cost <= 0:
		return
	unit.get_attributes_container().change_attribute_current_value_by("mana", -cost)




# -----------------------------------------------------------------------------
# Tags helpers
# -----------------------------------------------------------------------------
func has_tag(in_tag: String) -> bool:
	var needle: String = in_tag.to_lower()
	for t in tags:
		if t.to_lower() == needle:
			return true
	return false



func has_any_tag(in_tags: Array[String]) -> bool:
	# Returns true if any of the provided tags is present on this skill.
	for candidate_tag in in_tags:
		if tags.has(candidate_tag.to_lower()):
			return true
	return false
	# TODO: Use a Set for tags to speed up membership queries if tag counts grow.
