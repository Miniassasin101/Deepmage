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
	var unit: Unit = action_container.unit
	#Utilities.spawn_text_line(unit, spawn_text, text_color, scale)
	
	var attacking_unit: Unit = CombatSystem.instance.current_combat_event_data.attacker
	
	if attacking_unit:
	
		await rotate_towards_target(attacking_unit)
	
	
	end_action()


func resolve_reaction() -> void:
	if CombatSystem.instance.current_combat_event_data.is_success:
		return
	
	var guard_pool: DicePool = DicePool.new(base_defend_value)
	
	CombatSystem.instance.current_combat_event_data.armor_test_hits += guard_pool.success_count
	
	print_debug("Blocked " + str(guard_pool.success_count))
	
	


func end_action() -> void:
	super.end_action()


func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()

	owner.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await owner.movement_controller.rotation_precomplete

func get_stat_name() -> String:
	return defend_attribute


func can_activate() -> bool:
	return true
