## [b]Class:[/b] RoundPhaseManager
## [i]Owns the round/phase state machine and cycle loop, extracted from TurnSystem (Phase 4).[/i]
##
## [b]Responsibilities[/b][br]
## • Drives the AI_PLANNING → PLAYER_PLANNING → RESOLUTION → CLEANUP state machine.[br]
## • Runs the cycle loop: iterates the initiative queue until all AP is spent.[br]
## • Emits all round/turn/cycle [code]SignalBus[/code] events at the appropriate moments.[br]
## • Has no knowledge of skill chains or passive reactions — those remain in [TurnSystem]
##   and will be addressed in Phase 5.
##
## [b]How it is wired[/b][br]
## Created and owned by [TurnSystem] in [method TurnSystem._ready]. Refs ([member unit_manager],
## [member initiative_manager], [member turn_system], [member enemy_ai_system]) are injected
## before [method Node.add_child] so they are available when [method _ready] fires.[br]
## External code should interact with phases exclusively through [TurnSystem]'s public API
## (delegates) — never through this class directly.
##
## [b]Back-reference note[/b][br]
## [member turn_system] is a back-ref to the parent coordinator. It is used in exactly
## two places: [method _run_one_cycle] calls [method TurnSystem.begin_unit_turn] to let
## TurnSystem clear passive tracking and update selection at the start of each unit's turn.
class_name RoundPhaseManager
extends Node
# Must extend Node (not RefCounted) because _run_one_cycle uses await get_tree().create_timer().


# ─── Injected references ──────────────────────────────────────────────────────
# All set by TurnSystem before add_child() so _ready() fires with them available.

## Back-reference to the coordinating TurnSystem. Used only to call begin_unit_turn().
var turn_system: TurnSystem = null

## The initiative manager; provides the turn queue for cycle iteration.
var initiative_manager: InitiativeManager = null

## The unit registry; used to get all units for AP/PP refresh and combat-over checks.
var unit_manager: UnitManager = null

## Optional enemy AI planner. Called synchronously during AI_PLANNING.
var enemy_ai_system: Node = null


# ─── Phase state ──────────────────────────────────────────────────────────────
# These were previously bare vars on TurnSystem. TurnSystem now exposes them as
# read-only forwarding properties so all existing callers compile unchanged.

## The current round phase. Use [code]TurnSystem.RoundPhase.*[/code] values.
var current_phase: int = TurnSystem.RoundPhase.AI_PLANNING

## Increments each time a new round begins.
var round_number: int = 1

## True once start_combat() has been called.
var is_combat_started: bool = false

## Guard flag: prevents begin_round_resolution() from firing twice if clicked rapidly.
var start_round_button_blocked: bool = false

## Tracks which cycle (pass over the initiative queue) we are currently in.
var cycle_index: int = 0

# Cached team counts used for combat-over detection; updated inside _is_combat_over().
var cached_player_alive_count: int = 0
var cached_enemy_alive_count: int = 0


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect the "End Turn / Begin Round" button signal here so TurnSystem._ready()
	# does not need to know about this internal handler.
	SignalBus.end_turn.connect(_on_end_turn)


# ─── PUBLIC ENTRY ─────────────────────────────────────────────────────────────

## Starts the first round. Called via TurnSystem.start_combat() delegate.
## Previously the body of TurnSystem.start_combat().
func start_combat() -> void:
	if is_combat_started:
		return

	is_combat_started = true
	round_number = 1

	# Selection lives in TurnSystem; ask it to pick the first unit for UI purposes.
	turn_system.set_selected_unit(UnitManager.instance.get_first_unit())

	SignalBus.on_combat_started.emit()
	_start_round()


# ─── ROUND CYCLE ──────────────────────────────────────────────────────────────

## Kicks off a new round: refresh AP/PP, roll initiative, then enter AI planning.
## Previously TurnSystem._start_round().
func _start_round() -> void:
	SignalBus.on_round_start.emit(round_number)
	initialize_initiative_ap_and_pp()
	_enter_ai_planning_phase()


## Resets AP/PP and rolls initiative. Called at the top of every round so the
## initiative queue and resource bars are ready before the planning phases begin.
## Previously TurnSystem.initialize_initiative_ap_and_pp().
func initialize_initiative_ap_and_pp() -> void:
	_refresh_ap_pp_for_all_units()
	initiative_manager.roll_all_living()
	initiative_manager.sort_queue()

	SignalBus.instantiate_initiative_queue.emit()
	SignalBus.update_stat_bars.emit()


## Transitions to AI_PLANNING. Calls enemy_ai_system synchronously (safe — AI only
## writes tactics, it does not animate or await).
## Previously TurnSystem._enter_ai_planning_phase().
func _enter_ai_planning_phase() -> void:
	current_phase = TurnSystem.RoundPhase.AI_PLANNING
	SignalBus.on_planning_ai_start.emit(round_number)

	if enemy_ai_system:
		enemy_ai_system.call("plan_round_for_enemies", unit_manager)

	SignalBus.on_planning_ai_end.emit(round_number)
	_enter_player_planning_phase()


## Transitions to PLAYER_PLANNING. Enables input and waits for the player to press
## the Begin Round button (which fires SignalBus.end_turn → _on_end_turn).
## Previously TurnSystem._enter_player_planning_phase().
func _enter_player_planning_phase() -> void:
	current_phase = TurnSystem.RoundPhase.PLAYER_PLANNING
	SignalBus.on_planning_player_start.emit(round_number)

	UnitActionSystem.instance.is_enabled = true
	CombatLog.instance.add_log("Player Planning")
	start_round_button_blocked = false


## Signal handler for SignalBus.end_turn (the "Begin Round" button).
## Only acts during PLAYER_PLANNING; other presses are silently ignored.
## Previously TurnSystem._on_end_turn().
func _on_end_turn() -> void:
	if current_phase == TurnSystem.RoundPhase.PLAYER_PLANNING:
		begin_round_resolution()
	else:
		CombatLog.instance.add_log()


## Called by the UI "Begin Round" button or via the TurnSystem delegate.
## Closes the planning phase and starts RESOLUTION. The guard flag prevents double-fires.
## Previously TurnSystem.begin_round_resolution().
func begin_round_resolution() -> void:
	if start_round_button_blocked:
		return
	start_round_button_blocked = true

	UnitActionSystem.instance.is_enabled = false
	SignalBus.on_planning_player_end.emit(round_number)
	CombatLog.instance.add_log("Round Resolution")

	_enter_resolution_phase()


## Transitions to RESOLUTION. Runs cycles until no more viable actions remain or
## combat ends, then hands off to CLEANUP.
## Previously TurnSystem._enter_resolution_phase().
func _enter_resolution_phase() -> void:
	current_phase = TurnSystem.RoundPhase.RESOLUTION
	cycle_index = 0

	CombatLog.instance.add_log("Resolution Phase")

	# Fire round-start passives after planning ends, before the first unit acts.
	await SkillTriggerSystem.instance.fire("ROUND_START", {"round_number": round_number})

	while _has_viable_actions_remaining():
		await _run_one_cycle()
		if _is_combat_over():
			break
		if cycle_index >= 100:
			push_error("Cycle count exceeded 100 in RoundPhaseManager — infinite loop guard triggered.")
			break

	_enter_cleanup_phase()


## Transitions to CLEANUP. Fires round-end hooks, increments round_number, and
## either starts the next round or ends combat.
## Previously TurnSystem._enter_cleanup_phase().
func _enter_cleanup_phase() -> void:
	current_phase = TurnSystem.RoundPhase.CLEANUP

	SignalBus.on_round_end.emit(round_number)
	await SkillTriggerSystem.instance.fire("ROUND_END", {"round_number": round_number})

	if _is_combat_over():
		SignalBus.on_team_wiped.emit(cached_enemy_alive_count == 0)
		CombatLog.instance.add_log()
		CombatLog.instance.add_log("Combat Ended!")
		return

	CombatLog.instance.add_log("Cleanup Phase")
	round_number += 1
	_start_round()


# ─── CYCLES & TURNS ───────────────────────────────────────────────────────────

## One full pass over the initiative queue. Each living unit with AP > 0 gets a turn.
## Previously TurnSystem._run_one_cycle().
func _run_one_cycle() -> void:
	SignalBus.on_cycle_begin.emit(cycle_index)
	CombatLog.instance.add_log("Cycle Start")

	for u in initiative_manager.queue:
		u.turn_state = Unit.TurnState.IN_QUEUE

	var any_action_executed_in_this_pass: bool = false

	for acting_unit in initiative_manager.queue:
		if !is_instance_valid(acting_unit):
			continue
		if !acting_unit.is_alive():
			continue

		var ap_now: int = acting_unit.get_attributes_container().get_attribute_current_value("active_points")
		if ap_now <= 0:
			acting_unit.turn_state = Unit.TurnState.TURN_ENDED
			continue

		# Notify TurnSystem to clear passive-use tracking and update unit selection.
		# turn_system.begin_unit_turn() is the single back-ref call RPM makes into TurnSystem.
		acting_unit.turn_state = Unit.TurnState.TURN_STARTED
		turn_system.begin_unit_turn(acting_unit)

		SignalBus.on_turn_start.emit(acting_unit)
		await SkillTriggerSystem.instance.fire("TURN_START", {"unit": acting_unit, "pass_index": cycle_index})
		Utilities.spawn_text_line(acting_unit, "Starting Turn")

		var action_executed: bool = await _try_execute_unit_action(acting_unit)

		acting_unit.turn_state = Unit.TurnState.TURN_ENDED
		SignalBus.on_turn_end.emit(acting_unit)
		await SkillTriggerSystem.instance.fire("TURN_END", {"unit": acting_unit, "pass_index": cycle_index})
		await get_tree().create_timer(0.1).timeout

		if action_executed:
			any_action_executed_in_this_pass = true

		if _is_combat_over():
			break

	SignalBus.on_cycle_end.emit(cycle_index)
	cycle_index += 1
	CombatLog.instance.add_log("Cycle End")


## Decides what action the unit takes this turn (tactics → "First Skill" action) and
## executes it. Returns true if an action was actually resolved.
## Previously TurnSystem._try_execute_unit_action().
func _try_execute_unit_action(acting_unit: Unit) -> bool:
	var chosen_action_id: String = ""
	var chosen_context: Dictionary = {}
	var use_skill_action: Action = null

	var tactics_controller: TacticsController = acting_unit.tactics_controller
	if tactics_controller:
		use_skill_action = acting_unit.get_action_container().get_action_by_name("First Skill")

	if !use_skill_action:
		return false

	SignalBus.on_before_action.emit(acting_unit, chosen_action_id, chosen_context)
	await SkillTriggerSystem.instance.fire("BEFORE_ACTION", chosen_context)

	var executed_ok: bool = await _resolve_action_and_reactions(acting_unit, use_skill_action, chosen_context)

	SignalBus.on_after_action.emit(acting_unit, chosen_action_id, chosen_context)
	await SkillTriggerSystem.instance.fire("AFTER_ACTION", {
		"user": acting_unit, "action_id": chosen_action_id, "ctx": chosen_context
	})

	SignalBus.update_stat_bars.emit()
	return executed_ok


## Runs the chosen action and waits for it to finish.
## Previously TurnSystem._resolve_action_and_reactions().
func _resolve_action_and_reactions(user_unit: Unit, use_skill_action: Action, _ctx: Dictionary) -> bool:
	var run_action: Action = user_unit.get_action_container().use_action(use_skill_action, user_unit)
	await run_action.on_action_ended
	return true


# ─── QUERIES ──────────────────────────────────────────────────────────────────

## Returns true if any living unit in the queue has AP > 0 and at least one valid action.
## The resolution phase loop continues while this is true.
## Previously TurnSystem._has_viable_actions_remaining().
func _has_viable_actions_remaining() -> bool:
	for unit in initiative_manager.queue:
		if !unit.is_alive():
			continue
		var ap_now: int = unit.get_attributes_container().get_attribute_current_value("active_points")
		if ap_now <= 0:
			continue
		var tactics_controller: Node = unit.tactics_controller
		if tactics_controller and tactics_controller.get_first_valid_active_skill():
			return true
	return false


## Returns true if all units on one side are dead or downed.
## Updates [member cached_player_alive_count] and [member cached_enemy_alive_count]
## as a side-effect (used by _enter_cleanup_phase to know which team won).
## Previously TurnSystem._is_combat_over().
func _is_combat_over() -> bool:
	cached_player_alive_count = 0
	cached_enemy_alive_count = 0
	for unit in unit_manager.get_all_units():
		if unit.is_alive():
			if unit.is_enemy:
				cached_enemy_alive_count += 1
			else:
				cached_player_alive_count += 1
	return cached_enemy_alive_count == 0 or cached_player_alive_count == 0


# ─── HELPERS ──────────────────────────────────────────────────────────────────

## Restores every unit's AP and PP to their base values at the start of a new round.
## Previously TurnSystem._refresh_ap_pp_for_all_units().
func _refresh_ap_pp_for_all_units() -> void:
	for unit in unit_manager.get_all_units():
		var container = unit.get_attributes_container()
		container.set_attribute_current_value("active_points",  container.get_attribute("active_points").base_value)
		container.set_attribute_current_value("passive_points", container.get_attribute("passive_points").base_value)
