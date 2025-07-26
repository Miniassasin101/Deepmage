class_name DebugSettings
extends Node

@export var control_enemy_debug: bool = true



static var instance: DebugSettings = null



# Called when the node enters the scene tree
func _ready() -> void:
	if instance != null:
		push_error("There's more than one DebugSettings! - " + str(instance))
		queue_free()
		return
	instance = self
