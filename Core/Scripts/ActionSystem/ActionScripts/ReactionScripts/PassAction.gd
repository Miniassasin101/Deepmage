class_name PassAction
extends Reaction



@export_category("Action Variables")
@export var spawn_text: String = "Pass"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0

@export var defend_attribute: String = ""



func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var unit: Unit = action_container.unit
	Utilities.spawn_text_line(unit, spawn_text, text_color, scale)
	end_action()




func end_action() -> void:
	super.end_action()

func get_stat_name() -> String:
	return defend_attribute

func can_activate() -> bool:
	return true
