class_name TopHPBar
extends Control

@export var header: PanelContainer
@export var slide: AttackPreviewSlideContainer

@export_category("References")
@export var unit_name_label: Label
@export var health_bar: SimpleAnimatableProgressBar
@export var current_health_label: Label
@export var current_defense_label: Label


var current_unit: Unit = null


func _ready() -> void:
	SignalBus.update_stat_bars.connect(update)
	
	header.gui_input.connect(_on_header_gui_input)
	slide.gui_input.connect(_on_header_gui_input)
	pass

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slide.toggle()


func update() -> void:
	if current_unit:
		setup_from_unit(current_unit)


func setup_from_unit(in_unit: Unit) -> void:
	if !in_unit:
		return
	current_unit = in_unit
	
	
	unit_name_label.text = current_unit.ui_name

	var health_attribute: Attribute = current_unit.get_attributes_container().get_attribute("health")
	var current_modified_value: int = health_attribute.get_current_modified_value()
	current_health_label.text = "HP: %d" % [
		current_modified_value
	]
	
	var defence: int = current_unit.get_attributes_container().get_defence()
	current_defense_label.set_text(str(defence))
	
	
	
	# Animate the health bar value.
	var target_health_percentage: float = (float(current_modified_value) / float(health_attribute.maximum_value) * 100)
	
	health_bar.animate_to_percent(target_health_percentage)
