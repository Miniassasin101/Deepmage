class_name TurnSystem
extends Node

enum RoundPhase { AI_PLANNING, PLAYER_PLANNING, RESOLUTION, CLEANUP }

@export_category("References")
@export var unit_manager: UnitManager
@export var leader_system: Node          # optional: apply leader skills during planning
@export var enemy_ai_system: Node        # optional: your AI planner
@export var action_resolver: Node        # optional: centralized action execution/reactions
@export var skill_trigger_system: SkillTriggerSystem
@export_category("Chaining")
@export var chain_depth_limit: int = 8
var chain_group_stack: Array[ChainGroup] = []


var round_number: int = 1
var current_phase: int = RoundPhase.AI_PLANNING
var is_combat_started: bool = false

var initiative_scores: Dictionary[Unit, int] = {}
## The tick value of the unit with the lowest score, usually the one up next.
var lowest_initiative_score: int = 0
var initiative_queue: Array[Unit] = []

# Contains all the units that can no longer use passive skills until the next unit's turn
var used_p_skill_this_turn: Array[Unit] = []

var passive_bars_by_key: Dictionary = {}   # key: String -> Array[PassiveSkillBar]

# When a unit declares a skill but has not finished it they enter this stack.
# Last unit in the stack/chain will use their skill before finally making it's way back to the turn unit
var use_skill_stack: Array[Unit] = []

var cycle_index: int = 0

# Optional helpers to break early
var cached_player_alive_count: int = 0
var cached_enemy_alive_count: int = 0

var selected_unit: Unit = null

var start_round_button_blocked: bool = false

static var instance: TurnSystem = null



class ChainGroup:
	var trigger_phase: int
	var source_skill: Skill
	var source_user: Unit
	var source_target: Unit
	var reactors_in_order: Array[Unit] = []
	var next_index: int = 0
	var depth: int = 0

	func _init(in_phase: int, in_skill: Skill, in_user: Unit, in_target: Unit, in_reactors: Array[Unit], in_depth: int) -> void:
		trigger_phase = in_phase
		source_skill = in_skill
		source_user = in_user
		source_target = in_target
		reactors_in_order = in_reactors
		depth = in_depth






func _ready() -> void:
	if instance != null:
		push_error("There's more than one TurnSystem! - " + str(instance))
		queue_free()
		return
	instance = self

	SignalBus.end_turn.connect(_on_end_turn)  # you can repurpose this to "Begin Round" click
	

func _unhandled_input(_event: InputEvent) -> void:
	if !is_combat_started:
		if Input.is_action_just_pressed("testkey_n"):
			start_combat()


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC ENTRY
# ─────────────────────────────────────────────────────────────────────────────
func start_combat() -> void:
	if is_combat_started:
		return


	is_combat_started = true
	round_number = 1
	
	set_selected_unit(UnitManager.instance.get_first_unit())

	SignalBus.on_combat_started.emit()
	_start_round()   # enters AI_PLANNING first

# ─────────────────────────────────────────────────────────────────────────────
# ROUND CYCLE
# ─────────────────────────────────────────────────────────────────────────────
# A round can have multiple cycles within it, this kicks off the beginning
func _start_round() -> void:
	SignalBus.on_round_start.emit(round_number)
	
	initialize_initiative_ap_and_pp()

	_enter_ai_planning_phase()

# Resets the initiatives, action points, and passive points early for planning stage reasons
func initialize_initiative_ap_and_pp() -> void:
	# Refresh AP/PP and roll initiative
	_refresh_ap_pp_for_all_units()
	_roll_initiative_for_all_living()
	_sort_initiative_queue()

	SignalBus.instantiate_initiative_queue.emit()
	SignalBus.update_stat_bars.emit()
	pass

func _enter_ai_planning_phase() -> void:
	current_phase = RoundPhase.AI_PLANNING
	SignalBus.on_planning_ai_start.emit(round_number)

	# Enemy AI sets tactics hidden from player (safe to do synchronously)
	if enemy_ai_system:
		enemy_ai_system.call("plan_round_for_enemies", unit_manager)

	SignalBus.on_planning_ai_end.emit(round_number)
	_enter_player_planning_phase()



func _enter_player_planning_phase() -> void:
	current_phase = RoundPhase.PLAYER_PLANNING
	SignalBus.on_planning_player_start.emit(round_number)

	# Give control to player: open tactics/equipment/leader UI here
	UnitActionSystem.instance.is_enabled = true
	# (Leader skills applied on confirm)
	# Wait for player to end the planning phase so the round can begin it's cycles
	CombatLog.instance.add_log("Player Planning")
	start_round_button_blocked = false
	pass



# When the Player presses the End Turn button it begins the combat phases of the round
func _on_end_turn() -> void:
	if current_phase == RoundPhase.PLAYER_PLANNING:

		begin_round_resolution()
	else:
		CombatLog.instance.add_log()



func begin_round_resolution() -> void:
	if !start_round_button_blocked:
		start_round_button_blocked = true
	else:
		return
	UnitActionSystem.instance.is_enabled = false
	
	# Called by UI “Begin Round” button or end turn button
	SignalBus.on_planning_player_end.emit(round_number)

	# Apply Leader pre-round effects if any
	if leader_system:
		leader_system.call("apply_pre_round_effects", round_number)

	# Any other at round start effects trigger here: (Limited at start of combat skills/Protocols)
	CombatLog.instance.add_log("Round Resolution")

	_enter_resolution_phase()


# Round Resolution
func _enter_resolution_phase() -> void:
	current_phase = RoundPhase.RESOLUTION
	cycle_index = 0

	# Repeat passes while any side has AP and actions available
	while _has_viable_actions_remaining():
		await _run_one_cycle()
		if _is_combat_over():
			break
		if cycle_index >= 100:
			push_error("Cycle Count Went Over 100 in TurnSystem")
			break
		#await get_tree().create_timer(0.5).timeout

	CombatLog.instance.add_log("Resolution Phase")
	
	# Round ends: cleanup → next round or combat end
	_enter_cleanup_phase()



func _enter_cleanup_phase() -> void:
	current_phase = RoundPhase.CLEANUP

	# HOOK: round end
	SignalBus.on_round_end.emit(round_number)
	SkillTriggerSystem.instance.fire("ROUND_END", {"round_number": round_number})

	# Tick statuses, decay, etc. (optional hook site)
	# StatusSystem.instance.end_of_round_tick()

	if _is_combat_over():
		SignalBus.team_wiped.emit(cached_enemy_alive_count == 0)
		CombatLog.instance.add_log()
		CombatLog.instance.add_log("Combat Ended!")
		return
	
	CombatLog.instance.add_log("Cleanup Phase")

	# Prepare next round
	round_number += 1
	_start_round()



# ─────────────────────────────────────────────────────────────────────────────
# CYCLES & TURNS
# ─────────────────────────────────────────────────────────────────────────────
func _run_one_cycle() -> void:
	SignalBus.on_cycle_begin.emit(cycle_index)
	var any_action_executed_in_this_pass: bool = false
	CombatLog.instance.add_log("Cycle Start")
	
	for u in initiative_queue:
		u.turn_state = Unit.TurnState.IN_QUEUE

	for acting_unit in initiative_queue:
		if !is_instance_valid(acting_unit):
			continue
		if !acting_unit.is_alive():
			continue

		var ap_now: int = acting_unit.get_attributes_container().get_attribute_current_value("active_points")
		if ap_now <= 0:
			acting_unit.turn_state = Unit.TurnState.TURN_ENDED
			continue
		
		used_p_skill_this_turn.clear()

		# HOOK: turn-start (auras, stances, upkeep)
		acting_unit.turn_state = Unit.TurnState.TURN_STARTED
		SignalBus.on_turn_start.emit(acting_unit)
		SkillTriggerSystem.instance.fire("TURN_START", {"unit": acting_unit, "pass_index": cycle_index})
		Utilities.spawn_text_line(acting_unit, "Starting Turn")
		set_selected_unit(acting_unit)

		var action_executed: bool = await _try_execute_unit_action(acting_unit)

		# HOOK: turn-end (regen, bleed ticks, stance decay)
		acting_unit.turn_state = Unit.TurnState.TURN_ENDED
		SignalBus.on_turn_end.emit(acting_unit)
		SkillTriggerSystem.instance.fire("TURN_END", {"unit": acting_unit, "pass_index": cycle_index})
		await get_tree().create_timer(0.1).timeout

		if action_executed:
			any_action_executed_in_this_pass = true

		if _is_combat_over():
			break

	SignalBus.on_cycle_end.emit(cycle_index)
	cycle_index += 1
	
	CombatLog.instance.add_log("Cycle End")
	
	# If nobody did anything this pass (no AP spends or no valid actions), force end of round
	if !any_action_executed_in_this_pass:
		# All units have AP=0 or no valid actions
		# This will cause _enter_cleanup_phase to run
		pass



func _try_execute_unit_action(acting_unit: Unit) -> bool:
	# Decide what to do using tactics (player-set or AI). Your TacticsController likely does this.
	var chosen_action_id: String = ""
	var chosen_context: Dictionary = {}
	var use_skill_action: Action = null

	var tactics_controller: Node = acting_unit.tactics_controller
	if tactics_controller:
		use_skill_action = acting_unit.get_action_container().get_action_by_name("First Skill")


	if !use_skill_action:
		return false  # No valid action met its conditions

	# HOOK: before-action (guards, "before enemy attacks", taunts)
	SignalBus.on_before_action.emit(acting_unit, chosen_action_id, chosen_context)
	SkillTriggerSystem.instance.fire("BEFORE_ACTION", chosen_context)

	# Execute (centralize damage, healing, status, multi-hit, etc.)
	var ap_cost: int = 1
	if chosen_context.has("ap_cost"):
		ap_cost = int(chosen_context["ap_cost"])

	var executed_ok: bool = await _resolve_action_and_reactions(acting_unit, use_skill_action, chosen_context)
	if executed_ok:
		acting_unit.get_attributes_container().change_attribute_current_value_by("active_points", -ap_cost)

	# HOOK: after-action (follow-ups, procs, on-hit riders)
	SignalBus.on_after_action.emit(acting_unit, chosen_action_id, chosen_context)
	SkillTriggerSystem.instance.fire("AFTER_ACTION", {
		"user": acting_unit, "action_id": chosen_action_id, "ctx": chosen_context
	})

	SignalBus.update_stat_bars.emit()
	return executed_ok




func _resolve_action_and_reactions(user_unit: Unit, use_skill_action: Action, ctx: Dictionary) -> bool:
	# Reactions spend PP here (counters, guards, “before ally attacks”, “when targeted”, etc.)
	# You can route to your CombatSystem or a new ActionResolver.
	if action_resolver:
		return action_resolver.call("resolve", user_unit, use_skill_action, ctx)
	else:
		user_unit.get_action_container().use_action(use_skill_action, user_unit)
		await use_skill_action.on_action_ended
		# HOOK example for a specific reaction:
		# SkillTriggerSystem.instance.fire("BEFORE_HIT", {"user": user_unit, "ctx": ctx})
		return true

# Called by Skill.activate_skill BEFORE the Action runs.
func declare_skill(declared_skill: Skill, target_unit: Unit) -> void:
	
	if declared_skill == null or target_unit == null:
		push_error("No skill or target unit in declare_skill")
		return
	
	
	var user_unit: Unit = declared_skill.unit
	if user_unit == null:
		return
	
	# Make the skill activation bar appear
	SkillActivationUI.instance.on_active_declared(declared_skill.skill_name)
	
	
	# Open Chain Group 1: BEFORE_SKILL_USED (i.e., "on declaration")
	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.BEFORE_SKILL_USED,
		declared_skill, user_unit, target_unit, 0)



func after_skill_used(used_skill: Skill, target_unit: Unit) -> void:
	# Call this IMMEDIATELY AFTER the Action finishes (i.e., when the skill "ends").
	if used_skill == null or target_unit == null:
		return

	var user_unit: Unit = used_skill.unit
	if user_unit == null:
		return
	
	if SkillActivationUI.instance != null:
		SkillActivationUI.instance.schedule_active_end(1.0)
	

	# Open another Chain Group 1: AFTER_SKILL_USED (i.e., "on skill end")
	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.AFTER_SKILL_USED,
		used_skill, user_unit, target_unit, 0)



func _open_and_resolve_chain_group(trigger_phase: int, source_skill: Skill, source_user: Unit, source_target: Unit, current_depth: int) -> void:
	if current_depth >= chain_depth_limit:
		push_warning("Chain depth limit reached; aborting deeper reactions.")
		return

	# Ask SkillTriggerSystem which units can react and what passive they’ll use.
	var reaction_context: Dictionary = {
		"source_skill": source_skill,
		"source_user": source_user,
		"source_target": source_target,
		"trigger_phase": trigger_phase
	}

	var mapping_units_to_skills: Dictionary = skill_trigger_system.get_chaining_units_with_context(reaction_context)
	if mapping_units_to_skills.is_empty():
		return

	# Build initiative-ordered list of reactors.
	var reactor_units: Array[Unit] = mapping_units_to_skills.keys()
	reactor_units = _sort_units_by_initiative_desc(reactor_units)

	var new_group: ChainGroup = ChainGroup.new(trigger_phase, source_skill, source_user, source_target, reactor_units, current_depth + 1)
	chain_group_stack.push_back(new_group)
	await _resolve_top_chain_group(mapping_units_to_skills)
	chain_group_stack.pop_back()



func _resolve_top_chain_group(mapping_units_to_skills: Dictionary) -> void:
	if chain_group_stack.is_empty():
		return

	var active_group: ChainGroup = chain_group_stack[chain_group_stack.size() - 1]

	while active_group.next_index < active_group.reactors_in_order.size():
		var reactor_unit: Unit = active_group.reactors_in_order[active_group.next_index]

		if !is_instance_valid(reactor_unit) or !reactor_unit.is_alive():
			active_group.next_index += 1
			continue
		if used_p_skill_this_turn.has(reactor_unit):
			active_group.next_index += 1
			continue

		var passive_skill: Skill = mapping_units_to_skills.get(reactor_unit, null)
		if passive_skill == null:
			active_group.next_index += 1
			continue

		# DECLARE passive → open nested BEFORE_SKILL_USED for the passive itself
		await _declare_passive(passive_skill, reactor_unit, active_group)

		# USE passive (spend PP here if your Action doesn’t)
		await _use_passive(passive_skill, reactor_unit, active_group)

		# END passive → open nested AFTER_SKILL_USED for the passive itself
		await _end_passive(passive_skill, reactor_unit, active_group)


		active_group.next_index += 1



func _declare_passive(passive_skill: Skill, reactor_unit: Unit, parent_group: ChainGroup) -> void:
	CombatLog.instance.add_log(reactor_unit.ui_name + " declares passive: " + passive_skill.skill_name)
	used_p_skill_this_turn.append(reactor_unit)
	
	
	if SkillActivationUI.instance != null:
		var new_bar: PassiveSkillBar = await SkillActivationUI.instance.on_passive_declared(passive_skill.skill_name)
		var key_string: String = _make_passive_key(reactor_unit, passive_skill)
		if !passive_bars_by_key.has(key_string):
			passive_bars_by_key[key_string] = []
		var list_for_key: Array = passive_bars_by_key[key_string]
		list_for_key.append(new_bar)
		passive_bars_by_key[key_string] = list_for_key
	
	
	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.BEFORE_SKILL_USED,
		passive_skill,
		reactor_unit,
		parent_group.source_target,
		parent_group.depth
	)


func _use_passive(passive_skill: Skill, reactor_unit: Unit, _parent_group: ChainGroup) -> void:
	# Spend PP if not already handled by the Action
	if passive_skill.skill_category == Skill.SkillCategory.PASSIVE:
		var pp_attribute: Attribute = reactor_unit.get_attributes_container().get_attribute("passive_points")
		if pp_attribute != null:
			reactor_unit.get_attributes_container().change_attribute_current_value_by("passive_points", -passive_skill.skill_cost)

	# Execute the Action behind this passive (if any)
	if passive_skill.action != null:
		
		var target_pkg: TargetPackage = TargetPackage.new()
		var target_unit: Unit = passive_skill.get_random_valid_unit()
		target_pkg.set_unit_target(target_unit)
		target_pkg.set_skill(passive_skill)
		

		var run_action: Action = reactor_unit.character_sheet.action_container.use_action(passive_skill.action, target_pkg, true)
		await run_action.on_action_ended

	else:
		await get_tree().create_timer(0.05).timeout
		push_error("No action set in " + passive_skill.skill_name)


func _end_passive(passive_skill: Skill, reactor_unit: Unit, parent_group: ChainGroup) -> void:
	CombatLog.instance.add_log(reactor_unit.ui_name + " ends passive: " + passive_skill.skill_name)
	
	if SkillActivationUI.instance != null:
		var key_string: String = _make_passive_key(reactor_unit, passive_skill)
		if passive_bars_by_key.has(key_string):
			var list_for_key: Array = passive_bars_by_key[key_string]
			if list_for_key.size() > 0:
				var bar: PassiveSkillBar = list_for_key.pop_front()
				SkillActivationUI.instance.on_passive_ended(bar)
				passive_bars_by_key[key_string] = list_for_key
	
	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.AFTER_SKILL_USED,
		passive_skill,
		reactor_unit,
		parent_group.source_target,
		parent_group.depth
	)



func _sort_units_by_initiative_desc(units_in: Array[Unit]) -> Array[Unit]:
	var out_units: Array[Unit] = units_in.duplicate()
	out_units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var a_init: int = a.get_attributes_container().get_attribute_current_value("initiative")
		var b_init: int = b.get_attributes_container().get_attribute_current_value("initiative")
		if a_init == b_init:
			# Stable tie-breaker by unique name/id
			return a.get_instance_id() < b.get_instance_id()
		else:
			return a_init > b_init
	)
	return out_units



func _make_passive_key(reactor_unit: Unit, passive_skill: Skill) -> String:
	return str(reactor_unit.get_instance_id()) + ":" + str(passive_skill.get_instance_id())


"""
	var all_reactions_resolved: bool = false
	var iter_num: int = 0
	var chain_group: ChainGroup = ChainGroup.new()

	while !all_reactions_resolved and iter_num <= 20:
		iter_num += 1
		var chaining_units: Dictionary[Unit, Skill] = skill_trigger_system.get_chaining_units(skill, skill_trigger_system.TriggerPhase.BEFORE_SKILL_USED)
		if chaining_units.is_empty():
			continue
		
		chain_group.chain_depth = iter_num
		chain_group.s
		
		for key in chaining_units.keys():
			var c_unit: Unit = key
			var chained_skill: Skill = chaining_units[key]
		

	pass
"""


# ─────────────────────────────────────────────────────────────────────────────
# UTILITIES
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_ap_pp_for_all_units() -> void:
	for unit in unit_manager.get_all_units():
		var container = unit.get_attributes_container()
		container.set_attribute_current_value("active_points", container.get_attribute("active_points").base_value)
		container.set_attribute_current_value("passive_points", container.get_attribute("passive_points").base_value)
		# HOOKS if you want them:
		# SkillTriggerSystem.instance.fire("AP_REFRESH", {"unit": unit})
		# SkillTriggerSystem.instance.fire("PP_REFRESH", {"unit": unit})

func _roll_initiative_for_all_living() -> void:
	initiative_scores.clear()
	for unit in unit_manager.get_all_units():
		if unit.is_alive():
			var result: int = unit.get_attributes_container().get_attribute_current_value("initiative")
			initiative_scores[unit] = result

func _sort_initiative_queue() -> void:
	initiative_queue.assign(initiative_scores.keys())
	initiative_queue.sort_custom(func(a: Unit, b: Unit) -> bool:
		return initiative_scores[b] < initiative_scores[a]
	)

func _has_viable_actions_remaining() -> bool:
	# True if at least one living unit has AP > 0 AND at least one valid action
	for unit in initiative_queue:
		if !unit.is_alive():
			continue
		var ap_now: int = unit.get_attributes_container().get_attribute_current_value("active_points")
		if ap_now <= 0:
			continue
		var tactics_controller: Node = unit.tactics_controller
		if tactics_controller and tactics_controller.get_first_valid_active_skill():
			return true
		
	return false

func _is_combat_over() -> bool:
	cached_player_alive_count = 0
	cached_enemy_alive_count = 0
	for unit in unit_manager.get_all_units():
		if unit.is_alive():
			if unit.is_enemy:
				cached_enemy_alive_count += 1
			else:
				cached_player_alive_count += 1
	if cached_enemy_alive_count == 0 or cached_player_alive_count == 0:
		return true
	return false




func set_selected_unit(in_unit: Unit) -> void:
	if !can_select_unit(in_unit):
		return
	
	# Make the previous selected unit's square white again
	if selected_unit:
		selected_unit.selection_visual.clear_material()
		SignalBus.on_unit_unselected.emit(selected_unit)
	
	selected_unit = in_unit
	SignalBus.on_unit_selected.emit(selected_unit)
	selected_unit.selection_visual.set_blue()
	selected_unit.selection_visual.pulse_square()

func can_select_unit(_to_unit: Unit) -> bool:
	return true
