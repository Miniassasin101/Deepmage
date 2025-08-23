class_name ActionSystemUI
extends Control


@export_category("References")

@export_group("UI References")
@export var turn_system_ui: TurnSystemUI
@export var initiative_queue_ui: InitiativeQueueUI
@export_group("")
@export var action_button_hbox: HBoxContainer
@export var action_button_prefab: PackedScene = null

var active_buttons: Array[ActionButtonUI] = []

static var instance: ActionSystemUI = null




func _ready() -> void:
	if instance != null:
		push_error("There's more than one ActionSystemUI! - " + str(instance))
		queue_free()
		return
	instance = self
	
	SignalBus.on_unit_selected.connect(on_unit_selected)



func on_unit_selected(unit: Unit) -> void:
	make_action_buttons(unit)


func make_action_buttons(unit: Unit, make_reactions: bool = false) -> void:
	for child in action_button_hbox.get_children():
		child.queue_free()
	
	active_buttons.clear()
	
	for action in unit.character_sheet.action_container.actions:
		if action.is_action_type("reaction"):
			if !make_reactions:
				continue
		elif make_reactions:
			continue
		var new_button: ActionButtonUI = action_button_prefab.instantiate() as ActionButtonUI
		
		new_button.set_base_action(action)
		new_button.set_action_system_ui(self)
		
		action_button_hbox.add_child(new_button)
		active_buttons.append(new_button)
	
	
	on_action_button_pressed(active_buttons[0].action)


func on_action_button_pressed(action: Action) -> void:
	SignalBus.on_selected_action_changed.emit(action)
	pass

func try_press_button_by_number(num: int) -> void:
	
	if active_buttons.get(num - 1):
		var btn := active_buttons[num - 1]
		on_action_button_pressed(btn.action)
		
		btn.grab_focus()
		
