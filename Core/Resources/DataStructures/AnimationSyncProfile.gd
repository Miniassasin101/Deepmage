# AnimationSyncProfile.gd
class_name AnimationSyncProfile
extends Resource

@export var markers: Dictionary[String, float] = {}  # store as [time, label_id]
# Human friendly access (set in inspector via helper script below)
@export var min_time_scale: float = 0.85
@export var max_time_scale: float = 1.15

# Nice API
func time_of(label: StringName, default := -1.0) -> float:
	return markers.get(label, default)

func window(a: StringName, b: StringName) -> Vector2:
	return Vector2(time_of(a), time_of(b))
