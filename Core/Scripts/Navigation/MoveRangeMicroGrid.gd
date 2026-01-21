# MoveRangeMicroGrid.gd (Marching Squares boundary)
class_name MoveRangeMicroGrid
extends RefCounted


class Cell:
	var walkable: bool = false
	var nav_pos: Vector3 = Vector3.ZERO
	var cost: float = INF


class MinHeap:
	var _costs: Array[float] = []
	var _grid_xs: Array[int] = []
	var _grid_zs: Array[int] = []

	func clear() -> void:
		_costs.clear()
		_grid_xs.clear()
		_grid_zs.clear()

	func is_empty() -> bool:
		return _costs.is_empty()

	func push(cost_value: float, grid_x: int, grid_z: int) -> void:
		_costs.append(cost_value)
		_grid_xs.append(grid_x)
		_grid_zs.append(grid_z)
		_sift_up(_costs.size() - 1)

	func peek_cost() -> float:
		return _costs[0]

	func peek_x() -> int:
		return _grid_xs[0]

	func peek_z() -> int:
		return _grid_zs[0]

	func pop() -> void:
		var last_index: int = _costs.size() - 1
		_swap(0, last_index)
		_costs.pop_back()
		_grid_xs.pop_back()
		_grid_zs.pop_back()
		if not _costs.is_empty():
			_sift_down(0)

	func _sift_up(index_in: int) -> void:
		var index: int = index_in
		while index > 0:
			var parent_index: int = floori((index - 1) / 2.0)
			if _costs[index] < _costs[parent_index]:
				_swap(index, parent_index)
				index = parent_index
			else:
				break

	func _sift_down(index_in: int) -> void:
		var index: int = index_in
		while true:
			var left_index: int = index * 2 + 1
			var right_index: int = index * 2 + 2
			var smallest_index: int = index

			if left_index < _costs.size() and _costs[left_index] < _costs[smallest_index]:
				smallest_index = left_index
			if right_index < _costs.size() and _costs[right_index] < _costs[smallest_index]:
				smallest_index = right_index

			if smallest_index != index:
				_swap(index, smallest_index)
				index = smallest_index
			else:
				break

	func _swap(index_a: int, index_b: int) -> void:
		var temp_cost: float = _costs[index_a]
		_costs[index_a] = _costs[index_b]
		_costs[index_b] = temp_cost

		var temp_x: int = _grid_xs[index_a]
		_grid_xs[index_a] = _grid_xs[index_b]
		_grid_xs[index_b] = temp_x

		var temp_z: int = _grid_zs[index_a]
		_grid_zs[index_a] = _grid_zs[index_b]
		_grid_zs[index_b] = temp_z


# Config (set these from PathfindingSystem)
var navmap: RID = RID()
var cell_size: float = 0.33
var snap_threshold: float = 0.20
var max_step_height: float = 0.75
var allow_diagonals: bool = true
var prevent_corner_cut: bool = true
var smoothing_iterations: int = 1


# Render smoothing (post-processing of the contour)
var render_resample_spacing: float = 0.15			# world meters between points after resample
var render_smooth_window_radius: int = 2			# 2 => averages 5 points (i-2..i+2)
var render_smooth_passes: int = 3					# how many times to apply moving average
var render_reproject_to_navmesh: bool = true
var render_reproject_max_snap: float = 0.35			# limit sideways snapping (meters)



# Runtime
var origin_world: Vector3 = Vector3.ZERO
var origin_on_nav: Vector3 = Vector3.ZERO
var budget: float = 0.0

var grid_size: int = 0
var half_cells: int = 0

# Untyped columns because nested typed collections are not supported
var _cells: Array = []			# Array of columns; each column is Array of Cell
var _reachable: Array = []		# Array of columns; each column is Array of bool

var _heap: MinHeap = MinHeap.new()


func build(in_navmap: RID, in_origin_world: Vector3, in_budget: float) -> void:
	navmap = in_navmap
	origin_world = in_origin_world
	budget = maxf(0.0, in_budget)

	if not navmap.is_valid() or budget <= 0.0:
		_clear_runtime()
		return

	origin_on_nav = NavigationServer3D.map_get_closest_point(navmap, origin_world)

	_build_grid()
	_sample_walkability()
	_run_dijkstra()


func get_best_boundary_world(height_offset: float = 0.06) -> PackedVector3Array:
	if grid_size <= 1:
		return PackedVector3Array()

	var loops: Array = _extract_marching_squares_loops_from_reachable()
	if loops.is_empty():
		return PackedVector3Array()

	var best_loop: Array = []
	var best_perimeter: float = -1.0

	var loop_index: int = 0
	while loop_index < loops.size():
		var candidate_loop: Array = loops[loop_index]
		var candidate_perimeter: float = _loop_perimeter_world_from_sample_points(candidate_loop)
		if candidate_perimeter > best_perimeter:
			best_perimeter = candidate_perimeter
			best_loop = candidate_loop
		loop_index += 1

	if best_loop.size() < 3:
		return PackedVector3Array()

	# Convert loop sample-points -> world points (XZ from grid-space, Y from origin plane for now)
	var world_points: Array[Vector3] = []
	var point_index: int = 0
	while point_index < best_loop.size():
		var sample_point: Vector2 = best_loop[point_index]
		var point_world: Vector3 = _sample_point_to_world(sample_point)
		point_world.y = origin_on_nav.y
		world_points.append(point_world)
		point_index += 1

	# 1) Resample to even spacing (critical for stable smoothing)
	if render_resample_spacing > 0.01:
		world_points = _resample_closed_polyline_world(world_points, render_resample_spacing)

	# 2) Smooth (moving average on XZ)
	if render_smooth_window_radius > 0 and render_smooth_passes > 0:
		world_points = _moving_average_smooth_closed_world(world_points, render_smooth_window_radius, render_smooth_passes)

	# 3) Optional: your existing Chaikin (works better after resample)
	if smoothing_iterations > 0:
		world_points = _chaikin_closed(world_points, smoothing_iterations)

	# 4) Reproject to navmesh (but clamp sideways snapping so we don't reintroduce jitter)
	var final_points: Array[Vector3] = []
	point_index = 0
	while point_index < world_points.size():
		var desired_point: Vector3 = world_points[point_index]
		desired_point.y = origin_on_nav.y

		var snapped_point: Vector3 = desired_point
		if render_reproject_to_navmesh and navmap.is_valid():
			var closest_point: Vector3 = NavigationServer3D.map_get_closest_point(navmap, desired_point)
			var snap_distance: float = closest_point.distance_to(desired_point)
			if snap_distance <= render_reproject_max_snap:
				snapped_point = closest_point
			else:
				# If closest jumps too far, keep the smoothed point (prevents "triangle edge wobble")
				snapped_point = desired_point

		snapped_point.y += height_offset
		snapped_point += Utilities.nav_vector_offset
		final_points.append(snapped_point)

		point_index += 1

	var packed_points: PackedVector3Array = PackedVector3Array()
	point_index = 0
	while point_index < final_points.size():
		packed_points.append(final_points[point_index])
		point_index += 1

	return packed_points


func _resample_closed_polyline_world(points_world: Array[Vector3], spacing_world: float) -> Array[Vector3]:
	if points_world.size() < 3:
		return points_world
	if spacing_world <= 0.0001:
		return points_world

	# Compute total perimeter
	var perimeter: float = 0.0
	var index: int = 0
	while index < points_world.size():
		var point_a: Vector3 = points_world[index]
		var point_b: Vector3 = points_world[(index + 1) % points_world.size()]
		perimeter += point_a.distance_to(point_b)
		index += 1

	if perimeter <= spacing_world:
		return points_world

	var target_count: int = int(maxf(3.0, floor(perimeter / spacing_world)))
	var result: Array[Vector3] = []

	var distance_step: float = perimeter / float(target_count)
	var target_distance: float = 0.0

	var segment_index: int = 0
	var accumulated: float = 0.0

	while result.size() < target_count and segment_index < points_world.size():
		var segment_start: Vector3 = points_world[segment_index]
		var segment_end: Vector3 = points_world[(segment_index + 1) % points_world.size()]
		var segment_length: float = segment_start.distance_to(segment_end)

		if segment_length <= 0.00001:
			segment_index += 1
			continue

		while target_distance <= accumulated + segment_length and result.size() < target_count:
			var distance_into_segment: float = target_distance - accumulated
			var t_value: float = distance_into_segment / segment_length
			var sample_point: Vector3 = segment_start.lerp(segment_end, t_value)
			result.append(sample_point)
			target_distance += distance_step

		accumulated += segment_length
		segment_index += 1

	return result


func _moving_average_smooth_closed_world(points_world: Array[Vector3], window_radius: int, passes: int) -> Array[Vector3]:
	if points_world.size() < 3:
		return points_world
	if window_radius <= 0 or passes <= 0:
		return points_world

	var smoothed: Array[Vector3] = points_world
	var pass_index: int = 0

	while pass_index < passes:
		var new_points: Array[Vector3] = []
		var count: int = smoothed.size()

		var point_index: int = 0
		while point_index < count:
			var sum_x: float = 0.0
			var sum_y: float = 0.0
			var sum_z: float = 0.0
			var samples: int = 0

			var offset_index: int = -window_radius
			while offset_index <= window_radius:
				var neighbor_index: int = point_index + offset_index
				while neighbor_index < 0:
					neighbor_index += count
				while neighbor_index >= count:
					neighbor_index -= count

				var neighbor_point: Vector3 = smoothed[neighbor_index]
				sum_x += neighbor_point.x
				sum_y += neighbor_point.y
				sum_z += neighbor_point.z
				samples += 1

				offset_index += 1

			var averaged_point: Vector3 = Vector3(sum_x / float(samples), sum_y / float(samples), sum_z / float(samples))
			new_points.append(averaged_point)

			point_index += 1

		smoothed = new_points
		pass_index += 1

	return smoothed



func is_world_position_reachable(test_world: Vector3) -> bool:
	if grid_size <= 0:
		return false

	var cell_coords: Vector2i = _world_to_cell(test_world)
	if cell_coords == Vector2i(-1, -1):
		return false

	return bool(_reachable[cell_coords.x][cell_coords.y])


# -------------------------------------------------------------------
# Grid build / sampling
# -------------------------------------------------------------------
func _clear_runtime() -> void:
	grid_size = 0
	half_cells = 0
	_cells.clear()
	_reachable.clear()
	_heap.clear()


func _build_grid() -> void:
	var padded_radius: float = budget + cell_size * 2.0
	half_cells = int(ceil(padded_radius / cell_size))
	grid_size = half_cells * 2 + 1

	_cells.clear()
	_reachable.clear()

	var grid_x: int = 0
	while grid_x < grid_size:
		var column_cells: Array = []
		var column_reach: Array = []

		var grid_z: int = 0
		while grid_z < grid_size:
			column_cells.append(Cell.new())
			column_reach.append(false)
			grid_z += 1

		_cells.append(column_cells)
		_reachable.append(column_reach)
		grid_x += 1


func _sample_walkability() -> void:
	if snap_threshold <= 0.0:
		snap_threshold = cell_size * 0.6

	var grid_x: int = 0
	while grid_x < grid_size:
		var grid_z: int = 0
		while grid_z < grid_size:
			var sample_world: Vector3 = _cell_to_world_center(grid_x, grid_z)
			sample_world.y = origin_on_nav.y

			var closest_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, sample_world)
			var cell: Cell = _cells[grid_x][grid_z]

			if closest_nav.distance_to(sample_world) <= snap_threshold:
				cell.walkable = true
				cell.nav_pos = closest_nav
			else:
				cell.walkable = false
				cell.nav_pos = closest_nav

			cell.cost = INF
			grid_z += 1
		grid_x += 1


# -------------------------------------------------------------------
# Dijkstra flood fill (cost-based)
# -------------------------------------------------------------------
func _run_dijkstra() -> void:
	_heap.clear()

	var start_grid_x: int = half_cells
	var start_grid_z: int = half_cells

	var start_cell: Cell = _cells[start_grid_x][start_grid_z]
	start_cell.walkable = true
	start_cell.nav_pos = origin_on_nav
	start_cell.cost = 0.0

	_reachable[start_grid_x][start_grid_z] = true
	_heap.push(0.0, start_grid_x, start_grid_z)

	var directions_4: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	var directions_8: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	var directions_to_use: Array[Vector2i] = directions_8 if allow_diagonals else directions_4

	while not _heap.is_empty():
		var current_cost: float = _heap.peek_cost()
		var current_grid_x: int = _heap.peek_x()
		var current_grid_z: int = _heap.peek_z()
		_heap.pop()

		if current_cost > float(_cells[current_grid_x][current_grid_z].cost):
			continue

		if current_cost > budget:
			continue

		var direction_index: int = 0
		while direction_index < directions_to_use.size():
			var direction_offset: Vector2i = directions_to_use[direction_index]

			var neighbor_grid_x: int = current_grid_x + direction_offset.x
			var neighbor_grid_z: int = current_grid_z + direction_offset.y

			if neighbor_grid_x < 0 or neighbor_grid_x >= grid_size or neighbor_grid_z < 0 or neighbor_grid_z >= grid_size:
				direction_index += 1
				continue

			var current_cell: Cell = _cells[current_grid_x][current_grid_z]
			var neighbor_cell: Cell = _cells[neighbor_grid_x][neighbor_grid_z]

			if not neighbor_cell.walkable:
				direction_index += 1
				continue

			if allow_diagonals and prevent_corner_cut and direction_offset.x != 0 and direction_offset.y != 0:
				var adjacent_x_1: int = current_grid_x + direction_offset.x
				var adjacent_z_1: int = current_grid_z
				var adjacent_x_2: int = current_grid_x
				var adjacent_z_2: int = current_grid_z + direction_offset.y

				if adjacent_x_1 < 0 or adjacent_x_1 >= grid_size or adjacent_z_1 < 0 or adjacent_z_1 >= grid_size:
					direction_index += 1
					continue
				if adjacent_x_2 < 0 or adjacent_x_2 >= grid_size or adjacent_z_2 < 0 or adjacent_z_2 >= grid_size:
					direction_index += 1
					continue

				var adjacent_cell_1: Cell = _cells[adjacent_x_1][adjacent_z_1]
				var adjacent_cell_2: Cell = _cells[adjacent_x_2][adjacent_z_2]
				if not adjacent_cell_1.walkable or not adjacent_cell_2.walkable:
					direction_index += 1
					continue

			if absf(neighbor_cell.nav_pos.y - current_cell.nav_pos.y) > max_step_height:
				direction_index += 1
				continue

			var step_length: float = cell_size
			if direction_offset.x != 0 and direction_offset.y != 0:
				step_length = cell_size * 1.38421356

			var new_cost: float = current_cost + step_length
			if new_cost > budget:
				direction_index += 1
				continue

			if new_cost < float(neighbor_cell.cost):
				neighbor_cell.cost = new_cost
				_reachable[neighbor_grid_x][neighbor_grid_z] = true
				_heap.push(new_cost, neighbor_grid_x, neighbor_grid_z)

			direction_index += 1


# -------------------------------------------------------------------
# Marching Squares boundary extraction (from reachable cell samples)
# -------------------------------------------------------------------
func _extract_marching_squares_loops_from_reachable() -> Array:
	# segments: Array of [Vector2, Vector2]
	var segments: Array = []

	var square_x: int = 0
	while square_x < grid_size - 1:
		var square_z: int = 0
		while square_z < grid_size - 1:
			var bottom_left_inside: bool = bool(_reachable[square_x][square_z])
			var bottom_right_inside: bool = bool(_reachable[square_x + 1][square_z])
			var top_right_inside: bool = bool(_reachable[square_x + 1][square_z + 1])
			var top_left_inside: bool = bool(_reachable[square_x][square_z + 1])

			var case_index: int = 0
			if bottom_left_inside:
				case_index |= 1
			if bottom_right_inside:
				case_index |= 2
			if top_right_inside:
				case_index |= 4
			if top_left_inside:
				case_index |= 8

			if case_index != 0 and case_index != 15:
				_add_marching_square_segments(segments, square_x, square_z, case_index)

			square_z += 1
		square_x += 1

	if segments.is_empty():
		return []

	return _stitch_segments_into_loops(segments)


func _add_marching_square_segments(segments: Array, square_x: int, square_z: int, case_index: int) -> void:
	var point_bottom: Vector2 = Vector2(float(square_x) + 0.5, float(square_z))
	var point_right: Vector2 = Vector2(float(square_x) + 1.0, float(square_z) + 0.5)
	var point_top: Vector2 = Vector2(float(square_x) + 0.5, float(square_z) + 1.0)
	var point_left: Vector2 = Vector2(float(square_x), float(square_z) + 0.5)

	match case_index:
		1:
			segments.append([point_left, point_bottom])
		2:
			segments.append([point_bottom, point_right])
		3:
			segments.append([point_left, point_right])
		4:
			segments.append([point_right, point_top])
		5:
			# ambiguous: draw two separate segments around the two "inside" corners
			segments.append([point_left, point_bottom])
			segments.append([point_right, point_top])
		6:
			segments.append([point_bottom, point_top])
		7:
			segments.append([point_left, point_top])
		8:
			segments.append([point_top, point_left])
		9:
			segments.append([point_bottom, point_top])
		10:
			# ambiguous: draw two separate segments around the two "inside" corners
			segments.append([point_bottom, point_right])
			segments.append([point_top, point_left])
		11:
			segments.append([point_right, point_top])
		12:
			segments.append([point_left, point_right])
		13:
			segments.append([point_bottom, point_right])
		14:
			segments.append([point_left, point_bottom])
		_:
			pass


func _stitch_segments_into_loops(segments: Array) -> Array:
	# adjacency: key(String) -> Array[String] neighbor keys
	var adjacency: Dictionary = {}
	# key -> Vector2 point
	var point_by_key: Dictionary = {}
	# used undirected edges: "a|b" -> true
	var used_edges: Dictionary = {}

	var segment_index: int = 0
	while segment_index < segments.size():
		var segment: Array = segments[segment_index]
		var point_a: Vector2 = segment[0]
		var point_b: Vector2 = segment[1]

		var key_a: String = _sample_point_key(point_a)
		var key_b: String = _sample_point_key(point_b)

		point_by_key[key_a] = point_a
		point_by_key[key_b] = point_b

		if not adjacency.has(key_a):
			adjacency[key_a] = []
		if not adjacency.has(key_b):
			adjacency[key_b] = []

		(adjacency[key_a] as Array).append(key_b)
		(adjacency[key_b] as Array).append(key_a)

		segment_index += 1

	# loops: Array where each element is an Array of Vector2
	var loops: Array = []

	segment_index = 0
	while segment_index < segments.size():
		var base_segment: Array = segments[segment_index]
		var base_point_a: Vector2 = base_segment[0]
		var base_point_b: Vector2 = base_segment[1]

		var base_key_a: String = _sample_point_key(base_point_a)
		var base_key_b: String = _sample_point_key(base_point_b)

		var base_edge_key: String = _undirected_edge_key(base_key_a, base_key_b)
		if used_edges.has(base_edge_key):
			segment_index += 1
			continue

		var start_key: String = base_key_a
		var previous_key: String = base_key_a
		var current_key: String = base_key_b

		var loop_keys: Array = []
		loop_keys.append(start_key)

		used_edges[base_edge_key] = true

		var safety_counter: int = 0
		while safety_counter < 20000:
			safety_counter += 1

			loop_keys.append(current_key)
			if current_key == start_key:
				break

			var neighbor_keys: Array = adjacency.get(current_key, [])
			if neighbor_keys.is_empty():
				break

			var chosen_next_key: String = ""
			var neighbor_index: int = 0
			while neighbor_index < neighbor_keys.size():
				var candidate_key: String = neighbor_keys[neighbor_index]
				if candidate_key != previous_key:
					var candidate_edge_key: String = _undirected_edge_key(current_key, candidate_key)
					if not used_edges.has(candidate_edge_key):
						chosen_next_key = candidate_key
						break
				neighbor_index += 1

			# If everything is used (or only neighbor is previous), try any unused edge.
			if chosen_next_key.is_empty():
				neighbor_index = 0
				while neighbor_index < neighbor_keys.size():
					var candidate_key_fallback: String = neighbor_keys[neighbor_index]
					var candidate_edge_key_fallback: String = _undirected_edge_key(current_key, candidate_key_fallback)
					if not used_edges.has(candidate_edge_key_fallback):
						chosen_next_key = candidate_key_fallback
						break
					neighbor_index += 1

			if chosen_next_key.is_empty():
				break

			var step_edge_key: String = _undirected_edge_key(current_key, chosen_next_key)
			used_edges[step_edge_key] = true

			previous_key = current_key
			current_key = chosen_next_key

		# validate closed loop (last key equals start)
		if loop_keys.size() >= 4 and loop_keys[0] == loop_keys[loop_keys.size() - 1]:
			loop_keys.pop_back()

			var loop_points: Array = []
			var key_index: int = 0
			while key_index < loop_keys.size():
				var loop_key: String = loop_keys[key_index]
				var loop_point: Vector2 = point_by_key[loop_key]
				loop_points.append(loop_point)
				key_index += 1

			if loop_points.size() >= 3:
				loops.append(loop_points)

		segment_index += 1

	return loops


func _sample_point_key(sample_point: Vector2) -> String:
	# Points are on integer/half coordinates -> multiply by 2 for stable integer keys
	var key_x: int = int(round(sample_point.x * 2.0))
	var key_z: int = int(round(sample_point.y * 2.0))
	return "%d,%d" % [key_x, key_z]


func _undirected_edge_key(key_a: String, key_b: String) -> String:
	if key_a <= key_b:
		return key_a + "|" + key_b
	return key_b + "|" + key_a


# -------------------------------------------------------------------
# Conversions
# -------------------------------------------------------------------
func _cell_to_world_center(grid_x: int, grid_z: int) -> Vector3:
	var offset_x: float = float(grid_x - half_cells) * cell_size
	var offset_z: float = float(grid_z - half_cells) * cell_size
	return Vector3(origin_on_nav.x + offset_x, origin_on_nav.y, origin_on_nav.z + offset_z)


func _sample_point_to_world(sample_point: Vector2) -> Vector3:
	var offset_x: float = (sample_point.x - float(half_cells)) * cell_size
	var offset_z: float = (sample_point.y - float(half_cells)) * cell_size
	return Vector3(origin_on_nav.x + offset_x, origin_on_nav.y, origin_on_nav.z + offset_z)


func _world_to_cell(world: Vector3) -> Vector2i:
	var delta_x: float = world.x - origin_on_nav.x
	var delta_z: float = world.z - origin_on_nav.z

	var grid_x: int = int(round(delta_x / cell_size)) + half_cells
	var grid_z: int = int(round(delta_z / cell_size)) + half_cells

	if grid_x < 0 or grid_x >= grid_size or grid_z < 0 or grid_z >= grid_size:
		return Vector2i(-1, -1)

	return Vector2i(grid_x, grid_z)


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
func _loop_perimeter_world_from_sample_points(loop_points_sample: Array) -> float:
	if loop_points_sample.size() < 2:
		return 0.0

	var total: float = 0.0
	var index: int = 0
	while index < loop_points_sample.size():
		var current_sample: Vector2 = loop_points_sample[index]
		var next_sample: Vector2 = loop_points_sample[(index + 1) % loop_points_sample.size()]

		var world_a: Vector3 = _sample_point_to_world(current_sample)
		var world_b: Vector3 = _sample_point_to_world(next_sample)

		total += world_a.distance_to(world_b)
		index += 1

	return total


func _chaikin_closed(points: Array[Vector3], iterations: int) -> Array[Vector3]:
	var output_points: Array[Vector3] = points
	var iteration_index: int = 0

	while iteration_index < iterations:
		if output_points.size() < 3:
			return output_points

		var refined: Array[Vector3] = []
		var point_index: int = 0
		while point_index < output_points.size():
			var point_0: Vector3 = output_points[point_index]
			var point_1: Vector3 = output_points[(point_index + 1) % output_points.size()]

			var q_point: Vector3 = point_0.lerp(point_1, 0.25)
			var r_point: Vector3 = point_0.lerp(point_1, 0.75)

			refined.append(q_point)
			refined.append(r_point)

			point_index += 1

		output_points = refined
		iteration_index += 1

	return output_points
