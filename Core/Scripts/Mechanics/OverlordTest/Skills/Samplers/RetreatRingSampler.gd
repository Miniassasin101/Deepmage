class_name RetreatRingSampler
extends Resource

@export var min_radius: float = 4.0
@export var max_radius: float = 12.0
@export var ring_count: int = 3
@export var points_per_ring: int = 16

# Optional bias: if true, we bias samples opposite the average enemy direction.
@export var bias_away_from_enemies: bool = true
@export var bias_sector_width_degrees: float = 120.0

func get_candidate_positions(owner: Unit) -> Array[Vector3]:
	var results: Array[Vector3] = []
	if owner == null:
		return results

	var radii: Array[float] = _linspace(min_radius, max_radius, ring_count)
	var center: Vector3 = owner.global_transform.origin

	# Optional: compute a direction away from enemies to prefer that sector first.
	var away_dir: Vector3 = Vector3.ZERO
	if bias_away_from_enemies:
		away_dir = _compute_away_from_enemies_dir(owner)

	for radius_value in radii:
		# Use your existing nav-aware ring sampler
		var ring_points: Array[Vector3] = PathfindingSystem.instance.get_radial_points_surrounding_unit(owner, radius_value, points_per_ring)

		# If we have a bias, rotate/sort the ring so the preferred sector is earlier.
		if bias_away_from_enemies and away_dir.length() > 0.01:
			ring_points = _prioritize_sector(ring_points, center, away_dir, deg_to_rad(bias_sector_width_degrees))

		for pos in ring_points:
			results.append(pos)

	return results


func _compute_away_from_enemies_dir(owner: Unit) -> Vector3:
	var center: Vector3 = owner.global_transform.origin
	var enemy_sum: Vector3 = Vector3.ZERO
	var enemy_count: int = 0

	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == owner:
			continue
		if other_unit.is_enemy != owner.is_enemy:
			enemy_sum += other_unit.global_transform.origin
			enemy_count += 1

	if enemy_count == 0:
		return Vector3.ZERO

	var enemy_centroid: Vector3 = enemy_sum / float(enemy_count)
	var away: Vector3 = (center - enemy_centroid)
	away.y = 0.0
	return away.normalized()


func _prioritize_sector(points: Array[Vector3], center: Vector3, preferred_dir: Vector3, half_angle_radians: float) -> Array[Vector3]:
	var in_sector: Array[Vector3] = []
	var out_sector: Array[Vector3] = []

	for p in points:
		var vec: Vector3 = (p - center)
		vec.y = 0.0
		if vec.length() < 0.001:
			out_sector.append(p)
			continue

		var dot_val: float = vec.normalized().dot(preferred_dir)
		# dot = cos(theta). Keep points whose angle to preferred_dir is within half-angle.
		var theta: float = acos(clamp(dot_val, -1.0, 1.0))
		if theta <= half_angle_radians * 0.5:
			in_sector.append(p)
		else:
			out_sector.append(p)

	# Put preferred sector first so later preferences will see them earlier if they narrow.
	var reordered: Array[Vector3] = []
	reordered.append_array(in_sector)
	reordered.append_array(out_sector)
	return reordered


func _linspace(start_value: float, end_value: float, count_value: int) -> Array[float]:
	var arr: Array[float] = []
	if count_value <= 1:
		arr.append(end_value)
		return arr

	var step_value: float = (end_value - start_value) / float(count_value - 1)
	for i in range(count_value):
		arr.append(start_value + step_value * float(i))
	return arr
