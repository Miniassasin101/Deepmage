class_name TestBall
extends Node3D

signal on_free

@export var mesh_ball: MeshInstance3D

func set_timer(in_time: float) -> void:
	await get_tree().create_timer(in_time).timeout
	on_free.emit()
	queue_free()


func set_color(in_color: Color) -> void:
	Utilities.set_color_on_cel_shaded_mesh(mesh_ball, in_color)
