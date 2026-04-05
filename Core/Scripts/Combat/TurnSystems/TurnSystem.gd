## [b]Class:[/b] TurnSystem
## [i]Thin coordinator for the combat turn loop. Phase 4 refactor.[/i]
##
## [b]What changed in Phase 4[/b][br]
## Initiative management was extracted into [InitiativeManager].[br]
## The round/phase/cycle state machine was extracted into [RoundPhaseManager].[br]
## Both are created as child nodes in [method _ready] and wired with injected refs.[br]
## All previously public properties and methods remain on this class as forwarding
## properties or one-line delegates — no external caller needs to change.
##
## [b]What remains here[/b][br]
## • The [enum RoundPhase] enum (external code references [code]TurnSystem.RoundPhase.*[/code]).[br]
## • The [ChainGroup] inner class and the full passive-skill chain resolution pipeline.[br]
##   This block is intentionally untouched and will be addressed in Phase 5.[br]
## • Unit selection ([member selected_unit], [method set_selected_unit]).[br]
## • Passive-use tracking ([member used_p_skill_this_turn]) and the chain-group stack.[br]
## • The thin coordinator glue: forwarding properties + delegate methods.
class_name TurnSystem
extends Node


# ─── Enum ─────────────────────────────────────────────────────────────────────
# Stays here so external code (UnitCharacterSheet, UseFirstSkillAction, etc.) can
# continue writing TurnSystem.RoundPhase.PLAYER_PLANNING without any changes.
enum RoundPhase { AI_PLANNING, PLAYER_PLANNING, RESOLUTION, CLEANUP }


# ─── Exports ──────────────────────────────────────────────────────────────────
@export_category("References")
@export var unit_manager: UnitManager
@export var enemy_ai_system: Node        # optional: your AI planner
@export var skill_trigger_system: SkillTriggerSystem

@export_category("Debug")
## When false, units never enter the Downed state regardless of posture damage.
@export var death_enabled: bool = true

@export_category("Chaining")
@export var chain_depth_limit: int = 8


# ─── Skill-chain state ────────────────────────────────────────────────────────
# These remain in TurnSystem because the skill-chain pipeline (below) uses them.
# They will be reconsidered in Phase 5 when that pipeline gets its own home.

## Tracks which units have already fired a passive skill during the current unit's turn,
## preventing the same unit from chaining again until the next turn.
var used_p_skill_this_turn: Array[Unit] = []

## When a unit declares a skill but has not finished it they enter this stack.
var use_skill_stack: Array[Unit] = []

## Stack of active ChainGroups. Grows with nested passive reactions; shrinks as they resolve.
var chain_group_stack: Array[ChainGroup] = []


# ─── Selection ────────────────────────────────────────────────────────────────
var selected_unit: Unit = null

## True while the game is paused (written by PauseManager, read by UI).
var is_paused: bool = false


# ─── Private: managed child nodes ─────────────────────────────────────────────
# These are the two extracted coordinators. External code must NOT access them
# directly — use TurnSystem's forwarding properties and delegate methods instead.
var _initiative_manager: InitiativeManager
var _round_phase_manager: RoundPhaseManager


# ─── Singleton ────────────────────────────────────────────────────────────────
static var instance: TurnSystem = null


# ─── Forwarding properties ────────────────────────────────────────────────────
# These preserve the full external API. Every file that previously read
# TurnSystem.instance.initiative_queue (etc.) continues to compile and work
# without a single-line change.

## Live turn queue from InitiativeManager. Returns the actual array (no copy),
## so callers reading it see real-time updates just as before.
var initiative_queue: Array[Unit]:
	get: return _initiative_manager.queue

## Per-unit initiative scores for this round.
var initiative_scores: Dictionary[Unit, int]:
	get: return _initiative_manager.scores

## The score of the unit at the back of the sorted queue.
var lowest_initiative_score: int:
	get: return _initiative_manager.lowest_score

## The current round phase. Compare against TurnSystem.RoundPhase.* values.
var current_phase: int:
	get: return _round_phase_manager.current_phase

## Increments each time a new round begins.
var round_number: int:
	get: return _round_phase_manager.round_number

## True once start_combat() has been called.
var is_combat_started: bool:
	get: return _round_phase_manager.is_combat_started


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if instance != null:
		push_error("There's more than one TurnSystem! - " + str(instance))
		queue_free()
		return
	instance = self

	# Create InitiativeManager first; RoundPhaseManager depends on it.
	# Refs are injected before add_child() so each node's _ready() fires with
	# them already available (Godot calls _ready() synchronously inside add_child).
	_initiative_manager = InitiativeManager.new()
	_initiative_manager.name = "InitiativeManager"
	_initiative_manager.unit_manager = unit_manager
	add_child(_initiative_manager)

	_round_phase_manager = RoundPhaseManager.new()
	_round_phase_manager.name = "RoundPhaseManager"
	_round_phase_manager.unit_manager     = unit_manager
	_round_phase_manager.enemy_ai_system  = enemy_ai_system
	_round_phase_manager.initiative_manager = _initiative_manager
	_round_phase_manager.turn_system      = self   # back-reference; safe — both are Nodes
	add_child(_round_phase_manager)
	# RoundPhaseManager connects SignalBus.end_turn in its own _ready().


func _unhandled_input(_event: InputEvent) -> void:
	# Test-key shortcut to start combat without a UI button.
	if !is_combat_started:
		if Input.is_action_just_pressed("testkey_n"):
			start_combat()


# ─── PUBLIC ENTRY DELEGATES ───────────────────────────────────────────────────
# One-line wrappers so external code keeps calling TurnSystem.instance.start_combat()
# etc. without knowing which internal class now owns the logic.

func start_combat() -> void:
	_round_phase_manager.start_combat()

func begin_round_resolution() -> void:
	_round_phase_manager.begin_round_resolution()


# ─── INITIATIVE DELEGATES ─────────────────────────────────────────────────────
# These methods are part of the public API (called by statuses, Unit.revive(), etc.).
# They delegate data work to InitiativeManager and keep UI signal emission here
# because signals are a coordination concern, not an initiative-data concern.

## Inserts a just-revived unit into the current round's initiative queue.
## Called by Unit.revive() when revival happens during a planning phase.
func add_revived_unit_to_round(unit: Unit) -> void:
	_initiative_manager.add_revived_unit(unit)
	# IM updates scores and re-sorts; TurnSystem fires the UI signals.
	SignalBus.instantiate_initiative_queue.emit()
	SignalBus.update_stat_bars.emit()
	CombatLog.instance.add_log(unit.ui_name + " re-enters the initiative queue.")

## Re-rolls all living units' initiative from current attribute values and re-sorts.
## Called by InitiativeDownAffliction / InitiativeUpBlessing status effects.
func resort_initiative_mid_round(preserve_current_turn: bool = true) -> void:
	_initiative_manager.resort_mid_round(preserve_current_turn, selected_unit)
	# IM updates scores, re-sorts, and optionally pins the acting unit; TurnSystem signals UI.
	SignalBus.instantiate_initiative_queue.emit()


# ─── ROUND-PHASE CALLBACK ─────────────────────────────────────────────────────

## Called by RoundPhaseManager at the top of each unit's turn (the single back-ref call
## RPM makes into TurnSystem). Clears passive-use tracking and updates selection.
func begin_unit_turn(unit: Unit) -> void:
	used_p_skill_this_turn.clear()
	set_selected_unit(unit)


# ─── HIT REACTION GATEWAY ─────────────────────────────────────────────────────

## Public entry point for CombatAction to open a BEFORE_HIT_RESOLVES or AFTER_HIT_RESOLVES
## chain group at the hit moment. Keeps _open_and_resolve_chain_group() private while
## giving CombatAction a clean, named hook.
func open_hit_reactions(phase: int, source_skill: Skill, source_user: Unit, source_target: Unit, depth: int) -> void:
	await _open_and_resolve_chain_group(phase, source_skill, source_user, source_target, depth)


## Silently evaluates and applies BEFORE_HIT_RESOLVES passive skills at declaration time,
## before any animation begins. Effects (e.g. [ForceMissEffect]) are applied directly
## from [member Skill.effects] / [member Skill.self_effects] — no Action, no UI, no chain.
##
## Deliberately skips the [member used_p_skill_this_turn] guard so Dodge/Parry passives
## always fire regardless of what the unit has already done this turn.
##
## Called by [method CombatSystem.declare_attack] after the hit roll but BEFORE
## [method CombatSystem.determine_reaction], so [member CombatEventData.is_hit] is
## already final when the reaction animation is selected.
##
## Skills that fire are appended to [member CombatEventData.pre_hit_passive_skills]
## so [CombatAction] can schedule their passive bar slide-in later.
func evaluate_pre_hit_passives(cd: CombatEventData) -> void:
	if skill_trigger_system == null or cd == null or cd.skill == null:
		return

	var ctx: Dictionary = {
		"source_skill":  cd.skill,
		"source_user":   cd.attacker,
		"source_target": cd.defender,
		"trigger_phase": SkillTriggerSystem.TriggerPhase.BEFORE_HIT_RESOLVES
	}

	for reactor_unit: Unit in initiative_queue:
		if reactor_unit == null or !reactor_unit.is_alive():
			continue
		if reactor_unit.tactics_controller == null:
			continue

		var passive_skill: Skill = reactor_unit.tactics_controller.get_first_valid_passive_skill_with_context(ctx)
		if passive_skill == null:
			continue

		# Stamp context onto conditions so they can read combat event data during effect.apply()
		passive_skill._apply_context_to_all_conditions(ctx)

		# Deduct passive points (same as _use_passive in the normal chain)
		reactor_unit.get_attributes_container().change_attribute_current_value_by("passive_points", -passive_skill.skill_cost)

		# Apply effects directly — no Action, no animation, no UI at this stage
		var target_unit: Unit = passive_skill.get_random_valid_unit()
		for effect in passive_skill.effects:
			if effect == null:
				continue
			effect.set_context({"user": reactor_unit, "target_unit": target_unit})
			effect.apply()
		for effect in passive_skill.self_effects:
			if effect == null:
				continue
			effect.set_context({"user": reactor_unit, "target_unit": reactor_unit})
			effect.apply()

		if !cd.pre_hit_passive_skills.has(passive_skill):
			cd.pre_hit_passive_skills.append(passive_skill)

		CombatLog.instance.add_log(reactor_unit.ui_name + " pre-evaluated passive: " + passive_skill.skill_name)


## Executes a passive skill without opening a chain group for reactions.
## Used by SkillTriggerSystem.fire() for round-boundary passives (ON_ROUND_START,
## ON_ROUND_END), which cannot be reacted to by design.
## Mirrors _declare_passive + _use_passive + _end_passive minus the chaining calls.
func execute_passive_skill_no_chain(passive_skill: Skill, reactor_unit: Unit) -> void:
	CombatLog.instance.add_log(reactor_unit.ui_name + " uses round passive: " + passive_skill.skill_name)

	var manager_ref: PassiveBarManager = _get_passive_manager()
	var passive_key: String = ""
	if manager_ref != null:
		passive_key = _make_passive_key(reactor_unit, passive_skill)
		manager_ref.add_passive(passive_skill.skill_name, passive_key)

	reactor_unit.get_attributes_container().change_attribute_current_value_by("passive_points", -passive_skill.skill_cost)

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

	if manager_ref != null:
		await manager_ref.end_oldest_for_key(passive_key)

	CombatLog.instance.add_log(reactor_unit.ui_name + " ends round passive: " + passive_skill.skill_name)


# ─────────────────────────────────────────────────────────────────────────────
# SKILL CHAIN PIPELINE  (Phase 5 domain — intentionally unchanged)
# ─────────────────────────────────────────────────────────────────────────────
# Everything below this line was not touched in Phase 4. It handles active-skill
# declaration, passive-skill reactions, and the nested ChainGroup stack.
# Phase 5 will implement SkillTriggerSystem.fire() and may extract this block.


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


func execute_active_skill_for_unit(acting_unit: Unit, explicit_skill: Skill = null) -> bool:
	if acting_unit == null:
		return false
	if !acting_unit.is_alive():
		return false

	var chosen_skill: Skill = explicit_skill
	if chosen_skill == null:
		if acting_unit.tactics_controller == null:
			return false
		chosen_skill = acting_unit.tactics_controller.get_first_valid_active_skill()

	if chosen_skill == null:
		return false

	if chosen_skill.unit == null:
		chosen_skill.set_unit(acting_unit)

	var target_unit: Unit = chosen_skill.get_random_valid_unit()
	if target_unit == null:
		CombatLog.instance.add_log("No valid target for " + chosen_skill.skill_name)
		return false

	var context: Dictionary = {
		"skill": chosen_skill,
		"target": target_unit
	}

	SignalBus.on_before_action.emit(acting_unit, chosen_skill.skill_name, context)
	# Note: fire("BEFORE_ACTION") is called at the outer scope in RoundPhaseManager._try_execute_unit_action().
	# Not duplicated here to avoid double-firing once fire() is implemented for equipment/gear hooks.

	await declare_skill(chosen_skill, target_unit)

	var did_resolve: bool = await _run_skill_action_core(acting_unit, chosen_skill, target_unit)

	await after_skill_used(chosen_skill, target_unit)

	chosen_skill.end_skill()

	if did_resolve:
		var ap_spend: int = chosen_skill.skill_cost
		acting_unit.get_attributes_container().change_attribute_current_value_by("active_points", -ap_spend)

	SignalBus.on_after_action.emit(acting_unit, chosen_skill.skill_name, context)
	# Note: fire("AFTER_ACTION") is called at the outer scope in RoundPhaseManager._try_execute_unit_action().

	SignalBus.update_stat_bars.emit()
	return did_resolve


func _run_skill_action_core(user_unit: Unit, skill: Skill, target_unit: Unit) -> bool:
	if user_unit == null:
		return false
	if skill == null:
		return false
	if target_unit == null:
		return false

	var target_package: TargetPackage = Utilities.make_target_package(target_unit)
	target_package.set_skill(skill)

	var run_action: Action = user_unit.character_sheet.action_container.use_action(skill.action, target_package, true)
	await run_action.on_action_ended
	return true


# Called by Skill.activate_skill BEFORE the Action runs.
func declare_skill(declared_skill: Skill, target_unit: Unit) -> void:
	if declared_skill == null or target_unit == null:
		push_error("No skill or target unit in declare_skill")
		return

	var user_unit: Unit = declared_skill.unit
	if user_unit == null:
		return

	var prio_num: int = user_unit.tactics_controller.get_skill_priority_num(declared_skill)

	SkillActivationUI.instance.on_active_declared(declared_skill.skill_name, prio_num)
	UnitActionSystem.instance.show_unit_move_ranges(user_unit)

	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.BEFORE_SKILL_USED,
		declared_skill, user_unit, target_unit, 0)


func after_skill_used(used_skill: Skill, target_unit: Unit) -> void:
	if used_skill == null or target_unit == null:
		return

	var user_unit: Unit = used_skill.unit
	if user_unit == null:
		return

	if SkillActivationUI.instance != null:
		SkillActivationUI.instance.schedule_active_end(1.0)

	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.AFTER_SKILL_USED,
		used_skill, user_unit, target_unit, 0)


func _open_and_resolve_chain_group(trigger_phase: int, source_skill: Skill, source_user: Unit, source_target: Unit, current_depth: int) -> void:
	if current_depth >= chain_depth_limit:
		push_warning("Chain depth limit reached; aborting deeper reactions.")
		return

	var reaction_context: Dictionary = {
		"source_skill": source_skill,
		"source_user": source_user,
		"source_target": source_target,
		"trigger_phase": trigger_phase
	}

	var mapping_units_to_skills: Dictionary = skill_trigger_system.get_chaining_units_with_context(reaction_context)
	if mapping_units_to_skills.is_empty():
		return

	var reactor_units: Array[Unit] = mapping_units_to_skills.keys()
	# Delegate ordering to InitiativeManager so the sort logic lives in one place.
	reactor_units = _initiative_manager.sort_units_desc(reactor_units)

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
		
		# Delay to aid in player visual parsing
		await get_tree().create_timer(0.5).timeout
		
		await _declare_passive(passive_skill, reactor_unit, active_group)
		await _use_passive(passive_skill, reactor_unit, active_group)
		await _end_passive(passive_skill, reactor_unit, active_group)
		
		# Delay to aid in player visual parsing
		await get_tree().create_timer(0.5).timeout

		active_group.next_index += 1


func _declare_passive(passive_skill: Skill, reactor_unit: Unit, parent_group: ChainGroup) -> void:
	CombatLog.instance.add_log(reactor_unit.ui_name + " declares passive: " + passive_skill.skill_name)
	used_p_skill_this_turn.append(reactor_unit)
	if passive_skill.skill_name == "Passive Critical Up":# or passive_skill.skill_name == "Passive Martial Up":
		pass

	var manager_ref: PassiveBarManager = _get_passive_manager()
	if manager_ref != null:
		var passive_key: String = _make_passive_key(reactor_unit, passive_skill)
		manager_ref.add_passive(passive_skill.skill_name, passive_key)

	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.BEFORE_SKILL_USED,
		passive_skill,
		reactor_unit,
		parent_group.source_target,
		parent_group.depth
	)


func _use_passive(passive_skill: Skill, reactor_unit: Unit, _parent_group: ChainGroup) -> void:
	if passive_skill.skill_category == Skill.SkillCategory.PASSIVE:
		var pp_attribute: Attribute = reactor_unit.get_attributes_container().get_attribute("passive_points")
		if pp_attribute != null:
			reactor_unit.get_attributes_container().change_attribute_current_value_by("passive_points", -passive_skill.skill_cost)
	
	var reaction_context: Dictionary = {
		"source_skill": _parent_group.source_skill,
		"source_user": _parent_group.source_user,
		"source_target": _parent_group.source_target,
		"trigger_phase": _parent_group.trigger_phase
	}
	
	if passive_skill.action != null:
		passive_skill._apply_context_to_all_conditions(reaction_context)
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

	var manager_ref: PassiveBarManager = _get_passive_manager()
	if manager_ref != null:
		var passive_key: String = _make_passive_key(reactor_unit, passive_skill)
		await manager_ref.end_oldest_for_key(passive_key)

	await _open_and_resolve_chain_group(
		SkillTriggerSystem.TriggerPhase.AFTER_SKILL_USED,
		passive_skill,
		reactor_unit,
		parent_group.source_target,
		parent_group.depth
	)


# ─── SELECTION ────────────────────────────────────────────────────────────────

func set_selected_unit(in_unit: Unit) -> void:
	if !can_select_unit(in_unit):
		return

	if selected_unit:
		selected_unit.selection_visual.clear_material()
		SignalBus.on_unit_unselected.emit(selected_unit)

	selected_unit = in_unit
	SignalBus.on_unit_selected.emit(selected_unit)
	selected_unit.selection_visual.set_blue()
	selected_unit.selection_visual.pulse_square()

func can_select_unit(_to_unit: Unit) -> bool:
	return true


# ─── PRIVATE HELPERS ──────────────────────────────────────────────────────────

func _get_passive_manager() -> PassiveBarManager:
	if SkillActivationUI.instance != null:
		return SkillActivationUI.instance.passive_manager
	return null

func _make_passive_key(reactor_unit: Unit, passive_skill: Skill) -> String:
	return str(reactor_unit.get_instance_id()) + ":" + str(passive_skill.get_instance_id())
