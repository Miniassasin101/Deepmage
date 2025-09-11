class_name TextDistanceFromUnitAction
extends Action



@export_category("Action Variables")
@export var spawn_text: String = "Distance: "
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0


 
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var target_unit: Unit = targ_pack.unit
	
	var distance: float = unit.global_position.distance_to(target_unit.global_position)
	distance = snappedf(distance, 0.01)
	
	Utilities.spawn_text_line(unit, spawn_text + str(distance) + " to " + target_unit.ui_name, text_color, scale)
	end_action()


func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("unit"):
		return false
	
	var target_unit: Unit = target_pack.unit
	
	if !action_container:
		return false
	
	if target_unit == unit:
		return false
	
	return true
