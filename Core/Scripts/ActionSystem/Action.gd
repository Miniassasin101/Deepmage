class_name Action
extends Resource

signal on_action_ended

@export var action_name: String = "none"
@export var selection_types: Array[NamedBool]
@export var reaction_check_timing: float = 0.3
@export var tags: Array[String] = []

var action_container: ActionContainer = null

var unit: Unit = null

var context: Dictionary = {}


func try_activate(targ_pack: TargetPackage = null) -> void:

	if can_activate_on_target(targ_pack):
		start_action(targ_pack)

	pass

func setup_action(in_action_container: ActionContainer) -> void:
	if !action_container:
		action_container = in_action_container

	if !unit and action_container:
		unit = action_container.unit
		if self is CombatAction:
			pass


@warning_ignore("unused_parameter")
func start_action(targ_pack: TargetPackage = null) -> void:
	action_container.on_action_started(self)
	pass


func end_action() -> void:
	on_action_ended.emit()
	action_container.on_action_ended(self)


func set_context(in_ctx: Dictionary) -> void:
	context = in_ctx


@warning_ignore("unused_parameter")
func can_activate_on_target(target_pack: TargetPackage) -> bool:
	return true

func can_activate() -> bool:
	return true

func has_valid_targets() -> bool:
	return false

func is_action_type(in_type: String) -> bool:
	if tags.has(in_type):
		return true

	return false



func has_selection_type(in_type: String) -> bool:
	for type in selection_types:
		if type.name == in_type:
			return true

	return false
