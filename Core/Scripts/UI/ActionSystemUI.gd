class_name ActionSystemUI
extends Control


@export_category("References")

@export_group("UI References")
@export var turn_system_ui: TurnSystemUI
@export var initiative_queue_ui: InitiativeQueueUI
@export_group("")
@export var action_button_hbox: HBoxContainer
@export var action_button_prefab: PackedScene = null


func _ready() -> void:
	SignalBus.on_unit_selected.connect(on_unit_selected)



func on_unit_selected(unit: Unit) -> void:
	make_action_buttons(unit)


func make_action_buttons(unit: Unit) -> void:
	for child in action_button_hbox.get_children():
		child.queue_free()
	
	for action in unit.character_sheet.action_container.actions:
		var new_button: ActionButtonUI = action_button_prefab.instantiate() as ActionButtonUI
		
		new_button.set_base_action(action)
		
		action_button_hbox.add_child(new_button)
		
