class_name ActionContainer
extends Node

@export var unit: Unit

@export var actions: Array[Action] = []


func _ready() -> void:
	make_actions_unique()

## Called once at start to make sure actions are all unique so changing one on this unit wont affect another.
func make_actions_unique() -> void:
	var new_actions: Array[Action] = []
	for action in actions:
		new_actions.append(action.duplicate(true))
	actions = new_actions
	actions.reverse()


func use_action(in_action: Action) -> void:
	if actions.has(in_action):
		in_action.try_activate(self)


func on_action_started(in_action: Action) -> void:
	SignalBus.on_action_started.emit(in_action)
	pass

func on_action_ended(in_action: Action) -> void:
	SignalBus.on_action_ended.emit(in_action)
	pass
