class_name CombatLog
extends Control

@export var label_preset: LabelSettings

@export var button: ActionButtonUI

@export var slide_panel_container: SlidePanelContainer

@export var log_container: VBoxContainer

@export var max_logs: int = 8

var is_open: bool = false

var logs: Array[Label] = []


static var instance: CombatLog = null




func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatLog! - " + str(instance))
		queue_free()
		return
	instance = self
	
	setup_combat_log()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("l_key"):
		toggle_log()

func setup_combat_log() -> void:
	clear_log()
	
	button.set_button_text("LOG")
	
	button.toggle_button_selected(true)
	
	button.gui_input.connect(on_button_pressed)

func add_log(new_log: String = "", to_godot: bool = false) -> void:
	var new_label: Label = Label.new()
	new_label.label_settings = label_preset
	new_label.set_text(new_log)
	log_container.add_child(new_label)
	
	logs.append(new_label)
	
	# Also print to console
	if to_godot:
		print_debug(new_log)
	
	if logs.size() <= max_logs:
		return
	
	clear_log(true)


func on_button_pressed(input_event: InputEvent) -> void:
	if input_event.is_action_pressed("right_mouse"):
		if Input.is_action_pressed("left_shift"):
			clear_log(true)
		else:
			clear_log()
	
	if !input_event.is_action_pressed("left_mouse"):
		return
	
	


func toggle_log() -> void:
	if is_open:
		close()
		is_open = false
		return
	open()
	is_open = true


func open() -> void:
	button.toggle_button_selected(false)
	slide_panel_container.open()
	pass

func close() -> void:
	button.toggle_button_selected(true)
	slide_panel_container.close()
	pass


func clear_log(clear_one: bool = false) -> void:

		
	if clear_one:
		if logs.is_empty():
			return
		var log_to_remove: Label = logs.pop_front() as Label
		log_to_remove.queue_free()
		return
	
	
	for child in log_container.get_children():
		child.queue_free()
	
	logs = []
