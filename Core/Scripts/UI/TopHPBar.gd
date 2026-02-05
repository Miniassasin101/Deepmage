class_name TopHPBar
extends Control

@export var enable_slide_preview: bool = false
@export_category("References")
@export var unit_name_label: Label
@export var health_bar: HealthProgressBar
@export var current_health_label: Label
@export var current_defense_label: Label
@export var header: PanelContainer
@export var slide: AttackPreviewSlideContainer


var current_unit: Unit = null

# --- Preview state tracking ---
var _slide_open: bool = false
var _hovered_unit: Unit = null
var _selected_action: Action = null

func _ready() -> void:
	SignalBus.update_stat_bars.connect(update)
	SignalBus.on_selected_action_changed.connect(_on_selected_action_changed)
	
	# Listen directly to the MouseController hover feed (same one UnitActionSystem uses)
	if MouseController.instance:
		MouseController.instance.on_unit_hovered.connect(_on_unit_hovered_changed)

	header.gui_input.connect(_on_header_gui_input)
	slide.gui_input.connect(_on_header_gui_input)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_slide()


# --- Slide helpers (don’t call slide.toggle() everywhere; keep state in sync here) ---n
func _toggle_slide() -> void:
	slide.toggle()
	_slide_open = !_slide_open

func _open_slide() -> void:
	if !_slide_open:
		slide.toggle()
		_slide_open = true

func _close_slide() -> void:
	if _slide_open:
		slide.toggle()
		_slide_open = false


# --- External updates ---
func _on_selected_action_changed(action: Action) -> void:
	_selected_action = action
	_refresh_preview()

func _on_unit_hovered_changed(in_unit: Unit) -> void:
	_hovered_unit = in_unit
	if in_unit:
		setup_from_unit(in_unit) # keep top bar stats fresh with hover
	_refresh_preview()


# --- Decides whether to show/hide/fill the preview slide ---
func _refresh_preview() -> void:
	# Must have an AttackAction selected
	if !enable_slide_preview or _selected_action == null or !(_selected_action is AttackAction):
		slide.clear()
		_close_slide()
		return

	var attacker := TurnSystem.instance.selected_unit
	var target := _hovered_unit

	# No target under cursor → clear/hide to avoid stale info
	if target == null:
		slide.clear()
		_close_slide()
		return

	# Don’t preview when hovering your own selected unit
	if attacker == target:
		slide.clear()
		_close_slide()
		return

	# Need a valid action container to verify usability
	if attacker == null or attacker.get_action_container() == null:
		slide.clear()
		_close_slide()
		return

	# Only preview if the attack can actually be used on this target
	if !attacker.get_action_container().can_use_action_at_target(_selected_action, target):
		slide.clear()
		_close_slide()
		return
	

	
	# All good: fill & open
	slide.fill_from_attack(_selected_action as AttackAction, attacker, target)
	_open_slide()



func update() -> void:
	if current_unit:
		setup_from_unit(current_unit)


func setup_from_unit(in_unit: Unit) -> void:
	if !in_unit:
		return
	current_unit = in_unit

	unit_name_label.text = in_unit.ui_name

	var health_attribute: Attribute = in_unit.get_attributes_container().get_attribute("posture")
	var current_modified_value: int = maxi(health_attribute.get_current_modified_value(), 0)
	current_health_label.text = "POS: %d" % [current_modified_value]

	var defence: int = in_unit.get_attributes_container().get_attribute_current_value("evade")
	current_defense_label.set_text(str(defence))

	var target_health_percentage: float = (float(current_modified_value) / float(health_attribute.get_max_value()) * 100.0)
	health_bar.animate_to_percent(target_health_percentage)

	#health_bar.set_to_percent(target_health_percentage)
