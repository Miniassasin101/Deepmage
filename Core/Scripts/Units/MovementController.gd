class_name MovementController
extends Node

signal movement_complete
## Emitted once per rotate request when current facing gets within `pre_rotation_complete_margin` radians of the target.
signal rotation_precomplete
## Emitted once per rotate request when current facing is (nearly) perfectly aligned to the target.
signal rotation_complete

@export_category("References")
@export var unit: Unit

@export_category("Movement Variables")
@export var move_speed:                  float = 5.0
@export var rotate_speed:                float = 8.0           # base rotation slerp speed (radians/sec-ish factor)
@export var acceleration_time:           float = 0.3
@export var rotation_acceleration_time:  float = 0.3
@export var stopping_distance:           float = 0.1


@export_category("Rotation Thresholds")
## Default early margin (in radians). e.g. 0.17 ≈ 10 degrees.
@export var pre_rotation_complete_margin: float = 0.17
## Full completion epsilon (in radians). e.g. 0.01 ≈ ~0.57 degrees.
@export var rotation_complete_epsilon:    float = 0.01

# Internal state:
var movement_curve:      Curve3D
var curve_length:        float
var current_speed:       float
var move_rotate_speed:   float
var acceleration_timer:  float
var rotation_acceleration_timer: float
var curve_travel_offset: float
var is_moving: bool = false

var is_rotating: bool = false
var facing_direction: Vector3 = Vector3.FORWARD
var turn_towards_speed: float = 4.0

# Rotation request scoped state:
var _rotation_target_dir: Vector3 = Vector3.FORWARD
var _pre_margin_this_turn: float = -1.0
var _pre_emitted: bool = false

func _physics_process(delta: float) -> void:
	if is_moving:
		move_along_curve_process(delta)
	if is_rotating:
		rotate_unit_towards_target_position_process(delta)

#region Movement Logic
# Handles setting up movement parameters and starting movement
func animate_movement_along_curve(move_speed_in: float, movement_curve_in: Curve3D, 
		curve_length_in: float, acceleration_timer_in: float, rotation_acceleration_timer_in: float,  
		stopping_distance_in: float, rotate_speed_in: float) -> void:

	move_speed = move_speed_in
	movement_curve = movement_curve_in
	curve_length = curve_length_in
	acceleration_timer = acceleration_timer_in
	rotation_acceleration_timer = rotation_acceleration_timer_in
	stopping_distance = stopping_distance_in
	move_rotate_speed = rotate_speed_in
	current_speed = 0.1  # Initial movement speed
	curve_travel_offset = 0.0
	is_moving = true

func move_along_curve_process(delta: float) -> void:
	if curve_travel_offset >= curve_length:
		on_stop_moving()
		return

	# Accelerate movement speed smoothly
	if acceleration_timer > 0.0:
		acceleration_timer -= delta
		var acceleration_progress: float = 1.0 - (acceleration_timer / 0.5)
		current_speed = lerp(0.0, move_speed, acceleration_progress)
	else:
		current_speed = move_speed

	# Get current & next positions on the curve
	var current_position = unit.global_transform.origin
	var next_position: Vector3 = movement_curve.sample_baked(curve_travel_offset)
	var move_direction: Vector3 = (next_position - current_position).normalized()

	# Move towards next point
	var distance_to_next_point = current_position.distance_to(next_position)
	if distance_to_next_point > stopping_distance:
		current_position += move_direction * current_speed * delta
		unit.global_transform.origin = current_position

		# Smoothly accelerate rotation towards movement direction
		if rotation_acceleration_timer > 0.0:
			rotation_acceleration_timer -= delta
			var rotation_progress: float = 1.0 - (rotation_acceleration_timer / 0.5)
			rotate_speed = lerp(move_rotate_speed - 3.0, move_rotate_speed, rotation_progress)
		else:
			rotate_speed = move_rotate_speed

		# Smoothly rotate body towards movement \\
		var tar_rot = Basis.looking_at(move_direction, Vector3.UP, true)
		unit.global_transform.basis = unit.global_transform.basis.slerp(tar_rot, delta * rotate_speed).orthonormalized()

	# Increment travel offset
	curve_travel_offset += min(current_speed * delta, curve_length - curve_travel_offset)

func on_stop_moving() -> void:
	is_moving = false
	await get_tree().physics_frame
	movement_complete.emit()
#endregion

#region Rotation API (with pre-complete margin)
## Rotate the unit to face `target_position`. You can override the default speed and pre-complete margin here.
## - `rot_spd`: slerp multiplier (higher = faster).
## - `pre_margin_override`: radians remaining at which we'll emit `rotation_precomplete`. Pass < 0 to use the exported default.
func rotate_unit_towards_target_position(target_position: Vector3, rot_spd: float = 4.0, pre_margin_override: float = -1.0) -> void:
	var unit_name: String = unit.ui_name
	var is_downed: bool = unit.status_controller.get_status_by_name("downed") != null
	if is_downed:
		pass
	var dir := (target_position - unit.get_global_position())
	if dir.length_squared() < 0.0001:
		# Degenerate case: target is at our position. We consider it instantly complete.
		is_rotating = false
		_pre_emitted = true
		rotation_precomplete.emit()
		rotation_complete.emit()
		return

	# Normalize and store rotation request scoped params
	_rotation_target_dir = dir.normalized()
	_pre_margin_this_turn = pre_margin_override if pre_margin_override >= 0.0 else pre_rotation_complete_margin
	_pre_emitted = false

	is_rotating = true
	turn_towards_speed = rot_spd
	# Use per-call speed by writing into rotate_speed (the process uses this)
	rotate_speed = rot_spd

	# Kick an initial frame to ensure process runs this tick
	#rotate_unit_towards_target_position_process(
	#(1.0 / float(Engine.get_physics_ticks_per_second())) 
	#if Engine.get_physics_ticks_per_second() > 0 
	#else 0.016
#)

## Internal per-frame rotation logic.
func rotate_unit_towards_target_position_process(delta: float) -> void:
	# Slerp current basis towards target basis
	var tar_rot := Basis.looking_at(_rotation_target_dir, Vector3.UP, true)
	unit.global_transform.basis = unit.global_transform.basis.slerp(tar_rot, delta * rotate_speed).orthonormalized()

	# Measure remaining angle between current forward and target dir.
	# We use +Z as "forward" because Basis.looking_at aligns +Z to the look vector.
	var current_forward := unit.global_transform.basis.z.normalized()
	var dot_val: float = clampf(current_forward.dot(_rotation_target_dir), -1.0, 1.0)
	var remaining_angle := acos(dot_val)  # radians in [0..PI]

	# Fire early (once) when within pre-margin.
	if not _pre_emitted and remaining_angle <= max(_pre_margin_this_turn, rotation_complete_epsilon):
		_pre_emitted = true
		rotation_precomplete.emit()

	# Finish when we're within epsilon.
	if remaining_angle <= rotation_complete_epsilon:
		is_rotating = false
		rotation_complete.emit()
#endregion
