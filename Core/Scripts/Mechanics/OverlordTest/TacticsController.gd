class_name TacticsController
extends Node

@export var unit: Unit = null
@export var starting_tactic: Tactic = null
@export var current_tactic: Tactic

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
	# Copy skills from the starting tactic into the current tactic, then “own” them.
	current_tactic.active_skills.assign(starting_tactic.active_skills)
	current_tactic.passive_skills.assign(starting_tactic.passive_skills)

	# Ensure skills are unique and bound to this unit instance.
	current_tactic.make_skills_unique(unit)

	CombatLog.instance.add_log("Unit Skills Setup: " + unit.ui_name)

	# TODO: Validate skill wiring (action present, unit present) and warn once per issue.
	# TODO: Add passive skill hooks (on turn start/end, on damage taken/dealt, etc.).


func set_current_tactic_from_skills(in_askills: Array[Skill] = [], in_pskills: Array[Skill] = [], make_unique: bool = false ) -> void:
	var new_tactic: Tactic = Tactic.new()

	new_tactic.set_active_skills(in_askills)
	new_tactic.set_passive_skills(in_pskills)
	
	if make_unique:
		new_tactic.make_skills_unique(unit)
	
	current_tactic = new_tactic


func get_first_valid_active_skill() -> Skill:
	# Returns the first skill whose conditions allow activation.
	if !current_tactic:
		push_error("No Current Tactic In TacticsController")
	var valid_skill: Skill = null
	
	var priority_num: int = 0
	
	var active_skills_list: Array[Skill] = current_tactic.active_skills
	for candidate_skill in active_skills_list:
		priority_num += 1
		if candidate_skill.can_activate_skill():
			valid_skill = candidate_skill
			break
	
	if valid_skill:
		CombatLog.instance.add_log("Unit: " + unit.ui_name + "  Skill: " + valid_skill.skill_name + "  Priority: " + str(priority_num), true)

	return valid_skill
	# TODO: Replace linear scan with priority ordering or scoring function.
	# TODO: Add “selector” strategies (first-valid, best-target, highest-damage, utility).
