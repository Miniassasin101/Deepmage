# ToggleInvulnAnimationEffect.gd
class_name ToggleInvulnAnimationEffect
extends AnimationEffect

@export var enabled: bool = true

func play_effect(unit: Unit = null) -> void:
	if unit:
		pass
		#unit.set_invuln(enabled)   # we'll add this to Unit in step 5
 
