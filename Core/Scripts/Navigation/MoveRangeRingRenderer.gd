class_name MoveRangeRingRenderer
extends Node3D

@export_category("Rendering")
@export var radius_profile: Curve
@export var material: Material
@export var bake_interval: float = 0.12

@export_category("Fade")
@export_range(0.05, 2.0, 0.01) var fade_duration: float = 0.33
@export var hide_when_invisible: bool = true
@export var shader_alpha_param: StringName = &"alpha" # If using ShaderMaterial, expect a uniform named "alpha"

var _mesh: CurveMesh3D = null
var _mat_instance: Material = null
var _fade_tween: Tween = null
var _current_alpha: float = 0.0
var _pending_clear_on_fade_out: bool = false

func _ready() -> void:
	_ensure_mesh()
	_ensure_material_instance()
	_apply_alpha(0.0)
	if hide_when_invisible and _mesh:
		_mesh.visible = false


func clear() -> void:
	# Fade out quickly, then clear geometry at the end.
	if _mesh == null or !is_instance_valid(_mesh):
		return
	_pending_clear_on_fade_out = true
	_fade_to(0.0)


func set_ring_world_points(points_world: PackedVector3Array) -> void:
	_ensure_mesh()
	_ensure_material_instance()

	# If invalid, fade out instead of snapping off.
	if points_world.size() < 3:
		clear()
		return

	_pending_clear_on_fade_out = false

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
	_mesh.material = _mat_instance

	# Fade in (and keep current alpha if we're mid-transition).
	_fade_to(1.0)


func _ensure_mesh() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		return

	_mesh = CurveMesh3D.new()
	_mesh.name = "MoveRangeRingMesh"
	add_child(_mesh)


func _ensure_material_instance() -> void:
	# We duplicate the exported material so changing alpha doesn't affect other users of the same resource.
	if material == null:
		return

	if _mat_instance != null and is_instance_valid(_mat_instance):
		return

	_mat_instance = material.duplicate(true)
	_mat_instance.resource_local_to_scene = true

	# If it's a StandardMaterial3D / BaseMaterial3D, ensure alpha blending is enabled.
	if _mat_instance is BaseMaterial3D:
		var bm: BaseMaterial3D = _mat_instance
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA



func _fade_to(target_alpha: float) -> void:
	if _mesh == null or !is_instance_valid(_mesh):
		return

	target_alpha = clampf(target_alpha, 0.0, 1.0)
	
	if _mat_instance == null:
		_mat_instance = _mesh.material
	
	var bm: BaseMaterial3D = _mat_instance
	bm.albedo_color.a = 0
	_current_alpha = 0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	bm.depth_draw_mode =BaseMaterial3D.DEPTH_DRAW_ALWAYS


	if hide_when_invisible and target_alpha > 0.0:
		_mesh.visible = true

	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_QUAD)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)

	_fade_tween.tween_method(Callable(self, "_apply_alpha"), _current_alpha, target_alpha, fade_duration).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(Callable(self, "_on_fade_complete").bind(target_alpha))


func _apply_alpha(value: float) -> void:
	_current_alpha = clampf(value, 0.0, 1.0)

	if _mat_instance == null:
		_mat_instance = _mesh.material
		return

	# Standard/Base material path: drive albedo alpha.
	if _mat_instance is BaseMaterial3D:
		var bm: BaseMaterial3D = _mat_instance
		var c: Color = bm.albedo_color
		c.a = _current_alpha
		bm.albedo_color = c
		return

	# Shader material path: drive a uniform (default name "alpha").
	if _mat_instance is ShaderMaterial:
		var sm: ShaderMaterial = _mat_instance
		sm.set_shader_parameter(shader_alpha_param, _current_alpha)


func _on_fade_complete(target_alpha: float) -> void:
	# If we faded out, optionally clear geometry and hide.
	if target_alpha <= 0.001:
		if _pending_clear_on_fade_out and _mesh != null and is_instance_valid(_mesh):
			_mesh.cm_clear()
		if hide_when_invisible and _mesh != null and is_instance_valid(_mesh):
			_mesh.visible = false
