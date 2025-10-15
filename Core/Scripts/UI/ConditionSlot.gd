class_name ConditionSlot
extends PanelContainer

signal condition_changed(slot_index: int, new_blueprint: ConditionBlueprint)
signal on_hovered_changed(is_slot_hovered: bool)
signal on_input_handled


@export var title_label: Label
@export var slot_index: int = 0
@export var accept_preferences: bool = true

var current_blueprint: ConditionBlueprint = null
var is_hovered: bool = false

func _ready() -> void:

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# We’ll poll only when dragging (cheap).
	set_process(true)

func _process(_delta: float) -> void:
	var viewport_obj: Viewport = get_viewport()
	if viewport_obj == null:
		return

	# During GUI drag, Godot might not emit enter/exit reliably.
	var dragging_now: bool = viewport_obj.gui_is_dragging()
	if dragging_now:
		var inside_now: bool = get_global_rect().has_point(viewport_obj.get_mouse_position())
		if inside_now != is_hovered:
			set_hovered(inside_now)

# ----------------------------
# Drag & drop (note: use "_" or engine wont call!)
# ----------------------------
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var dict: Dictionary = data as Dictionary
	if dict.is_empty():
		return false
	if not dict.has("dd_type") or String(dict["dd_type"]) != "condition_blueprint":
		return false
	var ok: bool = dict.has("blueprint") and (dict["blueprint"] as ConditionBlueprint) != null

	# When engine asks us repeatedly during a drag, mark hovered if valid.
	if ok and not is_hovered:
		set_hovered(true)
	return ok

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dict: Dictionary = data as Dictionary
	var dropped_bp: ConditionBlueprint = dict["blueprint"] as ConditionBlueprint
	if dropped_bp == null:
		return
	_set_blueprint(dropped_bp)
	# Clear hover right after a successful drop.
	if is_hovered:
		set_hovered(false)

# If a drag ends elsewhere, make sure hover is cleaned up.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if is_hovered:
			set_hovered(false)

# ----------------------------
# Slot content
# ----------------------------
func _set_blueprint(new_blueprint: ConditionBlueprint) -> void:
	current_blueprint = new_blueprint
	if title_label != null:
		title_label.text = new_blueprint.display_name
	on_condition_changed.call_deferred(new_blueprint)
	#on_condition_changed(new_blueprint)

func _clear_slot() -> void:
	current_blueprint = null
	if title_label != null:
		title_label.text = "Blank"
	on_condition_changed.call_deferred()


# NOTE: if not call deferred can lead to changing of values mid setup
func on_condition_changed(new_blueprint: ConditionBlueprint = null) -> void:
	condition_changed.emit(slot_index, new_blueprint)

# ----------------------------
# Context actions
# ----------------------------
func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return

	var is_right: bool = int(mb.button_index) == MOUSE_BUTTON_RIGHT
	var is_left: bool = int(mb.button_index) == MOUSE_BUTTON_LEFT
	var shift: bool = Input.is_key_pressed(KEY_SHIFT)
	var ctrl: bool = Input.is_key_pressed(KEY_CTRL)

	if is_right and shift:
		_clear_slot()
	elif is_left and shift and ctrl and current_blueprint != null:
		var parent_bar: TacticsSkillBar = _find_skill_bar()
		if parent_bar != null:
			parent_bar.duplicate_condition_below(slot_index)
	on_input_handled.emit()

# ----------------------------
# Hover plumbing
# ----------------------------
func set_hovered(in_is_hovered: bool) -> void:
	if is_hovered == in_is_hovered:
		return
	is_hovered = in_is_hovered
	on_hovered_changed.emit(is_hovered)

func _on_mouse_entered() -> void:
	set_hovered(true)

func _on_mouse_exited() -> void:
	set_hovered(false)

# ----------------------------
# Helpers
# ----------------------------
func _find_skill_bar() -> TacticsSkillBar:
	var walker: Node = self
	while walker != null:
		walker = walker.get_parent()
		var maybe: TacticsSkillBar = walker as TacticsSkillBar
		if maybe != null:
			return maybe
	return null
