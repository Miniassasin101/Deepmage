class_name UnitActionSystem
extends Node


@export var unit: Unit


@export var label: Label
var d_count: int = 0

#@export var diego_n_array: Array[String] = []

## Boolean to enable and disable to prevent the action system from registering input, possibly during animations and such.
var is_disabled: bool = false

var is_busy: bool = false


static var instance: UnitActionSystem = null



func _ready() -> void:
	if instance != null:
		push_error("There's more than one UnitActionSystem! - " + str(instance))
		queue_free()
		return
	instance = self



func _process(delta: float) -> void:
	#move_to_click()
	action_input_process()


func action_input_process() -> void:
	if is_disabled:
		return
	
	# If user is on ui, ignore.
	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		return
	
	if is_busy:
		return
	
	if Input.is_action_just_pressed("left_mouse"):
		on_left_mouse_clicked()
	


func on_left_mouse_clicked() -> void:
	move_to_click()
	#call_diego_the_n_word()


func set_selected_unit(in_selected_unit: Unit) -> void:
	pass






""" Call Diego the N word
func call_diego_the_n_word() -> void:
	if d_count >= 3:
		d_count = 0
	
	var curr_string: String = diego_n_array[d_count]
	label.set_text(curr_string)
	if d_count == 2:
		label.label_settings.font_color = Color.RED
	else:
		label.label_settings.font_color = Color.WHITE
	d_count += 1
"""

func move_to_click() -> void:
	if Input.is_action_just_pressed("left_mouse"):
		var target_position = MouseController.instance.get_mouse_raycast_result("position")
		if target_position and target_position is Vector3:
			#target_position.y = 0
			
			unit.set_movement_target(target_position)
		
			var final_pos: Vector3 = unit.nav_agent.get_final_position()
			var nav_data := unit.nav_agent.get_current_navigation_path()
			print_debug(nav_data)



func _physics_process(delta: float) -> void:
	# 1) On right‐click, set a new target for the nav agent
	if Input.is_action_just_pressed("right_mouse"):
		var pos = MouseController.instance.current_hovered_position
		if pos and pos is Vector3:
			#pos.y = 0
			unit.set_movement_target(pos)

	# 2) If the agent has an active path, pull the next point and move the unit
	var agent = unit.nav_agent
	if not agent.is_navigation_finished():
		# This call also advances the agent’s internal path index :contentReference[oaicite:0]{index=0}
		var next_point: Vector3 = agent.get_next_path_position()
		var current: Vector3 = unit.global_transform.origin
		
		var to_next: Vector3 = next_point - current

		if to_next.length() > 0.21:
			var dir: Vector3 = to_next.normalized()
			# translate the unit toward that point
			unit.global_translate(dir * unit.movement_speed * delta)

			# --- Rotation (yaw only) ---
			var target_yaw = atan2(dir.x, dir.z)
			var current_yaw = unit.rotation.y
			var new_yaw = lerp_angle(current_yaw, target_yaw, unit.rotation_speed * delta)
			unit.rotation.y = new_yaw
