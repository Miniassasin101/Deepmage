class_name UnitVFXManager
extends Node3D


@export_category("Status VFX")
@export var blessing_effect: Node = null
@export var affliction_effect: Node = null

@export_range(0.0, 2.0, 0.01) var fade_in_time: float = 0.15
@export_range(0.0, 2.0, 0.01) var fade_out_time: float = 0.15


var _blessing_active: bool = false
var _affliction_active: bool = false

var _blessing_tween: Tween = null
var _affliction_tween: Tween = null


func _ready() -> void:
	_prepare_effect(blessing_effect)
	_prepare_effect(affliction_effect)


func set_status_category_active(blessing_is_active: bool, affliction_is_active: bool) -> void:
	set_blessing_active(blessing_is_active)
	set_affliction_active(affliction_is_active)


func set_blessing_active(is_active: bool) -> void:
	if _blessing_active == is_active:
		return
	_blessing_active = is_active
	_apply_fade(blessing_effect, is_active, true)


func set_affliction_active(is_active: bool) -> void:
	if _affliction_active == is_active:
		return
	_affliction_active = is_active
	_apply_fade(affliction_effect, is_active, false)


func _prepare_effect(effect_node: Node) -> void:
	if effect_node == null:
		return
	_set_effect_strength(effect_node, 0.0)
	_set_effect_emitting(effect_node, false)
	_set_effect_visible(effect_node, false)


func _apply_fade(effect_node: Node, enable: bool, is_blessing: bool) -> void:
	if effect_node == null:
		return

	_kill_existing_tween(is_blessing)

	if enable:
		_set_effect_visible(effect_node, true)
		_set_effect_emitting(effect_node, true)

		if fade_in_time <= 0.0:
			_set_effect_strength(effect_node, 1.0)
			return

		_set_effect_strength(effect_node, 0.0)

		var tween: Tween = create_tween()
		_store_tween(is_blessing, tween)
		tween.tween_method(Callable(self, "_tween_set_strength").bind(effect_node), 0.0, 1.0, fade_in_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		tween.finished.connect(Callable(self, "_clear_tween").bind(is_blessing))
	else:
		var start_strength: float = _get_effect_strength(effect_node)

		if fade_out_time <= 0.0:
			_set_effect_strength(effect_node, 0.0)
			_set_effect_emitting(effect_node, false)
			_set_effect_visible(effect_node, false)
			return

		var tween_out: Tween = create_tween()
		_store_tween(is_blessing, tween_out)
		tween_out.tween_method(Callable(self, "_tween_set_strength").bind(effect_node), start_strength, 0.0, fade_out_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
		tween_out.finished.connect(Callable(self, "_on_fade_out_finished").bind(effect_node, is_blessing))


func _kill_existing_tween(is_blessing: bool) -> void:
	var tween: Tween = _get_tween(is_blessing)
	if tween != null:
		tween.kill()
	_store_tween(is_blessing, null)


func _store_tween(is_blessing: bool, tween: Tween) -> void:
	if is_blessing:
		_blessing_tween = tween
	else:
		_affliction_tween = tween


func _get_tween(is_blessing: bool) -> Tween:
	if is_blessing:
		return _blessing_tween
	return _affliction_tween


func _clear_tween(is_blessing: bool) -> void:
	_store_tween(is_blessing, null)


func _on_fade_out_finished(effect_node: Node, is_blessing: bool) -> void:
	_clear_tween(is_blessing)
	_set_effect_strength(effect_node, 0.0)
	_set_effect_emitting(effect_node, false)
	_set_effect_visible(effect_node, false)


func _tween_set_strength(value: float, effect_node: Node) -> void:
	_set_effect_strength(effect_node, value)


func _set_effect_visible(effect_node: Node, is_vis: bool) -> void:
	if effect_node is VisualInstance3D:
		(effect_node as VisualInstance3D).visible = is_vis


func _set_effect_emitting(effect_node: Node, is_emitting: bool) -> void:
	if effect_node is GPUParticles3D:
		(effect_node as GPUParticles3D).emitting = is_emitting
	elif effect_node is CPUParticles3D:
		(effect_node as CPUParticles3D).emitting = is_emitting


func _set_effect_strength(effect_node: Node, strength: float) -> void:
	var clamped_strength: float = clampf(strength, 0.0, 1.0)

	if effect_node is GPUParticles3D:
		(effect_node as GPUParticles3D).amount_ratio = clamped_strength
		return
	if effect_node is CPUParticles3D:
		(effect_node as CPUParticles3D).amount_ratio = clamped_strength
		return

	# Fallback if you ever swap the effect to something non-particles:
	effect_node.set_meta(&"vfx_strength", clamped_strength)
	if effect_node is Node3D:
		var target_scale: float = lerpf(0.01, 1.0, clamped_strength)
		(effect_node as Node3D).scale = Vector3.ONE * target_scale


func _get_effect_strength(effect_node: Node) -> float:
	if effect_node is GPUParticles3D:
		return (effect_node as GPUParticles3D).amount_ratio
	if effect_node is CPUParticles3D:
		return (effect_node as CPUParticles3D).amount_ratio

	if effect_node.has_meta(&"vfx_strength"):
		return float(effect_node.get_meta(&"vfx_strength"))

	return 0.0
