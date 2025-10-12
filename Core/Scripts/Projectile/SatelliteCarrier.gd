class_name SatelliteCarrier
extends Node3D

# =========================
# Exports (Inspector sliders)
# =========================
@export_category("Anchor / Follow")
@export var anchor: Node3D
@export var decouple_from_parent: bool = true
enum FollowMode { INHERIT, SMOOTH_LERP, SPRING }
@export var follow_mode: FollowMode = FollowMode.SMOOTH_LERP

# Position follow (SMOOTH_LERP): bigger = more lag (slower to catch up)
@export_range(0.0, 2.0, 0.01, "or_greater") var follow_lag_seconds: float = 0.25
# Optional speed cap (0 = unlimited)
@export_range(0.0, 200.0, 0.1, "or_greater") var follow_max_speed: float = 0.0

# Rotation follow
@export var follow_rotation: bool = true
@export_range(0.0, 2.0, 0.01, "or_greater") var rotation_lag_seconds: float = 0.25

# Offset from anchor (formation slot)
@export var position_offset: Vector3 = Vector3.ZERO

@export_category("Bob")
@export var bob_enabled: bool = true
@export_range(0.0, 5.0, 0.01) var bob_amplitude: float = 0.2
@export_range(0.0, 8.0, 0.01) var bob_frequency_hz: float = 1.0
@export var bob_axis: Vector3 = Vector3.UP
@export var randomize_bob_phase: bool = true

@export_category("Orbit (Optional)")
@export var orbit_enabled: bool = false
@export_range(0.0, 10.0, 0.01) var orbit_radius: float = 0.0
@export_range(-720.0, 720.0, 1.0) var orbit_degrees_per_sec: float = 0.0
@export var orbit_plane_normal: Vector3 = Vector3.UP

@export_category("Debug")
@export var draw_debug_gizmos: bool = false

var sat_controller: SatelliteController = null

# =========================
# Runtime
# =========================
var satellite: Node3D = null
@warning_ignore("unused_private_class_variable")
var _velocity: Vector3 = Vector3.ZERO     # for spring mode, if you add it later
var _time_accum: float = 0.0
var _bob_phase: float = 0.0


func _ready() -> void:
	if decouple_from_parent:
		set_as_top_level(true) # Keep global transform independent of parent so lag is visible
	set_process(true)
	if randomize_bob_phase:
		_bob_phase = randf() * TAU

func _physics_process(delta: float) -> void:
	if anchor == null:
		return

	_time_accum += delta

	# 1) Compute the desired anchor transform (+ orbit + offset)
	var anchor_pos: Vector3 = anchor.global_transform.origin
	var anchor_basis: Basis = anchor.global_transform.basis

	if orbit_enabled:
		var angle_rad: float = deg_to_rad(orbit_degrees_per_sec) * _time_accum
		var plane_up: Vector3 = orbit_plane_normal.normalized()
		var right: Vector3 = plane_up.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.0001:
			right = plane_up.cross(Vector3.RIGHT).normalized()
		var forward: Vector3 = right.cross(plane_up).normalized()
		var orbit_offset: Vector3 = (right * cos(angle_rad) + forward * sin(angle_rad)) * orbit_radius
		anchor_pos += orbit_offset

	var desired_pos: Vector3 = anchor_pos + position_offset
	var desired_rot_quat: Quaternion = anchor_basis.get_rotation_quaternion()

	# 2) Follow (position)
	if follow_mode == FollowMode.INHERIT:
		global_position = desired_pos
	else:
		var alpha_pos: float = 1.0
		if follow_mode == FollowMode.SMOOTH_LERP:
			if follow_lag_seconds <= 0.0:
				alpha_pos = 1.0
			else:
				alpha_pos = 1.0 - exp(-delta / follow_lag_seconds)

		var new_pos: Vector3 = global_position.lerp(desired_pos, clamp(alpha_pos, 0.0, 1.0))

		# Optional max speed cap
		if follow_max_speed > 0.0:
			var max_dist: float = follow_max_speed * delta
			var delta_vec: Vector3 = new_pos - global_position
			var dist_len: float = delta_vec.length()
			if dist_len > max_dist:
				new_pos = global_position + delta_vec.normalized() * max_dist

		global_position = new_pos

	# 3) Follow (rotation)
	if follow_rotation:
		if rotation_lag_seconds <= 0.0:
			global_transform.basis = Basis(desired_rot_quat)
		else:
			var current_quat: Quaternion = global_transform.basis.get_rotation_quaternion()
			var alpha_rot: float = 1.0 - exp(-delta / rotation_lag_seconds)
			var slerped: Quaternion = current_quat.slerp(desired_rot_quat, clamp(alpha_rot, 0.0, 1.0))
			global_transform.basis = Basis(slerped)

	# 4) Bob offset (applied after follow)
	if bob_enabled and bob_amplitude > 0.0 and bob_frequency_hz > 0.0:
		var bob_dir: Vector3 = bob_axis.normalized()
		var bob_value: float = sin(_bob_phase + _time_accum * TAU * bob_frequency_hz)
		var bob_vec: Vector3 = bob_dir * bob_amplitude * bob_value
		global_position += bob_vec

func add_satellite(in_satellite: Node3D) -> void:
	if in_satellite == null:
		return

	satellite = in_satellite
	if in_satellite.get_parent():
		in_satellite.reparent(self, false)
	else:
		add_child(in_satellite)
	in_satellite.global_position = global_position

# ============== Utilities / API ==============

func set_anchor(anchor_node: Node3D) -> void:
	anchor = anchor_node

func get_anchor() -> Node3D:
	return anchor

func set_follow_mode_inherit() -> void:
	follow_mode = FollowMode.INHERIT

func set_follow_mode_smooth_lerp() -> void:
	follow_mode = FollowMode.SMOOTH_LERP

func set_follow_active(active: bool) -> void:
	set_physics_process(active) # follow + bob live in _physics_process()
	set_process(active)         # harmless here; keeps it symmetric

func set_follow_lag_seconds(seconds_amount: float) -> void:
	if seconds_amount < 0.0:
		follow_lag_seconds = 0.0
	else:
		follow_lag_seconds = seconds_amount

func set_bob_enabled(is_enabled: bool) -> void:
	bob_enabled = is_enabled

func set_bob(amplitude: float, frequency_hz: float) -> void:
	bob_amplitude = max(0.0, amplitude)
	bob_frequency_hz = max(0.0, frequency_hz)

func snap_to_anchor() -> void:
	if anchor == null:
		return
	global_transform = anchor.global_transform
	global_position += position_offset

func destroy_satellite() -> void:
	if satellite:
		satellite.queue_free()
	
	if sat_controller.satellite_carriers.has(self):
		sat_controller.satellite_carriers.erase(self)
	
	queue_free()

func retrieve_satellite() -> Node3D:
	return satellite
