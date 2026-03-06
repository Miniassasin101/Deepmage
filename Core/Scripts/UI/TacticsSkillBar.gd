## [b]Class:[/b] TacticsSkillBar
## [i]A single skill row in the Tactics UI. Displays the skill name, condition slots, hover/disabled visuals, and supports duplicate/remove actions and slot reordering.[/i]
##
## [b]Responsibilities[/b][br]
## • Hosts a row of [Class ConditionSlot]s inside [member conditions_rhbox] and keeps their order synced to the underlying [Class Skill].[br]
## • Handles mouse hover effects using tweened color transitions from the current stylebox.[br]
## • Supports right-click disable/enable, Shift+Right-Click remove, and Shift+Ctrl+Left-Click duplicate of the entire bar.[br]
## • Emits [signal TacticsSkillBar.on_tactics_skill_bar_update] when anything changes (order/disable/duplicate) so parent UI can re-prioritize.[br]
##
## [b]Notes[/b][br]
## • Logic is unchanged; documentation comments only.[br]
## • Conditions are treated as “blueprints”: external conditions first, then target preferences (split by [_is_preference_blueprint]).

class_name TacticsSkillBar
extends PanelContainer

## Emitted whenever this bar changes in a way that requires a parent refresh (e.g., order or disabled state changed).
signal on_tactics_skill_bar_update

@export_category("References")
## Label displaying this bar’s priority number (1..N) in the list.
@export var priority_number_label: Label
## Label displaying the skill’s display name.
@export var skill_name_label: Label
## Label displaying filled/empty diamonds equal to the skill’s point cost.
@export var points_label: Label
## Horizontal reorderable container holding child [Class ConditionSlot]s.
@export var conditions_rhbox: ReorderableHBox
@export_group("Styleboxes")
## Stylebox used when the skill is marked as Active.
@export var red_style_box: StyleBoxFlat
## Stylebox used when the skill is marked as Passive.
@export var blue_style_box: StyleBoxFlat
## Stylebox used when the skill is marked as Neutral/Other.
@export var gray_style_box: StyleBoxFlat

@export_category("Hover Settings")
## Duration (seconds) for hover-in color tween.
@export var hover_in_duration_seconds: float = 0.12
## Duration (seconds) for hover-out color tween.
@export var hover_out_duration_seconds: float = 0.18

@export_category("Disabled Visuals")
## If [code]true[/code], draw a strike-through line over the skill name when disabled.
@export var draw_strike_through: bool = true
## Pixel thickness for the strike-through line.
@export_range(1, 6) var strike_through_thickness_px: int = 2
## Horizontal insets (left/right) for the strike-through line.
@export var strike_through_inset_px: int = 4
## Vertical bias (pixels) to nudge the strike-through up/down over the text line.
@export var strike_through_vertical_bias_px: int = 0  # move line up/down if needed

## Node used to render the strike-through when disabled (created on demand).
var strike_through_rect: ColorRect = null

## True while any child slot wants the bar considered “hovered”.
var is_slot_hovered: bool = false

## Guard flag to prevent double-processing a click when a child already handled it.
var input_handled: bool = false

# Stylebox Variables
## Current stylebox applied to this panel (active/passive/neutral).
var current_stylebox: StyleBoxFlat = null

## Base colors derived from the current stylebox (“resting” look).
var base_bg_color: Color
var base_border_color: Color
## Hover target colors derived by boosting value (HSV) to 1.0.
var hover_bg_color: Color
var hover_border_color: Color

## Saved “normal” base/border colors for restoring after temporary disabled visuals.
var normal_bg_color: Color
var normal_border_color: Color

## Tween used for hover animations.
var hover_tween: Tween = null
## Set to [code]true[/code] after hover target colors have been derived from the stylebox.
var hover_targets_ready: bool = false


## Displayed priority number for this bar (1..10).
var priority_num: int = 0
## Maximum number of condition slots that this bar should expose (UI policy).
var max_conditions_count: int = 4

## The [Class Skill] represented by this bar.
var current_skill: Skill = null

## Not used directly in this file; kept for compatibility with callers using conditions arrays.
var current_conditions: Array[SkillCondition] = []

## Ordered list of condition blueprints currently present in the slots (external first, then preferences).
var current_condition_blueprints: Array[ConditionBlueprint] = []


# NOTE: Add the ability to enable and disable conditions and skills with shift + right click
# NOTE: Add the ability to duplicate conditions and skills with shift + right click
# NOTE: Add the ability to swap Tactics presets with shift + numkeys

## [b]Engine callback:[/b] wires signals, sets up styleboxes, forwards hover events from the slots container, and connects slot change events.
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


## Iterates all child [Class ConditionSlot]s, assigns their [member ConditionSlot.slot_index], and connects to their change signal.
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


## Reacts to per-slot blueprint changes by rebuilding local order and pushing it back to the [Class Skill].
func _on_slot_condition_changed(_slot_index: int, _new_blueprint: ConditionBlueprint) -> void:
	_rebuild_blueprint_order_from_slots()
	_apply_conditions_order_to_skill()


## Rebuilds [member current_condition_blueprints] by scanning each [Class ConditionSlot] in [member conditions_rhbox].
func _rebuild_blueprint_order_from_slots() -> void:
	current_condition_blueprints.clear()
	var slots_array: Array[Node] = conditions_rhbox.get_children()
	for node_item in slots_array:
		var slot: ConditionSlot = node_item as ConditionSlot
		if slot == null:
			continue
		if slot.current_blueprint != null:
			current_condition_blueprints.append(slot.current_blueprint)


## Duplicates the condition in [param slot_index] into the next slot (if any).
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


## Duplicates styleboxes so each bar can mutate its own visuals independently.
func make_styleboxes_unique() -> void:
	if red_style_box:
		red_style_box = red_style_box.duplicate()
	if blue_style_box:
		blue_style_box = blue_style_box.duplicate()
	if gray_style_box:
		gray_style_box = gray_style_box.duplicate()


## Connects mouse enter/exit signals on the bar itself to drive hover tweens.
func connect_mouse_hover_signals() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered_skillbar):
		mouse_entered.connect(_on_mouse_entered_skillbar)
	if not mouse_exited.is_connected(_on_mouse_exited_skillbar):
		mouse_exited.connect(_on_mouse_exited_skillbar)

#region Mouse Hover Logic

## Keeps hover active when moving across STOP-filtered child controls by re-sending the bar’s enter logic.
func _on_forwarder_gui_input(input_event: InputEvent) -> void:
	var mouse_event: InputEventMouse = input_event as InputEventMouse
	if mouse_event != null:
		# Guarantees the bar stays highlighted while moving within STOP-filtered widgets
		_on_mouse_entered_skillbar()


## Wires a child control to forward hover and click events to this bar’s handlers.
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


## Forwards hover from the conditions row (and optionally its children) back into this bar.
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


## Optional hook to forward hover for dynamically-added children of [member conditions_rhbox].
func _on_rhbox_child_entered_tree(entered_node: Node) -> void:
	var entered_control: Control = entered_node as Control
	if entered_control != null:
		_connect_hover_forwarding_for_control(entered_control)


## Derives hover target colors from a given stylebox (boosting value to 1.0, preserving H/S/A).
func _refresh_hover_targets_from(stylebox_source: StyleBoxFlat) -> void:
	if stylebox_source == null:
		return

	base_bg_color = stylebox_source.bg_color
	base_border_color = stylebox_source.border_color

	# Push Value (V in HSV) to max (1.0), preserve H, S, and A.
	hover_bg_color = Color.from_hsv(base_bg_color.h, base_bg_color.s, 1.0, base_bg_color.a)
	hover_border_color = Color.from_hsv(base_border_color.h, base_border_color.s, 1.0, base_border_color.a)

	hover_targets_ready = true


## Ensures [member current_stylebox] and hover targets are prepared before animating.
func _ensure_hover_targets_ready() -> void:
	if current_stylebox == null:
		# Try to pull whatever is currently overridden on "panel"
		var stylebox_from_theme: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
		current_stylebox = stylebox_from_theme
	if current_stylebox != null and not hover_targets_ready:
		_refresh_hover_targets_from(current_stylebox)


## Stops and clears any in-flight hover tween.
func _kill_hover_tween() -> void:
	if hover_tween != null and hover_tween.is_running():
		hover_tween.kill()
	hover_tween = null


## Hover-in animation for the bar, unless the skill is disabled.
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

## Hover-out animation for the bar, unless the skill is disabled.
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

#endregion


## Click handler for the whole bar. Shortcuts:[br]
## • Right-Click → toggle disabled.[br]
## • Shift + Right-Click → remove this bar from the tactic.[br]
## • Shift + Ctrl + Left-Click → duplicate this bar and append a copy.
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
		_duplicate_self()
		return
	
	if is_left_click and shift_down and not ctrl_down:
		open_skill_description()
		return

	if is_right_click and not shift_down and not ctrl_down:
		_toggle_disabled_state()
		return

func open_skill_description() -> void:
	var manager: TacticsManagerUI = _find_parent_manager()
	if !manager:
		return
	
	manager.skill_description_ui.load_data_from_skill(current_skill)



## Toggles [member Skill.is_disabled] and updates visuals, then notifies parent via [signal on_tactics_skill_bar_update].
func _toggle_disabled_state() -> void:
	if current_skill == null:
		return

	current_skill.is_disabled = not current_skill.is_disabled
	_apply_disabled_visuals(current_skill.is_disabled)
	on_tactics_skill_bar_update.emit()


## Applies disabled/enabled visuals (dimmed palette + optional strike-through when disabled; restores on enable).
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


## Duplicates this bar (deep-copying the underlying [Class Skill]) and appends it to the parent list.
func _duplicate_self() -> void:
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
	
	if !new_bar.get_parent_control():
		parent_vbox.add_child(new_bar)
	else:
		new_bar.reparent(parent_vbox)

	manager.reprioritize_skills()


## Removes this bar from the parent list and asks the manager to refresh priorities.
func _remove_self_from_tactic() -> void:
	var parent_vbox: ReorderableVBox = get_parent() as ReorderableVBox
	if parent_vbox == null:
		queue_free()
		return

	var manager: TacticsManagerUI = _find_parent_manager()
	queue_free()
	if manager != null:
		manager.reprioritize_skills()

## Walks up the tree to find the owning [Class TacticsManagerUI].
func _find_parent_manager() -> TacticsManagerUI:
	var walker: Node = self
	while walker != null:
		walker = walker.get_parent()
		var maybe_manager: TacticsManagerUI = walker as TacticsManagerUI
		if maybe_manager != null:
			return maybe_manager
	return null


## Populates this bar from a [param in_skill]: sets name, slots, and category visuals (active/passive).
func populate_from_skill(in_skill: Skill) -> void:
	if in_skill == null:
		return
	current_skill = in_skill
	set_skill_name(in_skill.skill_name)
	if points_label:
		points_label.set_text("◆".repeat(in_skill.skill_cost) + "◇".repeat(max(0, 3 - in_skill.skill_cost)))
	_set_slots_from_skill_blueprints(in_skill)
	if in_skill.skill_category == Skill.SkillCategory.ACTIVE:
		set_self_as_active()
	elif in_skill.skill_category == Skill.SkillCategory.PASSIVE:
		set_self_as_passive()
	_apply_disabled_visuals(in_skill.is_disabled)


## Fills the visible slots from the skill’s blueprints (external then preferences). Clears remaining slots.
func _set_slots_from_skill_blueprints(in_skill: Skill) -> void:
	var external_bps: Array[ConditionBlueprint] = in_skill.get_external_condition_blueprints()
	var preference_bps: Array[ConditionBlueprint] = in_skill.get_target_preference_blueprints()

	current_condition_blueprints.clear()
	current_condition_blueprints.append_array(external_bps)
	current_condition_blueprints.append_array(preference_bps)
	for c in current_condition_blueprints:
		if c == null:
			current_condition_blueprints.erase(c)
	
	if in_skill.skill_name == "Ball Throw":
		pass
	
	var slots_array: Array[Node] = conditions_rhbox.get_children()
	var fill_index: int = 0
	for i in range(slots_array.size()):
		var slot: ConditionSlot = slots_array[i] as ConditionSlot
		if slot == null:
			continue
		if fill_index < current_condition_blueprints.size() and !current_condition_blueprints.is_empty():
			slot._set_blueprint(current_condition_blueprints[fill_index]) # Note: FIXHERE
			fill_index += 1
			slot.on_input_handled.connect(set_input_handled)
		else:
			slot._clear_slot()
			slot.on_input_handled.connect(set_input_handled)


## Sets an internal flag so the bar’s click handler doesn’t re-handle clicks consumed by slots.
func set_is_slot_hovered(in_set: bool) -> void:
	is_slot_hovered = in_set

## Mark that input was handled by a slot so the bar-level handler can ignore the same press.
func set_input_handled() -> void:
	input_handled = true


## Triggered when the [member conditions_rhbox] is reordered. Rebuilds blueprint order and applies to skill.
func _on_conditions_reordered(_from_index: int, _to_index: int) -> void:
	_rebuild_blueprint_order_from_slots()
	_apply_conditions_order_to_skill()


## Splits [member current_condition_blueprints] into external vs. preference arrays and writes them back to the [Class Skill].
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

## Returns [code]true[/code] if [param bp] represents a target preference (based on its prototype type).
func _is_preference_blueprint(bp: ConditionBlueprint) -> bool:
	if bp == null or bp.prototype == null:
		return false
	return (bp.prototype as TargetPreference) != null


## Ensures the strike-through [Class ColorRect] exists and is connected to label resize for layout updates.
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


## Positions and sizes the strike-through line over the skill name label.
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


## Computes the strike-through color from the theme’s [code]font_color[/code] for [Class Label].
func _get_strike_color() -> Color:
	# Start from the theme font color; make it a bit more opaque/darker if you like.
	var base_font_color: Color = skill_name_label.get_theme_color("font_color", "Label")
	var out_color: Color = base_font_color
	out_color.a = 0.9
	return out_color


## Sets the display name shown on this bar.
func set_skill_name(in_name: String) -> void:
	if !skill_name_label:
		return
	skill_name_label.set_text(in_name)


## Sets and displays this bar’s priority number (1..10 expected by UI).
func set_priority_num(in_priority: int) -> void:
	if in_priority >= 0 and in_priority <= 10:
		priority_num = in_priority
		priority_number_label.set_text(str(priority_num))
		
	return

## Switches visuals to “Active” (red) and prepares hover colors.
func set_self_as_active() -> void:
	add_theme_stylebox_override("panel", red_style_box)
	current_stylebox = red_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color

## Switches visuals to “Passive” (blue) and prepares hover colors.
func set_self_as_passive() -> void:
	add_theme_stylebox_override("panel", blue_style_box)
	current_stylebox = blue_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color

## Switches visuals to “Neutral” (gray) and prepares hover colors.
func set_self_as_neutral() -> void:
	add_theme_stylebox_override("panel", gray_style_box)
	current_stylebox = gray_style_box
	_refresh_hover_targets_from(current_stylebox)
	normal_bg_color = base_bg_color
	normal_border_color = base_border_color


## Returns the [Class Skill] currently bound to this bar (may be [code]null[/code] before [method populate_from_skill]).
func get_current_skill() -> Skill:
	return current_skill
