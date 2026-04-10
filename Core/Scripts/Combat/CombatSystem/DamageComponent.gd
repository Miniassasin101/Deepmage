class_name DamageComponent
extends Resource

## A self-contained extra damage roll added on top of a skill's primary damage.
##
## Each component rolls independently with its own prowess stat, power percentage,
## and defense attribute, then its net result is summed into effective_damage.
##
## Two sources can carry components:
##   - [Weapon.enchantment_components]  — fire rune, frost binding, etc.
##   - [Skill.extra_damage_components]  — inherent multi-type abilities (spells, special moves)
##
## Crit and miss are inherited from the primary attack.
## [code]pending_defense_value[/code] / [code]pending_power_percent[/code] status hooks affect
## the primary component only. [code]damage_multiplier[/code] (post-roll) scales all components.

@export_group("Damage Component")

## Attribute key for the attacker's contribution to this component (e.g. "martial", "channel").
## Must be non-empty — a component with an empty prowess_attribute is skipped with an error.
@export var prowess_attribute: String = "martial"

## Power scaling as a percentage of the weapon damage range (100 = full damage, 50 = half).
@export var power_percent: int = 50

## Attribute key checked against the defender for this component (e.g. "parry", "resist").
## Must be non-empty — a component with an empty defense_attribute is skipped with an error.
@export var defense_attribute: String = "parry"
