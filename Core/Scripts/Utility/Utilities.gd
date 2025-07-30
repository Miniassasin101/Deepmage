## Global Autoload Singleton
## Manages any utilities
extends Node








func make_target_package(in_target: Variant) -> TargetPackage:
	var new_pack: TargetPackage = TargetPackage.new()
	if new_pack.try_set_target(in_target):
		return new_pack
	
	return null


func set_color_on_cel_shaded_mesh(mesh: MeshInstance3D ,color: Color = Color.DEEP_SKY_BLUE, remove_overlay: bool = false) -> void:
	if remove_overlay:
		mesh.set_material_overlay(null)
		return
	var mesh_mat: ShaderMaterial = preload("res://Deepmage/Core/Art/Materials/GrayscaleCelShadedMat.tres").duplicate(true)
	var colarray: PackedColorArray = PackedColorArray([Color(000000), color])
	var new_grad: Gradient = mesh_mat.get("shader_parameter/texture_albedo").gradient
	new_grad.set_color(1, color)
	#mesh_mat.set_shader_parameter("texture_albedo/gradient/colors", colarray)
	#mesh_mat.set_albedo(color)
	mesh.set_material_overlay(mesh_mat)



# Text Utilities
func spawn_text_line(in_unit: Unit, text: String, color: Color = Color.SNOW, scale: float = 1.0, at_pos: Vector3 = Vector3.ZERO) -> void:
	if !in_unit:
		return
	var add_to_q: bool = false
	if at_pos == Vector3.ZERO:
		add_to_q = true
		at_pos = in_unit.get_world_position_above_marker()
	var camera: Camera3D = MouseController.instance.camera
	var screen_pos: Vector2 = camera.unproject_position(at_pos)

	# Instance the label
	var text_label_scene: PackedScene = UILayer.instance.text_controller_scene
	var text_label = text_label_scene.instantiate() as TextController
	
	# Add to CharacterLogQueue instead of UILayer directly
	if add_to_q:
		UILayer.instance.character_log_queue.add_message(text_label)
	else:
		UILayer.instance.add_child(text_label)

	# Position it in screen-space
	text_label.set_position(screen_pos)
	text_label.world_pos = at_pos
	text_label.set_scale(Vector2(scale, scale))
	text_label.set_text_color(color)

	# Initialize the label's text, color, etc.
	text_label.play(text)



func spawn_damage_label(in_unit: Unit, damage_val: float, color: Color = Color.CRIMSON, scale: float = 0.6) -> void:
	var chest_pos: Vector3 = in_unit.get_world_position_chest()
	var camera: Camera3D = MouseWorld.instance.camera
	# Assume 'camera' is a reference to your Camera3D node
	var screen_pos: Vector2 = camera.unproject_position(chest_pos)
	
	# Now instance the label
	var text_label_scene: PackedScene = UILayer.instance.text_controller_scene
	var text_label = text_label_scene.instantiate() as TextController
	UILayer.instance.add_child(text_label)
	# Position it in screen-space
	text_label.set_position(screen_pos)
	text_label.set_scale(Vector2(scale, scale))
	text_label.world_pos = chest_pos
	text_label.set_text_color(color)
	
	# Initialize the label's text, color, etc.
	text_label.play(str(int(damage_val)), "DamageNumberAnim")



# Call this function to change the game speed (e.g., slow down or speed up)
# new_time_scale: the desired time scale (e.g., 0.5 for half speed, 2.0 for double speed)
# duration: how long (in seconds, using real time) to keep that speed before reverting to 1.0
func slow_game(new_time_scale: float = 1.0, duration: float = 0.7) -> void:
	# Immediately set the time scale.
	Engine.set_time_scale(new_time_scale)
	if new_time_scale != 1.0:
		await get_tree().create_timer(duration, true, false, true).timeout
		Engine.set_time_scale(1.0)
