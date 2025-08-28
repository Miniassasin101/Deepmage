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
	var combat_data: CombatEventData = CombatSystem.instance.current_combat_event_data
	var enemy_crtl: AnimationController = combat_data.defender.animation_controller if combat_data else null
	
	
	# Stops animation speed then resumes it after the timer is up
	if enemy_crtl:
		enemy_crtl.set_timescales(0.0)
	ctrl.set_timescales(0.0)
	
	await ctrl.get_tree().create_timer(duration).timeout
	
	if enemy_crtl:
		enemy_crtl.set_timescales(1.0)
	ctrl.set_timescales(1.0)


 
