class_name SpawnTextOnUnitAction
extends Action



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0


 
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var targ_unit: Unit = targ_pack.unit
	Utilities.spawn_text_line(targ_unit, spawn_text + " " + targ_unit.ui_name, text_color, scale)
	end_action()


func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("unit"):
		return false
	
	#var unit: Unit = target_pack.unit
	
	
	return true
