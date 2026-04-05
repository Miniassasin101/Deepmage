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

	# 1) Play main clip — fall back to RESET if this unit doesn't have the animation
	var main_path := _anim_path_for(pack)
	if !animator.has_animation(main_path):
		var reset_path := _get_reset_fallback_path()
		if reset_path != "":
			push_warning("AnimationController: '%s' not found on '%s' — using RESET fallback." % [main_path, unit.ui_name if unit else str(name)])
			main_path = reset_path
			current_animation = &"RESET"
		else:
			push_error("AnimationController: '%s' not found on '%s' and no RESET fallback exists — resolving immediately." % [main_path, unit.ui_name if unit else str(name)])
			is_resolving = true
			_play_events_for_package(pack)
			_finish_without_main_animation()
			return

	is_resolving = true
	animator.play(main_path)

	# 2) Bake/play events clip
	_play_events_for_package(pack)

	# 3) Setup Early Signal Timer for smoother action transitions
	

func play_package_timed(pack: AnimationPackage, delay: float = 0.0, speed_scale: float = 1.0) -> void:
	if pack == null:
		return
	# Mark resolving immediately so callers that check is_resolving during the
	# delay window (e.g. wait_for_animation_resolve on a ranged reaction) don't
	# see a false gap and skip the await.
	is_resolving = true
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


func get_anim_time_left() -> float:
	if !animator.is_playing():
		return 0.0
		
	var time_left: float = animator.current_animation_length - animator.current_animation_position
	return time_left


func _on_anim_finished(anim_name: StringName) -> void:
	# Ignore completions from hit-reaction or any other non-package animation.
	var matches := anim_name.ends_with("/" + str(current_animation)) or anim_name == current_animation
	if not matches:
		return
	
	
	
	animator.speed_scale = _restore_speed_on_finish

	# Wait for the event animator before declaring the package done,
	# so listeners receive the signal only after all effects have fired.
	if event_animator and event_animator.is_playing():
		await event_animator.animation_finished

	if event_library:
		for anim in event_library.get_animation_list():
			event_library.remove_animation(anim)

	is_resolving = false

	# Single emit, once both animators are truly finished.
	animation_finished.emit(current_animation)

# Called by method keys on the events animation
func _on_event_key(effect: AnimationEffect) -> void:
	if effects_controller:
		effects_controller.play_effect(effect)
	effect_fired.emit(effect)

# ---------------- Event animation builder & playback ----------------

func _play_events_for_package(pack: AnimationPackage) -> void:
	if event_animator == null:
		return

	var ev_name := _ensure_events_animation(pack)

	# Keep players in lock-step, then fire and forget.
	# _on_anim_finished is the single place that waits for event_animator.
	event_animator.speed_scale = animator.speed_scale
	event_animator.play(ev_name)
	event_animator.advance(0)  # flush any key at t=0 immediately


func _ensure_events_animation(pack: AnimationPackage) -> StringName:
	var ename := StringName(pack.get_anim_name() + "__events")

	# Always build fresh: instanced_animation_effects are duplicated and mutated
	# each attack (by modify_shake_and_hitstop), so any cached Animation would
	# hold stale effect references and fire wrong durations/settings.
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE

	var main_len := pack.animation.length
	var last_fx := _last_effect_time(pack)
	anim.length = maxf(main_len, last_fx + 0.01)

	# Method track — calls _on_event_key(effect) at each effect's timing.
	var track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track, NodePath("."))
	for fx in pack.get_instanced_animation_effects():
		anim.track_insert_key(track, fx.timing, {"method": "_on_event_key", "args": [fx]})

	# Named markers for sync/debug (HIT_START, HIT_END, REACT_ON, REACT_OFF, PEAK).
	if pack.has_method("marker_time"):
		for label in [&"HIT_START", &"HIT_END", &"REACT_ON", &"REACT_OFF", &"PEAK"]:
			var t := float(pack.marker_time(label))
			if t >= 0.0:
				anim.add_marker(StringName(label), t)

	_register_events_anim(ename, anim)
	return ename

func _register_events_anim(in_name: StringName, anim: Animation) -> void:
	for library in event_animator.get_animation_library_list():
		event_animator.remove_animation_library(library)

	if !event_animator.has_animation_library(""):
		var lib := AnimationLibrary.new()
		event_animator.add_animation_library("", lib)
		event_library = lib

	event_library.add_animation(in_name, anim)


func _last_effect_time(pack: AnimationPackage) -> float:
	var t := 0.0
	for fx in pack.get_instanced_animation_effects():
		if fx.timing > t:
			t = fx.timing
	
	var grace_amount: float = 0.01
	
	return t + grace_amount

## Returns the RESET animation path to use as a fallback.
## Checks [member current_library]/RESET first, then the unnamed default library.
## Returns [code]""[/code] if RESET is not found in either location.
func _get_reset_fallback_path() -> String:
	var in_lib := _libpath("RESET")
	if animator.has_animation(in_lib):
		return in_lib
	if animator.has_animation("RESET"):
		return "RESET"
	return ""


## Resolves [member is_resolving] and emits [signal animation_finished] without a main
## animation playing. Waits for the events animator to finish first so timing effects
## (hit moment, camera shake, etc.) still fire at the correct times.
func _finish_without_main_animation() -> void:
	if event_animator and event_animator.is_playing():
		await event_animator.animation_finished
	is_resolving = false
	animation_finished.emit(current_animation)


# Optional helper to build "library/anim" or just "anim" when library == ""
func _libpath(anim_name: String) -> String:
	return anim_name if current_library == "" else current_library + "/" + anim_name


func play_hit_reaction(flash_white: bool = true) -> void:
	if !hit_reaction_anim:
		return

	var h_r_name: StringName = hit_reaction_anim.resource_name

	if flash_white:
		unit.flash_white()

	# If a package animation (e.g. block) is currently playing, it is about to
	# be interrupted. Stop the event animator so its stale events are discarded,
	# then update current_animation so _on_anim_finished can match the hit
	# reaction when it finishes and correctly emit animation_finished.
	if event_animator and event_animator.is_playing():
		event_animator.stop()
	current_animation = h_r_name

	await play_animation_by_name(h_r_name)
