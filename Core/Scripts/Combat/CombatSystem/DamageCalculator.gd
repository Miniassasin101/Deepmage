## [b]Class:[/b] DamageCalculator
## [i]Computes base damage from roll inputs and writes the result to [CombatEventData].[/i]
##
## [b]Responsibilities[/b][br]
## • Takes the (already resolved) hit/crit flags from [CombatEventData].[br]
## • Applies the weapon damage range, prowess attribute, and power multiplier.[br]
## • Subtracts defense to produce [member CombatEventData.effective_damage].[br]
## • Does NOT apply post-roll status multipliers — [CombatSystem] handles those after this call.
##
## [b]Design Notes[/b][br]
## • Stateless: all inputs come from [CombatEventData] and [CombatFormulaResource].[br]
## • Formula constants (weapon range, crit multiplier) come from [CombatFormulaResource]
##   so tuning never requires code changes.
class_name DamageCalculator
extends RefCounted


## Computes damage and stores the result in [param cd].
## Writes [member CombatEventData.initial_low_damage], [member CombatEventData.initial_high_damage],
## [member CombatEventData.total_initial_damage], and [member CombatEventData.effective_damage].
## [param might_value] is the attacker's resolved prowess attribute value.
func calculate(cd: CombatEventData, might_value: int, formula: CombatFormulaResource) -> void:
	# Use the equipped weapon's damage range when available; fall back to formula globals.
	var weapon_min: int = formula.weapon_damage_min
	var weapon_max: int = formula.weapon_damage_max
	if cd.weapon != null:
		weapon_min = cd.weapon.damage_min
		weapon_max = cd.weapon.damage_max

	var min_base_dmg: int = weapon_min + might_value
	var max_base_dmg: int = weapon_max + might_value

	var power_mult: float = float(cd.pending_power_percent) / 100.0
	var modded_low: float = min_base_dmg * power_mult
	var modded_high: float = max_base_dmg * power_mult

	var dmg_roll: int = _roll_damage(modded_low, modded_high, cd.is_critical_success, formula.crit_damage_multiplier)

	cd.initial_low_damage = int(modded_low)
	cd.initial_high_damage = int(modded_high)
	cd.total_initial_damage = dmg_roll

	# Defense subtraction; clamp floor at 0 so defense can never produce negative raw damage.
	var damage_post_defense: int = dmg_roll - maxi(cd.pending_defense_value, 0)
	cd.effective_damage = damage_post_defense


## Calculates net damage for one [DamageComponent], floored at 0.
## Uses the same weapon damage range as the primary roll so enchantments scale with weapon quality.
## [param prowess] is the attacker's resolved attribute value for this component.
## [param power_pct] is the component's power percentage (100 = full, 50 = half).
## [param defense] is the defender's raw resistance attribute value for this component.
func calculate_component(
		weapon_min: int, weapon_max: int,
		prowess: int, power_pct: int,
		defense: int,
		is_crit: bool, formula: CombatFormulaResource) -> int:
	var modded_low: float  = (weapon_min + prowess) * (float(power_pct) / 100.0)
	var modded_high: float = (weapon_max + prowess) * (float(power_pct) / 100.0)
	var roll: int = _roll_damage(modded_low, modded_high, is_crit, formula.crit_damage_multiplier)
	return maxi(roll - maxi(defense, 0), 0)


# Rolls damage in [param low_dmg]..[param high_dmg]. On a crit, returns high * [param crit_multiplier].
# Both low and high are floored before use so partial values from power scaling round down.
func _roll_damage(low_dmg: float, high_dmg: float, is_crit: bool, crit_multiplier: float) -> int:
	if is_crit:
		return int(high_dmg * crit_multiplier)
	return randi_range(int(low_dmg), int(high_dmg))
