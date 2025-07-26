class_name CombatSystem
extends Node


static var instance: CombatSystem = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self
