class_name BashAction
extends Action

@export_category("Action Variables")
@export var attack_success_animation: AnimationPackage
@export var attack_range: float = 2.0
## Optional: how close (in radians) we want to be before starting the attack.
## If < 0, MovementController default is used.
@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice

@export var min_turn_delta_rad: float = 4.5 # only rotate if > ~6°

@export var accuracy_attribute: String = "agility"

@export var attack_attribute: String = "might"

@export var base_damage: int = 3

func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	print_debug("Bash Started")
	var target_unit: Unit = targ_pack.unit
	
	
	await rotate_towards_target(target_unit)
	
	
	print_debug("Rotate Completed")
	await declare_attack(target_unit)
	

	var effective_damage: int = maxi(base_damage - CombatSystem.instance.current_combat_event_data.armor_test_hits, 0)
	

	# Start attack slightly before perfect alignment.
	#owner.animation_controller.play_animation_by_name(attack_success_animation.get_anim_name())
	owner.animation_controller.play_package(attack_success_animation)



	# Temp timer—replace with your real combo/timing window logic
	await owner.get_tree().create_timer(0.6).timeout
	
	if !CombatSystem.instance.current_combat_event_data.is_hit:
		Utilities.spawn_text_line(target_unit, "MISS", Color.AQUA)
		end_action()
		return
	
	var curr_val: int = owner.get_attributes_container().get_attribute_current_value("health")
	owner.get_attributes_container().add_attribute_modifier("health", -effective_damage)#set_attribute_current_value("structure", curr_val - effective_damage)
	
	var color: Color = Color.FIREBRICK
	if effective_damage == 0:
		color = Color.ALICE_BLUE
	
	Utilities.spawn_damage_label(target_unit, effective_damage, color, 0.55)


	end_action()


func declare_attack(target_unit: Unit) -> void:
	await CombatSystem.instance.declare_attack(self, owner, target_unit)


func rotate_towards_target(target: Unit) -> void:

	var target_pos := target.get_global_position()

	owner.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await owner.movement_controller.rotation_precomplete


func end_action() -> void:
	super.end_action()


func get_stat_name() -> String:
	return attack_attribute


func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("unit"):
		return false
	var unit: Unit = target_pack.unit
	if !action_container:
		return false
	if unit == action_container.unit:
		return false
	if get_distance_to_owner(unit) > attack_range:
		return false
	return true


func get_distance_to_owner(unit: Unit) -> float:
	return unit.get_global_position().distance_to(owner.get_global_position())
