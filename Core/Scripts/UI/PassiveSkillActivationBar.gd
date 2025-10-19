## PassiveSkillBar.gd
class_name PassiveSkillBar
extends PanelContainer

@export var label_node: Label

@export var duration := 0.20
@export var trans := Tween.TRANS_CUBIC
@export var target_ease := Tween.EASE_OUT
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


func _ready() -> void:
	base_position = position
	var mod: Color = modulate
	mod.a = 0.0
	modulate = mod
	visible = true  # alpha drives visibility



func open() -> void:
	_open = true
	visible = true
	slide_out()

func close() -> void:
	_open = false
	await slide_up_out()
	abort_tween()
	queue_free()

func slide_out() -> void:
	abort_tween()
	var mod: Color = modulate
	mod.a = 0.0
	modulate = mod
	var parent: Control = get_parent_control()
	global_position = parent.global_position  # single authoritative placement before tween
	global_position.x += start_offset.x

	var target_mod: Color = modulate
	target_mod.a = 1.0
	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "modulate", target_mod, drift_duration)
	drift_tween.parallel().tween_property(self, "global_position:x", parent.global_position.x, drift_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func slide_up_out() -> void:
	abort_tween()

	var fade: Color = modulate
	fade.a = 0.0

	# Drift upward a bit while fading
	var target_y: float = global_position.y - 30.0
	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "modulate", fade, drift_duration)
	drift_tween.parallel().tween_property(self, "global_position:y", target_y, drift_duration)
	await drift_tween.finished


func slide_up_to() -> void:
	abort_tween()
	var parent_ctrl: Control = get_parent_control()
	var target_y: float = parent_ctrl.global_position.y
	drift_tween = get_tree().create_tween()
	drift_tween.tween_property(self, "global_position:y", target_y, drift_duration)
	await drift_tween.finished



func abort_tween() -> bool:
	if drift_tween != null:

		drift_tween.kill()
		drift_tween = null
		return true
	return false


func set_text(skill_text: String) -> void:
	if label_node != null:
		label_node.text = skill_text
