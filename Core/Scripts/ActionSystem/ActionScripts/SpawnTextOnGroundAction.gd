class_name SpawnTextOnGroundAction
extends Action



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0
@export var spawn_text_at_pos: bool = false

 
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var unit: Unit = action_container.unit
	var pos: Vector3 = targ_pack.position
	if spawn_text_at_pos:
		Utilities.spawn_text_line(unit, spawn_text + " " + str(pos), text_color, scale, pos)
	else:
		Utilities.spawn_text_line(unit, spawn_text + " " + str(pos), text_color, scale)
	end_action()


func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("position"):
		return false
	
	#var pos: Vector3 = target_pack.position
	
	
	return true
