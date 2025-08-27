# ToggleInvulnAnimationEffect.gd
class_name ToggleInvulnAnimationEffect
extends AnimationEffect

@export var enabled: bool = true

func play_effect(owner: Unit = null) -> void:
	if owner:
		pass
		#owner.set_invuln(enabled)   # we'll add this to Unit in step 5
 
