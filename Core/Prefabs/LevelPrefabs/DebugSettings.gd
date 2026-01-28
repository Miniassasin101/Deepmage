class_name DebugSettings
extends Node

@export var control_enemy_debug: bool = true
@export var allow_all_skills_in_tactics: bool = false


static var instance: DebugSettings = null


# Called when the node enters the scene tree
func _ready() -> void:
	if instance != null:
		push_error("There's more than one DebugSettings! - " + str(instance))
		queue_free()
		return
	instance = self
