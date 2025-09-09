class_name AnimationPackage
extends Resource

@export var name: String = "None"

@export var animation: Animation

@export var animation_effects: Array[AnimationEffect] = []


@export var sync_profile: AnimationSyncProfile
@export var tags: Array[String] = []   # optional (e.g., ["melee","right_to_left"])
@export var uses_root_motion: bool = false

var instanced_animation_effects: Array[AnimationEffect] = []


func get_anim_name() -> StringName:
	if animation:
		return animation.resource_name
	return ""


func get_anim_effects() -> Array[AnimationEffect]:
	return animation_effects

func get_instanced_animation_effects() -> Array[AnimationEffect]:
	return instanced_animation_effects


# AnimationPackage.gd (helpers used by sync)
func marker_time(label: StringName) -> float:
	if sync_profile != null:
		return sync_profile.time_of(label)
	return -1.0


func marker_window(start_label: StringName, end_label: StringName) -> Vector2:
	if sync_profile != null:
		return sync_profile.window(start_label, end_label)
	return Vector2(-1.0, -1.0)


func time_scale_range() -> Vector2:
	if sync_profile != null:
		return Vector2(sync_profile.min_time_scale, sync_profile.max_time_scale)
	return Vector2(1.0, 1.0)
