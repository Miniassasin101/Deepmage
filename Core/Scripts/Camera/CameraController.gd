class_name PlayerController

extends CharacterBody3D
# Camera script that provides smooth camera movement through interpolation.
# Hierarchy: CharacterBody3D -> Node3D -> SpringArm3D -> Camera3D

# References
@onready var spring_arm: SpringArm3D = $CamOrigin/SpringArm3D

# Zoom variables
@export var Zoom_Desired: float = 10
@export var Zoom_Min: float = 0.5
@export var Zoom_Max: float = 100.0
@export var Zoom_Speed: float = 5.0
@export var Zoom_Interp: float = 5.0

# Location variables
var Location_Desired: Vector3
@export var Location_Speed: float = 0.3
@export var Location_Interp: float = 5.0
# Rotation variables
var Rotation_Desired: Vector3
var Angle_Rotation_Desired: Vector3
@export var Rotation_Speed: float = 5.0
@export var Rotation_Interp: float = 5.0

# Smoothing speed for camera interpolation
@export var smooth_speed = 7

# Vertical rotation clamping (prevents flipping the camera vertically)
var vertical_min = deg_to_rad(-80)  # Maximum downward rotation
var vertical_max = deg_to_rad(80)   # Maximum upward rotation

# Initialization
func _ready():

	
	# Initialize location and rotation to the current transform of the CharacterBody3D
	Location_Desired = transform.origin
	Rotation_Desired = rotation
	Angle_Rotation_Desired = spring_arm.rotation


# Function to calculate the shortest angle between two angles
func shortest_angle_between(current_angle: float, target_angle: float) -> float:
	var difference = target_angle - current_angle
	difference = wrapf(difference, -PI, PI)  # Keep angle between -π and π
	return current_angle + difference

# Main camera update function
func _physics_process(delta: float):
	# Handle zoom (SpringArm Length interpolation)
	update_zoom(delta)
	
	# Interpolate the actor's location
	update_location(delta)

	# Interpolate rotation using shortest path
	update_rotation(delta)

	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		return
	
	# Handle player movement
	handle_movement()

	# Handle zoom input
	handle_zoom_input()

	# Handle rotation input
	handle_rotation_input()

# Update the camera's zoom level
func update_zoom(delta: float):
	var current_length = spring_arm.spring_length
	var new_length = lerp(current_length, Zoom_Desired, clamp(delta * Zoom_Interp, 0, 1))
	spring_arm.spring_length = new_length

# Update the actor's position smoothly
func update_location(delta: float):
	global_transform.origin = global_transform.origin.lerp(Location_Desired, smooth_speed * delta)

# Update rotation of the camera smoothly using the shortest path
func update_rotation(delta: float):
	# Horizontal (Y) Rotation (affects the actor's body)
	var current_actor_y_rotation = rotation.y
	var new_actor_y_rotation = shortest_angle_between(current_actor_y_rotation, Rotation_Desired.y)
	rotation.y = lerp(current_actor_y_rotation, new_actor_y_rotation, clamp(delta * Rotation_Interp, 0, 1))

	# Vertical (X) Rotation (affects the spring arm's vertical tilt)
	var current_springarm_x_rotation = spring_arm.rotation.x
	var new_springarm_x_rotation = shortest_angle_between(current_springarm_x_rotation, Angle_Rotation_Desired.x)
	spring_arm.rotation.x = lerp(current_springarm_x_rotation, new_springarm_x_rotation, clamp(delta * Rotation_Interp, 0, 1))

	# Clamp vertical rotation to prevent camera flipping
	Angle_Rotation_Desired.x = clamp(Angle_Rotation_Desired.x, vertical_min, vertical_max)

	# Wrap horizontal rotation to keep it between -π and π
	Rotation_Desired.y = wrapf(Rotation_Desired.y, -PI, PI)

# Handle player movement input (forward/backward, left/right)
func handle_movement():
	# Forward/backward movement (Z-axis)
	var forward_input = Input.get_axis("back", "forward") * Location_Speed
	Location_Desired += transform.basis.z * -forward_input

	# Left/right movement (X-axis)
	var right_input = Input.get_axis("left", "right") * Location_Speed
	Location_Desired += transform.basis.x * right_input

# Handle zoom input (zoom in/out)
func handle_zoom_input():
	if Input.is_action_just_pressed("zoom_out"):
		var zoom_input: float = Zoom_Speed
		var zoom_clamp: float = Zoom_Desired + zoom_input
		Zoom_Desired = clamp(zoom_clamp, Zoom_Min, Zoom_Max)

	if Input.is_action_just_pressed("zoom_in"):
		var zoom_input = Zoom_Speed
		var zoom_clamp = Zoom_Desired - zoom_input
		Zoom_Desired = clamp(zoom_clamp, Zoom_Min, Zoom_Max)

# Handle camera rotation input (horizontal and vertical rotation)
func handle_rotation_input():
	# Handle horizontal rotation (left/right) for the character
	if Input.is_action_just_pressed("rotate_right"):
		Rotation_Desired.y += deg_to_rad(45)  # Rotate right by 45 degrees
	if Input.is_action_just_pressed("rotate_left"):
		Rotation_Desired.y -= deg_to_rad(45)  # Rotate left by 45 degrees

	# Handle vertical rotation (up/down) for the spring arm
	if Input.is_action_just_pressed("rotate_down"):
		Angle_Rotation_Desired.x -= deg_to_rad(20)  # Rotate spring arm down by 20 degrees
	if Input.is_action_just_pressed("rotate_up"):
		Angle_Rotation_Desired.x += deg_to_rad(20)  # Rotate spring arm up by 20 degrees
