class_name MoveRangeRingRenderer
extends Node3D


@export_category("Rendering")
@export var radius_profile: Curve
@export var material: Material
@export var bake_interval: float = 0.12

var _mesh: CurveMesh3D = null


func _ready() -> void:
	_ensure_mesh()


func clear() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.cm_clear()


func set_ring_world_points(points_world: PackedVector3Array) -> void:
	_ensure_mesh()

	if points_world.size() < 3:
		clear()
		return

	var curve: Curve3D = Curve3D.new()
	curve.closed = true
	curve.bake_interval = bake_interval

	var index: int = 0
	while index < points_world.size():
		var world_point: Vector3 = points_world[index]
		var local_point: Vector3 = to_local(world_point)
		curve.add_point(local_point)
		index += 1

	_mesh.cm_clear()
	_mesh.curve = curve
	_mesh.radius_profile = radius_profile
	_mesh.material = material


func _ensure_mesh() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		return

	_mesh = CurveMesh3D.new()
	_mesh.name = "MoveRangeRingMesh"
	add_child(_mesh)
