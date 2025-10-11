@tool
class_name MoveToSafetySkill
extends Skill


# A positional Skill: activates only when threatened, then picks a safe point
# using ordered PositionPreferences, and triggers your MoveAction via TargetPackage.


@export var position_sampler: RetreatRingSampler
@export var position_preferences: Array[PositionPreference] = []
@export var safe_distance_from_enemies: float = 8.0

# --- Helper: create a position TargetPackage (adjust to your actual API) -----
func _make_position_target_package(target_pos: Vector3) -> TargetPackage:
	var pkg := TargetPackage.new()
	pkg.position = target_pos
	pkg.add_tag("position")
	return pkg

# Override activation to target a position instead of a unit.
func activate_skill() -> void:
	if unit == null:
		push_error("MoveToSafetySkill: unit is null")
		return

	if action == null:
		push_error("MoveToSafetySkill: action is null (expecting MoveAction)")
		return

	# 1) Generate candidates on the navmesh.
	if position_sampler == null:
		push_error("MoveToSafetySkill: position_sampler is null")
		return

	var candidates: Array[Vector3] = position_sampler.get_candidate_positions(unit)
	if candidates.is_empty():
		push_error("MoveToSafetySkill: no candidates from sampler")
		return

	# 2) Enforce "safe distance" hard rule up front.
	var safe_candidates: Array[Vector3] = []
	for candidate in candidates:
		if _is_point_safe_from_enemies(candidate, unit, safe_distance_from_enemies):
			safe_candidates.append(candidate)

	if safe_candidates.is_empty():
		push_error("MoveToSafetySkill: no safe candidates beyond min distance")
		return

	# 3) Apply ordered position preferences to narrow ties.
	var pool: Array[Vector3] = safe_candidates.duplicate()
	for pref in position_preferences:
		if pool.size() <= 1:
			break
		if pref:
			var narrowed := pref.apply(self, unit, pool)
			if not narrowed.is_empty():
				pool = narrowed

	# 4) Choose one (random among equals), package it, and run the MoveAction.
	var chosen_pos: Vector3 = pool.pick_random()
	var target_pkg: TargetPackage = _make_position_target_package(chosen_pos)

	unit.character_sheet.action_container.use_action(action, target_pkg)
	await SignalBus.on_action_ended

	end_skill()


func _is_point_safe_from_enemies(point: Vector3, owner: Unit, min_distance: float) -> bool:
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == owner:
			continue
		if other_unit.is_enemy != owner.is_enemy:
			var d: float = other_unit.global_transform.origin.distance_to(point)
			if d < min_distance:
				return false
	return true
