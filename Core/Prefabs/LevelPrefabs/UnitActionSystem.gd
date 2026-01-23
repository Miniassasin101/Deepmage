## [b]Class:[/b] UnitActionSystem
## [i]Input + selection coordinator for unit actions and reactions.[/i]
##
## [b]Responsibilities[/b][br]
## • Tracks the currently [member selected_action] and the hovered/selected units.[br]
## • Routes mouse/keyboard input into “use action”, unit selection, and reaction prompting.[br]
## • Updates selection visuals on hover and manages top-bar previews.[br]
## • Exposes a [signal reaction_confirmed] for consumers (e.g. combat resolution).[br]
##
## [b]Design Notes[/b][br]
## • Singleton-like: first instance sets [member instance]; later instances self-remove in [method Node._ready].[br]
## • UI routing: in [method _unhandled_input], events are ignored if hovering most UI controls (see comments for details).[br]
## • Reaction flow: [method prompt_reaction] shows a defender-only action list; confirmation emits [signal reaction_confirmed].[br]
## • No gameplay logic is altered here—documentation only.

class_name UnitActionSystem
extends Node


## Emitted when a defender confirms a chosen Reaction (e.g., [code]"Block"[/code] or [code]"Evade"[/code]).
## Carries the confirmed [param reaction] ([Class Action]) for subscribers to handle.
signal reaction_confirmed(reaction: Action)


## Optional reference used for local testing or dev tools.
@export var test_unit: Unit

## Label hook used by legacy/testing utilities.
@export var label: Label

@export_category("Action References")
## Local counter used by legacy/testing code paths.
var d_count: int = 0


## The currently highlighted/armed action (normal or reaction). May be [code]null[/code] if none is selected.
var selected_action: Action = null

## The last unit seen under the mouse cursor; used to clear/update hover visuals when it changes.
var prev_hovered_unit: Unit = null

## Global toggle: when [code]false[/code], the system ignores player input (e.g., during cutscenes/animations).
var is_enabled: bool = false

## True while an action is actively executing; prevents accidental double-activation.
var is_busy: bool = false

## True while the UI is prompting the defender to pick a Reaction; non-reaction selections are ignored.
var is_prompting_reaction: bool = false

## Visual scale used for hover pulse effects on selectable units.
const action_hover_pulse_scale: float = 0.14

## Singleton-style static pointer to the active [Class UnitActionSystem] instance.
static var instance: UnitActionSystem = null


## [b]Engine callback:[/b] registers the singleton instance and binds to global signals.
## If another instance exists, logs an error and frees this node.
func _ready() -> void:
	if instance != null:
		push_error("There's more than one UnitActionSystem! - " + str(instance))
		queue_free()
		return
	instance = self
	
	signalbus_connection()


## Connects to global buses and controllers:
## • [code]SignalBus[/code] for action selection/start/end events[br]
## • [code]MouseController[/code] for unit hover changes
func signalbus_connection() -> void:
	SignalBus.on_selected_action_changed.connect(on_selected_action_changed)
	SignalBus.on_action_started.connect(on_action_started)
	SignalBus.on_action_ended.connect(on_action_ended)
	
	MouseController.instance.on_unit_hovered.connect(on_hovered_unit_changed)


## Per-frame callback: delegates to action-input processing.
func _process(_delta: float) -> void:
	#move_to_click()
	action_input_process()


## Global input handling. Early exits if disabled or when hovering most UI controls.[br]
## [b]Note:[/b] As written, if a [Class ScrollContainer] is hovered, input is [i]not[/i] blocked here.
## For other controls, input is ignored to avoid interacting through UI.
func _unhandled_input(event: InputEvent) -> void:
	var paused := _is_game_paused()

	# If not enabled AND not paused, ignore completely.
	# If paused, we allow selection-only.
	if !is_enabled and !paused:
		return

	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		if !hovered_control.is_class("ScrollContainer"):
			return

	# PAUSED: selection-only (no use_action, no right-click actions, no hotkeys)
	if paused:
		if event.is_action_pressed("left_mouse") or event.is_action_pressed("right_mouse"):
			try_handle_unit_selection(true)
		return

	# Normal gameplay
	if Input.is_action_just_pressed("left_mouse"):
		if !is_busy:
			on_left_mouse_clicked()
	if Input.is_action_just_pressed("right_mouse"):
		on_right_mouse_clicked()

	var num_pressed: int = get_pressed_num_shortcut(event)
	if num_pressed != -1:
		ActionSystemUI.instance.try_press_button_by_number(num_pressed)



## Returns the pressed numeric shortcut (1–9) or -1 if none matched.
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


## Reserved hook for additional per-frame input logic (kept empty by design).
func action_input_process() -> void:
	pass


## Handles left-click behavior: try unit-selection first; otherwise attempts to use the selected action.
func on_left_mouse_clicked() -> void:
	if _is_game_paused():
		try_handle_unit_selection(true)
		return

	if try_handle_unit_selection():
		return

	use_action(TurnSystem.instance.selected_unit, selected_action)



## Handles right-click behavior: attempts alternate unit selection (no auto-use).
func on_right_mouse_clicked() -> void:
	if try_handle_unit_selection(true):
		return


## Attempts to select the currently hovered unit. Optionally checks whether the current action
## can be activated on that unit (and triggers it) when [param do_action_check] is [code]false[/code].
##
## [b]Returns[/b] [code]true[/code] if a unit selection change occurred (or UI updated for the new unit).
func try_handle_unit_selection(do_action_check: bool = false) -> bool:
	var unit: Unit = MouseController.instance.get_current_hovered_unit()
	if !unit:
		return false
	
	# If an action requires a unit target and we're not just checking selection,
	# try to activate it directly on the hovered unit.
	if selected_action and selected_action.has_selection_type("unit") and !do_action_check:
		if check_can_activate_action_on_unit(unit):
			return false
	
	# Ignore if clicking the already-selected unit
	if unit == TurnSystem.instance.selected_unit:
		return false
	
	set_selected_unit(unit)
	
	var char_sheet_ui: UnitCharacterSheetUI = UnitCharacterSheetUI.instance
	if char_sheet_ui.is_open:
		char_sheet_ui._populate_from_unit(unit)
		
	return true


# --------------------------------------------------------------------------------------
# Selection Mechanics
# --------------------------------------------------------------------------------------






## Returns [code]true[/code] if the selected action can be used on [param in_unit]; uses it immediately if so.
func check_can_activate_action_on_unit(in_unit: Unit) -> bool:
	var a_container: ActionContainer = TurnSystem.instance.selected_unit.get_action_container()
	if a_container.can_use_action_at_target(selected_action, in_unit):
		use_action(a_container.unit, selected_action, in_unit)
		return true
	return false





## Primary handler for selected-action changes from the UI or hotkeys.
## • If a Reaction is selected while prompting, it’s handled immediately (button) or armed (targeted).[br]
## • For normal actions: selecting a new one arms it; pressing the same one again with "button" selection uses it.
func on_selected_action_changed(in_action: Action) -> void:
	if in_action == null:
		return

	var is_reaction: bool = in_action.is_action_type("reaction")
	var unit: Unit= TurnSystem.instance.selected_unit
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


## Uses [param action] from [param unit] on an optional [param target]. If the armed action
## is ground-targeted and no explicit target is given, uses the currently hovered world position.
func use_action(unit: Unit, action: Action, target: Variant = null) -> void:
	if unit == null or action == null:
		return
	
	# Ground targeting fallback to hovered world position
	if target == null and selected_action != null and selected_action.has_selection_type("ground"):
		var worldpos = MouseController.instance.get_current_hovered_position()
		if worldpos is Vector3:
			worldpos = worldpos.snappedf(0.01)
			target = worldpos
	
	unit.get_action_container().use_action(action, target)
	
	# Track non-reaction last-used actions on the unit for UX/history
	if !action.is_action_type("reaction"):
		unit.get_action_container().last_used_action = action


# --------------------------------------------------------------------------------------
# Reaction Flow
# --------------------------------------------------------------------------------------

## Opens the reaction prompt for [param reacting_unit]. Shows a defender-only action bar
## (no auto-select). Defers one frame to avoid racing with end-of-attack UI refreshes.
func prompt_reaction(reacting_unit: Unit) -> void:
	is_prompting_reaction = true
	Utilities.spawn_text_line(reacting_unit, "Defending")
	# Defer one frame so any “end of attack” UI refresh doesn’t race this
	await get_tree().process_frame
	ActionSystemUI.instance.make_action_buttons(reacting_unit, true, false)


## Confirms a reaction, emits [signal reaction_confirmed], and restores the attacker’s normal action bar.
func on_reaction_confirmed(reaction: Action) -> void:
	is_prompting_reaction = false
	reaction_confirmed.emit(reaction)
	# Restore attacker’s normal action bar without auto-selecting anything
	ActionSystemUI.instance.make_action_buttons(TurnSystem.instance.selected_unit, false, false)


# --------------------------------------------------------------------------------------
# Busy state (action execution guards)
# --------------------------------------------------------------------------------------

## Called when an action begins execution; sets [member is_busy] while it runs.
func on_action_started(_in_action: Action) -> void:
	if !(_in_action == selected_action):
		return 
	set_busy()
	pass


## Called when an action ends execution; clears [member is_busy].
func on_action_ended(_in_action: Action) -> void:
	if !(_in_action == selected_action):
		return 
	set_busy(false)
	pass


## Sets or clears the busy flag.
func set_busy(on_off: bool = true) -> void:
	is_busy = on_off


## Updates the armed [member selected_action] without side effects.
func set_selected_action(in_action: Action) -> void:
	selected_action = in_action


## Updates the globally selected unit via [code]TurnSystem[/code].
func set_selected_unit(in_selected_unit: Unit) -> void:
	TurnSystem.instance.set_selected_unit(in_selected_unit)
	show_unit_move_ranges(in_selected_unit)
	pass


func show_unit_move_ranges(in_unit: Unit) -> void:
	if in_unit == null:
		return
	var speed_val: float = float(in_unit.get_attributes_container().get_attribute_current_value("speed"))
	var budget: float = speed_val * 2.0
	PathfindingSystem.instance.show_move_range_for_unit(in_unit, budget)

func _is_game_paused() -> bool:
	return TurnSystem.instance != null and TurnSystem.instance.is_paused


## Primary hover handler. Manages hover/selection visuals and updates the top HP bar.
func on_hovered_unit_changed(in_unit: Unit) -> void:
	if !is_enabled and !_is_game_paused():
		return
	
	var selected_unit: Unit = get_selected_unit()

	# If the hovered unit changed, clear the previous one (unless it’s the selected unit)
	if in_unit != prev_hovered_unit:
		if prev_hovered_unit and prev_hovered_unit.selection_visual:
			if in_unit == selected_unit or prev_hovered_unit == selected_unit:
				selected_unit.selection_visual.set_blue()
			else:
				prev_hovered_unit.selection_visual.clear_material()
		
		setup_top_bar(in_unit)

	# If nothing is hovered, update state and bail early
	if in_unit == null:
		prev_hovered_unit = null
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
			if in_unit == selected_unit:
				#in_unit.selection_visual.set_blue()
				pass
			else:
				#in_unit.selection_visual.clear_material()
				pass

	# Track current hover
	prev_hovered_unit = in_unit


## Updates the top-of-screen HP bar preview from the hovered unit (if present).
func setup_top_bar(in_unit: Unit) -> void:
	var top_hp_bar: TopHPBar = ActionSystemUI.instance.top_hp_bar
	if !top_hp_bar:
		return
	
	top_hp_bar.setup_from_unit(in_unit)


## Utility: returns this unit’s [Class MoveToUnitAction], if any.
func get_move_to_unit_action(in_unit: Unit) -> MoveToUnitAction:
	var actions: Array[Action] = in_unit.get_action_container().get_all_actions()
	
	for action in actions:
		if action is MoveToUnitAction:
			return action
	
	return null


## Placeholder: returns whether the UI is currently showing a movement preview.
func check_if_movement_preview() -> bool:
	return false


## Convenience: returns [code]TurnSystem.instance.selected_unit[/code].
func get_selected_unit() -> Unit:
	return TurnSystem.instance.selected_unit
