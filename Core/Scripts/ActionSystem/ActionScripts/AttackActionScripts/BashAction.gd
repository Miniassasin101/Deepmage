class_name BashAction
extends Action

#NOTE: Animation Timing Instructions:
# adjust Sync profile in action/reaction (hit start/end), (invuln start/end)






@export_category("Action Variables")
@export var attack_success_animation: AnimationPackage

@export_group("Camera Shake Effects")
@export var hit_anim_effect: CameraShakeAnimationEffect
@export var graze_anim_effect: CameraShakeAnimationEffect
@export var block_anim_effect: CameraShakeAnimationEffect

@export_group("Hit Stop Effects")
@export var hit_stop_effect: HitstopAnimationEffect
@export var graze_stop_effect: HitstopAnimationEffect
@export var block_stop_effect: HitstopAnimationEffect

@export_group("")
@export var attack_range: float = 2.0

## Optional: how close (in radians) we want to be before starting the attack.
## If < 0, MovementController default is used.
@export var pre_rotation_margin_override: float = 0.12   # ~7 degrees feels nice
@export var min_turn_delta_rad: float = 4.5              # only rotate if > ~6°

@export var accuracy_attribute: String = "agility"
@export var attack_attribute: String = "might"

@export var base_damage: int = 3

# === Sync tuning ===
@export var desired_invuln_lead: float = 0.05      # invuln center happens slightly before hit center
@export var default_reaction_latency: float = 0.06 # reaction input → start

var move_to_action: MoveToUnitAction = null


# ----------------------------
# Lifecycle
# ----------------------------
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	print_debug("Bash Started")
	if targ_pack == null or targ_pack.unit == null:
		end_action()
		return

	var target_unit: Unit = targ_pack.unit

	# 1) Move into range if needed
	await move_to_target_unit(target_unit)
	Utilities.spawn_text_line(owner, "Bash", Color.AQUA)

	# 2) Face target
	await rotate_towards_target(target_unit)
	print_debug("Rotate Completed")

	# 3) Declare attack (triggers reaction prompt + tests)
	await declare_attack(target_unit)

	# 4) Prep effect strengths (read what the test decided)
	var ev := CombatSystem.instance.current_combat_event_data
	var effective_damage: int = maxi(base_damage - ev.armor_test_hits, 0)

	var core_is_hit := ev.is_hit
	var core_is_graze := ev.is_graze
	var core_is_pure_miss := !core_is_hit and !core_is_graze

	# --- FX intent (what CameraShake/HitStop should look like) ---
	# By request: if it’s a pure miss, still play FX like a normal hit.
	var fx_is_hit := core_is_hit
	var fx_is_graze := core_is_graze
	#if core_is_pure_miss:
	#	fx_is_hit = true
	#	fx_is_graze = false

	# 5) Build sync with chosen reaction (if any)
	var defender := ev.defender
	var reaction: Action = ev.reaction

	var dodge_pack: AnimationPackage = null
	var reaction_latency := default_reaction_latency

	if reaction != null and reaction.has_method("get_reaction_package"):
		dodge_pack = reaction.call("get_reaction_package")
	if reaction != null and reaction.has_method("get_reaction_latency"):
		reaction_latency = float(reaction.call("get_reaction_latency"))

	var atk_hit := _safe_marker_window(attack_success_animation, &"HIT_START", &"HIT_END")
	var dd_inv := _safe_marker_window(dodge_pack, &"INVULN_ON", &"INVULN_OFF")
	var dd_peak := _safe_marker_time(dodge_pack, &"PEAK")
	var scale_range := _safe_scale_range(dodge_pack)
	var can_sync: bool = atk_hit.x >= 0.0 and dd_inv.x >= 0.0

	# Only try to play/sync a dodge if it WASN'T a pure miss.
	var should_play_dodge := !fx_is_hit and (dodge_pack != null) and (defender != null)

	var sync: Dictionary = _compute_sync(
		atk_hit, dd_inv, dd_peak,
		desired_invuln_lead, reaction_latency, scale_range
	)

	# If we will actually play a dodge and it lines up to be invuln at strike,
	# change the FX intent to look like a clean dodge (no hit FX).
	if should_play_dodge and can_sync:
		var will_be_invuln_at_hit := (reaction is EvadeAction) or (reaction != null and reaction.has_method("get_reaction_package"))
		if will_be_invuln_at_hit:
			#fx_is_hit = false
			#fx_is_graze = false
			pass

	# 6) Configure effects based on FX intent (NOT the rules result)
	_modify_camera_shake_effect(fx_is_hit, fx_is_graze, effective_damage)
	_modify_hit_stop(fx_is_hit, fx_is_graze, effective_damage)

	# 7) Schedule plays with offsets/time-scale (attack always plays)
	var attack_delay_val := float(sync.get("attack_delay", 0.0))
	_play_attack_with_delay(attack_success_animation, attack_delay_val)

	if should_play_dodge:
		var dodge_delay_val := float(sync.get("dodge_delay", 0.0))
		var dodge_scale_val := float(sync.get("dodge_scale", 1.0))
		_play_dodge_with_delay(defender, dodge_pack, dodge_delay_val, dodge_scale_val)

	# 8) Resolve exactly at the hit moment (keeps the actual rules result)
	await _resolve_at_hit_moment_or_timer(attack_success_animation, attack_delay_val, atk_hit, defender, effective_damage)


	# 9) End once the attack animation completes
	if owner.animation_controller.is_resolving:
		await owner.animation_controller.animation_finished
	end_action()


# ----------------------------
# Helpers: movement / rotation
# ----------------------------
func move_to_target_unit(targ_unit: Unit) -> void:
	if get_distance_to_owner(targ_unit) <= attack_range:
		return
	action_container.use_action(get_move_to_action(), targ_unit)
	await SignalBus.on_action_ended
	print_debug("moved to target")
	return


func declare_attack(target_unit: Unit) -> void:
	await CombatSystem.instance.declare_attack(self, owner, target_unit)


func rotate_towards_target(target: Unit) -> void:
	var target_pos := target.get_global_position()
	owner.movement_controller.rotate_unit_towards_target_position(
		target_pos,
		4.0,                         # rotation speed
		pre_rotation_margin_override # early-start margin
	)
	await owner.movement_controller.rotation_precomplete


# ----------------------------
# Hit resolution timing
# ----------------------------
func _resolve_at_hit_moment_or_timer(attack_pack: AnimationPackage, attack_delay: float, atk_hit: Vector2, defender: Unit, effective_damage: int) -> void:
	var ctrl := owner.animation_controller
	var resolved := false
	
	#do_resolve(resolved, defender, effective_damage)



	# Prefer: wait for HitMomentAnimationEffect fired by the attack animation
	var used_signal := false
	if ctrl != null:

		await ctrl.effects_controller.on_hit_moment
		print_debug("Signal Recieved")
		do_resolve(resolved, defender, effective_damage)
		used_signal = true

	# Fallback: timer to hit-center (attack_delay + center of window)
	if !used_signal:
		var hit_center := 0.5 * (atk_hit.x + atk_hit.y)
		await owner.get_tree().create_timer(max(0.0, attack_delay + hit_center)).timeout
		do_resolve(resolved, defender, effective_damage)



	


func do_resolve(resolved: bool, defender: Unit, effective_damage: int):
	if resolved:
		return
	resolved = true

	var ev := CombatSystem.instance.current_combat_event_data
	var is_hit := ev.is_hit
	var is_graze := ev.is_graze


	# Feedback / damage
	if !is_hit:
		if is_graze:
			Utilities.spawn_text_line(defender, "Graze", Color.AQUA)
		else:
			Utilities.spawn_text_line(defender, "MISS", Color.AQUA)
		return

	# On-hit damage
	defender.get_attributes_container().add_attribute_modifier("health", -effective_damage)
	var color: Color
	if effective_damage == 0:
		color = Color.ALICE_BLUE
	else:
		color = Color.FIREBRICK
	Utilities.spawn_damage_label(defender, effective_damage, color, 0.55)


# ----------------------------
# Animation scheduling
# ----------------------------
func _play_attack_with_delay(pack: AnimationPackage, delay: float) -> void:
	if owner.animation_controller == null:
		return

	if owner.animation_controller.has_method("play_package_timed"):
		owner.animation_controller.play_package_timed(pack, max(0.0, delay), 1.0)
		return

	await owner.get_tree().create_timer(max(0.0, delay)).timeout
	owner.animation_controller.play_package(pack)


func _play_dodge_with_delay(defender: Unit, pack: AnimationPackage, delay: float, scale: float) -> void:
	if defender.animation_controller == null:
		return

	if defender.animation_controller.has_method("play_package_timed"):
		defender.animation_controller.play_package_timed(pack, max(0.0, delay), max(0.01, scale))
		return

	await defender.get_tree().create_timer(max(0.0, delay)).timeout
	var old := defender.animation_controller.animator.speed_scale
	defender.animation_controller.animator.speed_scale = max(0.01, scale)
	defender.animation_controller.play_package(pack)
	await defender.animation_controller.animation_finished
	defender.animation_controller.animator.speed_scale = old


# ----------------------------
# Effects configuration (pre-play)
# ----------------------------
func _modify_camera_shake_effect(is_hit: bool, is_graze: bool, effective_damage: int) -> void:
	var effect: CameraShakeAnimationEffect = null
	var effects: Array[AnimationEffect] = attack_success_animation.get_anim_effects()
	for e in effects:
		if e is CameraShakeAnimationEffect:
			effect = e
	if effect:
		effect.is_disabled = false
		if !is_hit:
			if is_graze:
				effect.shake_frequency = graze_anim_effect.shake_frequency
				effect.shake_time = graze_anim_effect.shake_time
				effect.strength = graze_anim_effect.strength
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


func _modify_hit_stop(is_hit: bool, is_graze: bool, effective_damage: int) -> void:
	var effect: HitstopAnimationEffect = null
	var effects: Array[AnimationEffect] = attack_success_animation.get_anim_effects()
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


# ----------------------------
# Queries
# ----------------------------
func get_stat_name() -> String:
	return attack_attribute


func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if target_pack == null or !target_pack.has_tag("unit"):
		return false
	var unit: Unit = target_pack.unit
	if action_container == null:
		return false
	if unit == action_container.unit:
		return false
	if get_distance_to_owner(unit) > attack_range:
		if !can_move_to_unit(unit):
			return false
	return true


func get_distance_to_owner(unit: Unit) -> float:
	return unit.get_global_position().distance_to(owner.get_global_position())


func can_move_to_unit(target_unit: Unit) -> bool:
	var move_action: MoveToUnitAction = get_move_to_action()
	if move_action == null:
		return false
	if !action_container.can_use_action_at_target(move_action, target_unit):
		return false
	return true


func get_move_to_action() -> MoveToUnitAction:
	if move_to_action:
		return move_to_action
	var actions: Array[Action] = action_container.get_all_actions()
	for action in actions:
		if action is MoveToUnitAction:
			move_to_action = action
			return action
	return null


# ----------------------------
# Sync math & safe accessors
# ----------------------------
static func _compute_sync(atk_hit: Vector2, inv: Vector2, peak_time: float, lead: float, reaction_latency: float, scale_range: Vector2) -> Dictionary:
	# Centers
	var hit_c := 0.5 * (atk_hit.x + atk_hit.y)
	var inv_c := peak_time if peak_time >= 0.0 else 0.5 * (inv.x + inv.y)

	# We want invuln to slightly LEAD the hit
	var adjusted_inv_c := inv_c - maxf(0.0, lead)

	# Choose non-negative schedule delays
	var attack_delay := reaction_latency + adjusted_inv_c - hit_c
	var dodge_delay := reaction_latency
	if attack_delay < 0.0:
		# Push both forward equally so neither is negative
		dodge_delay -= attack_delay
		attack_delay = 0.0

	# Micro time scale so invuln span roughly matches the hit span
	var hit_len := maxf(0.001, atk_hit.y - atk_hit.x)
	var inv_len := maxf(0.001, inv.y - inv.x)
	var dodge_scale := clampf(hit_len / inv_len, scale_range.x, scale_range.y)

	return {
		"attack_delay": attack_delay,
		"dodge_delay": dodge_delay,
		"dodge_scale": dodge_scale
	}






static func _safe_marker_window(pack: AnimationPackage, a: StringName, b: StringName) -> Vector2:
	if pack == null:
		return Vector2(-1.0, -1.0)
	if pack.has_method("marker_window"):
		return pack.marker_window(a, b)
	return Vector2(-1.0, -1.0)


static func _safe_marker_time(pack: AnimationPackage, label: StringName) -> float:
	if pack == null:
		return -1.0
	if pack.has_method("marker_time"):
		return float(pack.marker_time(label))
	return -1.0


static func _safe_scale_range(pack: AnimationPackage) -> Vector2:
	if pack == null:
		return Vector2(1.0, 1.0)
	if pack.has_method("time_scale_range"):
		return pack.time_scale_range()
	return Vector2(1.0, 1.0)
