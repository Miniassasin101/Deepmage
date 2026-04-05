## [b]Condition:[/b] CombatResultCondition
## Reads the current [CombatEventData] to check the hit/miss outcome of the
## resolving attack.
##
## [b]Settings[/b][br]
## [member require_hit] = [code]true[/code]  — passes only when the attack IS hitting
##                                             (use on Dodge, Enrage, revenge effects)[br]
## [member require_hit] = [code]false[/code] — passes only when the attack MISSED / was evaded
##                                             (use on "counter on evade" passives)
##
## Safe to use in both [constant SkillTriggerSystem.TriggerPhase.BEFORE_HIT_RESOLVES]
## and [constant SkillTriggerSystem.TriggerPhase.AFTER_HIT_RESOLVES] — [code]cd.is_hit[/code]
## is set before either phase fires.
class_name CombatResultCondition
extends SkillCondition

## If true, the condition passes when the attack is a hit.
## If false, it passes when the attack is a miss / evade.
@export var require_hit: bool = true


func check_condition(_skill: Skill, _target: Unit) -> bool:
	var cd: CombatEventData = _get_cd()
	if cd == null:
		return false
	return cd.is_hit == require_hit


func _get_cd() -> CombatEventData:
	if CombatSystem.instance == null:
		return null
	return CombatSystem.instance.current_combat_event_data
