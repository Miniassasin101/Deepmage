class_name EffectsController
extends Node

@export var unit: Unit
@export var animation_controller: AnimationController

func play_effect(effect: AnimationEffect) -> void:
	if effect == null:
		return


	effect.play_effect(unit)
