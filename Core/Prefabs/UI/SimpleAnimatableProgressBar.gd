class_name SimpleAnimatableProgressBar
extends PanelContainer

@export var health_bar: TextureProgressBar
@export var animation_duration: float = 0.35
var progress_tween: Tween = null


func _ready() -> void:
	#await get_tree().process_frame
	#await get_tree().process_frame
	#set_to_percent()
	pass

func reset() -> void:
	pass

func animate_to_percent(in_percent: float = 100.0) -> void:

	abort_tween()
	
	in_percent = clampf(in_percent, 0.0, 100.0)
	progress_tween = get_tree().create_tween()
	if progress_tween and health_bar:
		progress_tween.tween_property(health_bar, "value", in_percent, animation_duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func set_to_percent(in_percent: float = 100.0) -> void:
	abort_tween()
	
	in_percent = clampf(in_percent, 0.0, 100.0)
	
	if health_bar:
		health_bar.set_value(in_percent)

func abort_tween() -> void:
	if progress_tween != null:
		progress_tween.kill()
		progress_tween = null
