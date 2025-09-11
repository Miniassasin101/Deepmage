class_name BlockAction
extends Reaction



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0

@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice
@export var defend_attribute: String = "might"

@export var base_defend_value: int = 3



func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	#Utilities.spawn_text_line(unit, spawn_text, text_color, scale)
	
	var attacking_unit: Unit = CombatSystem.instance.current_combat_event_data.attacker
	
	if attacking_unit:
	
		await rotate_towards_target(attacking_unit)
	
	
	end_action()


func resolve_reaction() -> void:
	var cbd: CombatEventData = CombatSystem.instance.current_combat_event_data
	if cbd.is_success:
		print_debug("Block Failed")
		CombatLog.instance.add_log(unit.ui_name + " Block Failed")
		return
	
	var block_value: int = 0

	
	block_value += base_defend_value
	
	block_value += maxi(cbd.defender_hits - cbd.defender_hits, 0)
	
	cbd.defense_bonus = block_value
	
	CombatLog.instance.add_log(unit.ui_name + " Blocked " + str(block_value))
	
	
	
	print_debug("Blocked " + str(block_value))
#	Utilities.spawn_text_line(unit, "Blocked " + str(block_value), text_color, scale)
	


func end_action() -> void:
	super.end_action()


func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()

	unit.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await unit.movement_controller.rotation_precomplete

func on_impact() -> void:
	Utilities.spawn_text_line(unit, "Blocked", text_color, scale)


func can_activate() -> bool:
	return true
