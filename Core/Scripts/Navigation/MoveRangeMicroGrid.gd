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
			# FIX: heap parent must be floor((index - 1) / 2)
			@warning_ignore("narrowing_conversion")
			var parent_index: int = (index - 1) / 2.0
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


# -------------------------------------------------------------------
# Config (set from your PathfindingSystem / game)
# -------------------------------------------------------------------
var navmap: RID = RID()
var cell_size: float = 0.33
var snap_threshold: float = 0.20
var max_step_height: float = 0.75

# Bigger stencil => more circle-like in open space.
# 1 => ~8-way, 2 => ~24-way, 3 => ~48-way (after circular trimming)
var neighbor_radius_cells: int = 3

# If true, any multi-cell step must have all crossed cells walkable (supercover line).
var prevent_skipping_through_obstacles: bool = false

# Boundary extraction mode
var use_marching_squares: bool = true

# Smoothing controls (THIS is what you lost in the jagged version)
var resample_spacing_world: float = 0.20		# if <= 0, auto = cell_size * 0.35
var average_window_radius: int = 4			# 2–4 are typical
var average_passes: int = 6					# 1–3 are typical
var chaikin_iterations: int = 0				# optional extra rounding (0 to disable)

# If you want to drop super tiny segments before smoothing
var simplify_epsilon_world: float = 0.0		# if <= 0, auto = cell_size * 0.1


# -------------------------------------------------------------------
# Runtime
# -------------------------------------------------------------------
var origin_world: Vector3 = Vector3.ZERO
var origin_on_nav: Vector3 = Vector3.ZERO
var budget: float = 0.0

var grid_size: int = 0
var half_cells: int = 0
var _cells: Array = []			# columns -> rows -> Cell (untyped because nested typed collections aren’t supported)
var _reachable: Array = []		# columns -> rows -> bool (untyped)

var _heap: MinHeap = MinHeap.new()
var _neighbor_offsets: Array[Vector2i] = []
var _neighbor_costs: Array[float] = []



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
	_build_neighbor_offsets()
	_run_dijkstra()


func get_best_boundary_world(height_offset: float = 0.06) -> PackedVector3Array:
	if grid_size <= 0:
		return PackedVector3Array()

	var loops: Array = []
	if use_marching_squares:
		loops = _extract_marching_squares_loops_from_reachable()
	else:
		loops = _extract_boundary_loops_from_reachable_edges()

	if loops.is_empty():
		return PackedVector3Array()

	var best_loop: Array = []
	var best_perimeter: float = -1.0

	var loop_index: int = 0
	while loop_index < loops.size():
		var candidate_loop: Array = loops[loop_index]
		var candidate_perimeter: float = 0.0
		if use_marching_squares:
			candidate_perimeter = _loop_perimeter_world_from_halfkeys(candidate_loop)
		else:
			candidate_perimeter = _loop_perimeter_world_from_vertices(candidate_loop)

		if candidate_perimeter > best_perimeter:
			best_perimeter = candidate_perimeter
			best_loop = candidate_loop

		loop_index += 1

	if best_loop.size() < 3:
		return PackedVector3Array()

	var boundary_points_world: Array[Vector3] = []
	if use_marching_squares:
		boundary_points_world = _halfkey_loop_to_world_points(best_loop)
	else:
		boundary_points_world = _vertex_loop_to_world_points(best_loop)

	boundary_points_world = _postprocess_boundary_world(boundary_points_world)

	boundary_points_world = _apply_height_only(boundary_points_world, height_offset)

	var packed_points: PackedVector3Array = PackedVector3Array()
	var point_index: int = 0
	while point_index < boundary_points_world.size():
		packed_points.append(boundary_points_world[point_index])
		point_index += 1

	return packed_points


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
	_neighbor_offsets.clear()
	_neighbor_costs.clear()


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

	# Anything beyond this radius can never be reachable, so don’t nav-sample it.
	var max_distance_world: float = budget + cell_size * 1.5
	var max_distance_sq: float = max_distance_world * max_distance_world

	var grid_x: int = 0
	while grid_x < grid_size:
		var grid_z: int = 0
		while grid_z < grid_size:
			var cell: Cell = _cells[grid_x][grid_z]
			cell.cost = INF

			var sample_world: Vector3 = _cell_to_world_center(grid_x, grid_z)
			var delta_x: float = sample_world.x - origin_on_nav.x
			var delta_z: float = sample_world.z - origin_on_nav.z
			var distance_sq: float = delta_x * delta_x + delta_z * delta_z

			if distance_sq > max_distance_sq:
				cell.walkable = false
				cell.nav_pos = sample_world
				grid_z += 1
				continue

			sample_world.y = origin_on_nav.y
			var closest_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, sample_world)
			cell.nav_pos = closest_nav

			if closest_nav.distance_to(sample_world) <= snap_threshold:
				cell.walkable = true
			else:
				cell.walkable = false

			grid_z += 1
		grid_x += 1



func _build_neighbor_offsets() -> void:
	_neighbor_offsets.clear()
	_neighbor_costs.clear()

	var radius_cells: int = clampi(neighbor_radius_cells, 1, 6)

	var offset_x: int = -radius_cells
	while offset_x <= radius_cells:
		var offset_z: int = -radius_cells
		while offset_z <= radius_cells:
			if offset_x == 0 and offset_z == 0:
				offset_z += 1
				continue

			var offset_length_sq: int = offset_x * offset_x + offset_z * offset_z
			var radius_sq: int = radius_cells * radius_cells
			if offset_length_sq > radius_sq:
				offset_z += 1
				continue

			var step_cost: float = _step_cost_world(offset_x, offset_z)
			_neighbor_offsets.append(Vector2i(offset_x, offset_z))
			_neighbor_costs.append(step_cost)

			offset_z += 1
		offset_x += 1

	_sort_neighbors_by_cost()

func _sort_neighbors_by_cost() -> void:
	var indices: Array[int] = []
	var index: int = 0
	while index < _neighbor_costs.size():
		indices.append(index)
		index += 1

	indices.sort_custom(func(a: int, b: int) -> bool:
		return _neighbor_costs[a] < _neighbor_costs[b]
	)

	var sorted_offsets: Array[Vector2i] = []
	var sorted_costs: Array[float] = []

	index = 0
	while index < indices.size():
		var source_index: int = indices[index]
		sorted_offsets.append(_neighbor_offsets[source_index])
		sorted_costs.append(_neighbor_costs[source_index])
		index += 1

	_neighbor_offsets = sorted_offsets
	_neighbor_costs = sorted_costs


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

	_heap.push(0.0, start_grid_x, start_grid_z)

	while not _heap.is_empty():
		var current_cost: float = _heap.peek_cost()
		var current_grid_x: int = _heap.peek_x()
		var current_grid_z: int = _heap.peek_z()
		_heap.pop()

		var stored_cost: float = float(_cells[current_grid_x][current_grid_z].cost)
		if current_cost > stored_cost:
			continue

		if current_cost > budget:
			continue

		var current_cell: Cell = _cells[current_grid_x][current_grid_z]
		var remaining_budget: float = budget - current_cost

		var neighbor_offset_index: int = 0
		while neighbor_offset_index < _neighbor_offsets.size():
			# OPT #4: precomputed cost + early-break (neighbors sorted by cost)
			var step_world_cost: float = _neighbor_costs[neighbor_offset_index]
			if step_world_cost > remaining_budget:
				break

			var neighbor_offset: Vector2i = _neighbor_offsets[neighbor_offset_index]

			var neighbor_grid_x: int = current_grid_x + neighbor_offset.x
			var neighbor_grid_z: int = current_grid_z + neighbor_offset.y

			if neighbor_grid_x < 0 or neighbor_grid_x >= grid_size or neighbor_grid_z < 0 or neighbor_grid_z >= grid_size:
				neighbor_offset_index += 1
				continue

			var neighbor_cell: Cell = _cells[neighbor_grid_x][neighbor_grid_z]
			if not neighbor_cell.walkable:
				neighbor_offset_index += 1
				continue

			var height_delta: float = absf(neighbor_cell.nav_pos.y - current_cell.nav_pos.y)
			if height_delta > max_step_height:
				neighbor_offset_index += 1
				continue

			if prevent_skipping_through_obstacles:
				var step_is_clear: bool = _is_step_clear_supercover(
					current_grid_x,
					current_grid_z,
					neighbor_grid_x,
					neighbor_grid_z
				)
				if not step_is_clear:
					neighbor_offset_index += 1
					continue

			var new_cost: float = current_cost + step_world_cost

			var neighbor_stored_cost: float = float(neighbor_cell.cost)
			if new_cost < neighbor_stored_cost:
				neighbor_cell.cost = new_cost
				_heap.push(new_cost, neighbor_grid_x, neighbor_grid_z)

			neighbor_offset_index += 1

	# LAST WIN: rebuild reachability in one cache-friendly pass
	_rebuild_reachable_from_cost()



func _rebuild_reachable_from_cost() -> void:
	if grid_size <= 0:
		return

	var grid_x: int = 0
	while grid_x < grid_size:
		var reachable_column: Array = _reachable[grid_x]
		var cell_column: Array = _cells[grid_x]

		var grid_z: int = 0
		while grid_z < grid_size:
			var cell: Cell = cell_column[grid_z]
			var is_reachable: bool = cell.walkable and float(cell.cost) <= budget
			reachable_column[grid_z] = is_reachable
			grid_z += 1

		grid_x += 1


func _step_cost_world(delta_grid_x: int, delta_grid_z: int) -> float:
	var delta_x: float = float(delta_grid_x)
	var delta_z: float = float(delta_grid_z)
	return cell_size * sqrt(delta_x * delta_x + delta_z * delta_z)


func _is_step_clear_supercover(start_grid_x: int, start_grid_z: int, end_grid_x: int, end_grid_z: int) -> bool:
	var crossed_cells: Array[Vector2i] = _supercover_line_cells(start_grid_x, start_grid_z, end_grid_x, end_grid_z)
	if crossed_cells.size() <= 1:
		return true

	var previous_coords: Vector2i = crossed_cells[0]
	var previous_cell: Cell = _cells[previous_coords.x][previous_coords.y]

	var index: int = 1
	while index < crossed_cells.size():
		var coords: Vector2i = crossed_cells[index]

		if coords.x < 0 or coords.x >= grid_size or coords.y < 0 or coords.y >= grid_size:
			return false

		var cell: Cell = _cells[coords.x][coords.y]
		if not cell.walkable:
			return false

		if absf(cell.nav_pos.y - previous_cell.nav_pos.y) > max_step_height:
			return false

		previous_cell = cell
		index += 1

	return true


func _supercover_line_cells(start_grid_x: int, start_grid_z: int, end_grid_x: int, end_grid_z: int) -> Array[Vector2i]:
	var crossed: Array[Vector2i] = []

	var current_x: int = start_grid_x
	var current_z: int = start_grid_z

	var delta_x: int = abs(end_grid_x - start_grid_x)
	var delta_z: int = abs(end_grid_z - start_grid_z)

	var step_x: int = 1 if start_grid_x < end_grid_x else -1
	var step_z: int = 1 if start_grid_z < end_grid_z else -1

	var error_value: int = delta_x - delta_z

	crossed.append(Vector2i(current_x, current_z))

	while not (current_x == end_grid_x and current_z == end_grid_z):
		var previous_x: int = current_x
		var previous_z: int = current_z

		var twice_error: int = error_value * 2

		if twice_error > -delta_z:
			error_value -= delta_z
			current_x += step_x

		if twice_error < delta_x:
			error_value += delta_x
			current_z += step_z

		if current_x != previous_x and current_z != previous_z:
			crossed.append(Vector2i(previous_x, current_z))
			crossed.append(Vector2i(current_x, previous_z))

		crossed.append(Vector2i(current_x, current_z))

	return crossed


# -------------------------------------------------------------------
# Marching Squares boundary extraction (preferred)
# Produces loops of “half-grid” keys: Vector2i where 1 unit = half a cell.
# -------------------------------------------------------------------
func _extract_marching_squares_loops_from_reachable() -> Array:
	# segments: Array of [Vector2i, Vector2i] where keys are in half-cell coordinates
	var segments: Array = []

	var square_x: int = 0
	while square_x < grid_size - 1:
		var square_z: int = 0
		while square_z < grid_size - 1:
			var bottom_left: bool = bool(_reachable[square_x][square_z])
			var bottom_right: bool = bool(_reachable[square_x + 1][square_z])
			var top_right: bool = bool(_reachable[square_x + 1][square_z + 1])
			var top_left: bool = bool(_reachable[square_x][square_z + 1])

			var case_index: int = 0
			if bottom_left:
				case_index |= 1
			if bottom_right:
				case_index |= 2
			if top_right:
				case_index |= 4
			if top_left:
				case_index |= 8

			_add_marching_segments_for_case(square_x, square_z, case_index, segments)

			square_z += 1
		square_x += 1

	if segments.is_empty():
		return []

	# Build adjacency: key(Vector2i) -> Array of neighbor keys (untyped array)
	var adjacency: Dictionary = {}

	var segment_index: int = 0
	while segment_index < segments.size():
		var segment: Array = segments[segment_index]
		var key_a: Vector2i = segment[0]
		var key_b: Vector2i = segment[1]

		if not adjacency.has(key_a):
			adjacency[key_a] = []
		if not adjacency.has(key_b):
			adjacency[key_b] = []

		(adjacency[key_a] as Array).append(key_b)
		(adjacency[key_b] as Array).append(key_a)

		segment_index += 1

	# Stitch segments into loops (similar to your edge-loop stitcher)
	var used_edges: Dictionary = {}
	var loops: Array = []

	segment_index = 0
	while segment_index < segments.size():
		var start_segment: Array = segments[segment_index]
		var start_key: Vector2i = start_segment[0]
		var next_key: Vector2i = start_segment[1]

		var start_edge_key: String = _halfkey_edge_key(start_key, next_key)
		if used_edges.has(start_edge_key):
			segment_index += 1
			continue

		used_edges[start_edge_key] = true

		var loop_keys: Array = []
		loop_keys.append(start_key)
		loop_keys.append(next_key)

		var previous_key: Vector2i = start_key
		var current_key: Vector2i = next_key

		var safety_counter: int = 0
		while current_key != start_key and safety_counter < 200000:
			safety_counter += 1

			var neighbor_list: Array = adjacency.get(current_key, [])
			if neighbor_list.size() == 0:
				break

			var chosen_next: Vector2i = Vector2i.ZERO
			if neighbor_list.size() == 1:
				chosen_next = neighbor_list[0]
			else:
				var neighbor_a: Vector2i = neighbor_list[0]
				var neighbor_b: Vector2i = neighbor_list[1]
				chosen_next = neighbor_a if neighbor_a != previous_key else neighbor_b

			var step_edge_key: String = _halfkey_edge_key(current_key, chosen_next)
			if used_edges.has(step_edge_key):
				# Try alternate if available
				if neighbor_list.size() > 2:
					var found_alternate: bool = false
					var neighbor_index: int = 0
					while neighbor_index < neighbor_list.size():
						var candidate: Vector2i = neighbor_list[neighbor_index]
						if candidate == previous_key:
							neighbor_index += 1
							continue
						var candidate_key: String = _halfkey_edge_key(current_key, candidate)
						if not used_edges.has(candidate_key):
							chosen_next = candidate
							step_edge_key = candidate_key
							found_alternate = true
							break
						neighbor_index += 1
					if not found_alternate:
						break
				else:
					break

			used_edges[step_edge_key] = true
			previous_key = current_key
			current_key = chosen_next
			loop_keys.append(current_key)

		if loop_keys.size() >= 4 and loop_keys[0] == loop_keys[loop_keys.size() - 1]:
			loop_keys.pop_back()
			loops.append(loop_keys)

		segment_index += 1

	return loops


func _add_marching_segments_for_case(square_x: int, square_z: int, case_index: int, segments_out: Array) -> void:
	# Half-key coordinates:
	# Corner sample coords are (square_x, square_z) etc in sample-grid space.
	# Contour points lie on edges at midpoints, represented in half-cell keys:
	# bottom edge midpoint: (2*square_x + 1, 2*square_z)
	# right edge midpoint:  (2*square_x + 2, 2*square_z + 1)
	# top edge midpoint:    (2*square_x + 1, 2*square_z + 2)
	# left edge midpoint:   (2*square_x,     2*square_z + 1)

	var base_key_x: int = square_x * 2
	var base_key_z: int = square_z * 2

	var edge_bottom: Vector2i = Vector2i(base_key_x + 1, base_key_z + 0)
	var edge_right: Vector2i = Vector2i(base_key_x + 2, base_key_z + 1)
	var edge_top: Vector2i = Vector2i(base_key_x + 1, base_key_z + 2)
	var edge_left: Vector2i = Vector2i(base_key_x + 0, base_key_z + 1)

	# Standard marching squares segment table for binary filled region (inside = reachable)
	match case_index:
		0:
			return
		1:
			segments_out.append([edge_left, edge_bottom])
		2:
			segments_out.append([edge_bottom, edge_right])
		3:
			segments_out.append([edge_left, edge_right])
		4:
			segments_out.append([edge_right, edge_top])
		5:
			segments_out.append([edge_left, edge_bottom])
			segments_out.append([edge_right, edge_top])
		6:
			segments_out.append([edge_bottom, edge_top])
		7:
			segments_out.append([edge_left, edge_top])
		8:
			segments_out.append([edge_top, edge_left])
		9:
			segments_out.append([edge_top, edge_bottom])
		10:
			segments_out.append([edge_bottom, edge_right])
			segments_out.append([edge_top, edge_left])
		11:
			segments_out.append([edge_right, edge_top])
		12:
			segments_out.append([edge_right, edge_left])
		13:
			segments_out.append([edge_bottom, edge_right])
		14:
			segments_out.append([edge_left, edge_bottom])
		15:
			return


func _halfkey_edge_key(key_a: Vector2i, key_b: Vector2i) -> String:
	if key_a.x < key_b.x or (key_a.x == key_b.x and key_a.y <= key_b.y):
		return "%d,%d|%d,%d" % [key_a.x, key_a.y, key_b.x, key_b.y]
	return "%d,%d|%d,%d" % [key_b.x, key_b.y, key_a.x, key_a.y]


func _halfkey_to_sample_point(half_key: Vector2i) -> Vector2:
	return Vector2(float(half_key.x) * 0.5, float(half_key.y) * 0.5)


func _sample_point_to_world(sample_point: Vector2) -> Vector3:
	# sample_point is in “cell center index space” (same as _reachable indices),
	# so (half_cells, half_cells) maps to origin_on_nav.
	var offset_x: float = (sample_point.x - float(half_cells)) * cell_size
	var offset_z: float = (sample_point.y - float(half_cells)) * cell_size
	return Vector3(origin_on_nav.x + offset_x, origin_on_nav.y, origin_on_nav.z + offset_z)


func _halfkey_loop_to_world_points(loop_halfkeys: Array) -> Array[Vector3]:
	var world_points: Array[Vector3] = []
	var index: int = 0
	while index < loop_halfkeys.size():
		var half_key: Vector2i = loop_halfkeys[index]
		var sample_point: Vector2 = _halfkey_to_sample_point(half_key)
		var world_point: Vector3 = _sample_point_to_world(sample_point)
		world_points.append(world_point)
		index += 1
	return world_points


func _loop_perimeter_world_from_halfkeys(loop_halfkeys: Array) -> float:
	if loop_halfkeys.size() < 2:
		return 0.0

	var total: float = 0.0
	var index: int = 0
	while index < loop_halfkeys.size():
		var key_a: Vector2i = loop_halfkeys[index]
		var key_b: Vector2i = loop_halfkeys[(index + 1) % loop_halfkeys.size()]
		var point_a: Vector3 = _sample_point_to_world(_halfkey_to_sample_point(key_a))
		var point_b: Vector3 = _sample_point_to_world(_halfkey_to_sample_point(key_b))
		total += point_a.distance_to(point_b)
		index += 1

	return total


# -------------------------------------------------------------------
# Fallback: your original edge-based boundary extraction (kept)
# -------------------------------------------------------------------
func _extract_boundary_loops_from_reachable_edges() -> Array:
	var edges: Array = []

	var grid_x: int = 0
	while grid_x < grid_size:
		var grid_z: int = 0
		while grid_z < grid_size:
			if bool(_reachable[grid_x][grid_z]):
				var vertex_00: Vector2i = Vector2i(grid_x, grid_z)
				var vertex_10: Vector2i = Vector2i(grid_x + 1, grid_z)
				var vertex_01: Vector2i = Vector2i(grid_x, grid_z + 1)
				var vertex_11: Vector2i = Vector2i(grid_x + 1, grid_z + 1)

				if grid_x == 0 or not bool(_reachable[grid_x - 1][grid_z]):
					edges.append([vertex_00, vertex_01])
				if grid_x == grid_size - 1 or not bool(_reachable[grid_x + 1][grid_z]):
					edges.append([vertex_10, vertex_11])
				if grid_z == 0 or not bool(_reachable[grid_x][grid_z - 1]):
					edges.append([vertex_00, vertex_10])
				if grid_z == grid_size - 1 or not bool(_reachable[grid_x][grid_z + 1]):
					edges.append([vertex_01, vertex_11])

			grid_z += 1
		grid_x += 1

	if edges.is_empty():
		return []

	var adjacency: Dictionary = {}

	var edge_index: int = 0
	while edge_index < edges.size():
		var edge: Array = edges[edge_index]
		var point_a: Vector2i = edge[0]
		var point_b: Vector2i = edge[1]

		if not adjacency.has(point_a):
			adjacency[point_a] = []
		if not adjacency.has(point_b):
			adjacency[point_b] = []

		(adjacency[point_a] as Array).append(point_b)
		(adjacency[point_b] as Array).append(point_a)

		edge_index += 1

	var used_edges: Dictionary = {}
	var loops: Array = []

	edge_index = 0
	while edge_index < edges.size():
		var start_edge: Array = edges[edge_index]
		var start_point: Vector2i = start_edge[0]
		var next_point: Vector2i = start_edge[1]

		var start_edge_key: String = _vertex_edge_key(start_point, next_point)
		if used_edges.has(start_edge_key):
			edge_index += 1
			continue

		used_edges[start_edge_key] = true

		var loop_vertices: Array = []
		loop_vertices.append(start_point)
		loop_vertices.append(next_point)

		var previous_point: Vector2i = start_point
		var current_point: Vector2i = next_point

		var safety_counter: int = 0
		while current_point != start_point and safety_counter < 200000:
			safety_counter += 1

			var neighbors: Array = adjacency.get(current_point, [])
			if neighbors.size() == 0:
				break

			var chosen_next: Vector2i = Vector2i.ZERO
			if neighbors.size() == 1:
				chosen_next = neighbors[0]
			else:
				var first_neighbor: Vector2i = neighbors[0]
				var second_neighbor: Vector2i = neighbors[1]
				chosen_next = first_neighbor if first_neighbor != previous_point else second_neighbor

			var step_edge_key: String = _vertex_edge_key(current_point, chosen_next)
			if used_edges.has(step_edge_key):
				break

			used_edges[step_edge_key] = true
			previous_point = current_point
			current_point = chosen_next
			loop_vertices.append(current_point)

		if loop_vertices.size() >= 4 and loop_vertices[0] == loop_vertices[loop_vertices.size() - 1]:
			loop_vertices.pop_back()
			loops.append(loop_vertices)

		edge_index += 1

	return loops


func _vertex_edge_key(point_a: Vector2i, point_b: Vector2i) -> String:
	if point_a.x < point_b.x or (point_a.x == point_b.x and point_a.y <= point_b.y):
		return "%d,%d|%d,%d" % [point_a.x, point_a.y, point_b.x, point_b.y]
	return "%d,%d|%d,%d" % [point_b.x, point_b.y, point_a.x, point_a.y]


func _vertex_loop_to_world_points(loop_vertices: Array) -> Array[Vector3]:
	var world_points: Array[Vector3] = []
	var index: int = 0
	while index < loop_vertices.size():
		var vertex: Vector2i = loop_vertices[index]
		var vertex_world: Vector3 = _vertex_to_world(vertex)
		world_points.append(vertex_world)
		index += 1
	return world_points


func _loop_perimeter_world_from_vertices(loop_vertices: Array) -> float:
	if loop_vertices.size() < 2:
		return 0.0

	var total: float = 0.0
	var index: int = 0
	while index < loop_vertices.size():
		var current_vertex: Vector2i = loop_vertices[index]
		var next_vertex: Vector2i = loop_vertices[(index + 1) % loop_vertices.size()]

		var world_a: Vector3 = _vertex_to_world(current_vertex)
		var world_b: Vector3 = _vertex_to_world(next_vertex)

		total += world_a.distance_to(world_b)
		index += 1

	return total


# -------------------------------------------------------------------
# Conversions (cell centers + grid vertices)
# -------------------------------------------------------------------
func _cell_to_world_center(grid_x: int, grid_z: int) -> Vector3:
	var offset_x: float = float(grid_x - half_cells) * cell_size
	var offset_z: float = float(grid_z - half_cells) * cell_size
	return Vector3(origin_on_nav.x + offset_x, origin_on_nav.y, origin_on_nav.z + offset_z)


func _vertex_to_world(vertex: Vector2i) -> Vector3:
	var offset_x: float = (float(vertex.x) - float(half_cells) - 0.5) * cell_size
	var offset_z: float = (float(vertex.y) - float(half_cells) - 0.5) * cell_size
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
# Post-processing (RESTORED): simplify -> resample -> moving average -> optional Chaikin
# -------------------------------------------------------------------
func _postprocess_boundary_world(points_world: Array[Vector3]) -> Array[Vector3]:
	if points_world.size() < 3:
		return points_world

	var epsilon_world: float = simplify_epsilon_world
	if epsilon_world <= 0.0:
		epsilon_world = cell_size * 0.1

	var processed: Array[Vector3] = _remove_near_duplicates_closed_world(points_world, epsilon_world)

	var spacing_world: float = resample_spacing_world
	if spacing_world <= 0.0:
		# Smaller spacing => less “hexagon/polygon” look
		spacing_world = cell_size * 0.35

	processed = _resample_closed_polyline_world(processed, spacing_world)

	if average_window_radius > 0 and average_passes > 0:
		processed = _moving_average_smooth_closed_world(processed, average_window_radius, average_passes)

	if chaikin_iterations > 0:
		processed = _chaikin_closed(processed, chaikin_iterations)

	return processed


func _remove_near_duplicates_closed_world(points_world: Array[Vector3], epsilon_world: float) -> Array[Vector3]:
	if points_world.size() < 3:
		return points_world
	if epsilon_world <= 0.0:
		return points_world

	var result: Array[Vector3] = []
	var count: int = points_world.size()

	var index: int = 0
	while index < count:
		var point: Vector3 = points_world[index]
		if result.is_empty():
			result.append(point)
		else:
			var previous: Vector3 = result[result.size() - 1]
			if previous.distance_to(point) > epsilon_world:
				result.append(point)
		index += 1

	# Also check closure seam
	if result.size() >= 2:
		var first_point: Vector3 = result[0]
		var last_point: Vector3 = result[result.size() - 1]
		if last_point.distance_to(first_point) <= epsilon_world:
			result.pop_back()

	return result


func _apply_height_only(points_world: Array[Vector3], height_offset: float) -> Array[Vector3]:
	# Important: don’t “snap” XZ here or you reintroduce wobble.
	# If you need height from navmesh, only copy Y when the closest point is nearby.
	var result: Array[Vector3] = []
	var index: int = 0
	while index < points_world.size():
		var world_point: Vector3 = points_world[index]
		var query_point: Vector3 = world_point
		query_point.y = origin_on_nav.y

		var closest_nav: Vector3 = NavigationServer3D.map_get_closest_point(navmap, query_point)

		var horizontal_distance: float = Vector2(query_point.x, query_point.z).distance_to(Vector2(closest_nav.x, closest_nav.z))
		if horizontal_distance <= snap_threshold:
			world_point.y = closest_nav.y
		else:
			world_point.y = origin_on_nav.y

		world_point.y += height_offset
		world_point += Utilities.nav_vector_offset

		result.append(world_point)
		index += 1

	return result


# --- Your original smooth helpers (unchanged logic, just typed vars) ---
func _resample_closed_polyline_world(points_world: Array[Vector3], spacing_world: float) -> Array[Vector3]:
	if points_world.size() < 3:
		return points_world
	if spacing_world <= 0.0001:
		return points_world

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


func _chaikin_closed(points: Array[Vector3], iterations: int) -> Array[Vector3]:
	var output_points: Array[Vector3] = points
	var iteration_index: int = 0

	while iteration_index < iterations:
		if output_points.size() < 3:
			return output_points

		var refined: Array[Vector3] = []
		var point_index: int = 0
		while point_index < output_points.size():
			var point_a: Vector3 = output_points[point_index]
			var point_b: Vector3 = output_points[(point_index + 1) % output_points.size()]

			var quarter_point: Vector3 = point_a.lerp(point_b, 0.25)
			var three_quarter_point: Vector3 = point_a.lerp(point_b, 0.75)

			refined.append(quarter_point)
			refined.append(three_quarter_point)

			point_index += 1

		output_points = refined
		iteration_index += 1

	return output_points
