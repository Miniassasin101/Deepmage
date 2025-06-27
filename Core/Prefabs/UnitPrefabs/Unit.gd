class_name Unit
extends Node3D


@export_category("References")
@export var above_head_marker: Marker3D

@export_category("Attributes")
@export var ui_name: String = "None"



func get_world_position_above_marker() -> Vector3:
	return above_head_marker.global_position if above_head_marker else Vector3.ZERO
