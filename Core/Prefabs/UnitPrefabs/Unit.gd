class_name Unit
extends Node3D


enum TurnState {
	OUTSIDE_COMBAT,
	IN_QUEUE,
	TURN_STARTED,
	TURN_ENDED
}


@export_category("References")
@export var above_head_marker: Marker3D
@export var nav_agent: NavigationAgent3D
@export var death_vfx_scene: PackedScene
@export var capsule_body: MeshInstance3D
@export var capsule_visor: MeshInstance3D


@export_category("Temp Stats")
@export var speed: int = 6



@export_category("Attributes")
@export var ui_name: String = "None"
@export var is_enemy: bool = false
@export var visor_color: Color = Color.ALICE_BLUE


@export_group("Movement Parameters")
@export var movement_speed: float = 2.0
@export var rotation_speed: float = 5.0    # radians per second
var movement_target_position: Vector3 = Vector3(-3.0,0.0,2.0)


@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 0.5


var turn_state: TurnState = TurnState.OUTSIDE_COMBAT





func _ready() -> void:
	setup_navigation()
	call_deferred("setup_mesh_colors")
	



func setup_mesh_colors() -> void:
	if is_enemy:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.FIREBRICK)
	else:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.SKY_BLUE)
	
	Utilities.set_color_on_cel_shaded_mesh(capsule_body, visor_color)







func setup_navigation() -> void:
	if !nav_agent:
		nav_agent = find_child("NavigationAgent3D")
	nav_agent.path_desired_distance = path_desired_distance
	nav_agent.target_desired_distance = target_desired_distance
	
	actor_setup.call_deferred()



func actor_setup():
	# Wait for the first physics frame so the NavigationServer can sync.
	await get_tree().physics_frame

	# Now that the navigation map is no longer empty, set the movement target.
	set_movement_target(movement_target_position)



func set_movement_target(movement_target: Vector3):
	nav_agent.set_target_position(movement_target)
	
	var nav_res := nav_agent.get_current_navigation_result()
	pass



func get_world_position_above_marker() -> Vector3:
	return above_head_marker.global_position if above_head_marker else Vector3.ZERO
