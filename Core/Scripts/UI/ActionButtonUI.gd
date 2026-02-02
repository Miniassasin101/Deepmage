class_name ActionButtonUI
extends Button





@export var button_text: Label
@export var button: Button
@export var panel: Panel

@export var button_up_style_box: StyleBoxFlat
@export var button_down_style_box: StyleBoxFlat

var action_system_ui: ActionSystemUI = null
var action: Action
var is_gait: bool = false
var gait: int = 0



enum SpecialCase {
	NONE,
	GAIT,
	NO_AP,
	REACTION,
	SPECIAL_EFFECT
}

var special_case: int = SpecialCase.NONE


func _ready() -> void:
	pass # Replace with function body.


func set_action_system_ui(asui: ActionSystemUI) -> void:
	action_system_ui = asui


func set_base_action(_action: Action) -> void:
	set_button_text(_action.action_name)
	action = _action

func set_button_text(in_text: String = "") -> void:
	button_text.set_text(in_text)


## This function is to set up an extra action button when a unit has no AP.
## This allows them to still take a move action and/or change gait even if they run out of ap in the first round or two.
func set_no_ap() -> void:
	special_case = SpecialCase.NO_AP
	button_text.set_text("Next Phase")

func toggle_button_selected(is_selected: bool) -> void:
	if is_selected:
		panel.set("theme_override_styles/panel", button_up_style_box)
		return
	panel.set("theme_override_styles/panel", button_down_style_box)
	

func _pressed() -> void:
	handle_special_case()
	grab_focus()



func handle_special_case() -> void:
	match special_case:

		SpecialCase.NONE:
			#SignalBus.selected_move_changed.emit(move)
			#EventBus.selected_action_changed.emit(action)
			if action_system_ui and action:
				action_system_ui.on_action_button_pressed(action)
			pass
		
		SpecialCase.GAIT:
			SignalBus.gait_selected.emit(gait)
		
		SpecialCase.NO_AP:
			SignalBus.next_phase.emit()
		
		SpecialCase.REACTION:
			#SignalBus.selected_move_changed.emit(move)
			pass


func _on_gui_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("right_mouse"):
		on_right_mouse_clicked()

func on_right_mouse_clicked() -> void:
	if !is_hovered():
		return
	if !action:
		return
	if action.is_action_type("attack"):
		# Make action/move preview
		pass
	

func _on_mouse_exited() -> void:
	pass # Replace with function body.
