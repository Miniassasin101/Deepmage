class_name MovementController
extends Node


signal movement_complete

signal rotation_complete

@export_category("References")
@export var unit: Unit

@export_category("Movement Variables")
@export var move_speed:                  float = 5.0
@export var rotate_speed:                float = 8.0
@export var acceleration_time:           float = 0.3
@export var rotation_acceleration_time:  float = 0.3
@export var stopping_distance:           float = 0.1

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
var facing_direction: Vector3
var turn_towards_speed: float = 4.0



func _physics_process(delta: float) -> void:
	if is_moving:
		move_along_curve_process(delta)
	if is_rotating:
		rotate_unit_towards_target_position_process(delta)

#region Movement Logic
 #Animate Movement Along Curve
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
	#animator_tree.set("parameters/Main/AnimationNodeStateMachine/conditions/IsWalking", true)


# Move Along Curve Process
# Handles the movement along the given curve in each frame
func move_along_curve_process(delta: float) -> void:
	if curve_travel_offset >= curve_length:
		on_stop_moving()
		return

	# Accelerate movement speed smoothly
	if acceleration_timer > 0.0:
		acceleration_timer -= delta
		var acceleration_progress: float = 1.0 - (acceleration_timer / 0.5)  # Interpolation factor from 0 to 1
		current_speed = lerp(0.0, move_speed, acceleration_progress)
	else:
		current_speed = move_speed

	# Get the current position on the curve
	var current_position = unit.global_transform.origin
	var next_position: Vector3 = movement_curve.sample_baked(curve_travel_offset)
	var move_direction: Vector3 = (next_position - current_position).normalized()

	# Move towards the next position with the current speed
	var distance_to_next_point = current_position.distance_to(next_position)
	if distance_to_next_point > stopping_distance:
		current_position += move_direction * current_speed * delta
		unit.global_transform.origin = current_position

		# Smoothly accelerate the rotation towards the movement direction
		if rotation_acceleration_timer > 0.0:
			rotation_acceleration_timer -= delta
			var rotation_progress: float = 1.0 - (rotation_acceleration_timer / 0.5)  # Interpolation factor from 0 to 1
			rotate_speed = lerp(move_rotate_speed - 3.0, move_rotate_speed, rotation_progress)
		else:
			rotate_speed = move_rotate_speed  # Default rotation speed

		# Smoothly rotate the unit towards the movement direction
		var tar_rot = Basis.looking_at(move_direction, Vector3.UP, true)
		unit.global_transform.basis = unit.global_transform.basis.slerp(tar_rot, delta * rotate_speed)
		unit.global_transform.basis = unit.global_transform.basis.orthonormalized()

	# Increment the travel offset along the curve
	curve_travel_offset += min(current_speed * delta, curve_length - curve_travel_offset)



func on_stop_moving() -> void:
	# called by move_along_curve_process once we've reached the end
	is_moving = false
	
	await get_tree().physics_frame
	movement_complete.emit()
#endregion

# Rotation Functions
# Handles the start and process of rotating towards a target position
func rotate_unit_towards_target_position(target_position: Vector3, rot_spd: float = 4.0) -> void:
	is_rotating = true
	facing_direction = (target_position - unit.get_global_position()).normalized()
	turn_towards_speed = rot_spd
	await rotation_complete
	return

func rotate_unit_towards_target_position_process(delta: float):
	var tar_rot = Basis.looking_at(facing_direction, Vector3.UP, true)
	var unit_slerp_basis: Basis = unit.global_transform.basis.slerp(tar_rot, delta * rotate_speed)
	unit.global_transform.basis = unit_slerp_basis.orthonormalized()

	# Check if the rotation is close enough to stop rotating
	var current_direction = unit.global_transform.basis.z.normalized()
	if current_direction.dot(facing_direction) > 0.9999:
		is_rotating = false  # Stop rotating if we're almost facing the target
		rotation_complete.emit()
