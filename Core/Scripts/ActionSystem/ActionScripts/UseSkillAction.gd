class_name UseSkillAction
extends Action



@export_category("Action Variables")
@export var skill: Skill = null


 
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	
	skill.activate_skill()
	#await unit.get_tree().create_timer(0.5)
	await Utilities.get_tree().create_timer(3.0).timeout
	
	end_action()


func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:
	
	if !target_pack:
		return false
	
	if unit != target_pack.get_unit():
		return false
	
	
	if !skill:
		return false
	
	skill.unit = unit
	
	if !skill.can_activate_skill():
		return false
	
	
	
	return true
