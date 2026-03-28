## [b]Class:[/b] CombatFormulaResource
## [i]Data-driven container for the constants that govern the damage formula.[/i]
##
## [b]Usage[/b][br]
## Assign an instance to [member CombatSystem.formula].
## If none is assigned, [CombatSystem] creates a default instance at runtime
## so all values fall back to the defaults defined here.
class_name CombatFormulaResource
extends Resource

## Low end of the base weapon damage range (added to the attacker's prowess attribute).
@export var weapon_damage_min: int = 1

## High end of the base weapon damage range (added to the attacker's prowess attribute).
@export var weapon_damage_max: int = 3

## Multiplier applied to the high-end damage roll on a critical hit.
@export var crit_damage_multiplier: float = 1.5

## Flat bonus added to the attacker's accuracy before evade is subtracted.
@export var accuracy_base_bonus: int = 5
