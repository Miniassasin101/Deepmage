class_name SkillTriggerSystem
extends Node

@export var combat_system: CombatSystem = null

static var instance: SkillTriggerSystem

func _ready() -> void:
	if instance != null:
		queue_free()
		return
	instance = self

func fire(trigger_name: String, context: Dictionary) -> void:
	# Later: route to units’ passives/gear/leader auras that subscribed to this trigger_name
	# Example: for equip in context.user.equipment: if trigger_name in equip.triggers: equip.on_trigger(context)
	pass
