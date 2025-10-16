class_name SkillChain
extends Resource

# data container that has all of the units that are reacting to a specific skill
# Think Yugioh trap cards

var chaining_units: Array[Unit] = []

var already_chained_units: Array[Unit] = []

var chain_depth: int = 0

var source_skill: Skill
