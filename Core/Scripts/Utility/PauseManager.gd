class_name PauseManager
extends Node

signal pause_changed(is_paused: bool)

static var instance: PauseManager = null

@export var pause_menu: Control

var is_paused: bool = false
var _restore_unit_action_enabled: bool = false

func _ready() -> void:
	if instance != null:
		queue_free()
		return
	instance = self

	process_mode = Node.PROCESS_MODE_ALWAYS

	if pause_menu:
		pause_menu.visible = false
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("space_key"):
		toggle_pause()

func toggle_pause() -> void:
	set_paused(!is_paused)

func set_paused(val: bool) -> void:
	if is_paused == val:
		return

	# save/restore world-input state
	if UnitActionSystem.instance:
		if !is_paused:
			_restore_unit_action_enabled = UnitActionSystem.instance.is_enabled

	is_paused = val

	# hard pause gameplay
	get_tree().paused = is_paused

	# show menu
	if pause_menu:
		pause_menu.visible = is_paused
	
	ActionSystemUI.instance.paused_label.visible = is_paused

	# gate “world” input while paused (UI still works)
	if UnitActionSystem.instance:
		if is_paused:
			UnitActionSystem.instance.is_enabled = false
		else:
			UnitActionSystem.instance.is_enabled = _restore_unit_action_enabled

	# keep your own flag too (handy for “if paused:” checks)
	if TurnSystem.instance:
		TurnSystem.instance.is_paused = is_paused

	pause_changed.emit(is_paused)
