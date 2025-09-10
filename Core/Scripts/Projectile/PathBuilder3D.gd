class_name PathBuilder3D
extends Node
##
## PathBuilder3D
## Utilities to create Path3D + Curve3D from two world positions.
## - Straight line or arced (apex) path.
## - Places the Path3D at `start` so curve points are local and stable.
## - Returns the created Path3D (already holding a Curve3D).
## 

static var instance: PathBuilder3D = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one PathBuilder3D! - " + str(instance))
		queue_free()
		return
	instance = self



static func make_path_straight(
		start: Vector3,
		end: Vector3,
		parent: Node = null,
		bake_interval: float = 0.2
) -> Path3D:
	var path := Path3D.new()
	if parent != null:
		parent.add_child(path)
	path.name = "Path_Straight"
	path.global_transform.origin = start

	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	curve.closed = false
	path.curve = curve

	var p0 := Vector3.ZERO
	var p1 := path.to_local(end)

	# Degenerate safeguard (if start ~= end, give a tiny segment forward)
	if p1.length() < 0.001:
		p1 = Vector3(0, 0, -0.1)

	curve.add_point(p0)              # handles default to (0,0,0)
	curve.add_point(p1)

	return path


static func make_path_arc(
		start: Vector3,
		end: Vector3,
		arc_height: float = 2.0,          # world-space height of apex relative to chord
		apex_t: float = 0.5,              # apex position along chord [0..1]
		smoothness: float = 0.25,         # handle length factor (0..~0.5)
		up_axis: Vector3 = Vector3.UP,    # world up for the apex offset
		parent: Node = null,
		bake_interval: float = 0.2
) -> Path3D:
	var path := Path3D.new()
	if parent != null:
		parent.add_child(path)
	path.name = "Path_Arc"
	path.global_transform.origin = start

	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	curve.closed = false
	# You can enable up vectors if you plan to use ROTATION_ORIENTED somewhere else:
	# curve.up_vector_enabled = true
	path.curve = curve

	var p0 := Vector3.ZERO
	var end_local := path.to_local(end)

	# Degenerate safeguard
	if end_local.length() < 0.001:
		end_local = Vector3(0, 0, -0.1)

	# Apex in world space, then convert to local
	if apex_t < 0.0:
		apex_t = 0.0
	if apex_t > 1.0:
		apex_t = 1.0

	var up_n := up_axis.normalized()
	if up_n == Vector3.ZERO:
		up_n = Vector3.UP

	var apex_world := start.lerp(end, apex_t) + up_n * arc_height
	var apex_local := path.to_local(apex_world)

	# Directions and distances for handle sizing
	var dir01 := apex_local - p0
	var d01 := dir01.length()
	var n01 := Vector3.ZERO
	if d01 > 0.0:
		n01 = dir01 / d01

	var dir12 := end_local - apex_local
	var d12 := dir12.length()
	var n12 := Vector3.ZERO
	if d12 > 0.0:
		n12 = dir12 / d12

	# Handle lengths proportional to neighboring segment lengths
	if smoothness < 0.0:
		smoothness = 0.0
	if smoothness > 0.5:
		smoothness = 0.5

	var h0_out := n01 * (d01 * smoothness)
	var h1_in := -n01 * (d01 * smoothness)
	var h1_out := n12 * (d12 * smoothness)
	var h2_in := -n12 * (d12 * smoothness)

	# Build 3-point curve: start → apex → end
	curve.add_point(p0, Vector3.ZERO, h0_out)
	curve.add_point(apex_local, h1_in, h1_out)
	curve.add_point(end_local, h2_in, Vector3.ZERO)

	return path


## Convenience: reuse an existing Path3D and rebuild its curve as a straight line.
static func rebuild_path_straight(path: Path3D, start: Vector3, end: Vector3, bake_interval: float = 0.2) -> void:
	if path == null:
		return
	path.global_transform.origin = start

	var curve := path.curve
	if curve == null:
		curve = Curve3D.new()
		path.curve = curve

	curve.clear_points()
	curve.bake_interval = bake_interval
	curve.closed = false

	var p0 := Vector3.ZERO
	var p1 := path.to_local(end)
	if p1.length() < 0.001:
		p1 = Vector3(0, 0, -0.1)

	curve.add_point(p0)
	curve.add_point(p1)


## Convenience: reuse an existing Path3D and rebuild its curve as an arc.
static func rebuild_path_arc(path: Path3D, start: Vector3, end: Vector3, arc_height: float = 2.0, apex_t: float = 0.5, smoothness: float = 0.25, up_axis: Vector3 = Vector3.UP, bake_interval: float = 0.2) -> void:
	if path == null:
		return
	path.global_transform.origin = start

	var curve := path.curve
	if curve == null:
		curve = Curve3D.new()
		path.curve = curve

	curve.clear_points()
	curve.bake_interval = bake_interval
	curve.closed = false

	var p0 := Vector3.ZERO
	var end_local := path.to_local(end)
	if end_local.length() < 0.001:
		end_local = Vector3(0, 0, -0.1)

	if apex_t < 0.0:
		apex_t = 0.0
	if apex_t > 1.0:
		apex_t = 1.0

	var up_n := up_axis.normalized()
	if up_n == Vector3.ZERO:
		up_n = Vector3.UP

	var apex_world := start.lerp(end, apex_t) + up_n * arc_height
	var apex_local := path.to_local(apex_world)

	var dir01 := apex_local - p0
	var d01 := dir01.length()
	var n01 := Vector3.ZERO
	if d01 > 0.0:
		n01 = dir01 / d01

	var dir12 := end_local - apex_local
	var d12 := dir12.length()
	var n12 := Vector3.ZERO
	if d12 > 0.0:
		n12 = dir12 / d12

	if smoothness < 0.0:
		smoothness = 0.0
	if smoothness > 0.5:
		smoothness = 0.5

	var h0_out := n01 * (d01 * smoothness)
	var h1_in := -n01 * (d01 * smoothness)
	var h1_out := n12 * (d12 * smoothness)
	var h2_in := -n12 * (d12 * smoothness)

	curve.add_point(p0, Vector3.ZERO, h0_out)
	curve.add_point(apex_local, h1_in, h1_out)
	curve.add_point(end_local, h2_in, Vector3.ZERO)
