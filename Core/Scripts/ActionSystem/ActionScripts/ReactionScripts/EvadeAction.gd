class_name EvadeAction
extends Action



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0



func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var unit: Unit = action_container.unit
	Utilities.spawn_text_line(unit, spawn_text, text_color, scale)
	end_action()




func end_action() -> void:
	super.end_action()



func can_activate() -> bool:
	return true
