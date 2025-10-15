## [b]Class:[/b] ActionContainer
## [i]Holds a unit’s actions, prepares unique instances, and routes activation calls.[/i]
##
## [b]Responsibilities[/b][br]
## • Owns a list of [Class Action] resources for a specific [Class Unit].[br]
## • Duplicates actions on startup so edits are per-unit (no shared instances).[br]
## • Provides helpers to look up, validate, and invoke actions against a [code]target[/code].[br]
## • Relays start/end events to a global [code]SignalBus[/code] for UI/flow control.[br]
##
## [b]Notes[/b][br]
## • Logic unchanged; only documentation comments added.[br]
## • [method make_actions_unique] is deferred from [method Node._ready] to avoid doing work during scene load.

class_name ActionContainer
extends Node


## Owning [Class Unit] that these actions belong to.
@export var unit: Unit

## The per-unit set of actions. Populated in the editor; made unique at runtime in [method make_actions_unique].
@export var actions: Array[Action] = []

## Last action the unit used (non-enforced; maintained by external systems like the action UI).
var last_used_action: Action = null


## [b]Engine callback:[/b] defers making actions unique until the node is ready in the scene tree.
func _ready() -> void:
	make_actions_unique.call_deferred()
	#make_actions_unique()


## Ensure all actions are unique instances so changing one on this unit won't affect others.[br]
## Also calls each action’s setup with this container as context, then reverses the list (useful for UI ordering).
func make_actions_unique() -> void:
	var new_actions: Array[Action] = []

	for action in actions:
		new_actions.append(action.duplicate(true))

	actions = new_actions

	for action in actions:
		action.setup_action(self)

	actions.reverse()


## Attempts to use [param in_action] on [param target].[br]
## Returns the resolved action instance from this container (or [code]null[/code] if not found/invalid).
func use_action(in_action: Action, target: Variant) -> Action:
	if !in_action:
		return
	
	var test_action: Action = get_action_by_name(in_action.action_name)
	
	if test_action:
		var targ_pack: TargetPackage = Utilities.make_target_package(target)
		test_action.try_activate(targ_pack)
	
	return test_action
	
	
## Linear lookup for an action by its display/internal name.
## [b]Returns:[/b] the [Class Action] or [code]null[/code] if missing.
func get_action_by_name(in_name: String) -> Action:
	for action in actions:
		if action.action_name == in_name:
			return action
	return null


## Relay: emit a global “action started” event for listeners (UI, turn system, etc.).
func on_action_started(in_action: Action) -> void:
	SignalBus.on_action_started.emit(in_action)
	pass


## Relay: emit a global “action ended” event for listeners.
func on_action_ended(in_action: Action) -> void:
	SignalBus.on_action_ended.emit(in_action)
	pass


## Validates whether [param in_action] can be used at/on [param target].[br]
## Wraps [method Action.can_activate_on_target] with a built [Class TargetPackage].
## [b]Returns:[/b] [code]true[/code] if usable; otherwise [code]false[/code].
func can_use_action_at_target(in_action: Action, target: Variant) -> bool:
	var targ_pack: TargetPackage = Utilities.make_target_package(target)
	
	if !targ_pack:
		return false
	
	if !in_action.can_activate_on_target(targ_pack):
		return false
		
	
	return true
	

## Returns all actions owned by this container (already unique and set up).
func get_all_actions() -> Array[Action]:
	return actions
