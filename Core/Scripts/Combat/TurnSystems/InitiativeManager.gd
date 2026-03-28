## [b]Class:[/b] InitiativeManager
## [i]Owns all initiative data and ordering logic, extracted from TurnSystem (Phase 4).[/i]
##
## [b]Responsibilities[/b][br]
## • Stores the per-unit initiative score table ([member scores]).[br]
## • Maintains the sorted turn queue ([member queue]).[br]
## • Rolls, sorts, and reorders initiative on request.[br]
## • Has no knowledge of phases, skill chains, or UI — it is pure data + ordering.
##
## [b]How it is wired[/b][br]
## Created and owned by [TurnSystem] in [method TurnSystem._ready]. External code should
## continue to read initiative data through [TurnSystem]'s forwarding properties
## ([code]initiative_queue[/code], [code]initiative_scores[/code], [code]lowest_initiative_score[/code])
## rather than accessing this class directly, so the public API stays stable.
class_name InitiativeManager
extends Node


# ─── Injected references ──────────────────────────────────────────────────────
# Set by TurnSystem before add_child() so _ready() can use them if needed.

## The unit registry. Used when rolling initiative for all living units.
var unit_manager: UnitManager = null


# ─── State ────────────────────────────────────────────────────────────────────
# These were previously bare vars on TurnSystem (initiative_scores, initiative_queue,
# lowest_initiative_score). They now live here; TurnSystem exposes them as read-only
# forwarding properties so all existing callers continue to compile unchanged.

## Maps each living unit to its current initiative score for this round.
var scores: Dictionary[Unit, int] = {}

## Units sorted descending by initiative score — this IS the turn queue.
var queue: Array[Unit] = []

## The score of the unit at the back of the queue (lowest initiative).
## Previously declared on TurnSystem but never assigned; now properly maintained here.
var lowest_score: int = 0


# ─── Initiative rolling ───────────────────────────────────────────────────────

## Rebuilds [member scores] from each living unit's current initiative attribute.
## Previously [code]_roll_initiative_for_all_living()[/code] on TurnSystem.
func roll_all_living() -> void:
	scores.clear()
	for unit in unit_manager.get_all_units():
		if unit.is_alive():
			var result: int = unit.get_attributes_container().get_attribute_current_value("initiative")
			scores[unit] = result


# ─── Queue sorting ────────────────────────────────────────────────────────────

## Rebuilds [member queue] from [member scores] sorted highest-first, then updates
## [member lowest_score] to the tail of the sorted list.
## Previously [code]_sort_initiative_queue()[/code] on TurnSystem.
func sort_queue() -> void:
	queue.assign(scores.keys())
	queue.sort_custom(func(a: Unit, b: Unit) -> bool:
		return scores[b] < scores[a]
	)
	# lowest_initiative_score was declared on TurnSystem but never written to.
	# We now maintain it correctly here.
	lowest_score = scores.get(queue.back(), 0) if not queue.is_empty() else 0


## Returns a copy of [param units_in] sorted by initiative attribute, highest first.
## Tie-broken by instance ID for deterministic ordering.
## Previously [code]_sort_units_by_initiative_desc()[/code] on TurnSystem; still used
## by [TurnSystem]'s chain-group resolution to order passive reactors.
func sort_units_desc(units_in: Array[Unit]) -> Array[Unit]:
	var out: Array[Unit] = units_in.duplicate()
	out.sort_custom(func(a: Unit, b: Unit) -> bool:
		var a_init: int = a.get_attributes_container().get_attribute_current_value("initiative")
		var b_init: int = b.get_attributes_container().get_attribute_current_value("initiative")
		if a_init == b_init:
			return a.get_instance_id() < b.get_instance_id()
		else:
			return a_init > b_init
	)
	return out


# ─── Mid-round updates ────────────────────────────────────────────────────────

## Inserts a freshly revived [param unit] into the active round's queue.
## Reads the unit's current initiative attribute, adds it to [member scores], and re-sorts.
## Previously part of [code]add_revived_unit_to_round()[/code] on TurnSystem.
## The caller (TurnSystem) is responsible for emitting SignalBus events afterward.
func add_revived_unit(unit: Unit) -> void:
	var init_score: int = unit.get_attributes_container().get_attribute_current_value("initiative")
	scores[unit] = init_score
	sort_queue()


## Re-rolls all living units' initiative from their current attributes and re-sorts the queue.
## If [param preserve_current] is true and [param current_unit] is mid-turn, they are pinned
## to the front of the new queue so their turn is not interrupted.
## Previously the body of [code]resort_initiative_mid_round()[/code] on TurnSystem.
## The caller (TurnSystem) is responsible for emitting SignalBus events afterward.
func resort_mid_round(preserve_current: bool, current_unit: Unit) -> void:
	var current_has_turn: bool = false
	if current_unit != null:
		current_has_turn = current_unit.turn_state == Unit.TurnState.TURN_STARTED

	roll_all_living()
	sort_queue()

	# Pin the acting unit at the front so a mid-action resort does not skip their turn.
	if preserve_current and current_has_turn:
		if queue.has(current_unit):
			queue.erase(current_unit)
			queue.push_front(current_unit)
