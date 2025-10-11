class_name CombatEventData
extends Resource

# Participants
var attacker: Unit = null

var defender: Unit = null


# Actions/Reactions
var action: AttackAction = null

var reaction: Reaction = null


# Attack Data
var is_success: bool = false

var is_critical_success: bool = false

var is_graze: bool = false

# sometimes an attack will hit even if the attack loses, Ex: Guard reaction.
var is_hit: bool = true

var net_hits: int = 0

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

var crit_bonus_damage_pool: int = 2

# Text lines
var on_impact_lines: Array[String] = []


# Banwa Fields (temp)
# [{roll:int, modified:int, evaded:bool, chained:bool, crit:bool, raw_damage:int, after_defense:int}, ...]
var per_die_results: Array[Dictionary] = [] 
var total_initial_damage: int = 0            # sum of (die) across non-evaded dice (+chains) and Prowess
var total_after_defense: int = 0             # after subtracting defense Prowess
var any_die_hit: bool = false                # at least one die passed EVD
var was_crit_any: bool = false
var chained_count: int = 0
