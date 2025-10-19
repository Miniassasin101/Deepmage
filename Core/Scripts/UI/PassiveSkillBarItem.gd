class_name PassiveBarItem
extends PanelContainer

@export var label_node: Label

@export var enter_duration: float = 0.20
@export var move_duration: float = 0.18
@export var exit_duration: float = 0.20
@export var trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var t_ease: Tween.EaseType = Tween.EASE_OUT

var current_tween: Tween = null
var is_in_use: bool = false
var is_exiting: bool = false

func _ready() -> void:
	_reset_visuals()

func _reset_visuals() -> void:
	if current_tween != null:
		current_tween.kill()
		current_tween = null
	visible = true
	modulate = Color(1, 1, 1, 1)    # we animate THIS alpha
	position = Vector2.ZERO

func set_text(text_value: String) -> void:
	if label_node != null:
		label_node.text = text_value

func play_enter(from_pos: Vector2, to_pos: Vector2) -> void:
	is_exiting = false
	_reset_visuals()
	position = from_pos
	current_tween = get_tree().create_tween().set_trans(trans).set_ease(t_ease)
	current_tween.tween_property(self, "position", to_pos, enter_duration)
	current_tween.parallel().tween_property(self, "modulate:a", 1.0, enter_duration)
	await  current_tween.finished
	pass

func play_move(to_pos: Vector2) -> void:
	if is_exiting:
		return
	if current_tween != null:
		current_tween.kill()
	current_tween = get_tree().create_tween().set_trans(trans).set_ease(t_ease)
	current_tween.tween_property(self, "position", to_pos, move_duration)

func play_exit(to_pos: Vector2) -> Signal:
	is_exiting = true
	if current_tween != null:
		current_tween.kill()
	current_tween = get_tree().create_tween().set_trans(trans).set_ease(t_ease)
	current_tween.tween_property(self, "position", to_pos, exit_duration)
	current_tween.parallel().tween_property(self, "modulate:a", 0.0, exit_duration)
	return current_tween.finished
