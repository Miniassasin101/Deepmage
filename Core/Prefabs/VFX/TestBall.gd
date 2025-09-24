class_name TestBall
extends Node3D


func set_timer(in_time: float) -> void:
	await get_tree().create_timer(in_time).timeout
	queue_free()
