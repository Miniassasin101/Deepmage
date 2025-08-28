class_name UnitActionSystem
extends Node


signal reaction_confirmed(reaction: Action)


@export var test_unit: Unit


@export var label: Label

@export_category("Action References")
var d_count: int = 0

#@export var diego_n_array: Array[String] = []

var selected_action: Action = null

var prev_hovered_unit: Unit = null


## Boolean to enable and disable to prevent the action system from registering input, possibly during animations and such.
var is_enabled: bool = false

var is_busy: bool = false

var is_prompting_reaction: bool = false


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

func _unhandled_input(event: InputEvent) -> void:
	if !is_enabled:
		return
	
	# If user is on ui, ignore.
	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		return
	
	

	
	if Input.is_action_just_pressed("left_mouse"):
		if !is_busy:
			on_left_mouse_clicked()
	if Input.is_action_just_pressed("right_mouse"):
		on_right_mouse_clicked()
	
	var num_pressed: int = get_pressed_num_shortcut(event)
	if num_pressed != -1:
		ActionSystemUI.instance.try_press_button_by_number(num_pressed)

func get_pressed_num_shortcut(event: InputEvent) -> int:
	if event.is_action("1_key"):
		return 1
	elif event.is_action("2_key"):
		return 2
	elif event.is_action("3_key"):
		return 3
	elif event.is_action("4_key"):
		return 4
	elif event.is_action("5_key"):
		return 5
	elif event.is_action("6_key"):
		return 6
	elif event.is_action("7_key"):
		return 7
	elif event.is_action("8_key"):
		return 8
	elif event.is_action("9_key"):
		return 9
	else:
		return -1




func action_input_process() -> void:

	pass


func on_left_mouse_clicked() -> void:
	#call_diego_the_n_word()
	
	if try_handle_unit_selection():
		return
	
	use_action(TurnSystem.instance.selected_unit, selected_action)

func on_right_mouse_clicked() -> void:
	if try_handle_unit_selection(true):
		return


func try_handle_unit_selection(do_action_check: bool = false) -> bool:
	

	
	var unit: Unit = MouseController.instance.get_current_hovered_unit()
	
	if !unit:
		return false
	
	if selected_action and selected_action.has_selection_type("unit") and !do_action_check:
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




func on_selected_action_changed_dep(in_action: Action) -> void:

	var is_reaction: bool = in_action.is_action_type("reaction")
	
	if !selected_action and !is_reaction:
		set_selected_action(in_action)
		return
	
	if selected_action != in_action and !is_reaction:
		set_selected_action(in_action)
		return
	
	var unit: Unit = TurnSystem.instance.selected_unit
	
	if !unit:
		return
	
	
	if is_busy and !is_reaction:
		return
	
	if in_action.has_selection_type("button"):
		if is_reaction:
			on_reaction_confirmed(in_action)
			return
		use_action(unit, in_action)

func on_selected_action_changed(in_action: Action) -> void:
	if in_action == null:
		return

	var is_reaction: bool = in_action.is_action_type("reaction")
	var unit := TurnSystem.instance.selected_unit
	if unit == null:
		return

	# 🔒 While reaction menu is up, ignore non-reaction selections entirely.
	if is_prompting_reaction and !is_reaction:
		return

	# --- Reaction branch ---
	if is_reaction:
		# If reaction uses "button" selection, pressing it confirms the reaction.
		if in_action.has_selection_type("button"):
			on_reaction_confirmed(in_action)
			return
		# Otherwise it's a targeted/ground reaction: just select it.
		selected_action = in_action
		return

	# --- Normal action branch ---
	# Change selection if new action was pressed.
	if selected_action == null or selected_action != in_action:
		
		selected_action = in_action
		return

	# Pressing the SAME normal action again with "button" selection uses it.
	if !is_busy and in_action.has_selection_type("button"):
		use_action(unit, in_action)



func use_action(unit: Unit, action: Action, target: Variant = null) -> void:
	if unit == null or action == null:
		return
	
	if target == null and selected_action != null and selected_action.has_selection_type("ground"):
		var worldpos = MouseController.instance.get_current_hovered_position()
		if worldpos is Vector3:
			worldpos = worldpos.snappedf(0.01)
			target = worldpos
	
	unit.get_action_container().use_action(action, target)
	
	
	if !action.is_action_type("reaction"):
		unit.get_action_container().last_used_action = action
	





func prompt_reaction(reacting_unit: Unit) -> void:
	is_prompting_reaction = true
	Utilities.spawn_text_line(reacting_unit, "Defending")
	# Defer one frame so any “end of attack” UI refresh doesn’t race this
	await get_tree().process_frame
	ActionSystemUI.instance.make_action_buttons(reacting_unit, true, false)



func on_reaction_confirmed(reaction: Action) -> void:
	is_prompting_reaction = false
	reaction_confirmed.emit(reaction)
	# Restore attacker’s normal action bar without auto-selecting anything
	ActionSystemUI.instance.make_action_buttons(TurnSystem.instance.selected_unit, false, false)


func on_action_started(_in_action: Action) -> void:
	if !(_in_action == selected_action):
		return 
	set_busy()
	pass


func on_action_ended(_in_action: Action) -> void:
	if !(_in_action == selected_action):
		return 
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
	if !is_enabled:
		return
	
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
	var can_use: bool = false
	
	
	
	if selected_unit and selected_unit.get_action_container() and selected_action:
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

func get_move_to_unit_action(in_unit: Unit) -> MoveToUnitAction:
	var actions: Array[Action] = in_unit.get_action_container().get_all_actions()
	
	for action in actions:
		if action is MoveToUnitAction:
			return action
	
	return null

func check_if_movement_preview() -> bool:
	return false


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
