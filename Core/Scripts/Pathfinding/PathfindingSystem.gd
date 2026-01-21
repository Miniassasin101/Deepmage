class_name PathfindingSystem
extends Node


@export_category("References")
@export var nav_region_3d: NavigationRegion3D

@export var curvemesh: CurveMesh3D = null
@export var radius_curve: Curve
@export var debug_curve_material: StandardMaterial3D


@export_category("Move Range (MicroGrid)")
@export var move_range_renderer: MoveRangeRingRenderer
@export_range(0.1, 1.0, 0.01) var move_range_cell_size: float = 0.33
@export_range(0.01, 1.0, 0.01) var move_range_snap_threshold: float = 0.20
@export_range(0.0, 2.0, 0.01) var move_range_max_step_height: float = 0.75
@export_range(0.0, 0.5, 0.005) var move_range_height_offset: float = 0.06
@export_range(0, 3, 1) var move_range_smoothing_iterations: int = 1


var navmap: RID = RID()
static var instance: PathfindingSystem = null

const MAX_SNAP: float = 10.0

var _microgrid: MoveRangeMicroGrid = MoveRangeMicroGrid.new()


func _ready() -> void:
	if instance != null:
		push_error("There's more than one Pathfinding! - " + str(instance))
		queue_free()
		return
	instance = self

	navigation_setup.call_deferred()
	call_deferred("_ensure_move_range_renderer")


func _ensure_move_range_renderer() -> void:
	if move_range_renderer != null and is_instance_valid(move_range_renderer):
		return
	move_range_renderer = MoveRangeRingRenderer.new()
	move_range_renderer.name = "MoveRangeRingRenderer"
	add_child(move_range_renderer)


func get_path_package(world_position: Vector3, unit: Unit, should_get_path: bool = true, should_get_cost: bool = false) -> PathPackage:
	var path_pack: PathPackage = PathPackage.new()
	unit.nav_agent.set_target_position(world_position)

	if should_get_path:
		var optimize_path: bool = true
		var path_arr: PackedVector3Array = NavigationServer3D.map_get_path(
			navmap,
			unit.global_position,
			world_position,
			optimize_path
		)
		path_pack.set_path_array(path_arr)

	if should_get_cost:
		pass

	make_visible_path(path_pack)
	return path_pack


func get_path_pack_to_unit(from_unit: Unit, to_unit: Unit) -> PathPackage:
	var to_pos: Vector3 = to_unit.get_global_position()
	var path_pack: PathPackage = get_path_package(to_pos, from_unit, true)
	return path_pack


func navigation_setup() -> void:
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)

	var region: RID = nav_region_3d.get_rid()
	nav_region_3d.set_navigation_map(map)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, nav_region_3d.navigation_mesh)

	navmap = map

	await get_tree().physics_frame
	await get_tree().physics_frame


func make_visible_path(path_package: PathPackage) -> void:
	var curve: Curve3D = path_package.get_curve_3d_from_path()
	if curvemesh:
		curvemesh.queue_free()

	curvemesh = CurveMesh3D.new()
	add_child(curvemesh)

	curvemesh.cm_clear()
	curvemesh.curve = curve
	curvemesh.radius_profile = radius_curve
	curvemesh.material = debug_curve_material


func get_closest_nav_point_to(pos: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(navmap, pos) + Utilities.nav_vector_offset


func get_radial_points_surrounding_unit(in_unit: Unit, radius: float, points_sampled: int) -> Array[Vector3]:
	var radial_points: Array[Vector3] = []

	if in_unit == null or points_sampled <= 0 or radius <= 0.0:
		push_error("Invalid Data On Radial Points")
		return radial_points

	if not navmap.is_valid():
		push_error("PathfindingSystem.navmap is not ready yet.")
		return radial_points

	var center: Vector3 = in_unit.get_global_position()
	var start_on_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, center)
	var optimize_path: bool = true

	for sample_index in range(points_sampled):
		var t_value: float = float(sample_index) / float(points_sampled)
		var angle: float = TAU * t_value
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var desired_sample: Vector3 = center + direction * radius

		var on_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, desired_sample)

		if on_nav.distance_to(desired_sample) > MAX_SNAP:
			continue

		var path: PackedVector3Array = NavigationServer3D.map_get_path(navmap, start_on_nav, on_nav, optimize_path)
		if path.size() >= 2:
			radial_points.append(on_nav + Utilities.nav_vector_offset)

	return radial_points


func sort_positions_by_distance_inplace(positions: Array[Vector3], to: Vector3) -> Array[Vector3]:
	positions.sort_custom(func(position_a: Vector3, position_b: Vector3) -> bool:
		return position_a.distance_squared_to(to) < position_b.distance_squared_to(to)
	)
	return positions


# -------------------------------------------------------------------
# Move Range API
# -------------------------------------------------------------------
func clear_move_range() -> void:
	if move_range_renderer and is_instance_valid(move_range_renderer):
		move_range_renderer.clear()


func show_move_range_for_unit(in_unit: Unit, budget_distance: float) -> void:
	if in_unit == null:
		return
	if not navmap.is_valid():
		return

	_microgrid.cell_size = move_range_cell_size
	_microgrid.snap_threshold = move_range_snap_threshold
	_microgrid.max_step_height = move_range_max_step_height
	_microgrid.smoothing_iterations = move_range_smoothing_iterations

	_microgrid.build(navmap, in_unit.global_position, budget_distance)
	var ring_points: PackedVector3Array = _microgrid.get_best_boundary_world(move_range_height_offset)

	if move_range_renderer and is_instance_valid(move_range_renderer):
		move_range_renderer.set_ring_world_points(ring_points)
