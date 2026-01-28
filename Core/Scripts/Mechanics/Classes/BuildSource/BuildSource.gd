class_name BuildSource
extends Resource

@export var ui_name: String = ""
@export var tags: PackedStringArray = []

@export var grant_magic_types: PackedStringArray = []
@export var grant_skills: Array[Skill] = []
@export var grant_spells: Array[Skill] = []
@export var grant_statuses: Array[Status] = []
@export var attribute_mods: Array[AttributeMod] = []
