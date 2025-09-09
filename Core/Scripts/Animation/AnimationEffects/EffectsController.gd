class_name EffectsController
extends Node

signal on_hit_moment

signal effect_tag(tag: String)

@export var unit: Unit
@export var animation_controller: AnimationController

func play_effect(effect: AnimationEffect) -> void:
	if effect == null:
		return


	effect.play_effect(unit)
	
	if effect is HitMomentAnimationEffect:
		on_hit_moment.emit()
