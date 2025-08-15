class_name AnimationController
extends Node


signal animation_started(anim: StringName)
signal animation_finished(anim: StringName)
signal effect_fired(effect: AnimationEffect)


@export var unit: Unit
@export var animator: AnimationPlayer
@export var effects_controller: EffectsController

@export var current_library: String = ""

var current_animation: String = ""


var _current_package: AnimationPackage
var _pending_effects: Array[AnimationEffect] = []
var _last_pos := 0.0
const EPS := 0.0001



func _ready() -> void:
	if animator:
		animator.animation_finished.connect(_on_anim_finished)



func play_animation_by_name(animation_name: String) -> void:
	
	if !has_animation(animation_name):
		return
	
	Utilities.spawn_text_line(unit, "Has Animation: " + animation_name)
	
	var anim_path: String = current_library + "/" + animation_name
	
	animator.play(anim_path)
	
	await animator.animation_finished
	
	Utilities.spawn_text_line(unit, "Animation Finished: " + animation_name)
	pass



func has_animation(animation_name: String) -> bool:
	var anim_path: String = current_library + "/" + animation_name
	
	if !animator.has_animation(anim_path):
		return false
	
	return true


func _anim_path_for(package: AnimationPackage) -> String:
	var t_name := package.get_anim_name()
	var path := ""
	if current_library == "":
		path = t_name
	else:
		path = current_library + "/" + t_name
	return path


func play_package(pack: AnimationPackage) -> void:
	if pack == null or pack.animation == null:
		push_warning("AnimationPackage is missing its Animation.")
		return

	_current_package = pack
	_arm_effects_from_package(pack)
	current_animation = pack.get_anim_name()
	emit_signal("animation_started", current_animation)

	var path := _anim_path_for(pack)
	animator.play(path)
	_last_pos = 0.0
	set_process(true)

"""
func toggle_slowdown(speed_scale: float = 0.0) -> void:

	if !is_slowed:
			set_timescales(speed_scale)
			# FIXME: Multiplier might be inverted, increases rather than decreases
			#timescale_multiplier = speed_scale
			is_slowed = true

	else:
		set_timescales(1.0)
		#timescale_multiplier = 1.0
		is_slowed = false
"""

func set_timescales(val: float) -> void:
	#animator_tree.set("parameters/Main/TimeScale/scale", val)
	animator.set_speed_scale(val)



func _process(_delta: float) -> void:
	if _current_package == null:
		return
	if !animator.is_playing():
		return

	var pos := animator.current_animation_position

	while _pending_effects.size() > 0 and _pending_effects[0].timing <= pos + EPS:
		var fx: AnimationEffect = _pending_effects.pop_front()
		_fire_effect(fx)

	_last_pos = pos

	if _pending_effects.is_empty():
		set_process(false)

func _fire_effect(fx: AnimationEffect) -> void:
	if effects_controller != null:
		effects_controller.play_effect(fx)
	emit_signal("effect_fired", fx)



func _arm_effects_from_package(pack: AnimationPackage) -> void:
	_pending_effects = pack.get_anim_effects().duplicate()
	_pending_effects.sort_custom(func(a: AnimationEffect, b: AnimationEffect) -> bool:
		return a.timing < b.timing
	)

func _on_anim_finished(anim_name: StringName) -> void:
	var matches := false
	if anim_name.ends_with("/" + str(current_animation)):
		matches = true
	elif anim_name == current_animation:
		matches = true

	if matches:
		_pending_effects.clear()
		set_process(false)
		emit_signal("animation_finished", current_animation)


func apply_hitstop_ms(ms: int) -> void:
	if ms <= 0:
		return
	var old := animator.speed_scale
	animator.speed_scale = 0.0
	await get_tree().create_timer(ms / 1000.0).timeout
	animator.speed_scale = old
