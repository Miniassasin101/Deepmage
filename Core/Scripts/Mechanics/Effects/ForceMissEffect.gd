## [b]Effect:[/b] ForceMissEffect
## Sets [member CombatEventData.is_hit] to [code]false[/code] on the currently-resolving
## combat event, turning a would-be hit into a miss.
##
## Use this as the [Effect] payload on a BEFORE_HIT_RESOLVES passive skill to implement
## Dodge / Evade mechanics. Because [code]is_hit[/code] is read by [CombatAction.do_resolve]
## after this phase fires, the damage step is fully skipped.
##
## [b]Target key is ignored[/b] — this effect operates on the global combat event, not on a unit.
class_name ForceMissEffect
extends Effect


func can_apply() -> bool:
	return CombatSystem.instance != null and CombatSystem.instance.current_combat_event_data != null


func apply() -> void:
	if CombatSystem.instance == null:
		emit_signal("effect_finished")
		return

	var cd: CombatEventData = CombatSystem.instance.current_combat_event_data
	if cd != null:
		cd.is_hit = false

	emit_signal("effect_finished")
