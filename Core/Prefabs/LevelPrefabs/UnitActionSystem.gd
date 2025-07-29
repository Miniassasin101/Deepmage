class_name UnitActionSystem
extends Node


@export var test_unit: Unit


@export var label: Label
var d_count: int = 0

#@export var diego_n_array: Array[String] = []

var selected_action: Action = null



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
	
	signalbus_connection()


func signalbus_connection() -> void:
	SignalBus.on_selected_action_changed.connect(on_selected_action_changed)
	SignalBus.on_action_started.connect(on_action_started)
	SignalBus.on_action_ended.connect(on_action_ended)



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
	#move_to_click()
	#call_diego_the_n_word()
	
	if try_handle_unit_selection():
		return
	
	use_action(TurnSystem.instance.selected_unit, selected_action)
	
	


func try_handle_unit_selection() -> bool:
	
	var collider : Node = MouseController.instance.get_mouse_raycast_result("collider")
	if !collider:
		return false
	
	var unit: Unit = collider.get_parent() as Unit
	
	if !unit:
		return false
	
	if unit.turn_state != Unit.TurnState.TURN_STARTED:
		return false
	
	if unit == TurnSystem.instance.selected_unit:
		return false
	
	set_selected_unit(unit)
	
	return true

# Selection Mechanics


func on_selected_action_changed(in_action: Action) -> void:

	if !selected_action:
		set_selected_action(in_action)
		return
	
	if selected_action != in_action:
		set_selected_action(in_action)
		return
	
	var unit: Unit = TurnSystem.instance.selected_unit
	
	if !unit:
		return
	
	if is_busy:
		return
	
	use_action(unit, selected_action)




func use_action(unit: Unit, action: Action) -> void:
	if !unit:
		return
	unit.get_action_container().use_action(action)
	


func on_action_started(in_action: Action) -> void:
	set_busy()
	pass


func on_action_ended(in_action: Action) -> void:
	set_busy(false)
	pass


func set_busy(on_off: bool = true) -> void:
	is_busy = on_off



func set_selected_action(in_action: Action) -> void:
	selected_action = in_action





func set_selected_unit(in_selected_unit: Unit) -> void:
	TurnSystem.instance.set_selected_unit(in_selected_unit)
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
			
			test_unit.set_movement_target(target_position)
		
			var final_pos: Vector3 = test_unit.nav_agent.get_final_position()
			var nav_data := test_unit.nav_agent.get_current_navigation_path()
			print_debug(nav_data)
			


""" Physics process move to click
func _physics_process(delta: float) -> void:
	# 1) On right‐click, set a new target for the nav agent
	if Input.is_action_just_pressed("right_mouse"):
		var pos = MouseController.instance.current_hovered_position
		if pos and pos is Vector3:
			#pos.y = 0
			test_unit.set_movement_target(pos)

	# 2) If the agent has an active path, pull the next point and move the unit
	var agent = test_unit.nav_agent
	if not agent.is_navigation_finished():
		# This call also advances the agent’s internal path index :contentReference[oaicite:0]{index=0}
		var next_point: Vector3 = agent.get_next_path_position()
		var current: Vector3 = test_unit.global_transform.origin
		
		var to_next: Vector3 = next_point - current

		if to_next.length() > 0.21:
			var dir: Vector3 = to_next.normalized()
			# translate the unit toward that point
			test_unit.global_translate(dir * test_unit.movement_speed * delta)

			# --- Rotation (yaw only) ---
			var target_yaw = atan2(dir.x, dir.z)
			var current_yaw = test_unit.rotation.y
			var new_yaw = lerp_angle(current_yaw, target_yaw, test_unit.rotation_speed * delta)
			test_unit.rotation.y = new_yaw
"""
