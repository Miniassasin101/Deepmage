class_name PathPackage
extends Resource

var path: Array[Vector3] = []
var path_cost: float = INF

const path_y_offset_initial: float = -0.16

const curve_bake_interval: float = 0.2

# Setters
func set_path_array(in_path: Array[Vector3]) -> void:
	path = in_path

func set_path_cost(in_path_cost: float) -> void:
	path_cost = in_path_cost

# Getters
func get_path_array() -> Array[Vector3]:
	return path

func get_path_cost() -> float:
	return path_cost

# New: pass a y_offset to raise/lower the whole curve
func get_curve_3d_from_path(y_offset: float = 0.0) -> Curve3D:
	if path.is_empty():
		return null
	
	var new_curve: Curve3D = Curve3D.new()
	new_curve.set_bake_interval(curve_bake_interval)
	
	for i in range(path.size()):
		var base_point: Vector3 = path[i]
		var point := base_point + Utilities.nav_vector_offset  # apply Y offset

		var control_offset := Vector3.ZERO
		if i > 0 and i < path.size() - 1:
			# Tangent based on neighbors (offset cancels out in the diff)
			control_offset = (path[i + 1] - path[i - 1]).normalized() * 0.5

		new_curve.add_point(point, -control_offset, control_offset)

	return new_curve
