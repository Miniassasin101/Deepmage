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

class MoveRangeCacheEntry:
	var navmap: RID = RID()
	var origin_on_nav: Vector3 = Vector3.ZERO
	var budget_key: int = 0
	var config_key: int = 0
	var height_offset_key: int = 0
	var ring_points: PackedVector3Array = PackedVector3Array()
	var microgrid: MoveRangeMicroGrid = null


var _move_range_cache_by_unit_id: Dictionary = {} # int -> MoveRangeCacheEntry
@export var move_range_cache_max_entries: int = 64


func _quantize_key(value: float, step: float) -> int:
	if step <= 0.0:
		return int(round(value * 1000.0))
	return int(round(value / step))


func _hash_combine_int(hash_value: int, next_value: int) -> int:
	# Simple 32-bit-ish mix (fast, stable enough for config keys)
	var mixed: int = hash_value
	mixed = mixed ^ next_value
	mixed = int(mixed * 16777619)
	return mixed


func _move_range_config_key() -> int:
	var hash_value: int = 2166136261

	hash_value = _hash_combine_int(hash_value, _quantize_key(move_range_cell_size, 0.001))
	hash_value = _hash_combine_int(hash_value, _quantize_key(move_range_snap_threshold, 0.001))
	hash_value = _hash_combine_int(hash_value, _quantize_key(move_range_max_step_height, 0.001))

	# Include any MoveRangeMicroGrid settings you expose/tune:
	hash_value = _hash_combine_int(hash_value, int(_microgrid.neighbor_radius_cells))
	hash_value = _hash_combine_int(hash_value, int(_microgrid.use_marching_squares))
	hash_value = _hash_combine_int(hash_value, int(_microgrid.prevent_skipping_through_obstacles))

	hash_value = _hash_combine_int(hash_value, _quantize_key(_microgrid.resample_spacing_world, 0.001))
	hash_value = _hash_combine_int(hash_value, int(_microgrid.average_window_radius))
	hash_value = _hash_combine_int(hash_value, int(_microgrid.average_passes))
	hash_value = _hash_combine_int(hash_value, int(_microgrid.chaikin_iterations))
	hash_value = _hash_combine_int(hash_value, _quantize_key(_microgrid.simplify_epsilon_world, 0.001))

	return hash_value


func invalidate_move_range_cache_for_unit(in_unit: Unit) -> void:
	if in_unit == null:
		return
	var unit_id: int = in_unit.get_instance_id()
	if _move_range_cache_by_unit_id.has(unit_id):
		_move_range_cache_by_unit_id.erase(unit_id)


func clear_move_range_cache() -> void:
	_move_range_cache_by_unit_id.clear()


func _evict_cache_if_needed() -> void:
	if move_range_cache_max_entries <= 0:
		return
	if _move_range_cache_by_unit_id.size() <= move_range_cache_max_entries:
		return

	# Cheap eviction: remove arbitrary keys until under limit.
	# (If you want true LRU, we can add timestamps.)
	var keys: Array = _move_range_cache_by_unit_id.keys()
	while _move_range_cache_by_unit_id.size() > move_range_cache_max_entries and keys.size() > 0:
		var key_to_remove: Variant = keys.pop_back()
		_move_range_cache_by_unit_id.erase(key_to_remove)





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
	if move_range_renderer == null or not is_instance_valid(move_range_renderer):
		return

	# Snap start to nav (this is the “did the unit move?” test anchor)
	var unit_world_position: Vector3 = in_unit.global_position
	var origin_on_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, unit_world_position)

	var unit_id: int = in_unit.get_instance_id()

	# Quantize budget & height offset to avoid float jitter causing unnecessary rebuilds
	var budget_key: int = _quantize_key(budget_distance, 0.01)
	var height_offset_key: int = _quantize_key(move_range_height_offset, 0.001)

	# Build config key (includes microgrid settings too)
	var config_key: int = _move_range_config_key()

	# Movement tolerance: if snapped origin changes less than this, treat as “not moved”
	var movement_epsilon: float = move_range_cell_size * 0.20
	var movement_epsilon_sq: float = movement_epsilon * movement_epsilon

	if _move_range_cache_by_unit_id.has(unit_id):
		var existing_entry: MoveRangeCacheEntry = _move_range_cache_by_unit_id[unit_id]

		var same_navmap: bool = existing_entry.navmap == navmap
		var same_budget: bool = existing_entry.budget_key == budget_key
		var same_config: bool = existing_entry.config_key == config_key
		var same_height: bool = existing_entry.height_offset_key == height_offset_key
		var same_origin: bool = existing_entry.origin_on_nav.distance_squared_to(origin_on_nav) <= movement_epsilon_sq

		if same_navmap and same_budget and same_config and same_height and same_origin:
			# ✅ Reuse last generation
			move_range_renderer.set_ring_world_points(existing_entry.ring_points)
			return

	# Cache miss or invalidated → rebuild
	_microgrid.cell_size = move_range_cell_size
	_microgrid.snap_threshold = move_range_snap_threshold
	_microgrid.max_step_height = move_range_max_step_height

	_microgrid.build(navmap, unit_world_position, budget_distance)
	var ring_points: PackedVector3Array = _microgrid.get_best_boundary_world(move_range_height_offset)

	move_range_renderer.set_ring_world_points(ring_points)

	# Store/refresh cache
	var new_entry: MoveRangeCacheEntry = MoveRangeCacheEntry.new()
	new_entry.navmap = navmap
	new_entry.origin_on_nav = origin_on_nav
	new_entry.budget_key = budget_key
	new_entry.config_key = config_key
	new_entry.height_offset_key = height_offset_key
	new_entry.ring_points = ring_points
	new_entry.microgrid = _microgrid # optional: store if you want to reuse queries too

	_move_range_cache_by_unit_id[unit_id] = new_entry
	_evict_cache_if_needed()
