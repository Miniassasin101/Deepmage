class_name AttackAction
extends Action

# -----------------------------------------------------------------------------
# NOTE: Animation Timing Tips
# Adjust sync profiles in action/reaction (hit start/end), (react start/end)
# -----------------------------------------------------------------------------


# =========================
# Exported Variables
# =========================

@export_category("Action Variables")
@export var animation_package: AnimationPackage

@export_group("Camera Shake Effects")
@export var hit_anim_effect: CameraShakeAnimationEffect
@export var graze_anim_effect: CameraShakeAnimationEffect
@export var block_anim_effect: CameraShakeAnimationEffect

@export_group("Hit Stop Effects")
@export var hit_stop_effect: HitstopAnimationEffect
@export var graze_stop_effect: HitstopAnimationEffect
@export var block_stop_effect: HitstopAnimationEffect

@export_group("Selection Data")
@export var attack_range: float = 2.0


@export_group("Attack Data")
@export var die_size: int = 6   # Ex: d6, d10
@export var die_count: int = 1  # Ex: 2d4, 5d6
@export var is_melee_attack: bool = true
@export var prowess_attribute: String = "might"
@export var defense_attribute: String = "endurance"
@export var uses_area_pattern: bool = false



@export_group("Pokerole Attack Data")
@export var accuracy_attribute1: String = "agility"
@export var accuracy_attribute2: String = "martial"
@export var damage_attribute: String = "might"
@export var base_damage: int = 3
@export var base_target_number: int = 1





# === Sync tuning ===
@export_group("Animation Sync Tuning")
@export var desired_react_lead: float = 0.05      # reaction center happens slightly before hit center
@export var default_reaction_latency: float = 0.06 # reaction input → start

@export var hit_delay: float = 3.0
@export var use_hit_delay: bool = false

@export var reaction_anim_end_wait_margin: float = 0.15

# Cached helper action reference
var move_to_action: MoveToUnitAction = null

## Optional: how close (in radians) we want to be before starting the attack.
## If < 0, MovementController default is used.
const pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice


# =========================
# Lifecycle
# =========================

## Starts the full attack flow: ensure range, face target, prompt reactions, sync and play anims, resolve on hit, then end.
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)

	if targ_pack == null or targ_pack.get_unit() == null:
		end_action()
		return

	var target_unit: Unit = targ_pack.get_unit()

	# 1) Move into range if needed
	await move_to_target_unit(target_unit)

	spawn_action_name_text()

	# 2) Face target
	await rotate_towards_target(target_unit)

	# 3) Declare attack (triggers reaction prompt + tests)
	await declare_attack(target_unit)

	# 5) Build sync with chosen reaction (if any)
	var reaction_anim_pack: AnimationPackage = get_reaction_anim_pack()
	var sync: Dictionary = get_animation_sync(reaction_anim_pack)

	# 6) Configure effects based on FX intent (NOT the rules result)
	modify_shake_and_hitstop()

	# 7) Schedule plays with offsets/time-scale (attack always plays)
	_play_attack_with_delay(animation_package, sync)
	_play_reaction_with_delay(reaction_anim_pack, sync)

	# 8) Resolve exactly at the hit moment (keeps the actual rules result)
	await unit.get_tree().process_frame
	await _resolve_at_hit_moment_or_timer(sync)
	# NOTE: Make sure event timings dont perfectly overlap: Causes animation event override for earlier ones.
	
	await wait_for_animation_resolve(target_unit)
	

	end_action()


# =========================
# Helpers: Movement / Rotation / Declaration
# =========================

## Moves the unit into attack range of the target unit if needed.
func move_to_target_unit(targ_unit: Unit) -> void:
	if targ_unit == unit:
		return
	
	if get_distance_to_unit(targ_unit) <= attack_range:
		return
	var temp_action: Action = action_container.use_action(get_move_to_action(), targ_unit)
	await temp_action.on_action_ended
	print_debug("moved to target")
	return

## Declares the attack to the combat system (prompts for defender reactions & runs hit tests).
func declare_attack(target_unit: Unit) -> void:
	await CombatSystem.instance.declare_attack(self, unit, target_unit)

## Rotates the unit to face the target position, then waits for pre-rotation completion.
func rotate_towards_target(target: Unit) -> void:
	if target == unit:
		return
	var target_pos := target.get_global_position()
	unit.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # early-start margin
	)
	await unit.movement_controller.rotation_precomplete

## Retrieves the reaction animation package from the chosen reaction, if any.
func get_reaction_anim_pack() -> AnimationPackage:
	var reaction: Reaction = CombatSystem.instance.current_combat_event_data.reaction

	var reaction_anim_pack: AnimationPackage = null

	if reaction != null and reaction.has_method("get_reaction_package"):
		reaction_anim_pack = reaction.call("get_reaction_package")

	return reaction_anim_pack

## Reads current combat event outcome flags (hit/graze/block) and primes FX settings accordingly.
func modify_shake_and_hitstop() -> void:
	var cd: CombatEventData = CombatSystem.instance.current_combat_event_data
	var is_hit: bool = cd.is_hit
	var is_graze: bool = cd.is_graze
	
	animation_package.instanced_animation_effects.clear()
	
	for event in animation_package.get_anim_effects():
		animation_package.instanced_animation_effects.append(event.duplicate())
	
	_modify_camera_shake_effect(is_hit, is_graze, cd.effective_damage)
	_modify_hit_stop(is_hit, is_graze, cd.effective_damage)


# =========================
# Hit Resolution Timing
# =========================

## Resolves rules/effects at the correct hit moment: prefer signal from animation, otherwise uses a timer fallback.
func _resolve_at_hit_moment_or_timer(sync: Dictionary) -> void:
	var ctrl := unit.animation_controller

	# Prefer: wait for HitMomentAnimationEffect fired by the attack animation
	var used_signal := false
	if ctrl != null and !use_hit_delay:

		await ctrl.effects_controller.on_hit_moment
		#print_debug("Signal Recieved")
		do_resolve()
		used_signal = true
		return

	# Fallback: timer to hit-center (attack_delay + center of window)
	if !used_signal:
		var attack_delay: float = sync.get("attack_delay", -1.0)
		var hit_center: float = sync.get("attack_center", -1.0)
		if hit_center == -1.0 or attack_delay == -1.0:
			push_error("Invalid Hit Center Or Attack Delay (Animation Sync Error)")
			return
		
		if use_hit_delay:
			attack_delay += hit_delay
		
		await unit.get_tree().create_timer(max(0.0, attack_delay + hit_center)).timeout
		do_resolve()



func do_resolve() -> void:
	var cd: CombatEventData = CombatSystem.instance.current_combat_event_data
	var defender: Unit = cd.defender

	if not cd.is_hit:
		Utilities.spawn_text_line(defender, "EVADE", Color.AQUA)
		CombatLog.instance.add_log("Result: Evaded")
		return

	# OPTIONAL: switch to Posture track later.
	# For now, keep your health to minimize refactor:
	defender.get_attributes_container().add_attribute_modifier("posture", -cd.effective_damage)

	# Fx
	if cd.effective_damage > 1:
		defender.animation_controller.play_hit_reaction()
		Utilities.spawn_damage_label(defender, cd.effective_damage, Color.FIREBRICK, 0.5)
	else:
		Utilities.spawn_damage_label(defender, cd.effective_damage, Color.AZURE, 0.5)

	# Reaction on-impact hook
	if cd.reaction and cd.reaction.has_method("on_impact"):
		cd.reaction.on_impact()


func wait_for_animation_resolve(target_unit: Unit) -> void:
	# 9) End once the attack animation completes
	if unit.animation_controller.is_resolving:
		await unit.animation_controller.animation_finished
		if target_unit.animation_controller.is_resolving:
			#CombatLog.instance.add_log()
			#CombatLog.instance.add_log(str(target_unit.animation_controller.get_anim_time_left()))
			
			var time_left: float = target_unit.animation_controller.get_anim_time_left()
			if time_left >= reaction_anim_end_wait_margin + 0.1:
				var difference: float = time_left - reaction_anim_end_wait_margin
				await unit.get_tree().create_timer(difference).timeout
				return
			await target_unit.animation_controller.animation_finished




# =========================
# Animation Sync & Scheduling
# =========================

## Computes timing offsets and scaling for attack vs reaction based on markers and reaction latency.
func get_animation_sync(reaction_anim_pack: AnimationPackage) -> Dictionary:
	var reaction: Reaction = CombatSystem.instance.current_combat_event_data.reaction
	var reaction_latency: float = default_reaction_latency

	if reaction != null and reaction.has_method("get_reaction_latency"):
		reaction_latency = float(reaction.call("get_reaction_latency"))

	var atk_hit := _safe_marker_window(animation_package, &"HIT_START", &"HIT_END")
	var dd_inv := _safe_marker_window(reaction_anim_pack, &"REACT_ON", &"REACT_OFF")
	var dd_peak := _safe_marker_time(reaction_anim_pack, &"PEAK")
	var scale_range := _safe_scale_range(reaction_anim_pack)
	# var can_sync: bool = atk_hit.x >= 0.0 and dd_inv.x >= 0.0

	var sync: Dictionary = _compute_sync(
		atk_hit, dd_inv, dd_peak,
		desired_react_lead, reaction_latency, scale_range
	)
	return sync

## Plays the attack animation package after a computed delay (or immediately if supported method absent).
func _play_attack_with_delay(pack: AnimationPackage, sync: Dictionary) -> void:
	if unit.animation_controller == null:
		return

	var attack_delay_val: float = sync.get("attack_delay", 0.0) as float

	if unit.animation_controller.has_method("play_package_timed"):
		unit.animation_controller.play_package_timed(pack, max(0.0, attack_delay_val), 1.0)
		return

	await unit.get_tree().create_timer(maxf(0.0, attack_delay_val)).timeout
	unit.animation_controller.play_package(pack)

## Plays the defender’s reaction animation (if applicable) with delay/scale from sync data.
func _play_reaction_with_delay(reaction_anim_pack: AnimationPackage, sync: Dictionary) -> void:
	var c_event: CombatEventData = CombatSystem.instance.current_combat_event_data
	var defender: Unit = c_event.defender
	var anim_contr: AnimationController = defender.animation_controller

	var should_play_reaction: bool = true#!c_event.is_hit and (reaction_anim_pack != null) and (defender != null)
	if !should_play_reaction:
		return

	if anim_contr == null:
		return

	var delay: float = sync.get("reaction_delay", 0.0) as float
	var scale: float = sync.get("reaction_scale", 1.0) as float
	
	if use_hit_delay:
		delay += hit_delay
	
	
	if anim_contr.has_method("play_package_timed"):
		anim_contr.play_package_timed(reaction_anim_pack, max(0.0, delay), max(0.01, scale))
		return

	await defender.get_tree().create_timer(maxf(0.0, delay)).timeout
	var old := anim_contr.animator.speed_scale
	anim_contr.set_timescales(maxf(0.01, scale))
	anim_contr.play_package(reaction_anim_pack)
	await anim_contr.animation_finished
	anim_contr.set_timescales(old)


# =========================
# Effects Configuration (Pre-Play)
# =========================

## Chooses camera shake parameters based on outcome (miss/graze/block/hit) and enables/disables effect.
func _modify_camera_shake_effect(is_hit: bool, is_graze: bool, effective_damage: int) -> void:
	var effect: CameraShakeAnimationEffect = null
	var effects: Array[AnimationEffect] = animation_package.get_instanced_animation_effects()
	for e in effects:
		if e is CameraShakeAnimationEffect:
			effect = e
	if effect:
		effect.is_disabled = false
		if !is_hit:
			if is_graze:
				#effect.shake_frequency = graze_anim_effect.shake_frequency
				#effect.shake_time = graze_anim_effect.shake_time
				#effect.strength = graze_anim_effect.strength
				effect.is_disabled = true
			else:
				effect.is_disabled = true
		elif effective_damage == 0:
			effect.shake_frequency = block_anim_effect.shake_frequency
			effect.shake_time = block_anim_effect.shake_time
			effect.strength = block_anim_effect.strength
		else:
			effect.shake_frequency = hit_anim_effect.shake_frequency
			effect.shake_time = hit_anim_effect.shake_time
			effect.strength = hit_anim_effect.strength
		
		if use_hit_delay:
			effect.timing += hit_delay
	


## Chooses hit-stop duration based on outcome (miss/graze/block/hit) and enables/disables effect.
func _modify_hit_stop(is_hit: bool, is_graze: bool, effective_damage: int) -> void:
	var effect: HitstopAnimationEffect = null
	var effects: Array[AnimationEffect] = animation_package.get_instanced_animation_effects()
	for e in effects:
		if e is HitstopAnimationEffect:
			effect = e
	if effect:
		effect.is_disabled = false
		if !is_hit:
			if is_graze:
				effect.duration = graze_stop_effect.duration
			else:
				effect.is_disabled = true
		elif effective_damage == 0:
			effect.duration = block_stop_effect.duration
		else:
			effect.duration = hit_stop_effect.duration
		
		if use_hit_delay:
			CombatLog.instance.add_log("Effect Timing: " + str(effect.timing))
			effect.timing += hit_delay



## Spawns a small text label over the unit with this action’s name (UI feedback).
func spawn_action_name_text() -> void:
	Utilities.spawn_text_line(unit, action_name)


# =========================
# Queries
# =========================

## Returns the attribute used for damage rolls (for UI or rule queries).
func get_stat_name() -> String:
	return damage_attribute

func get_damage_attribute() -> String:
	return damage_attribute

func get_accuracy_attributes() -> Array[String]:
	var accuracy_attributes: Array[String] = [accuracy_attribute1, accuracy_attribute2]
	return accuracy_attributes


## Checks if this action can be used on the given target pack (range, self-target, and pathing).
func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if target_pack == null or !target_pack.has_tag("unit"):
		return false

	var target_unit: Unit = target_pack.unit

	if unit == null:
		return false

	if target_unit == unit:
		return false

	if get_distance_to_unit(target_unit) > attack_range:
		if !can_move_to_unit(target_unit):
			return false
	return true

## Distance helper from unit to a given unit.
func get_distance_to_unit(in_unit: Unit) -> float:
	return unit.get_global_position().distance_to(in_unit.get_global_position())

## Checks if we have a valid MoveToUnitAction and if it can reach the target.
func can_move_to_unit(target_unit: Unit) -> bool:
	var move_action: MoveToUnitAction = get_move_to_action()
	if move_action == null:
		return false
	if !action_container.can_use_action_at_target(move_action, target_unit):
		return false
	return true

## Retrieves (and caches) a MoveToUnitAction from the action container, if present.
func get_move_to_action() -> MoveToUnitAction:
	if move_to_action:
		return move_to_action
	var actions: Array[Action] = action_container.get_all_actions()
	for action in actions:
		if action is MoveToUnitAction:
			move_to_action = action
			return action
	return null


# =========================
# Sync Math & Safe Accessors
# =========================

## Core timing math: aligns attack window with reaction window using latency and desired lead; returns schedule & scale.
static func _compute_sync(atk_window: Vector2, react_window: Vector2, peak_time: float, lead: float, reaction_latency: float, scale_range: Vector2) -> Dictionary:
	# Centers
	var attack_center: float = 0.5 * (atk_window.x + atk_window.y)
	var react_center: float = peak_time if peak_time >= 0.0 else 0.5 * (react_window.x + react_window.y)

	# We want reaction to slightly LEAD the hit
	var adjusted_react_c: float = react_center - maxf(0.0, lead)

	# Choose non-negative schedule delays
	var attack_delay: float = reaction_latency + adjusted_react_c - attack_center
	var reaction_delay: float = reaction_latency
	if attack_delay < 0.0:
		# Push both forward equally so neither is negative
		reaction_delay -= attack_delay
		attack_delay = 0.0

	# Micro time scale so reaction span roughly matches the attack span
	var hit_len := maxf(0.001, atk_window.y - atk_window.x)
	var react_len := maxf(0.001, react_window.y - react_window.x)
	var reaction_scale := clampf(hit_len / react_len, scale_range.x, scale_range.y)
	
	# Testing Purposes
	
	

	return {
		"attack_delay": attack_delay,
		"attack_center": attack_center,
		"reaction_delay": reaction_delay,
		"reaction_scale": reaction_scale
	}

## Safe marker-window access: returns [-1, -1] if missing or method unsupported.
static func _safe_marker_window(pack: AnimationPackage, a: StringName, b: StringName) -> Vector2:
	if pack == null:
		return Vector2(-1.0, -1.0)
	if pack.has_method("marker_window"):
		return pack.marker_window(a, b)
	return Vector2(-1.0, -1.0)

## Safe marker-time access: returns -1 if missing or method unsupported.
static func _safe_marker_time(pack: AnimationPackage, label: StringName) -> float:
	if pack == null:
		return -1.0
	if pack.has_method("marker_time"):
		return float(pack.marker_time(label))
	return -1.0

## Safe time-scale range access: returns [1, 1] if missing or method unsupported.
static func _safe_scale_range(pack: AnimationPackage) -> Vector2:
	if pack == null:
		return Vector2(1.0, 1.0)
	if pack.has_method("time_scale_range"):
		return pack.time_scale_range()
	return Vector2(1.0, 1.0)
