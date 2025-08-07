extends Node3D
class_name SelectionSquareVisual

@export var blue_square_mat: StandardMaterial3D
@export var red_square_mat: StandardMaterial3D
@export var green_square_mat: StandardMaterial3D
@export var selection_square_meshinstance: MeshInstance3D

@export var pulse_scale: float = 1.1

var pulse_tween: Tween = null

# Sets the override material of the mesh instance to the given material (or clears if null)
func set_material(mat: StandardMaterial3D) -> void:
	if not selection_square_meshinstance:
		push_error("SelectionSquareVisual: MeshInstance3D is not assigned.")
		return
	selection_square_meshinstance.set_surface_override_material(0, mat)

# Convenience methods for each color
func set_blue() -> void:
	set_material(blue_square_mat)

func set_red() -> void:
	set_material(red_square_mat)

func set_green() -> void:
	set_material(green_square_mat)

# Clear any override material
func clear_material() -> void:
	set_material(null)

# Visibility controls
# Shows the selection square mesh
func show_square() -> void:
	if not selection_square_meshinstance:
		push_error("SelectionSquareVisual: MeshInstance3D is not assigned.")
		return
	selection_square_meshinstance.visible = true

# Hides the selection square mesh
func hide_square() -> void:
	if not selection_square_meshinstance:
		push_error("SelectionSquareVisual: MeshInstance3D is not assigned.")
		return
	selection_square_meshinstance.visible = false

# Sets visibility to the given state
func set_visibility(visible: bool) -> void:
	if not selection_square_meshinstance:
		push_error("SelectionSquareVisual: MeshInstance3D is not assigned.")
		return
	selection_square_meshinstance.visible = visible

# Toggles the current visibility state
func toggle_visibility() -> void:
	if not selection_square_meshinstance:
		push_error("SelectionSquareVisual: MeshInstance3D is not assigned.")
		return
	selection_square_meshinstance.visible = not selection_square_meshinstance.visible


func pulse_square(in_pulse_scale: float = pulse_scale) -> void:
	
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.tween_property(selection_square_meshinstance, "scale", Vector3(in_pulse_scale, in_pulse_scale, in_pulse_scale), 0.2)
	pulse_tween.tween_property(selection_square_meshinstance, "scale", Vector3(1.0, 1.0, 1.0), 0.2)
	
	
