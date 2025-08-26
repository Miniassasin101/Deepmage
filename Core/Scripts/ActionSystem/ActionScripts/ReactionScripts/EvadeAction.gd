class_name EvadeAction
extends Reaction



@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE


@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice

@export var defend_attribute: String = "agility"


func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var unit: Unit = action_container.unit
	Utilities.spawn_text_line(unit, spawn_text, text_color)
	
	var attacking_unit: Unit = CombatSystem.instance.current_combat_event_data.attacker
	
	if attacking_unit:
		await rotate_towards_target(attacking_unit)
	
	end_action()




func end_action() -> void:
	super.end_action()


func resolve_reaction() -> void:
	var cbevent: CombatEventData = CombatSystem.instance.current_combat_event_data
	
	if !cbevent:
		return
	
	if !cbevent.is_success:
		cbevent.is_hit = false




func get_stat_name() -> String:
	return defend_attribute


func can_activate() -> bool:
	return true


func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()

	owner.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await owner.movement_controller.rotation_precomplete
