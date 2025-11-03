class_name InflictEffectAction
extends AttackAction


@export var effects: Array[Effect] = []





func do_resolve() -> void:
	var cd: CombatEventData = CombatSystem.instance.current_combat_event_data
	var target_unit: Unit = cd.defender
	
	var target_is_self: bool = unit == target_unit
	
	if not cd.is_hit and !target_is_self:
		Utilities.spawn_text_line(target_unit, "EVADE", Color.AQUA)
		CombatLog.instance.add_log("Result: Evaded")
		return

	apply_effects(unit, target_unit)
	
	if target_is_self:
		return
	
	

	
	# OPTIONAL: switch to Posture track later.
	# For now, keep your health to minimize refactor:
	target_unit.get_attributes_container().add_attribute_modifier("posture", -cd.effective_damage)

	# Fx
	if cd.effective_damage > 1:
		target_unit.animation_controller.play_hit_reaction()
		Utilities.spawn_damage_label(target_unit, cd.effective_damage, Color.FIREBRICK, 0.5)
	else:
		Utilities.spawn_damage_label(target_unit, cd.effective_damage, Color.AZURE, 0.5)

	# Reaction on-impact hook
	if cd.reaction and cd.reaction.has_method("on_impact"):
		cd.reaction.on_impact()


func apply_effects(user: Unit, target: Unit) -> void:
	for effect in effects:
		effect.set_context({"user": user, "target_unit": target})
		effect.apply()
		pass



## Checks if this action can be used on the given target pack (range, self-target, and pathing).
func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if target_pack == null or !target_pack.has_tag("unit"):
		return false

	var target_unit: Unit = target_pack.unit

	if unit == null or target_unit == null:
		return false
	
	if target_unit != unit and get_distance_to_unit(target_unit) > attack_range:
		if !can_move_to_unit(target_unit):
			return false
	return true
