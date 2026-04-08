class_name BuildSource
extends Resource

@export var ui_name: String = ""
@export var tags: PackedStringArray = []

@export var grant_magic_types: PackedStringArray = []
@export var grant_skills: Array[Skill] = []
@export var grant_spells: Array[Skill] = []
@export var grant_statuses: Array[Status] = []
@export var attribute_mods: Array[AttributeMod] = []

## If true, this Magic Class BuildSource marks the unit as a Warmage archetype.
## Warmages receive a free Martial Class, have higher Martial Potential ceilings,
## are restricted to 1–2 affinities, and gain access to Enforcement and Manifestation spells.
## Truemages leave this false and gain broader affinity access and more spell slots per rank.
@export var warmage_archetype: bool = false
