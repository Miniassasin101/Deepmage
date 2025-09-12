@tool
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
@export var selection_visual: SelectionSquareVisual
@export var character_sheet: CharacterSheet
@export var movement_controller: MovementController
@export var animation_controller: AnimationController

@export_category("Prefabs")
@export var character_sheet_packed_scene: PackedScene = null

@export_category("Temp Stats")
@export var speed: int = 6



@export_category("Attributes")

@export var ui_name: String = "Unit":
	set(val):
		ui_name = val
		change_node_name_to_unit()

@export var is_enemy: bool = false
@export var visor_color: Color = Color.ALICE_BLUE

@export_category("Visual Modifiers")
@export var white_hit_flash_mat: StandardMaterial3D
@export var hit_flash_time: float = 0.3

#@export_group("Movement Parameters")
#@export var movement_speed: float = 2.0
#@export var rotation_speed: float = 5.0    # radians per second
#var movement_target_position: Vector3 = Vector3(-3.0,0.0,2.0)
#
#
#@export var path_desired_distance: float = 0.5
#@export var target_desired_distance: float = 0.5


var turn_state: TurnState = TurnState.OUTSIDE_COMBAT





func _ready() -> void:
	if Engine.is_editor_hint():
		if !character_sheet_packed_scene:
			print("Packed Scene Not Found")
			return
		if find_child("CharacterSheet", false):
			print("Character sheet found")
			return
		var char_sheet: CharacterSheet = character_sheet_packed_scene.instantiate() as CharacterSheet

		add_child(char_sheet)
		char_sheet.set_owner(get_tree().edited_scene_root)
		character_sheet = char_sheet
		print("added child")
		property_list_changed.connect(change_node_name_to_unit)
		return
	setup_navigation()
	call_deferred("setup_mesh_colors")
	
func change_node_name_to_unit() -> void:
	if !Engine.is_editor_hint():
		return
	if (ui_name != "Unit") and (get_name() != ui_name):
		if ui_name.is_empty():
			set_name("Unit")
		else:
			set_name(ui_name)
		print("name changed to " + name)


func setup_mesh_colors() -> void:
	if is_enemy:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.FIREBRICK)
	else:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.SKY_BLUE)
	
	Utilities.set_color_on_cel_shaded_mesh(capsule_body, visor_color)


func setup_navigation() -> void:
	if !nav_agent:
		nav_agent = find_child("NavigationAgent3D")


func set_movement_target(movement_target: Vector3):
	nav_agent.set_target_position(movement_target)
	

func flash_white(flash_time: float = hit_flash_time) -> void:
	var unit_meshes: Array[MeshInstance3D] = get_all_unit_meshes()
	var saved_mat_overrides: Array[StandardMaterial3D] = []
	for mesh in unit_meshes:
		saved_mat_overrides.append(mesh.get_material_override())
		mesh.set_material_override(white_hit_flash_mat)

	await get_tree().create_timer(flash_time).timeout

	for mesh in unit_meshes:
		mesh.set_material_override(saved_mat_overrides.pop_front())



func get_all_unit_meshes() -> Array[MeshInstance3D]:
	return [capsule_body, capsule_visor]


func get_world_position_above_marker() -> Vector3:
	return above_head_marker.global_position if above_head_marker else Vector3.ZERO

func get_action_container() -> ActionContainer:
	return character_sheet.action_container


func get_attributes_container() -> AttributesContainer:
	return character_sheet.get_attributes_container()
