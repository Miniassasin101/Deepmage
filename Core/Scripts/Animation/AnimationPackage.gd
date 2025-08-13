class_name AnimationPackage
extends Resource

@export var name: String = "None"

@export var animation: Animation


@export var event_timings: Array[float] = []


func get_anim_name() -> StringName:
	if animation:
		return animation.resource_name
	return ""
