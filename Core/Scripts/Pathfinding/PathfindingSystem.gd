class_name PathfindingSystem
extends Node


@export_category("References")
@export var nav_region_3d: NavigationRegion3D

@export var curvemesh: CurveMesh3D = null

@export var radius_curve: Curve

@export var debug_curve_material: StandardMaterial3D 

var navmap: RID = RID()

static var instance: PathfindingSystem = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one Pathfinding! - " + str(instance))
		queue_free()
		return
	instance = self
	
	navigation_setup.call_deferred()



func get_path_package(world_position: Vector3, unit: Unit, get_path: bool = true, get_cost: bool = false) -> PathPackage:
	var path_pack: PathPackage = PathPackage.new()
	unit.nav_agent.set_target_position(world_position)
	

	
	if get_path:
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
	
	if get_cost:
		pass
		
	make_visible_path(path_pack)
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
	
	
	# Query the path from the navigation server.
	var start_position: Vector3 = Vector3(0.1, 0.0, 0.1)
	var target_position: Vector3 = Vector3(9.0, 0.0, 1.0)
	var optimize_path: bool = true


	"""
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
	return NavigationServer3D.map_get_closest_point(navmap, pos)
