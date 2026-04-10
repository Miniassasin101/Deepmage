class_name MinimizePathLengthPreference
extends PositionPreference
# Keep positions with the SHORTEST path length from current position (saves AP/time).

func apply(_skill: Skill, owner: Unit, candidates: Array[Vector3]) -> Array[Vector3]:
	if candidates.size() <= 1:
		return candidates

	var best_len: float = INF
	var lengths: Dictionary = {}  # Vector3 -> float

	for pos in candidates:
		var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(pos, owner, true, false)
		var curve: Curve3D = path_pack.get_curve_3d_from_path()
		var length_value: float = 0.0
		if curve:
			length_value = curve.get_baked_length()
		lengths[pos] = length_value
		if length_value < best_len:
			best_len = length_value

	var narrowed: Array[Vector3] = []
	for pos in candidates:
		if float(lengths[pos]) == best_len:
			narrowed.append(pos)

	if narrowed.is_empty():
		return candidates
	return narrowed
