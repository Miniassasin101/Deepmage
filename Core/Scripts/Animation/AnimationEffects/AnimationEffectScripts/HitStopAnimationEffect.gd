class_name HitstopAnimationEffect
extends AnimationEffect

@export_range(0, 2) var duration: float = 0.2

var is_disabled: bool = false

func play_effect(owner: Unit = null) -> void:
	if owner == null or is_disabled:
		return
	
	if duration <= 0.0:
		return
	
	var ctrl: AnimationController = owner.animation_controller
	
	
	# Stops animation speed then resumes it after the timer is up
	ctrl.set_timescales(0.01)
	await ctrl.get_tree().create_timer(duration).timeout
	ctrl.set_timescales(1.0)


 
