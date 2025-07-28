class_name Action
extends Resource

@export var action_name: String = "none"

@export var tags: Array[String] = []

var action_container: ActionContainer = null


func try_activate(in_action_container: ActionContainer) -> void:
	if !action_container:
		action_container = in_action_container
	if can_activate():
		start_action()
		
	pass

func start_action() -> void:
	action_container.on_action_started(self)
	pass


func end_action() -> void:
	action_container.on_action_ended(self)



func can_activate() -> bool:
	return true
