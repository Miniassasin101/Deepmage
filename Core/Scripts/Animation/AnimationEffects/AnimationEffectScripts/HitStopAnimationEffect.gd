class_name HitStopAnimationEffect
extends AnimationEffect

@export_range(0, 2) var duration: float = 0.2

var is_disabled: bool = false

## Freezes only this unit's animator for `duration` seconds.
## Defender hitstop is applied separately by CombatAction at the hit moment,
## keeping combat knowledge out of visual effect resources.
func play_effect(unit: Unit = null) -> void:
	if unit == null or is_disabled or duration <= 0.0:
		return

	var ctrl: AnimationController = unit.animation_controller
	if ctrl == null:
		return

	# Stops animation speed then resumes it after the timer is up
	ctrl.set_timescales(0.0)
	await ctrl.get_tree().create_timer(duration).timeout
	ctrl.set_timescales(1.0)


 

 
