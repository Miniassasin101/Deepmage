class_name PathfindingSystem
extends Node


@export_category("References")
@export var nav_region_3d: NavigationRegion3D

@export var curvemesh: CurveMesh3D = null

@export var radius_curve: Curve

@export var debug_curve_material: StandardMaterial3D 

var navmap: RID = RID()

static var instance: PathfindingSystem = null

# How far we're willing to let a snapped point drift from the ideal ring sample
const MAX_SNAP := 2.0


func _ready() -> void:
	if instance != null:
		push_error("There's more than one Pathfinding! - " + str(instance))
		queue_free()
		return
	instance = self
	
	navigation_setup.call_deferred()



func get_path_package(world_position: Vector3, unit: Unit, should_get_path: bool = true, should_get_cost: bool = false) -> PathPackage:
	var path_pack: PathPackage = PathPackage.new()
	unit.nav_agent.set_target_position(world_position)
	

	
	if should_get_path:
		var optimize_path: bool = true
		
		#var nav_path: Array = unit.nav_agent.get_current_navigation_path()
		#var final_position: Vector3 = unit.nav_agent.get_final_position()
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

	# Create a new navigation map.
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)

	# Add the navigation region to the map
	var region: RID = nav_region_3d.get_rid()
	nav_region_3d.set_navigation_map(map)
	#NavigationServer3D.region_set_transform(region, Transform3D())
	NavigationServer3D.region_set_map(region, map)
	
	
	NavigationServer3D.region_set_navigation_mesh(region, nav_region_3d.navigation_mesh)
	
	navmap = map
	
	# Wait for NavigationServer sync to adapt to made changes.
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	
	"""
	#Query the path from the navigation server.
	var start_position: Vector3 = Vector3(0.1, 0.0, 0.1)
	var target_position: Vector3 = Vector3(9.0, 0.0, 1.0)
	var optimize_path: bool = true


	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		map,
		start_position,
		target_position,
		optimize_path
	)
	var closest_point: Vector3 = NavigationServer3D.map_get_closest_point(map, target_position)
	
	print("Found a path!")
	print(path)
"""

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
	
	
	
	
	pass


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
	
	# Center point to sample around
	var center: Vector3 = in_unit.get_global_position()
	
	#Snap center to the navmesh
	var start_on_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, center)
	
	var optimize_path := true
	
	for i in range(points_sampled):
		var t := float(i) / float(points_sampled)
		var angle := TAU * t
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var desired_sample := center + dir * radius

		# Snap each ring sample to the nearest navmesh point
		var on_nav := NavigationServer3D.map_get_closest_point(navmap, desired_sample)

		# (Optional) Discard if snapping jumps too far (e.g., over a wall / different island)
		if on_nav.distance_to(desired_sample) > MAX_SNAP:
			continue

		# (Optional but useful) Keep only if reachable from the center's island
		var path := NavigationServer3D.map_get_path(navmap, start_on_nav, on_nav, optimize_path)
		if path.size() >= 2:
			radial_points.append(on_nav + Utilities.nav_vector_offset)
	
	
	return radial_points


# Sorts the passed-in array in-place, nearest -> farthest.
func sort_positions_by_distance_inplace(positions: Array[Vector3], to: Vector3) -> Array[Vector3]:
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(to) < b.distance_squared_to(to)
	)
	return positions
