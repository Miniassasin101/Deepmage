class_name BashAction
extends Action

@export_category("Action Variables")
@export var attack_success_animation: AnimationPackage
@export var attack_range: float = 2.0
## Optional: how close (in radians) we want to be before starting the attack.
## If < 0, MovementController default is used.
@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice

@export var min_turn_delta_rad: float = 4.5 # only rotate if > ~6°

func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	print_debug("Bash Started")
	var target_unit: Unit = targ_pack.unit
	
	
	await rotate_towards_target(target_unit)
	
	print_debug("Rotate Completed")

	# Start attack slightly before perfect alignment.
	owner.animation_controller.play_animation_by_name(attack_success_animation.get_anim_name())

	# You can optionally still wait for full completion in parallel if needed:
	# await owner.movement_controller.rotation_complete

	# Temp timer—replace with your real combo/timing window logic
	await owner.get_tree().create_timer(1.5).timeout
	print_debug("Animation Played")

	end_action()

func end_action() -> void:
	super.end_action()

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


func rotate_towards_target_dep(target: Unit) -> void:
	# Begin turning. We do NOT await here; we await the early signal below.
	owner.movement_controller.rotate_unit_towards_target_position(
		target.get_global_position(),
		4.0, # rotation speed
		pre_rotation_margin_override
	)

	# Wait until we're "nearly there" for snappy feel.
	await owner.movement_controller.rotation_precomplete

func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()
	var yaw_delta := absf(_xz_yaw_angle_to(target_pos))

	# Deadzone: skip rotation if already facing close enough
	if yaw_delta <= min_turn_delta_rad:
		#return  # caller's `await rotate_towards_target(...)` completes immediately
		pass

	owner.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # your early-start margin
	)
	await owner.movement_controller.rotation_precomplete


func _xz_yaw_angle_to(target_pos: Vector3) -> float:
	# Direction to target on XZ
	var to_target := target_pos - owner.global_transform.origin
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return 0.0
	to_target = to_target.normalized()

	# Current forward on XZ (Godot faces -Z)
	var fwd := -owner.global_transform.basis.z
	fwd.y = 0.0
	if fwd.is_zero_approx():
		return 0.0
	fwd = fwd.normalized()

	# Signed angle around Y (radians). Use abs() if you only need magnitude.
	return fwd.signed_angle_to(to_target, Vector3.UP)
