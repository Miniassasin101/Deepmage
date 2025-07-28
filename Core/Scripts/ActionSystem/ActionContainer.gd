class_name ActionContainer
extends Node


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
