class_name ProjectileCarrier
extends PathFollow3D
##
## ProjectileCarrier
## - Child of Path3D (uses its Curve3D).
## - Moves an attached projectile along the curve at constant speed.
## - Adds a vertical arc offset (parabolic or flat).
## - Can face velocity (yaw-only or full 3D).
## - Precomputes total time before activation and exposes it.
##

signal started(projectile: Node3D, duration: float)
signal tick(projectile: Node3D, t_norm: float, distance_along_arc: float)
signal arrived(projectile: Node3D)
signal paused_changed(is_paused: bool)
signal detached(projectile: Node3D)
signal error(message: String)

# -------------------------
# Tunables / Exports
# -------------------------

@export_category("Motion")
@export var speed_units_per_sec: float = 20.0          # world units per second *along the arc path*
@export var start_distance: float = 0.0                 # path offset to begin (in curve units)
@export var end_distance: float = -1.0                  # -1 = curve length
@export var loop_path: bool = false                     # do not loop by default
@export var use_physics_process: bool = true            # physics by default for determinism

@export_category("Arc")
@export var arc_height: float = 0.0                     # 0 = flat; >0 = upward arc; <0 = dip
@export var arc_axis_world: Vector3 = Vector3.UP        # world axis for arc offset (normalized internally)

@export_category("Facing")
@export var face_velocity: bool = true                  # rotate projectile to face travel direction
@export var yaw_only: bool = true                       # face only around Y (ignore pitch/roll)

@export_category("Profile")
@export var speed_profile: Curve                        # optional multiplier vs normalized distance [0..1]; null = constant
@export var sample_step_min: float = 0.05               # min sample step in curve units when baking arc mapping
@export var sample_step_factor: float = 0.5             # step = min(curve.bake_interval * factor, bake_interval)

@export_category("Quality")
@export var use_cubic_interp: bool = true               # for Curve3D.sample_baked
@export var lookahead_distance: float = 0.1             # used for facing; in curve units

@export_category("Lifecycle")
@export var auto_detach_on_arrival: bool = false        # return projectile to original parent when done
@export var freeze_on_arrival: bool = true              # stop processing on arrival

# -------------------------
# Runtime state
# -------------------------

var projectile: Node3D = null
var _original_parent: Node = null
var _original_index: int = -1
var _original_global_xform: Transform3D

var _flight_path: Path3D = null
var _curve: Curve3D = null

var _planned: bool = false
var _active: bool = false
var _paused: bool = false

var _resolved_end_distance: float = 0.0
var _arc_offsets: PackedFloat32Array = PackedFloat32Array()   # base-curve distances (monotonic)
var _arc_cumulative: PackedFloat32Array = PackedFloat32Array()# cumulative arced distance along samples (monotonic)
var _total_arc_distance: float = 0.0
var _duration_sec: float = 0.0

var _elapsed_sec: float = 0.0
var _arc_axis_world_n: Vector3 = Vector3.UP

# -------------------------
# Built-in
# -------------------------

func _ready() -> void:
	# PathFollow3D defaults and safety
	loop = loop_path
	set_cubic_interpolation(use_cubic_interp)
	rotation_mode = PathFollow3D.ROTATION_XYZ   # we manually handle facing to keep arc_axis in world space
	tilt_enabled = false
	use_model_front = false

	_arc_axis_world_n = arc_axis_world.normalized()

	_flight_path = get_parent() if get_parent() is Path3D else null
	if _flight_path == null:
		emit_signal("error", "ProjectileCarrier must be a child of a Path3D.")
		return

	_curve = _flight_path.curve
	if _curve == null:
		emit_signal("error", "Parent Path3D has no Curve3D.")
		return

	_flight_path.curve_changed.connect(_on_curve_changed)

	# Use physics or idle processing
	#set_physics_process(use_physics_process)
	#set_process(!use_physics_process)


func _physics_process(delta: float) -> void:
	if use_physics_process:
		_tick(delta)


func _process(delta: float) -> void:
	if !use_physics_process:
		_tick(delta)

# -------------------------
# Public API
# -------------------------

## Attach (reparent) a projectile under this carrier.
## keep_global=true preserves world transform.
func attach_projectile(p: Node3D, keep_global: bool = true) -> void:
	if p == null:
		emit_signal("error", "attach_projectile(): projectile is null.")
		return

	# If already attached, detach first
	if projectile != null and projectile != p:
		detach_projectile(true, true)

	projectile = p
	if projectile.get_parent() != null:
		_original_parent = projectile.get_parent()
		_original_index = projectile.get_index()
	else:
		_original_parent = null
		_original_index = -1

	_original_global_xform = projectile.global_transform

	var prior = projectile.global_transform
	if !projectile.get_parent():
		add_child(projectile)
	else:
		projectile.reparent(self)
		
	if keep_global:
		projectile.global_transform = prior

	# Reset relative offset so we can drive global pos every frame
	projectile.position = Vector3.ZERO


## Return projectile to its original parent (if any).
func detach_projectile(return_to_original: bool = true, keep_global: bool = true) -> void:
	if projectile == null:
		return

	var prior = projectile.global_transform
	remove_child(projectile)

	if return_to_original and _original_parent != null:
		if _original_index >= 0 and _original_index <= _original_parent.get_child_count():
			_original_parent.add_child(projectile)
			_original_parent.move_child(projectile, _original_index)
		else:
			_original_parent.add_child(projectile)
	else:
		get_tree().root.add_child(projectile)

	if keep_global:
		projectile.global_transform = prior

	emit_signal("detached", projectile)
	projectile = null
	_original_parent = null
	_original_index = -1


## Build internal samples and compute total duration with current settings.
## You may call this anytime; returns computed duration in seconds.
func plan_travel() -> float:
	if _curve == null:
		emit_signal("error", "plan_travel(): Missing Curve3D.")
		return 0.0

	var curve_len := _curve.get_baked_length()
	if curve_len <= 0.0:
		emit_signal("error", "plan_travel(): Curve has zero length.")
		return 0.0

	_resolved_end_distance = end_distance
	if _resolved_end_distance < 0.0 or _resolved_end_distance > curve_len:
		_resolved_end_distance = curve_len

	if start_distance < 0.0:
		start_distance = 0.0

	if start_distance >= _resolved_end_distance:
		emit_signal("error", "plan_travel(): start_distance >= end_distance.")
		return 0.0

	# Build base-offset sample list within [start, end]
	var step := _curve.get_bake_interval() * sample_step_factor
	if step < sample_step_min:
		step = sample_step_min

	_arc_offsets = PackedFloat32Array()
	_arc_cumulative = PackedFloat32Array()

	var off := start_distance
	var last_world := _sample_world_with_arc(off)
	var cum := 0.0

	_arc_offsets.append(off)
	_arc_cumulative.append(0.0)

	while off + step < _resolved_end_distance:
		off += step
		var world := _sample_world_with_arc(off)
		cum += world.distance_to(last_world)
		_arc_offsets.append(off)
		_arc_cumulative.append(cum)
		last_world = world

	# Ensure exact end sample
	var world_end := _sample_world_with_arc(_resolved_end_distance)
	cum += world_end.distance_to(last_world)
	_arc_offsets.append(_resolved_end_distance)
	_arc_cumulative.append(cum)

	_total_arc_distance = cum

	# Integrate speed profile if provided: duration = ∫ ds / (speed * profile(s_norm))
	# Numeric approximation across samples.
	if speed_units_per_sec <= 0.0:
		emit_signal("error", "plan_travel(): speed must be > 0.")
		_duration_sec = 0.0
		_planned = true
		return _duration_sec

	var total_time := 0.0
	for i in range(1, _arc_offsets.size()):
		var ds := _arc_cumulative[i] - _arc_cumulative[i - 1]
		var s_mid_norm := 0.0
		if _total_arc_distance > 0.0:
			s_mid_norm = (_arc_cumulative[i] + _arc_cumulative[i - 1]) * 0.5 / _total_arc_distance
		var mult := 1.0
		if speed_profile != null:
			mult = max(0.0001, speed_profile.sample_baked(s_mid_norm))
		total_time += ds / (speed_units_per_sec * mult)


	_duration_sec = total_time
	_planned = true
	return _duration_sec


## Returns the last planned duration (seconds). If not planned yet, computes it now.
func get_planned_duration() -> float:
	if !_planned:
		return plan_travel()
	return _duration_sec


## Start traveling using the last plan (or compute one if missing).
func activate() -> void:
	if !_planned:
		plan_travel()
	if _duration_sec <= 0.0:
		emit_signal("error", "activate(): duration is zero; check speed and curve.")
		return

	_active = true
	_paused = false
	_elapsed_sec = 0.0
	progress = start_distance
	loop = false

	emit_signal("started", projectile, _duration_sec)


## Pause or resume travel.
func set_paused(p: bool) -> void:
	if !_active:
		return
	_paused = p
	emit_signal("paused_changed", _paused)


func is_paused() -> bool:
	return _paused


## Abort travel and reset to start (keeps projectile attached).
func reset() -> void:
	_active = false
	_paused = false
	_elapsed_sec = 0.0
	progress = start_distance


## Stop, snap to end, optionally auto-detach.
func stop_at_end() -> void:
	_active = false
	_paused = false
	_elapsed_sec = _duration_sec
	progress = _resolved_end_distance
	_update_projectile_transform(_resolved_end_distance)
	_on_arrived()


# -------------------------
# Internals
# -------------------------

func _tick(delta: float) -> void:
	if !_active or _paused or _curve == null:
		return

	if _duration_sec <= 0.0:
		_on_arrived()
		return

	_elapsed_sec += delta
	if _elapsed_sec >= _duration_sec:
		_elapsed_sec = _duration_sec

	# Distance traveled along the *arc* so far
	var dist_travelled := _distance_along_arc_at_time(_elapsed_sec)
	# Find corresponding base offset on the curve via look-up
	var base_off := _offset_for_arc_distance(dist_travelled)
	progress = base_off

	_update_projectile_transform(base_off)

	var t_norm := 0.0
	if _duration_sec > 0.0:
		t_norm = _elapsed_sec / _duration_sec
	emit_signal("tick", projectile, t_norm, dist_travelled)

	if _elapsed_sec >= _duration_sec:
		_on_arrived()


func _on_arrived() -> void:
	if freeze_on_arrival:
		_active = false
		_paused = false
	_update_projectile_transform(_resolved_end_distance)
	emit_signal("arrived", projectile)

	if auto_detach_on_arrival:
		detach_projectile(true, true)


func _on_curve_changed() -> void:
	# Rebuild plan when curve changes.
	_planned = false
	if _active:
		# If already active, re-plan to avoid divergence.
		var was_paused := _paused
		set_paused(true)
		plan_travel()
		set_paused(was_paused)


# Calculate distance traveled along arc at time t, honoring speed_profile.
func _distance_along_arc_at_time(t_sec: float) -> float:
	if t_sec <= 0.0:
		return 0.0
	if t_sec >= _duration_sec:
		return _total_arc_distance

	if speed_profile == null:
		# Constant speed => linear in time across arc distance
		return (_total_arc_distance * t_sec) / _duration_sec

	# With profile, integrate forward until reaching t_sec (numeric).
	# Use our precomputed ds segments and per-segment speed multipliers.
	var acc_time := 0.0
	for i in range(1, _arc_offsets.size()):
		var ds := _arc_cumulative[i] - _arc_cumulative[i - 1]
		if ds <= 0.0:
			continue
		var s_mid_norm := 0.0
		if _total_arc_distance > 0.0:
			s_mid_norm = (_arc_cumulative[i] + _arc_cumulative[i - 1]) * 0.5 / _total_arc_distance
		var mult: float = maxf(0.0001, speed_profile.sample_baked(s_mid_norm))
		var dt: float = ds / (speed_units_per_sec * mult)

		if acc_time + dt >= t_sec:
			# Within this segment; interpolate distance portion
			var remain := t_sec - acc_time
			var frac := remain / dt
			var dist_before := _arc_cumulative[i - 1]
			return dist_before + ds * frac

		acc_time += dt

	return _total_arc_distance


# Binary search in _arc_cumulative for target distance, then interpolate base offset.
func _offset_for_arc_distance(dist_along_arc: float) -> float:
	if _arc_cumulative.is_empty():
		return start_distance

	var d := clampf(dist_along_arc, 0.0, _total_arc_distance)

	# Edge cases
	if d <= 0.0:
		return _arc_offsets[0]
	if d >= _total_arc_distance:
		return _arc_offsets[_arc_offsets.size() - 1]

	# Binary search
	var lo: int = 0
	var hi: int = _arc_cumulative.size() - 1
	while lo <= hi:
		@warning_ignore("integer_division")
		var mid: int = (lo + hi) / 2
		var val := _arc_cumulative[mid]
		if is_equal_approx(val, d):
			return _arc_offsets[mid]
		if val < d:
			lo = mid + 1
		else:
			hi = mid - 1

	# Between hi and lo
	var i0 := maxi(0, hi)
	var i1 := mini(_arc_cumulative.size() - 1, lo)
	var d0 := _arc_cumulative[i0]
	var d1 := _arc_cumulative[i1]
	if is_equal_approx(d1, d0):
		return _arc_offsets[i0]
	var f := (d - d0) / (d1 - d0)
	return lerpf(_arc_offsets[i0], _arc_offsets[i1], f)


# Sample the curve at base offset and return WORLD position with arc applied.
func _sample_world_with_arc(base_offset: float) -> Vector3:
	var local := _curve.sample_baked(base_offset, use_cubic_interp)
	var world := _flight_path.to_global(local)
	var t_norm := 0.0
	var span := (_resolved_end_distance - start_distance)
	if span > 0.0:
		t_norm = (base_offset - start_distance) / span
	var arc_y := _arc_value(t_norm)
	return world + _arc_axis_world_n * arc_y


# Arc function: simple parabola peaking at t=0.5 with height = arc_height.
func _arc_value(t_norm: float) -> float:
	# 4t(1-t) in [0..1], peak=1 at t=0.5
	if t_norm <= 0.0 or t_norm >= 1.0:
		return 0.0
	var h := 4.0 * t_norm * (1.0 - t_norm)
	return arc_height * h


# Position the projectile at base_offset and apply orientation rules.
func _update_projectile_transform(base_offset: float) -> void:
	# Move the carrier along the base path (no rotation)
	progress = base_offset

	if projectile == null:
		return

	# Compute arced world position for current offset
	var here := _sample_world_with_arc(base_offset)
	projectile.global_position = here

	# Facing
	if face_velocity:
		var next_off := minf(base_offset + lookahead_distance, _resolved_end_distance)
		if is_equal_approx(next_off, base_offset):
			# Try small backstep for direction at endpoint
			next_off = max(base_offset - lookahead_distance, start_distance)
		var there := _sample_world_with_arc(next_off)
		var dir := there - here
		if yaw_only:
			dir.y = 0.0
		dir = dir.normalized()

		if dir.length() > 0.0001:
			projectile.look_at(there, Vector3.UP, true)
	# else: leave projectile orientation as-is
