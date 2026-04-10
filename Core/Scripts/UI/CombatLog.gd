class_name CombatLog
extends Control

signal logs_added

@export var label_preset: LabelSettings
@export var button: ActionButtonUI
@export var slide_panel_container: SlidePanelContainer
@export var log_container: VBoxContainer
@export var max_logs: int = 8
@export var scroll_container: ScrollContainer
@export var change_amount: int = 250

# --- Presets for test_num (1..9) ---
@export var test_num_presets: Array[float] = [
	-300.0, -240.0, -180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 240.0
]

@export_range(-300, 240, 20) var test_num: float = 160

const initial_y_pos: float = 421

var is_open: bool = false

# Active labels (oldest at index 0)
var logs: Array[Label] = []

# Queues
var logs_to_add: Array[Label] = []
var logs_to_clear: Array[Label] = []

var are_logs_queued_to_add: bool = false
var are_logs_queued_to_clear: bool = false

var shrunk: bool = false


static var instance: CombatLog = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatLog! - " + str(instance))
		queue_free()
		return
	instance = self
	setup_combat_log()


func _unhandled_input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed("l_key"):
		toggle_log()


func setup_combat_log() -> void:
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.set_button_text("LOG")
	button.toggle_button_selected(true)
	button.gui_input.connect(on_button_pressed)

	# Hard clear (no scheduling)
	for existing_child in log_container.get_children():
		existing_child.queue_free()
	logs.clear()
	logs_to_add.clear()
	logs_to_clear.clear()
	slide_panel_container.update_minimum_size()


# ---------- Public API ----------

func add_log(new_log_text: String = "", also_print_to_godot: bool = false) -> void:
	var label_node := Label.new()
	label_node.label_settings = label_preset
	label_node.text = new_log_text
	label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_node.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

	# Track and enqueue
	logs.append(label_node)
	logs_to_add.append(label_node)

	# Schedule drain once
	if not are_logs_queued_to_add:
		are_logs_queued_to_add = true
		add_queued_logs.call_deferred()

	if also_print_to_godot:
		print_debug(new_log_text)


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


func close() -> void:
	button.toggle_button_selected(true)
	slide_panel_container.close()



func clear_log(clear_one_only: bool = false) -> void:
	# Ensure pending adds have landed so we only remove from the scene
	if are_logs_queued_to_add:
		await logs_added

	if clear_one_only:
		if logs.is_empty():
			return
		logs_to_clear.append(logs.front())
	else:
		for child_node in log_container.get_children():
			if child_node is Label:
				logs_to_clear.append(child_node)

	if not logs_to_clear.is_empty() and not are_logs_queued_to_clear:
		are_logs_queued_to_clear = true
		remove_queued_logs.call_deferred()


# ---------- Queue Drainers (with hard cap enforced BEFORE add) ----------

# After finishing adds:
func add_queued_logs() -> void:
	while not logs_to_add.is_empty():
		var incoming_batch: Array[Label] = logs_to_add.duplicate()
		logs_to_add.clear()

		var current_count: int = _get_current_label_count()
		var overflow_count: int = (current_count + incoming_batch.size()) - max_logs
		if overflow_count > 0:
			_remove_oldest_immediate(overflow_count)

		for label_node in incoming_batch:
			log_container.add_child(label_node)

	# Finished adding
	are_logs_queued_to_add = false
	log_container.update_minimum_size()
	slide_panel_container.shrink_to_contents()
	slide_panel_container.update_minimum_size()
	logs_added.emit()
	await get_tree().process_frame
	scroll_container.ensure_control_visible(logs.back())


# After finishing removes:
func remove_queued_logs() -> void:
	if logs_to_clear.is_empty():
		are_logs_queued_to_clear = false
		return

	var removal_batch: Array[Label] = logs_to_clear.duplicate()
	logs_to_clear.clear()

	for label_node in removal_batch:
		if not label_node or label_node.is_queued_for_deletion():
			continue
		if label_node.get_parent() == log_container:
			log_container.remove_child(label_node)
		if label_node in logs:
			logs.erase(label_node)
		label_node.queue_free()

	are_logs_queued_to_clear = false
	
	await get_tree().process_frame
	
	_apply_test_num_to_panel.call_deferred()



# ---------- Helpers ----------

func _get_current_label_count() -> int:
	var count_total := 0
	for child_node in log_container.get_children():
		if child_node is Label:
			count_total += 1
	return count_total


func _remove_oldest_immediate(remove_count: int) -> void:
	var remaining_to_remove := remove_count
	while remaining_to_remove > 0 and not logs.is_empty():
		var oldest_label: Label = logs.front()
		# Only remove if it exists (it should, since we only trim scene labels here)
		if is_instance_valid(oldest_label):
			if oldest_label.get_parent() == log_container:
				log_container.remove_child(oldest_label)
			oldest_label.queue_free()
		logs.pop_front()
		remaining_to_remove -= 1


# ---------- Input from the LOG button ----------



func on_button_pressed(input_event: InputEvent) -> void:
	# Left click + number preset?
	if input_event.is_action_pressed("left_mouse"):
		if _handle_number_preset_click(input_event):
			return
		else:
			toggle_log()
		# (left click without a digit → no-op here)

	# Right click actions (your existing logic)
	if input_event.is_action_pressed("right_mouse"):
		if Input.is_action_pressed("left_shift"):
			if Input.is_action_pressed("space_key"):
				if !shrunk:
					slide_panel_container.size.y = get_combined_minimum_size().y + 100
					slide_panel_container.position.y = 421
					shrunk = true
				else:
					slide_panel_container.size.y = get_combined_minimum_size().y + 500 + test_num
					slide_panel_container.position.y = slide_panel_container.position.y - change_amount - (float(test_num) / 2.0)
					shrunk = false
				return
			clear_log(true)   # remove oldest only
		else:
			clear_log()       # remove all




# Returns true if it handled a left-click + digit preset
func _handle_number_preset_click(input_event: InputEvent) -> bool:
	# Only when LEFT mouse is pressed on the button
	if not input_event.is_action_pressed("left_mouse"):
		return false

	var pressed_digit := _get_pressed_digit_1_to_9()
	if pressed_digit == 0:
		return false

	# Map digit (1..9) -> preset index (0..8)
	var preset_index := clampi(pressed_digit - 1, 0, mini(test_num_presets.size(), 9) - 1)
	var preset_value := test_num_presets[preset_index]

	# Clamp to your allowed range just in case
	test_num = clampf(preset_value, -300.0, 240.0)

	_apply_test_num_to_panel()
	return true


# Detect which number key (1..9) is currently held.
# First tries input actions like "1_key".."9_key" (if you've set them),
# then falls back to physical keys (top row + numpad).
func _get_pressed_digit_1_to_9() -> int:
	# Prefer actions if you have them mapped (e.g., "1_key", "2_key", … "9_key")
	for digit in range(1, 10):
		var action_name := "%d_key" % digit
		if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
			return digit

	# Fallback to physical keys
	# Godot 4: use Key.*
	for digit in range(1, 10):
		var keycode := Key.KEY_0 + digit  # 1..9
		if Input.is_key_pressed(keycode):
			return digit
		# Numpad
		var np_keycode := Key.KEY_KP_0 + digit
		if Input.is_key_pressed(np_keycode):
			return digit

	return 0


# Apply current test_num to the slide panel's layout
func _apply_test_num_to_panel() -> void:
	# Recompute children first
	log_container.update_minimum_size()
	# Let the panel recompute its own min-size (your SlidePanelContainer has this helper)
	if slide_panel_container.has_method("shrink_to_contents"):
		slide_panel_container.shrink_to_contents()

	# Update size using your existing “test_num” scheme
	var content_height := get_combined_minimum_size().y

	# Example policy (same spirit as your earlier code):
	#   base 500 + test_num delta, never less than content
	var target_height := maxf(content_height, content_height + 500.0 + test_num)
	slide_panel_container.size.y = target_height

	# If you also want to nudge its Y like before, keep this (optional):
	slide_panel_container.position.y = initial_y_pos - float(change_amount) - (test_num / 1.5)
	


	# Final nudge so layout settles
	slide_panel_container.update_minimum_size()


# Blocked if crollcontainer needs scrollwheel
func can_camera_zoom(hovered_control: Control) -> bool:
	
	if hovered_control and scroll_container == hovered_control:
		if is_open:
			return false
	elif hovered_control and scroll_container.is_ancestor_of(hovered_control):
		if is_open:
			return false
	
	return true
