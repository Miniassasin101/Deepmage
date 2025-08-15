class_name CameraShakeAnimationEffect
extends AnimationEffect

@export var strength = 0.15 # the maximum shake strength. The higher, the messier

@export var shake_time = 0.4 # how much it will last
@export var shake_frequency = 50 # will apply 250 shakes per `shake_time`


func play_effect(owner: Unit = null) -> void:
	if !owner:
		return
	
	CameraShake.instance.shake(strength, shake_time, shake_frequency)
