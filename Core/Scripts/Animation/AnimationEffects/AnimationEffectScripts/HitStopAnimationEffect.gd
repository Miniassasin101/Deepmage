class_name HitstopAnimationEffect
extends AnimationEffect

@export_range(0, 500) var duration_ms: int = 90
@export var also_flash_target: bool = false

func play_effect(owner: Unit = null) -> void:
	if owner == null:
		return

	var ctrl := owner.animation_controller
	if ctrl != null:
		await ctrl.apply_hitstop_ms(duration_ms)

	if also_flash_target:
		if owner.has_method("flash_white"):
			owner.flash_white(0.06)
 
