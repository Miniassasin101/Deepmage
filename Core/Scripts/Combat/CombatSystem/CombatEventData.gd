class_name CombatEventData
extends Resource

# Participants
var attacker: Unit = null

var defender: Unit = null

# Skill
var skill: Skill = null

## The weapon used for this attack (resolved from EquipmentContainer at declaration time).
## null when the attacker has no EquipmentContainer or the skill has no associated weapon.
var weapon: Weapon = null

# Actions/Reactions
var action: CombatAction = null

var reaction: Reaction = null

## Tags written by passive skills at BEFORE_HIT_RESOLVES to influence reaction selection.
## Examples: "deflected", "barrier_absorbed", "fire_resisted", "parried".
## ReactionRule.excluded_combat_flags uses these to skip default animations.
var combat_flags: Array[String] = []

## If set by a passive skill, ReactionResolver returns this directly and skips rule evaluation.
## Set to a PassAction instance to suppress the reaction entirely.
var reaction_override: Reaction = null


# Attack Data
var is_success: bool = false

var is_critical_success: bool = false

var is_graze: bool = false

# sometimes an attack will hit even if the attack loses, Ex: Guard reaction.
var is_hit: bool = true

var net_hits: int = 0

var accuracy: int = 0


var initial_low_damage: int = 0
var initial_high_damage: int = 0

var effective_damage: int = 0

# also used for armor pen
var defense_bonus: int = 0

# Dice Pool Data
var attacker_test: Test = null

var attacker_hits: int = 0

var defender_test: Test = null

var defender_hits: int = 0

var armor_test: Test = null

var armor_test_hits: int = 0

var required_successes: int = 1

# Modifiers
var accuracy_mod: int = 0

var damage_multiplier: int = 100

var crit_bonus_damage_pool: int = 2

# Text lines
var on_impact_lines: Array[String] = []


var context: Dictionary = {}

# Snapshot of “roll inputs” (mutable by blessings/afflictions BEFORE rolling)
var pending_power_percent: int = 100			# starts at skill.base_power
var pending_accuracy: int = 0					# final computed accuracy after EVD, etc.
var pending_crit_chance: int = 0				# final crit chance after mods
var force_crit: bool = false
var force_miss: bool = false

# Optional: if you want statuses to modify defense before damage calc
var pending_defense_value: int = 0				# starts at defender defense attribute

# Optional: for debugging
var pre_roll_notes: Array[String] = []


# Banwa Fields (temp)
# [{roll:int, modified:int, evaded:bool, chained:bool, crit:bool, raw_damage:int, after_defense:int}, ...]
var per_die_results: Array[Dictionary] = [] 
var total_initial_damage: int = 0            # sum of (die) across non-evaded dice (+chains) and Prowess
var total_after_defense: int = 0             # after subtracting defense Prowess
var any_die_hit: bool = false                # at least one die passed EVD
var was_crit_any: bool = false
var chained_count: int = 0
