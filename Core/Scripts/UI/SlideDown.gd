# SlideDown.gd
class_name SlideDown
extends PanelContainer

@export var duration := 0.20          # seconds
@export var trans := Tween.TRANS_CUBIC
@export var target_ease := Tween.EASE_OUT
@export var start_open := false

@export var content: Control
var _open := false
var _tween: Tween


var drift_tween: Tween
var base_position: Vector2

@export var start_offset: Vector2 = Vector2(0.0, 0.0)
@export var drift_amount: Vector2 = Vector2(0.0, 0.0)
@export var drift_duration: float = 2.0
@export var parent_container: Container


func _ready() -> void:
	#clip_contents = true

	# Wait for layout so we can measure content size correctly
	await get_tree().process_frame
	await get_tree().process_frame
	#_expanded_h = content.get_combined_minimum_size().y
	if parent_container:
		base_position = parent_container.get_position() + start_offset
	set_position(base_position)
	

	if start_open:
		#_open = true
		#custom_minimum_size.y = _expanded_h
		open()
	else:
		close()
		#custom_minimum_size.y = 0.0

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	_open = true
	#_animate_to(_expanded_h)
	#set_visible(true)
	slide_out()

func close() -> void:
	_open = false
	#_animate_to(0.0)
	#stop_drift()
	slide_in()
	#set_visible(false)

func _animate_to(target_h: float) -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(trans).set_ease(target_ease)
	_tween.tween_property(self, "custom_minimum_size:y", target_h, duration)

# Call this function to start the drift animation.
func start_drift() -> void:
	# If already drifting, do nothing.
	if drift_tween:
		return
	base_position = get_position()
	var final_position: Vector2 = Vector2(base_position.x + drift_amount.x, base_position.y + drift_amount.y)
	drift_tween = get_tree().create_tween()
	drift_tween.set_loops(50)  # Loop indefinitely.
	drift_tween.tween_property(self, "position", final_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift_tween.tween_property(self, "position", base_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Call this function to stop the drift and reset the position.
func stop_drift() -> void:
	if abort_tween():
		set_position(base_position)

func slide_out() -> void:
	if drift_tween:
		abort_tween()


	#base_position = get_position()
	var final_position: Vector2 = Vector2(base_position.x + drift_amount.x, base_position.y + drift_amount.y)
	
	drift_tween = get_tree().create_tween()

	drift_tween.tween_property(self, "position", final_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#drift_tween.tween_property(self, "position", base_position, drift_duration) \
	#		   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func slide_in() -> void:
	if drift_tween:
		abort_tween()
	
	drift_tween = get_tree().create_tween()
	
	drift_tween.tween_property(self, "position", base_position, drift_duration)
	

func abort_tween() -> bool:
	if drift_tween:
		drift_tween.kill()
		drift_tween = null
		return true
	return false
"""
"""
