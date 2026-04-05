class_name BlockAction
extends Reaction


@export_category("Action Variables")
@export var spawn_text: String = "Testing"
@export var text_color: Color = Color.ALICE_BLUE
@export var scale: float = 1.0
@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice
@export var rotation_speed: float = 4.0

@export_category("Animation Package")
@export var block_package: AnimationPackage
@export var reaction_latency: float = 0.06  # seconds; tune per game

func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	#Utilities.spawn_text_line(unit, spawn_text, text_color, scale)

	var attacking_unit: Unit = CombatSystem.instance.current_combat_event_data.attacker

	if attacking_unit:
		await rotate_towards_target(attacking_unit)

	end_action()


func end_action() -> void:
	super.end_action()


func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()

	unit.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		rotation_speed,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await unit.movement_controller.rotation_precomplete


func get_reaction_package() -> AnimationPackage:
	return block_package

func get_reaction_latency() -> float:
	return reaction_latency


func can_activate() -> bool:
	return true
