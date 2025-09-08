# SlideDown.gd
class_name SlidePanelContainer
extends PanelContainer

@export var duration := 0.20          # seconds
@export var trans := Tween.TRANS_CUBIC
@export var target_ease := Tween.EASE_OUT
@export var start_open := false

var _open := false
var _tween: Tween


var drift_tween: Tween
var base_position: Vector2 = self.position

@export var start_offset: Vector2 = Vector2(0.0, 0.0)
@export var drift_amount: Vector2 = Vector2(0.0, 0.0)
@export var drift_duration: float = 2.0
@export var reset_position: bool = false
@export var parent_container: Control





func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	base_position = get_position()
	
	if parent_container:
		base_position = parent_container.get_position() + start_offset
	set_position(base_position)
	
	if start_open:
		open()
	else:
		close()
		pass

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	_open = true
	#set_visible(true)
	slide_out()

func close() -> void:
	_open = false
	await slide_in()
	#set_visible(false)




func slide_out() -> void:
	if drift_tween:
		abort_tween()
	
	var mod: Color = get_modulate()
	mod.a = 0
	set_modulate(mod)
	mod.a = 1
	

	
	set_position(base_position)
	

	var final_position: Vector2 = Vector2(base_position.x + drift_amount.x, base_position.y + drift_amount.y)
	
	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "modulate", mod, drift_duration)

	drift_tween.parallel().tween_property(self, "position", final_position, drift_duration) \
			   .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func slide_in() -> void:
	if drift_tween:
		abort_tween()
	
	var mod: Color = get_modulate()
	mod.a = 1
	set_modulate(mod)
	mod.a = 0
	
	if reset_position:
		base_position = get_position() + -drift_amount
	
	
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
