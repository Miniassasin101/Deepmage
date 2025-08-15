class_name AnimationPackage
extends Resource

@export var name: String = "None"

@export var animation: Animation


@export var animation_effects: Array[AnimationEffect] = []


func get_anim_name() -> StringName:
	if animation:
		return animation.resource_name
	return ""


func get_anim_effects() -> Array[AnimationEffect]:
	return animation_effects
