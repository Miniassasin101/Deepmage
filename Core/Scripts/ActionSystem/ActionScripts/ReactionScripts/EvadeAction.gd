class_name EvadeAction
extends Reaction



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE

@export var dodge_package: AnimationPackage
@export var reaction_latency: float = 0.06  # seconds; tune per game

@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice

@export var defend_attribute: String = "agility"


func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	#Utilities.spawn_text_line(unit, spawn_text, text_color)
	
	var attacking_unit: Unit = CombatSystem.instance.current_combat_event_data.attacker
	
	if attacking_unit:
		await rotate_towards_target(attacking_unit)
	
	end_action()




func end_action() -> void:
	super.end_action()


func get_reaction_package() -> AnimationPackage:
	return dodge_package

func get_reaction_latency() -> float:
	return reaction_latency


func resolve_reaction() -> void:
	var cbevent: CombatEventData = CombatSystem.instance.current_combat_event_data
	
	if !cbevent:
		return
	
	if !cbevent.is_success:
		cbevent.is_hit = false
		print_debug("Evasion SUCCESS")
		CombatLog.instance.add_log(unit.ui_name + " Evaded Successfully")
	else:
		CombatLog.instance.add_log(unit.ui_name + " Failed Evasion")
	





func can_activate() -> bool:
	return true




func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()

	unit.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await unit.movement_controller.rotation_precomplete
