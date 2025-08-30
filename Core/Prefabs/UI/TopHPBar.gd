class_name TopHPBar
extends Control

@export var header: PanelContainer
@export var slide: SlideDown

func _ready() -> void:
	header.gui_input.connect(_on_header_gui_input)
	slide.gui_input.connect(_on_header_gui_input)
	pass

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slide.toggle()
