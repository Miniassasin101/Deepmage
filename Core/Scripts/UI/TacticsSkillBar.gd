class_name TacticsSkillBar
extends PanelContainer

signal on_tactics_skill_bar_update

@export_category("References")
@export var priority_number_label: Label
@export var skill_name_label: Label
@export var conditions_rhbox: ReorderableHBox
@export_group("Styleboxes")
@export var red_style_box: StyleBoxFlat
@export var blue_style_box: StyleBoxFlat
@export var gray_style_box: StyleBoxFlat

@export_category("Hover Settings")
@export var hover_in_duration_seconds: float = 0.12
@export var hover_out_duration_seconds: float = 0.18

@export_category("Disabled Visuals")
@export var draw_strike_through: bool = true
@export_range(1, 6) var strike_through_thickness_px: int = 2
@export var strike_through_inset_px: int = 4
@export var strike_through_vertical_bias_px: int = 0  # move line up/down if needed

var strike_through_rect: ColorRect = null

var is_slot_hovered: bool = false

var input_handled: bool = false

# Stylebox Variables
var current_stylebox: StyleBoxFlat = null

var base_bg_color: Color
var base_border_color: Color
var hover_bg_color: Color
var hover_border_color: Color

var normal_bg_color: Color
var normal_border_color: Color


var hover_tween: Tween = null
var hover_targets_ready: bool = false




var priority_num: int = 0
var max_conditions_count: int = 4


var current_skill: Skill = null

var current_conditions: Array[SkillCondition] = []

var current_condition_blueprints: Array[ConditionBlueprint] = []


# NOTE: Add the ability to enable and disable conditions and skills with shift + right click
# NOTE: Add the ability to duplicate conditions and skills with shift + right click
# NOTE: Add the ability to swap Tactics presets with shift + numkeys

func _ready() -> void:
	# Keep the label order → skill arrays in sync when the user drags items.
	if conditions_rhbox and not conditions_rhbox.reordered.is_connected(_on_conditions_reordered):
		conditions_rhbox.reordered.connect(_on_conditions_reordered)
	
	make_styleboxes_unique()
	
	connect_mouse_hover_signals()
	
	_wire_rhbox_hover_forwarding()
	
	if not gui_input.is_connected(_on_gui_input_skillbar):
		gui_input.connect(_on_gui_input_skillbar)
	
	_connect_condition_slots()


func _connect_condition_slots() -> void:
	if conditions_rhbox == null:
		return
	var index_counter: int = 0
	for child_node in conditions_rhbox.get_children():
		var slot: ConditionSlot = child_node as ConditionSlot
		if slot == null:
			continue
		slot.slot_index = index_counter
		index_counter += 1
		if not slot.condition_changed.is_connected(_on_slot_condition_changed):
			slot.condition_changed.connect(_on_slot_condition_changed)


func _on_slot_condition_changed(_slot_index: int, _new_blueprint: ConditionBlueprint) -> void:
	_rebuild_blueprint_order_from_slots()
	_apply_conditions_order_to_skill()


func _rebuild_blueprint_order_from_slots() -> void:
	current_condition_blueprints.clear()
	var slots_array: Array[Node] = conditions_rhbox.get_children()
	for node_item in slots_array:
		var slot: ConditionSlot = node_item as ConditionSlot
		if slot == null:
			continue
		if slot.current_blueprint != null:
			current_condition_blueprints.append(slot.current_blueprint)


func duplicate_condition_below(slot_index: int) -> void:
	var slots_array: Array[Node] = conditions_rhbox.get_children()
	var next_index: int = slot_index + 1
	if next_index >= slots_array.size():
		return
	var src_slot: ConditionSlot = slots_array[slot_index] as ConditionSlot
	var dst_slot: ConditionSlot = slots_array[next_index] as ConditionSlot
	if src_slot == null or dst_slot == null or src_slot.current_blueprint == null:
		return
	# Reuse same blueprint reference (that’s what a blueprint is for).
	dst_slot._set_blueprint(src_slot.current_blueprint)
	if !dst_slot.on_input_handled.is_connected(set_input_handled):
		dst_slot.on_input_handled.connect(set_input_handled)



## Duplicates styleboxes so each bar has its own instance.
func make_styleboxes_unique() -> void:
	if red_style_box:
		red_style_box = red_style_box.duplicate()
	if blue_style_box:
		blue_style_box = blue_style_box.duplicate()
	if gray_style_box:
		gray_style_box = gray_style_box.duplicate()


func connect_mouse_hover_signals() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered_skillbar):
		mouse_entered.connect(_on_mouse_entered_skillbar)
	if not mouse_exited.is_connected(_on_mouse_exited_skillbar):
		mouse_exited.connect(_on_mouse_exited_skillbar)

#region Mouse Hover Logic


func _on_forwarder_gui_input(input_event: InputEvent) -> void:
	var mouse_event: InputEventMouse = input_event as InputEventMouse
	if mouse_event != null:
		# Guarantees the bar stays highlighted while moving within STOP-filtered widgets
		_on_mouse_entered_skillbar()



func _connect_hover_forwarding_for_control(forwarding_control: Control) -> void:
	# Make this control “pretend” it’s the bar for hover purposes
	if not forwarding_control.mouse_entered.is_connected(_on_mouse_entered_skillbar):
		forwarding_control.mouse_entered.connect(_on_mouse_entered_skillbar)

	if not forwarding_control.mouse_exited.is_connected(_on_mouse_exited_skillbar):
		forwarding_control.mouse_exited.connect(_on_mouse_exited_skillbar)

	# (Optional but helpful during drag/reorder) – keep highlight alive on mouse motion
	if not forwarding_control.gui_input.is_connected(_on_forwarder_gui_input):
		forwarding_control.gui_input.connect(_on_forwarder_gui_input)

	# Also forward click events to the bar’s click handler
	if not forwarding_control.gui_input.is_connected(_on_gui_input_skillbar):
		forwarding_control.gui_input.connect(_on_gui_input_skillbar)


func _wire_rhbox_hover_forwarding() -> void:
	if conditions_rhbox == null:
		return

	# You said this is required:
	conditions_rhbox.mouse_filter = Control.MOUSE_FILTER_STOP

	# Forward hover signals from the rhbox itself
	_connect_hover_forwarding_for_control(conditions_rhbox)

	# If children get added later (labels, icons, etc.), hook them as they enter the tree
	#if not conditions_rhbox.child_entered_tree.is_connected(_on_rhbox_child_entered_tree):
	#	conditions_rhbox.child_entered_tree.connect(_on_rhbox_child_entered_tree)

	# Also wire any existing children now
	#for potential_child in conditions_rhbox.get_children():
	#	var potential_child_control: Control = potential_child as Control
	#	if potential_child_control != null:
	#		_connect_hover_forwarding_for_control(potential_child_control)


func _on_rhbox_child_entered_tree(entered_node: Node) -> void:
	var entered_control: Control = entered_node as Control
	if entered_control != null:
		_connect_hover_forwarding_for_control(entered_control)



func _refresh_hover_targets_from(stylebox_source: StyleBoxFlat) -> void:
	if stylebox_source == null:
		return

	base_bg_color = stylebox_source.bg_color
	base_border_color = stylebox_source.border_color

	# Push Value (V in HSV) to max (1.0), preserve H, S, and A.
	hover_bg_color = Color.from_hsv(base_bg_color.h, base_bg_color.s, 1.0, base_bg_color.a)
	hover_border_color = Color.from_hsv(base_border_color.h, base_border_color.s, 1.0, base_border_color.a)

	hover_targets_ready = true


func _ensure_hover_targets_ready() -> void:
	if current_stylebox == null:
		# Try to pull whatever is currently overridden on "panel"
		var stylebox_from_theme := get_theme_stylebox("panel") as StyleBoxFlat
		current_stylebox = stylebox_from_theme
	if current_stylebox != null and not hover_targets_ready:
		_refresh_hover_targets_from(current_stylebox)


func _kill_hover_tween() -> void:
	if hover_tween != null and hover_tween.is_running():
		hover_tween.kill()
	hover_tween = null



func _on_mouse_entered_skillbar() -> void:
	if current_skill != null and current_skill.is_disabled:
		return
	_ensure_hover_targets_ready()
	if current_stylebox == null or not hover_targets_ready:
		return
	_kill_hover_tween()
	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(current_stylebox, "bg_color", hover_bg_color, hover_in_duration_seconds)
	hover_tween.parallel().tween_property(current_stylebox, "border_color", hover_border_color, hover_in_duration_seconds)

func _on_mouse_exited_skillbar() -> void:
	if current_skill != null and current_skill.is_disabled:
		return
	if current_stylebox == null or not hover_targets_ready:
		return
	_kill_hover_tween()
	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(current_stylebox, "bg_color", base_bg_color, hover_out_duration_seconds)
	hover_tween.parallel().tween_property(current_stylebox, "border_color", base_border_color, hover_out_duration_seconds)



func _on_gui_input_skillbar(input_event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = input_event as InputEventMouseButton
	if mouse_button == null:
		return
	if not mouse_button.pressed:
		return
	
	if input_handled:
		input_handled = false
		return

	var is_right_click: bool = int(mouse_button.button_index) == MOUSE_BUTTON_RIGHT
	var is_left_click: bool = int(mouse_button.button_index) == MOUSE_BUTTON_LEFT
	var shift_down: bool = Input.is_key_pressed(KEY_SHIFT)
	var ctrl_down: bool = Input.is_key_pressed(KEY_CTRL)

	if is_right_click and shift_down:
		_remove_self_from_tactic()
		return

	if is_left_click and shift_down and ctrl_down:
		_duplicate_self_below()
		return

	if is_right_click and not shift_down and not ctrl_down:
		_toggle_disabled_state()
		return


func _toggle_disabled_state() -> void:
	if current_skill == null:
		return

	current_skill.is_disabled = not current_skill.is_disabled
	_apply_disabled_visuals(current_skill.is_disabled)
	on_tactics_skill_bar_update.emit()


func _apply_disabled_visuals(is_now_disabled: bool) -> void:
	_kill_hover_tween()
	_ensure_hover_targets_ready()
	if current_stylebox == null:
		return

	if is_now_disabled:
		# Make disabled the *base* look
		var disabled_bg: Color = Color.from_hsv(base_bg_color.h, base_bg_color.s * 0.60, base_bg_color.v * 0.55, base_bg_color.a)
		var disabled_border: Color = Color.from_hsv(base_border_color.h, base_border_color.s * 0.60, base_border_color.v * 0.55, base_border_color.a)

		base_bg_color = disabled_bg
		base_border_color = disabled_border
		hover_bg_color = disabled_bg
		hover_border_color = disabled_border
		hover_targets_ready = true

		current_stylebox.bg_color = disabled_bg
		current_stylebox.border_color = disabled_border

		# Strike-through
		_ensure_strike_through_node()
		if strike_through_rect != null:
			_layout_strike_through()
			strike_through_rect.visible = true
	else:
		# Restore original “enabled” base and normal hover
		base_bg_color = normal_bg_color
		base_border_color = normal_border_color
		hover_bg_color = Color.from_hsv(base_bg_color.h, base_bg_color.s, 1.0, base_bg_color.a)
		hover_border_color = Color.from_hsv(base_border_color.h, base_border_color.s, 1.0, base_border_color.a)
		hover_targets_ready = true

		current_stylebox.bg_color = base_bg_color
		current_stylebox.border_color = base_border_color

		if strike_through_rect != null:
			strike_through_rect.visible = false

func _duplicate_self_below() -> void:
	if current_skill == null:
		return
	var parent_vbox: ReorderableVBox = get_parent() as ReorderableVBox
	if parent_vbox == null:
		return

	# Deep-copy the Skill resource (keeps current external conditions / preferences)
	var cloned_skill: Skill = current_skill.duplicate(true)

	var manager: TacticsManagerUI = _find_parent_manager()
	if manager == null:
		return

	var new_bar: TacticsSkillBar = manager._spawn_tactics_bar_for_skill(cloned_skill, parent_vbox)
	if new_bar == null:
		return
	
	new_bar.set_visible(false)
	
	if !new_bar.get_parent_control():
		parent_vbox.add_child(new_bar)
	else:
		new_bar.reparent(parent_vbox)

	# Move just below this one
	var my_index: int = parent_vbox.get_index()#get_child_index(self)
	parent_vbox.move_child(new_bar, my_index + 1)
	new_bar.set_visible(true)

	manager.reprioritize_skills(parent_vbox)

func _remove_self_from_tactic() -> void:
	var parent_vbox: ReorderableVBox = get_parent() as ReorderableVBox
	if parent_vbox == null:
		queue_free()
		return

	var manager: TacticsManagerUI = _find_parent_manager()
	queue_free()
	if manager != null:
		manager.reprioritize_skills(parent_vbox)

func _find_parent_manager() -> TacticsManagerUI:
	var walker: Node = self
	while walker != null:
		walker = walker.get_parent()
		var maybe_manager: TacticsManagerUI = walker as TacticsManagerUI
		if maybe_manager != null:
			return maybe_manager
	return null



#endregion





func populate_from_skill(in_skill: Skill) -> void:
	if in_skill == null:
		return
	current_skill = in_skill
	set_skill_name(in_skill.skill_name)
	_set_slots_from_skill_blueprints(in_skill)
	if in_skill.skill_category == Skill.SkillCategory.ACTIVE:
		set_self_as_active()
	elif in_skill.skill_category == Skill.SkillCategory.PASSIVE:
		set_self_as_passive()
	_apply_disabled_visuals(in_skill.is_disabled)


func _set_slots_from_skill_blueprints(in_skill: Skill) -> void:
	var external_bps: Array[ConditionBlueprint] = in_skill.get_external_condition_blueprints()
	var preference_bps: Array[ConditionBlueprint] = in_skill.get_target_preference_blueprints()

	current_condition_blueprints.clear()
	current_condition_blueprints.append_array(external_bps)
	current_condition_blueprints.append_array(preference_bps)

	var slots_array: Array[Node] = conditions_rhbox.get_children()
	var fill_index: int = 0
	for i in range(slots_array.size()):
		var slot: ConditionSlot = slots_array[i] as ConditionSlot
		if slot == null:
			continue
		if fill_index < current_condition_blueprints.size():
			slot._set_blueprint(current_condition_blueprints[fill_index])
			fill_index += 1
			slot.on_input_handled.connect(set_input_handled)
		else:
			slot._clear_slot()
			slot.on_input_handled.connect(set_input_handled)


func set_is_slot_hovered(in_set: bool) -> void:
	
	is_slot_hovered = in_set

func set_input_handled() -> void:
	input_handled = true


func _on_conditions_reordered(_from_index: int, _to_index: int) -> void:
	_rebuild_blueprint_order_from_slots()
	_apply_conditions_order_to_skill()


func _apply_conditions_order_to_skill() -> void:
	if current_skill == null:
		return

	var new_external_bps: Array[ConditionBlueprint] = []
	var new_preference_bps: Array[ConditionBlueprint] = []

	for bp in current_condition_blueprints:
		if bp == null:
			continue
		if _is_preference_blueprint(bp):
			new_preference_bps.append(bp)
		else:
			new_external_bps.append(bp)

	current_skill.external_condition_blueprints = new_external_bps
	current_skill.target_preference_blueprints = new_preference_bps
	
	on_tactics_skill_bar_update.emit()

func _is_preference_blueprint(bp: ConditionBlueprint) -> bool:
	if bp == null or bp.prototype == null:
		return false
	return (bp.prototype as TargetPreference) != null


func _ensure_strike_through_node() -> void:
	if not draw_strike_through:
		return
	if skill_name_label == null:
		return
	if strike_through_rect != null and is_instance_valid(strike_through_rect):
		return

	strike_through_rect = ColorRect.new()
	strike_through_rect.name = "StrikeThrough"
	strike_through_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike_through_rect.color = _get_strike_color()
	skill_name_label.add_child(strike_through_rect)

	# Keep it aligned if the label resizes
	if not skill_name_label.resized.is_connected(_layout_strike_through):
		skill_name_label.resized.connect(_layout_strike_through)

	_layout_strike_through()


func _layout_strike_through() -> void:
	if strike_through_rect == null or skill_name_label == null:
		return

	var thickness: float = float(strike_through_thickness_px)
	var inset: int = strike_through_inset_px
	var bias: int = strike_through_vertical_bias_px

	# Full width (minus insets), centered vertically over the text line
	strike_through_rect.anchor_left = 0.0
	strike_through_rect.anchor_right = 1.0
	strike_through_rect.anchor_top = 0.5
	strike_through_rect.anchor_bottom = 0.5

	strike_through_rect.offset_left = inset
	strike_through_rect.offset_right = -inset
	strike_through_rect.offset_top = -thickness / 2 + bias
	strike_through_rect.offset_bottom = thickness / 2 + bias


func _get_strike_color() -> Color:
	# Start from the theme font color; make it a bit more opaque/darker if you like.
	var base_font_color: Color = skill_name_label.get_theme_color("font_color", "Label")
	var out_color: Color = base_font_color
	out_color.a = 0.9
	return out_color





func set_skill_name(in_name: String) -> void:
	if !skill_name_label:
		return
	skill_name_label.set_text(in_name)


func set_priority_num(in_priority: int) -> void:
	if in_priority >= 0 and in_priority <= 10:
		priority_num = in_priority
		priority_number_label.set_text(str(priority_num))
		
	return

func set_self_as_active() -> void:
	add_theme_stylebox_override("panel", red_style_box)
	current_stylebox = red_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color

func set_self_as_passive() -> void:
	add_theme_stylebox_override("panel", blue_style_box)
	current_stylebox = blue_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color

func set_self_as_neutral() -> void:
	add_theme_stylebox_override("panel", gray_style_box)
	current_stylebox = gray_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color




func get_current_skill() -> Skill:
	return current_skill
