class_name TacticsController
extends Node

@export var unit: Unit = null
@export var starting_tactic: Tactic = null
@export var current_tactic: Tactic

## Active skills granted by currently-equipped gear (populated by EquipmentContainer).
var equipment_active_skills: Array[Skill] = []

## Passive skills granted by currently-equipped gear (populated by EquipmentContainer).
var equipment_passive_skills: Array[Skill] = []




func _ready() -> void:
	# Setup on combat start and also initialize locally.
	SignalBus.on_combat_started.connect(setup)
	setup_tactic()


func setup_tactic() -> void:
	# Initialize an empty current tactic. Population occurs in setup().
	if !starting_tactic:
		return

	current_tactic = Tactic.new()
	# TODO: Consider deep-duplicating starting_tactic to preserve authoring defaults.
	# TODO: Emit a signal when tactic changes so UI/AI can refresh bindings.


func setup() -> void:
	if unit and unit.starting_tactic:
		starting_tactic = unit.starting_tactic.duplicate(true)
	# Copy skills from the starting tactic into the current tactic, then "own" them.
	current_tactic.active_skills.assign(starting_tactic.active_skills)
	current_tactic.passive_skills.assign(starting_tactic.passive_skills)

	# Ensure skills are unique and bound to this unit instance.
	current_tactic.make_skills_unique(unit)

	CombatLog.instance.add_log("Unit Skills Setup: " + unit.ui_name)

	# TODO: Validate skill wiring (action present, unit present) and warn once per issue.
	# TODO: Add passive skill hooks (on turn start/end, on damage taken/dealt, etc.).


func set_current_tactic_from_skills(in_askills: Array[Skill] = [], in_pskills: Array[Skill] = [], make_unique: bool = true ) -> void:
	var new_tactic: Tactic = Tactic.new()

	new_tactic.set_active_skills(in_askills)
	new_tactic.set_passive_skills(in_pskills)

	if make_unique:
		new_tactic.make_skills_unique(unit)

	current_tactic = new_tactic


## Register an equipment-granted skill.  Call with a duplicate instance that has source_item set.
func add_equipment_skill(skill: Skill) -> void:
	if skill == null:
		return
	skill.set_unit(unit)
	if skill.skill_category == Skill.SkillCategory.PASSIVE:
		if !equipment_passive_skills.has(skill):
			equipment_passive_skills.append(skill)
	else:
		if !equipment_active_skills.has(skill):
			equipment_active_skills.append(skill)


## Remove all equipment-granted skills whose source_item matches [param source].
func remove_equipment_skills_from_source(source: BuildSource) -> void:
	equipment_active_skills = equipment_active_skills.filter(
		func(sk: Skill) -> bool: return sk.source_item != source
	)
	equipment_passive_skills = equipment_passive_skills.filter(
		func(sk: Skill) -> bool: return sk.source_item != source
	)


func get_first_valid_active_skill() -> Skill:
	# Returns the first skill whose conditions allow activation.
	if !current_tactic:
		push_error("No Current Tactic In TacticsController")
	var valid_skill: Skill = null

	var priority_num: int = 0

	# Tactic skills first, then equipment-granted skills.
	var active_skills_list: Array[Skill] = current_tactic.active_skills.duplicate()
	active_skills_list.append_array(equipment_active_skills)

	for candidate_skill in active_skills_list:
		if candidate_skill.unit == null:
			candidate_skill.set_unit(unit)
		priority_num += 1
		if candidate_skill.can_activate_skill():
			valid_skill = candidate_skill
			break

	if valid_skill:
		CombatLog.instance.add_log("Unit: " + unit.ui_name + "  Skill: " + valid_skill.skill_name + "  Priority: " + str(priority_num), true)

	return valid_skill
	# TODO: Replace linear scan with priority ordering or scoring function.
	# TODO: Add "selector" strategies (first-valid, best-target, highest-damage, utility).



func get_first_valid_passive_skill_with_context(ctx: Dictionary) -> Skill:
	if current_tactic == null:
		push_error("No Current Tactic In TacticsController")
		return null

	var trigger_phase: int = ctx.get("trigger_phase", SkillTriggerSystem.TriggerPhase.NONE)
	var valid_skill: Skill = null
	# Tactic passives first, then equipment-granted passives.
	var passive_skills_list: Array[Skill] = current_tactic.passive_skills.duplicate()
	passive_skills_list.append_array(equipment_passive_skills)
	var priority_counter: int = 0

	for candidate_skill in passive_skills_list:
		if candidate_skill == null:
			continue
		if candidate_skill.unit == null:
			candidate_skill.set_unit(unit)
		priority_counter += 1

		var can_trigger_now: bool = candidate_skill.can_trigger_passive_skill(trigger_phase, ctx)
		if can_trigger_now:
			valid_skill = candidate_skill
			break

	if valid_skill != null:
		CombatLog.instance.add_log("Passive Reactor " + unit.ui_name + " → " + valid_skill.skill_name + "  Priority: " + str(priority_counter), true)

	return valid_skill


func get_skill_priority_num(in_skill: Skill) -> int:
	var prio_num: int = 0
	if !in_skill:
		return prio_num

	for candidate_skill in current_tactic.active_skills:
		if !candidate_skill:
			continue
		prio_num += 1
		if candidate_skill == in_skill:
			return prio_num

	return prio_num
