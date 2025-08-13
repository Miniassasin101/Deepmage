class_name AnimationController
extends Node


@export var unit: Unit
@export var animator: AnimationPlayer

@export var current_library: String = ""

var current_animation: String = ""

func play_animation_by_name(animation_name: String) -> void:
	
	if !has_animation(animation_name):
		return
	
	Utilities.spawn_text_line(unit, "Has Animation: " + animation_name)
	
	var anim_path: String = current_library + "/" + animation_name
	
	animator.play(anim_path)
	
	await animator.animation_finished
	
	Utilities.spawn_text_line(unit, "Animation Finished: " + animation_name)
	pass



func has_animation(animation_name: String) -> bool:
	var anim_path: String = current_library + "/" + animation_name
	
	if !animator.has_animation(anim_path):
		return false
	
	return true
