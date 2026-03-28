## [b]Class:[/b] HitResolver
## [i]Determines whether an attack lands and whether it is a critical hit.[/i]
##
## [b]Responsibilities[/b][br]
## • Reads the pending roll inputs already staged on [CombatEventData] by [CombatSystem].[br]
## • Rolls hit and crit, honoring force flags.[br]
## • Writes the outcome flags back to [CombatEventData].
##
## [b]Design Notes[/b][br]
## • Stateless: all inputs come from [CombatEventData]; no internal mutable state.[br]
## • Private roll helpers use underscore prefix and are not part of the public API.
class_name HitResolver
extends RefCounted


## Resolves hit and crit outcome from the pending roll inputs already stored on [param cd].
## Writes [member CombatEventData.is_hit], [member CombatEventData.is_critical_success],
## [member CombatEventData.is_success], [member CombatEventData.was_crit_any],
## and [member CombatEventData.is_graze].
func resolve(cd: CombatEventData) -> void:
	var is_hit: bool
	if cd.force_miss:
		is_hit = false
	else:
		is_hit = _roll_hit(cd.pending_accuracy)

	var is_crit: bool
	if cd.force_crit:
		is_crit = true
	else:
		is_crit = _roll_crit(cd.pending_crit_chance)

	cd.is_hit = is_hit
	cd.is_critical_success = is_crit
	cd.is_success = is_hit
	cd.was_crit_any = is_crit
	cd.is_graze = false


# Roll-under hit check. Returns true if [param hit_chance] >= 100, false if <= 0.
func _roll_hit(hit_chance: int) -> bool:
	if hit_chance >= 100:
		return true
	if hit_chance <= 0:
		return false
	return randi_range(1, 100) <= hit_chance


# Roll-under crit check. Returns false if [param crit_chance] <= 0, true if >= 100.
func _roll_crit(crit_chance: int) -> bool:
	if crit_chance <= 0:
		return false
	if crit_chance >= 100:
		return true
	return randi_range(1, 100) <= crit_chance
