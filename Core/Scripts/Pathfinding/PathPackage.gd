class_name PathPackage
extends Resource

var path: Array[Vector3] = []
var path_cost: float = INF

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


func get_curve_3d_from_path() -> Curve3D:
	if path.is_empty():
		return null
	
	var new_curve: Curve3D = Curve3D.new()
	new_curve.set_bake_interval(curve_bake_interval)
	for i in range(path.size()):
		var point: Vector3 = path[i]
		var control_offset = Vector3(0, 0, 0)
		if i > 0 and i < path.size() - 1:
			# Smooth control points for intermediate nodes
			control_offset = (path[i + 1] - path[i - 1]).normalized() * 0.5
		new_curve.add_point(point, -control_offset, control_offset)
	
	return new_curve
