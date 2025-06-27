class_name MouseWorld
extends Node3D

# Layer mask for detecting objects on layer 2 (1 << 1)
const GRID_MASK: int = 2
# Layer mask for units
const UNIT_LAYER_MASK: int = 4

const OBSTACLE_LAYER_MASK: int = 1 << 4
# Toggle for showing a debug sphere at the mouse position
@export var mouse_debug_sphere: bool

# Reference to the RayCast3D node
@export var raycast: RayCast3D

@export var mouse_visual: MeshInstance3D

@export var debug_visual: PackedScene
# Reference to the active Camera3D
var camera: Camera3D

# Mouse position in screen coordinates
var mouse_position: Vector2



static var instance: MouseWorld = null



# Called when the node enters the scene tree
func _ready() -> void:
	if instance != null:
		push_error("There's more than one MouseWorld! - " + str(instance))
		queue_free()
		return
	instance = self
	camera = get_viewport().get_camera_3d()
	# Create and add the RayCast3D node dynamically if it's not in the scene
	if raycast == null:
		raycast = RayCast3D.new()
		#raycast.collision_mask = UNIT_LAYER_MASK  # Set the collision mask
		raycast.set_collision_mask_value(2, true)
		_change_layer_mask_to_grid()
		raycast.enabled = true  # Enable the RayCast3D node
		add_child(raycast)  # Add RayCast3D to the scene

# Called every frame
func _process(_delta: float) -> void:
	# Update mouse position
	adjust_mouse_position()
	

	# Perform the raycast and move the node if a hit is detected
	if mouse_debug_sphere:
		_adjust_mouse_debug_position()




func has_line_of_sight(start_position: Vector3, end_position: Vector3) -> bool:
	# Access the space state for physics queries
	var space_state = get_world_3d().direct_space_state
	# Create a raycast query
	var query = PhysicsRayQueryParameters3D.new()
	query.from = start_position
	query.to = end_position
	query.collision_mask = OBSTACLE_LAYER_MASK  # Set the collision mask to the provided layer
	query.collide_with_bodies = true
	query.collide_with_areas = true  # Include areas if needed

	# Perform the raycast
	var result: Dictionary = space_state.intersect_ray(query)

	# Debug visualization (optional)
	if debug_visual:
		var vis1: Node3D = debug_visual.instantiate()
		var vis2: Node3D = debug_visual.instantiate()
		add_child(vis1)
		add_child(vis2)
		vis1.global_position = start_position
		vis2.global_position = end_position
	if result.has("position"):
		print_debug("collided")
	# If no collision is detected, line of sight is clear
	return not result.has("position")





# Returns the mouse position in world space as a Dictionary
func get_mouse_raycast_result(result_type: String) -> Variant:
	# Ensure RayCast3D is available
	if raycast == null or not raycast.is_inside_tree():
		return null
	if result_type == "collider":
		_change_layer_mask_to_unit()
	elif result_type == "position":
		_change_layer_mask_to_grid()
		
	# Calculate ray origin and direction
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)

	# Update RayCast3D's position and target
	raycast.global_transform.origin = ray_origin
	raycast.target_position = ray_origin + ray_direction * 1000  # Extend ray

	# Force raycast update
	raycast.force_raycast_update()
	#print(raycast.get_collider())
	# Return collision data if a collision occurred
	if raycast.is_colliding():
		match result_type:
			"position":
				return raycast.get_collision_point()
			"collider":
				return raycast.get_collider()
				

	else:
		# Return null if there's no collision
		return null


	# Return null if no collision
	return null


# Updates the mouse position variable
func adjust_mouse_position() -> void:
	mouse_position = get_viewport().get_mouse_position()

func _change_layer_mask_to_unit() -> void:
	#print_debug("layer mask changed to unit")
	raycast.set_collision_mask_value(2, false)
	raycast.set_collision_mask_value(4, true)
	raycast.set_collision_mask_value(5, false)

func _change_layer_mask_to_grid() -> void:
	#print_debug("layer mask changed to grid")
	raycast.set_collision_mask_value(2, true)
	raycast.set_collision_mask_value(4, false)
	raycast.set_collision_mask_value(5, false)

func _change_layer_mask_to_obstacle() -> void:
	#print_debug("layer mask changed to obstacle")
	raycast.set_collision_mask_value(2, false)
	raycast.set_collision_mask_value(4, false)
	raycast.set_collision_mask_value(5, true)

func _adjust_mouse_debug_position() -> void:
	if camera != null and raycast != null:
		var hit_position = get_mouse_raycast_result("position")
		if hit_position != null:
			if mouse_visual.visible == false:
				mouse_visual.visible = true
			# Update the node's position to the raycast hit position
			global_transform.origin = hit_position
			
