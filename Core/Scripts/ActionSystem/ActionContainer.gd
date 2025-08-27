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

	for action in actions:
		action.setup_action(self)

	actions.reverse()


func use_action(in_action: Action, target: Variant) -> void:
	if actions.has(in_action):
		var targ_pack: TargetPackage = Utilities.make_target_package(target)
		in_action.try_activate(targ_pack)


func on_action_started(in_action: Action) -> void:
	SignalBus.on_action_started.emit(in_action)
	pass

func on_action_ended(in_action: Action) -> void:
	SignalBus.on_action_ended.emit(in_action)
	pass


func can_use_action_at_target(in_action: Action, target: Variant) -> bool:
	var targ_pack: TargetPackage = Utilities.make_target_package(target)
	
	if !targ_pack:
		return false
	
	if !in_action.can_activate_on_target(targ_pack):
		return false
		
	
	return true
	


func get_all_actions() -> Array[Action]:
	return actions
