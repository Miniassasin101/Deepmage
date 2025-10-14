# SlidePanelContainer.gd
class_name SlidePanelContainer
extends PanelContainer

@export var duration := 0.20
@export var trans := Tween.TRANS_CUBIC
@export var target_ease := Tween.EASE_OUT
@export var start_open := false
@export var use_offset: bool = false

# NEW: lock width only, let height collapse to contents
@export var lock_width: bool = true
@export var fixed_width: float = 240.0

var _open := false
var drift_tween: Tween
var base_position: Vector2

@export var start_offset: Vector2 = Vector2(0.0, 0.0)
@export var drift_amount: Vector2 = Vector2(0.0, 0.0)
@export var drift_duration: float = 2.0
@export var reset_position: bool = false
@export var parent_container: Control

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# IMPORTANT: for sliding by position, anchor this panel Top-Left in the editor.
	base_position = position

	# apply width policy; height free
	if lock_width:
		custom_minimum_size = Vector2(fixed_width, 0.0)
	else:
		custom_minimum_size = Vector2.ZERO

	position = base_position

	if start_open:
		open()
	else:
		close()

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	_open = true
	visible = true
	# recompute min-size just in case children changed while hidden
	update_minimum_size()
	slide_out()

func close() -> void:
	_open = false
	await slide_in()
	visible = false

func slide_out() -> void:
	if drift_tween:
		abort_tween()

	var mod := modulate
	mod.a = 0.0
	modulate = mod
	mod.a = 1.0

	position = base_position
	var final_position := base_position + drift_amount

	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "modulate", mod, drift_duration)
	drift_tween.parallel().tween_property(self, "position", final_position, drift_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func slide_in() -> void:
	if drift_tween:
		abort_tween()

	var mod := modulate
	mod.a = 1.0
	modulate = mod
	mod.a = 0.0
	
	
	if reset_position:
		base_position = position - drift_amount
		

	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "modulate", mod, drift_duration)
	drift_tween.parallel().tween_property(self, "position", base_position, drift_duration)
	await drift_tween.finished

func abort_tween() -> bool:
	if drift_tween:
		drift_tween.kill()
		drift_tween = null
		return true
	return false

# REPLACEMENT for reset_self_size(): allow shrinking
func shrink_to_contents() -> void:
	# lock width only (optional), never lock height
	if lock_width:
		custom_minimum_size = Vector2(fixed_width, 0.0)
	else:
		custom_minimum_size = Vector2.ZERO
	# tell the layout system to recompute
	update_minimum_size()
