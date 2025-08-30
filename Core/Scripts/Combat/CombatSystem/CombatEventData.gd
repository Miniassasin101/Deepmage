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
