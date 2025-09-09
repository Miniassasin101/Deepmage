class_name RangedAttackAction
extends AttackAction

@export var projectile_travel_time: float = 1.0







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
