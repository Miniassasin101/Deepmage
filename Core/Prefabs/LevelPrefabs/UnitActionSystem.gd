class_name UnitActionSystem
extends Node


@export var test_unit: Unit


@export var label: Label
var d_count: int = 0

#@export var diego_n_array: Array[String] = []

var selected_action: Action = null

var prev_hovered_unit: Unit = null


## Boolean to enable and disable to prevent the action system from registering input, possibly during animations and such.
var is_disabled: bool = false

var is_busy: bool = false

const action_hover_pulse_scale: float = 0.14


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
	
	MouseController.instance.on_unit_hovered.connect(on_hovered_unit_changed)



func _process(_delta: float) -> void:
	#move_to_click()
	action_input_process()

func _unhandled_input(_event: InputEvent) -> void:
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

func action_input_process() -> void:

	pass


func on_left_mouse_clicked() -> void:
	#call_diego_the_n_word()
	
	if try_handle_unit_selection():
		return
	
	use_action(TurnSystem.instance.selected_unit, selected_action)
	
	


func try_handle_unit_selection() -> bool:
	

	
	var unit: Unit = MouseController.instance.get_current_hovered_unit()
	
	if !unit:
		return false
	
	if selected_action and selected_action.has_selection_type("unit"):
		if check_can_activate_action_on_unit(unit):
			return false
	
	if unit.turn_state != Unit.TurnState.TURN_STARTED:
		return false
	
	if unit == TurnSystem.instance.selected_unit:
		return false
	
	set_selected_unit(unit)
	
	return true


# Selection Mechanics

func check_can_activate_action_on_unit(in_unit: Unit) -> bool:
	var a_container: ActionContainer = TurnSystem.instance.selected_unit.get_action_container()
	if a_container.can_use_action_at_target(selected_action, in_unit):
		use_action(a_container.unit, selected_action, in_unit)
		return true
	return false




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
	
	if selected_action.has_selection_type("button"):
		use_action(unit, selected_action)




func use_action(unit: Unit, action: Action, target: Variant = null) -> void:
	if !unit:
		return
	
	if target == null and selected_action.has_selection_type("ground"):
		var worldpos = MouseController.instance.get_mouse_raycast_result("position")
		if worldpos is Vector3:
			worldpos = worldpos.snappedf(0.01)
			target = worldpos
	
	unit.get_action_container().use_action(action, target)
	




func on_action_started(_in_action: Action) -> void:
	set_busy()
	pass


func on_action_ended(_in_action: Action) -> void:
	set_busy(false)
	pass


func set_busy(on_off: bool = true) -> void:
	is_busy = on_off



func set_selected_action(in_action: Action) -> void:
	selected_action = in_action





func set_selected_unit(in_selected_unit: Unit) -> void:
	TurnSystem.instance.set_selected_unit(in_selected_unit)
	pass


func on_hovered_unit_changed_dep(in_unit: Unit) -> void:
	
	if !in_unit  or in_unit != prev_hovered_unit:
		if prev_hovered_unit and prev_hovered_unit != get_selected_unit():
			prev_hovered_unit.selection_visual.clear_material()
	
	var selected_unit: Unit = get_selected_unit()
	
	if selected_unit and selected_unit.get_action_container().can_use_action_at_target(selected_action, in_unit):
		if in_unit.is_enemy != get_selected_unit().is_enemy:
			in_unit.selection_visual.set_red()
			in_unit.selection_visual.pulse_square(action_hover_pulse_scale)
		else:
			in_unit.selection_visual.set_green()
			in_unit.selection_visual.pulse_square(action_hover_pulse_scale)
	
	if in_unit != prev_hovered_unit:
		prev_hovered_unit = in_unit


func on_hovered_unit_changed(in_unit: Unit) -> void:
	var selected_unit: Unit = get_selected_unit()

	# If the hovered unit changed, clear the previous one (unless it’s the selected unit)
	if in_unit != prev_hovered_unit:
		if prev_hovered_unit and prev_hovered_unit != selected_unit and prev_hovered_unit.selection_visual:
			prev_hovered_unit.selection_visual.clear_material()

	# If nothing is hovered, update state and bail early
	if in_unit == null:
		prev_hovered_unit = null
		return

	# Don’t override the selected unit’s own visuals
	if selected_unit and in_unit == selected_unit:
		prev_hovered_unit = in_unit
		return

	# Check action usability safely
	var can_use := false
	if selected_unit and selected_unit.get_action_container():
		can_use = selected_unit.get_action_container().can_use_action_at_target(selected_action, in_unit)

	# Apply visuals
	if in_unit.selection_visual:
		if can_use:
			# Enemy vs ally color
			if in_unit.is_enemy != selected_unit.is_enemy:
				in_unit.selection_visual.set_red()
			else:
				in_unit.selection_visual.set_green()
			in_unit.selection_visual.pulse_square(action_hover_pulse_scale)
		else:
			# Optional: neutral or clear to avoid stale highlights
			in_unit.selection_visual.clear_material()

	# Track current hover
	prev_hovered_unit = in_unit




func get_selected_unit() -> Unit:
	return TurnSystem.instance.selected_unit

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
