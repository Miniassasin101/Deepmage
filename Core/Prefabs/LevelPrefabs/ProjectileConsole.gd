class_name ProjectileConsole
extends Node

# --- Last created/attached state for quick iteration ---
var last_path: Path3D = null
var last_carrier: ProjectileCarrier = null
var last_projectile: Node3D = null
var _proj_was_spawned_here: bool = false   # if true, we own and will free it

func _ready() -> void:
	# Build/attach
	Console.add_command("proj_build_line_units", proj_build_line_units,
		["start_unit","end_unit","speed?","arc_height?","face?","yaw_only?" ], 0,
		"Build STRAIGHT Path3D via PathBuilder3D from two units. Optionally set speed, arc_height (carrier), face (on/off), yaw_only (on/off).")
	Console.add_command("proj_build_arc_units", proj_build_arc_units,
		["start_unit","end_unit","arc_height","speed?","apex_t?","smooth?","face?","yaw_only?" ], 0,
		"Build ARCED Path3D (curve has apex). arc_height applies to path, not carrier. Optional speed/apex_t/smooth/face/yaw_only.")

	Console.add_command("proj_build_line_pos", proj_build_line_pos,
		["sx","sy","sz","ex","ey","ez","speed?","arc_height?","face?","yaw_only?" ], 0,
		"Build STRAIGHT path from world coordinates. Optional speed, arc_height, face, yaw_only.")
	Console.add_command("proj_build_arc_pos", proj_build_arc_pos,
		["sx","sy","sz","ex","ey","ez","arc_height","speed?","apex_t?","smooth?","face?","yaw_only?" ], 0,
		"Build ARCED path from world coordinates. arc_height applies to path curve. Optional speed/apex_t/smooth/face/yaw_only.")

	# Projectile management
	Console.add_command("proj_spawn_debug", proj_spawn_debug, ["size?"], 0,
		"Spawn a simple sphere MeshInstance3D projectile at current start. Optional size (default 0.15).")
	Console.add_command("proj_attach_node", proj_attach_node, ["node_name_or_path"], 1,
		"Attach an existing Node3D (by name or absolute node path) as the projectile.")
	Console.add_command("proj_detach", proj_detach, [], 0, "Detach projectile from carrier (returns it to original parent).")

	# Run controls
	Console.add_command("proj_plan", proj_plan, [], 0, "Precompute flight and print planned duration (seconds).")
	Console.add_command("proj_fire", proj_fire, [], 0, "Activate the projectile travel.")
	Console.add_command("proj_pause", proj_pause, ["on_off_toggle?"], 0, "Pause/resume/toggle.")
	Console.add_command("proj_stop", proj_stop, [], 0, "Stop and snap to end (fires arrived).")
	Console.add_command("proj_reset", proj_reset, [], 0, "Reset to start (does not fire arrived).")

	# Tweaks & info
	Console.add_command("proj_set_speed", proj_set_speed, ["speed"], 1, "Set carrier speed (world units/sec).")
	Console.add_command("proj_set_arc", proj_set_arc, ["arc_height"], 1, "Set carrier arc_height (parabola).")
	Console.add_command("proj_face", proj_face, ["on_off","yaw_only?"], 1, "Set facing (on/off) and optional yaw_only (on/off).")
	Console.add_command("proj_info", proj_info, [], 0, "Print debug info about path/carrier/projectile.")
	Console.add_command("proj_cleanup", proj_cleanup, [], 0, "Free path (and spawned debug projectile if we created it).")

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

func _scene_root() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root

func _find_unit_world(in_name: String) -> Vector3:
	if UnitManager.instance == null:
		Console.print_line("UnitManager.instance is null.", true); return Vector3.ZERO
	var u = UnitManager.instance.get_unit_by_name(in_name)
	if u == null:
		Console.print_line("Unit '%s' not found." % in_name, true); return Vector3.ZERO
	return u.global_transform.origin + Vector3(0.0, 1.0, 0.0)

func _bool_from_str(s: String, default_val: bool) -> bool:
	if s == null or s == "":
		return default_val
	var lower = s.to_lower()
	if lower == "1" or lower == "true" or lower == "on" or lower == "yes":
		return true
	if lower == "0" or lower == "false" or lower == "off" or lower == "no":
		return false
	return default_val

func _parse_vec3_components(ax: String, ay: String, az: String) -> Vector3:
	return Vector3(ax.to_float(), ay.to_float(), az.to_float())

func _ensure_carrier_on(path: Path3D) -> ProjectileCarrier:
	# Reuse existing if path matches
	if last_carrier != null and is_instance_valid(last_carrier) and last_carrier.get_parent() == path:
		return last_carrier
	# Else (re)create
	var carrier := ProjectileCarrier.new()
	path.add_child(carrier)
	# Make sure motion runs
	carrier.set_physics_process(true)
	carrier.set_process(false)
	last_carrier = carrier
	# Quick feedback
	carrier.started.connect(func(_p, dur): Console.print_line("→ started; duration=%.3f s" % dur, true))
	carrier.arrived.connect(func(_p): Console.print_line("→ arrived.", true))
	carrier.error.connect(func(msg): Console.print_line("ERROR: %s" % msg, true))
	return carrier

func _clear_previous_path() -> void:
	if last_path != null and is_instance_valid(last_path):
		last_path.queue_free()
	last_path = null
	last_carrier = null

func _ensure_start_position() -> Vector3:
	if last_path != null and is_instance_valid(last_path):
		return last_path.global_transform.origin
	return Vector3.ZERO

func _attach_if_present() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		return
	if last_projectile != null and is_instance_valid(last_projectile):
		last_carrier.attach_projectile(last_projectile, true)

# -------------------------------------------------------------------------
# Build/attach commands
# -------------------------------------------------------------------------

func proj_build_line_units(start_unit: String, end_unit: String, speed_s: String = "", arc_h_s: String = "", face_s: String = "", yaw_s: String = "") -> void:
	var start := _find_unit_world(start_unit)
	var end := _find_unit_world(end_unit)
	_clear_previous_path()
	last_path = PathBuilder3D.make_path_straight(start, end, _scene_root(), 0.1)
	var c := _ensure_carrier_on(last_path)

	if speed_s != "":
		c.speed_units_per_sec = speed_s.to_float()
	if arc_h_s != "":
		c.arc_height = arc_h_s.to_float()
	if face_s != "":
		c.face_velocity = _bool_from_str(face_s, c.face_velocity)
	if yaw_s != "":
		c.yaw_only = _bool_from_str(yaw_s, c.yaw_only)

	_attach_if_present()
	Console.print_line("Built STRAIGHT path between %s → %s" % [start_unit, end_unit], true)

func proj_build_arc_units(start_unit: String, end_unit: String, arc_h_path_s: String,
		speed_s: String = "", apex_t_s: String = "", smooth_s: String = "", face_s: String = "", yaw_s: String = "") -> void:
	var start := _find_unit_world(start_unit)
	var end := _find_unit_world(end_unit)
	var arc_h_path := arc_h_path_s.to_float()

	var apex_t: float = 0.5
	if apex_t_s != "":
		apex_t = apex_t_s.to_float()

	var smooth: float = 0.25
	if smooth_s != "":
		smooth = smooth_s.to_float()

	_clear_previous_path()
	last_path = PathBuilder3D.make_path_arc(start, end, arc_h_path, apex_t, smooth, Vector3.UP, _scene_root(), 0.1)
	var c := _ensure_carrier_on(last_path)

	# With ARCED curve, set carrier arc to 0 so you don't double-arc
	c.arc_height = 0.0
	if speed_s != "":
		c.speed_units_per_sec = speed_s.to_float()
	if face_s != "":
		c.face_velocity = _bool_from_str(face_s, c.face_velocity)
	if yaw_s != "":
		c.yaw_only = _bool_from_str(yaw_s, c.yaw_only)

	_attach_if_present()
	Console.print_line("Built ARCED path between %s → %s (arc_h=%.2f, apex_t=%.2f, smooth=%.2f)" %
		[start_unit, end_unit, arc_h_path, apex_t, smooth], true)

func proj_build_line_pos(sx: String, sy: String, sz: String, ex: String, ey: String, ez: String,
		speed_s: String = "", arc_h_s: String = "", face_s: String = "", yaw_s: String = "") -> void:
	var start := _parse_vec3_components(sx, sy, sz)
	var end := _parse_vec3_components(ex, ey, ez)
	_clear_previous_path()
	last_path = PathBuilder3D.make_path_straight(start, end, _scene_root(), 0.1)
	var c := _ensure_carrier_on(last_path)

	if speed_s != "":
		c.speed_units_per_sec = speed_s.to_float()
	if arc_h_s != "":
		c.arc_height = arc_h_s.to_float()
	if face_s != "":
		c.face_velocity = _bool_from_str(face_s, c.face_velocity)
	if yaw_s != "":
		c.yaw_only = _bool_from_str(yaw_s, c.yaw_only)

	_attach_if_present()
	Console.print_line("Built STRAIGHT path from %s to %s" % [start, end], true)

func proj_build_arc_pos(sx: String, sy: String, sz: String, ex: String, ey: String, ez: String, arc_h_path_s: String,
		speed_s: String = "", apex_t_s: String = "", smooth_s: String = "", face_s: String = "", yaw_s: String = "") -> void:
	var start := _parse_vec3_components(sx, sy, sz)
	var end := _parse_vec3_components(ex, ey, ez)
	var arc_h_path := arc_h_path_s.to_float()

	var apex_t: float = 0.5
	if apex_t_s != "":
		apex_t = apex_t_s.to_float()

	var smooth: float = 0.25
	if smooth_s != "":
		smooth = smooth_s.to_float()

	_clear_previous_path()
	last_path = PathBuilder3D.make_path_arc(start, end, arc_h_path, apex_t, smooth, Vector3.UP, _scene_root(), 0.1)
	var c := _ensure_carrier_on(last_path)

	c.arc_height = 0.0
	if speed_s != "":
		c.speed_units_per_sec = speed_s.to_float()
	if face_s != "":
		c.face_velocity = _bool_from_str(face_s, c.face_velocity)
	if yaw_s != "":
		c.yaw_only = _bool_from_str(yaw_s, c.yaw_only)

	_attach_if_present()
	Console.print_line("Built ARCED path from %s to %s (arc_h=%.2f, apex_t=%.2f)" %
		[start, end, arc_h_path, apex_t], true)

# -------------------------------------------------------------------------
# Projectile mgmt
# -------------------------------------------------------------------------

func proj_spawn_debug(size_s: String = "") -> void:
	if last_path == null or !is_instance_valid(last_path):
		Console.print_line("No path yet. Build one first (proj_build_*).", true); return

	var size: float = 0.15
	if size_s != "":
		size = size_s.to_float()

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.radial_segments = 16
	sphere.rings = 8
	mi.mesh = sphere
	mi.name = "DebugProjectile"

	last_path.add_child(mi) # temporary parent; attach will reparent
	mi.global_position = last_path.global_transform.origin

	last_projectile = mi
	_proj_was_spawned_here = true

	# Auto attach to carrier if present
	if last_carrier != null and is_instance_valid(last_carrier):
		last_carrier.attach_projectile(last_projectile, true)

	Console.print_line("Spawned debug projectile (sphere, r=%.2f)." % size, true)

func proj_attach_node(node_name_or_path: String) -> void:
	var node: Node = null
	if node_name_or_path.begins_with("/"):
		node = get_node_or_null(node_name_or_path)
	else:
		node = _scene_root().find_child(node_name_or_path, true, false)
	if node == null or !(node is Node3D):
		Console.print_line("Node not found or not a Node3D: %s" % node_name_or_path, true); return

	last_projectile = node
	_proj_was_spawned_here = false

	if last_carrier != null and is_instance_valid(last_carrier):
		last_carrier.attach_projectile(last_projectile, true)

	Console.print_line("Attached projectile node: %s" % node_name_or_path, true)

func proj_detach() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.detach_projectile(true, true)
	Console.print_line("Projectile detached.", true)

# -------------------------------------------------------------------------
# Run controls
# -------------------------------------------------------------------------

func proj_plan() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier. Build a path first.", true); return
	var dur := last_carrier.plan_travel()
	Console.print_line("Planned Duration: %.4f s" % dur, true)

func proj_fire() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier. Build a path first.", true); return
	if last_carrier.projectile == null and last_projectile != null and is_instance_valid(last_projectile):
		last_carrier.attach_projectile(last_projectile, true)
	last_carrier.set_physics_process(true)
	var dur := last_carrier.get_planned_duration()
	last_carrier.activate()
	Console.print_line("Firing. Planned duration=%.3f s" % dur, true)

func proj_pause(arg: String = "") -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	if arg == "" or arg.to_lower() == "toggle":
		last_carrier.set_paused(!last_carrier.is_paused())
	else:
		last_carrier.set_paused(_bool_from_str(arg, last_carrier.is_paused()))
	Console.print_line("Paused = %s" % str(last_carrier.is_paused()), true)

func proj_stop() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.stop_at_end()
	Console.print_line("Stopped at end.", true)

func proj_reset() -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.reset()
	Console.print_line("Reset to start.", true)

# -------------------------------------------------------------------------
# Tweaks & info
# -------------------------------------------------------------------------

func proj_set_speed(v: String) -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.speed_units_per_sec = v.to_float()
	Console.print_line("Speed set to %.3f." % last_carrier.speed_units_per_sec, true)

func proj_set_arc(v: String) -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.arc_height = v.to_float()
	Console.print_line("Carrier arc_height set to %.3f." % last_carrier.arc_height, true)

func proj_face(face_s: String, yaw_s: String = "") -> void:
	if last_carrier == null or !is_instance_valid(last_carrier):
		Console.print_line("No carrier.", true); return
	last_carrier.face_velocity = _bool_from_str(face_s, last_carrier.face_velocity)
	if yaw_s != "":
		last_carrier.yaw_only = _bool_from_str(yaw_s, last_carrier.yaw_only)
	Console.print_line("Facing: %s | Yaw-only: %s" % [str(last_carrier.face_velocity), str(last_carrier.yaw_only)], true)

func proj_info() -> void:
	if last_path == null or !is_instance_valid(last_path):
		Console.print_line("No path.", true); return
	var curve := last_path.curve
	var leng := curve.get_baked_length() if (curve != null) else 0.0 # <-- will replace next lines; Godot may flag '?', so do it verbose:
	# Replace the line above if your GDScript flags '?' here:
	# var leng := 0.0
	# if curve != null:
	# 	leng = curve.get_baked_length()

	var carrier_str := "null"
	if last_carrier != null and is_instance_valid(last_carrier):
		carrier_str = "OK"

	var proj_str := "null"
	if last_projectile != null and is_instance_valid(last_projectile):
		proj_str = last_projectile.name

	Console.print_line("Path: %s | CurveLen=%.3f | Carrier=%s | Projectile=%s" %
		[last_path.name, leng, carrier_str, proj_str], true)

	if last_carrier != null and is_instance_valid(last_carrier):
		Console.print_line("    speed=%.3f, arc_h=%.3f, face=%s, yaw_only=%s" %
			[last_carrier.speed_units_per_sec, last_carrier.arc_height, str(last_carrier.face_velocity), str(last_carrier.yaw_only)], true)
		Console.print_line("    start_dist=%.3f, end_dist=%.3f, planned=%.3f s" %
			[last_carrier.start_distance, last_carrier.end_distance, last_carrier.get_planned_duration()], true)

func proj_cleanup() -> void:
	if last_carrier != null and is_instance_valid(last_carrier):
		last_carrier.detach_projectile(true, true)
		last_carrier = null
	if last_path != null and is_instance_valid(last_path):
		last_path.queue_free()
	last_path = null
	if _proj_was_spawned_here and last_projectile != null and is_instance_valid(last_projectile):
		last_projectile.queue_free()
	_proj_was_spawned_here = false
	last_projectile = null
	Console.print_line("Cleaned up path/carrier%s." % ("" if !_proj_was_spawned_here else " and spawned projectile"), true)
