class_name AnimationController
extends Node

signal animation_started(anim: StringName)
signal animation_finished(anim: StringName)
signal effect_fired(effect: AnimationEffect)

@export var unit: Unit
@export var animator: AnimationPlayer                  # main motion
@export var event_animator: AnimationPlayer            # NEW: events-only
@export var effects_controller: EffectsController
@export var current_library: String = ""               # main player's library key ("" = default)

@export var hit_reaction_anim: Animation

var is_resolving: bool = false

var current_animation: String = ""
var _current_package: AnimationPackage

var event_library: AnimationLibrary = null

var _restore_speed_on_finish := 1.0
var _override_speed := 1.0

# cache: events animation name -> Animation (so we build once)
var _event_anim_cache: Dictionary = {}

func _ready() -> void:
	if animator:
		animator.animation_finished.connect(_on_anim_finished)

	# Configure event_animator so method keys are safe & precise
	if event_animator:
		event_animator.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
		event_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		# root_node defaults to ".." (parent), so method track path "." will call this controller.

# ---------------- Public API ----------------

func has_animation(animation_name: String) -> bool:
	var anim_path := _libpath(animation_name)
	return animator.has_animation(anim_path)


func play_animation_by_name(animation_name: String) -> void:
	if !has_animation(animation_name):
		return
	var anim_path := _libpath(animation_name)
	animator.play(anim_path)
	await animator.animation_finished


func play_package(pack: AnimationPackage) -> void:
	if pack == null or pack.animation == null:
		push_warning("AnimationPackage is missing its Animation.")
		return

	_current_package = pack
	current_animation = pack.get_anim_name()
	animation_started.emit(current_animation)

	# 1) Play main clip
	var main_path := _anim_path_for(pack)
	is_resolving = true
	animator.play(main_path)

	# 2) Bake/play events clip
	_play_events_for_package(pack)

func play_package_timed(pack: AnimationPackage, delay: float = 0.0, speed_scale: float = 1.0) -> void:
	if pack == null:
		return
	_override_speed = speed_scale
	_restore_speed_on_finish = 1.0
	_start_after_delay(pack, delay)

@rpc("call_local")
func _start_after_delay(pack: AnimationPackage, delay: float) -> void:
	await get_tree().create_timer(maxf(0.0, delay)).timeout
	set_timescales(_override_speed)
	play_package(pack)

func set_timescales(val: float) -> void:
	if animator:
		animator.speed_scale = val
	if event_animator:
		event_animator.speed_scale = val

func apply_hitstop_ms(ms: int) -> void:
	if ms <= 0:
		return
	var old := animator.speed_scale
	set_timescales(0.0)
	await get_tree().create_timer(ms / 1000.0).timeout
	set_timescales(old)

# ---------------- Internals ----------------

func _anim_path_for(package: AnimationPackage) -> String:
	var t_name := package.get_anim_name()
	return _libpath(t_name)


func _on_anim_finished(anim_name: StringName) -> void:
	var matches := false
	if anim_name.ends_with("/" + str(current_animation)): matches = true
	elif anim_name == current_animation: matches = true

	if matches:
		# stop events player too
		if event_animator and event_animator.is_playing():
			#event_animator.stop()
			pass
		animator.speed_scale = _restore_speed_on_finish
		animation_finished.emit(current_animation)
	
	if event_animator and event_animator.is_playing():
		await event_animator.animation_finished
	
	if event_library:
		for anim in event_library.get_animation_list():
			event_library.remove_animation(anim)
	
	is_resolving = false
	
	animation_finished.emit()

# Called by method keys on the events animation
func _on_event_key(effect: AnimationEffect) -> void:
	if effects_controller:
		effects_controller.play_effect(effect)
	effect_fired.emit(effect)

# ---------------- Event animation builder & playback ----------------

func _play_events_for_package(pack: AnimationPackage) -> void:
	if event_animator == null:
		return

	var ev_name := _ensure_events_animation(pack) # builds and registers in library if missing

	# keep players in lock-step
	event_animator.speed_scale = animator.speed_scale

	event_animator.play(ev_name)
	# update immediately so first key at t=0 fires if present
	event_animator.advance(0)
	
	await event_animator.animation_finished


func _ensure_events_animation(pack: AnimationPackage) -> StringName:
	var ename := StringName(pack.get_anim_name() + "__events")

	# already present in player?
	if event_animator.has_animation(ename):
		#return ename
		pass
	# built and cached but not yet registered?
	if _event_anim_cache.has(ename):
		#_register_events_anim(ename, _event_anim_cache[ename])
		#return ename
		pass

	# Build fresh
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE

	# Length: at least main length or last effect + small pad
	var main_len := pack.animation.length
	var last_fx := _last_effect_time(pack)
	anim.length = maxf(main_len, last_fx + 0.01)

	# 1) Method track that calls back into this controller
	var track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track, NodePath("."))  # "." resolves to AnimationController (event_animator's root_node parent)
	for fx in pack.get_instanced_animation_effects():
		var method_details: Dictionary = {
			"method": "_on_event_key",
			"args": [fx]
			}

		anim.track_insert_key(track, fx.timing, method_details)
		pass

	# 2) Optional: add named markers for sync/debug (HIT/REACT/PEAK)
	if pack.has_method("marker_time"):
		var labels := [&"HIT_START", &"HIT_END", &"REACT_ON", &"REACT_OFF", &"PEAK"]
		for label in labels:
			var t := float(pack.marker_time(label))
			if t >= 0.0:
				anim.add_marker(StringName(label), t)

	# Cache & register into the default library of the event_animator
	_event_anim_cache[ename] = anim
	_register_events_anim(ename, anim)
	return ename

func _register_events_anim(in_name: StringName, anim: Animation) -> void:
	# Ensure default library exists and add the animation there
	var lib: AnimationLibrary = null#event_animator.get_animation_library("default")
	for library in event_animator.get_animation_library_list():
		event_animator.remove_animation_library(library)


	if !event_animator.has_animation_library(""):
		lib = AnimationLibrary.new()
		event_animator.add_animation_library("", lib)
		event_library = lib

		pass
	else:
		lib = event_library
	lib.add_animation(in_name, anim)


func _last_effect_time(pack: AnimationPackage) -> float:
	var t := 0.0
	for fx in pack.get_instanced_animation_effects():
		if fx.timing > t:
			t = fx.timing
	
	var grace_amount: float = 0.01
	
	return t + grace_amount

# Optional helper to build "library/anim" or just "anim" when library == ""
func _libpath(anim_name: String) -> String:
	return anim_name if current_library == "" else current_library + "/" + anim_name


func play_hit_reaction() -> void:
	if !hit_reaction_anim:
		return
	var h_r_name: StringName = hit_reaction_anim.resource_name
	
	await play_animation_by_name(h_r_name)
