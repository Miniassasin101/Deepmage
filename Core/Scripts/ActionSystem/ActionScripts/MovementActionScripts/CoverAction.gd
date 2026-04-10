class_name CoverAction
extends Action

## Action used by Cover passive skills (Aid Cover, Heavy Cover, Guard Cover, etc.).
##
## When a BEFORE_SKILL_USED passive fires with this action, the covering unit:
##   1. [Heavy Cover only] rushes adjacent to the ally first.
##   2. Swaps positions with the targeted ally via simultaneous slides.
##   3. [Guard Cover only] grants itself a one-use Block status.
##   4. Registers the redirect so TurnSystem routes the incoming attack to the
##      covering unit instead of the original target.
##
## At the end of the attacker's turn, TurnSystem automatically slides both units
## back to their original positions — unless either has moved in the meantime
## (voluntary passive movement, knockback, etc.).


@export_group("Cover Settings")
## Speed (world-units/s) used for the swap slide animation.
@export var slide_speed: float = 8.0

## If > 0, grants this many points of one-use Block to self before the attack lands.
@export var grant_block_amount: int = 0

## If true, the covering unit first moves adjacent to the ally (speed-limited)
## before performing the position swap. Used for Heavy Cover variants.
@export var move_to_ally_first: bool = false

## Radius used when searching for a ring slot adjacent to the ally (Heavy Cover).
@export var approach_avoid_radius: float = 0.6
@export var approach_sample_number: int  = 15


func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)

	# First-cover-wins: if another Cover unit already claimed this attack this turn,
	# bow out immediately without moving or overwriting their redirect/swap-back data.
	if TurnSystem.instance.pending_target_redirect != null:
		end_action()
		return

	# The ally being attacked is the source_target from the BEFORE_SKILL_USED context.
	# TurnSystem._use_passive stamps the context onto the skill's conditions before
	# running the action, but we read it directly from the chain group context here.
	var ally: Unit = _get_source_target_from_skill(targ_pack)
	if ally == null or ally == unit:
		end_action()
		return

	# Heavy Cover: rush to be adjacent to the ally before swapping.
	if move_to_ally_first:
		await _rush_adjacent_to(ally)

	# Record positions before any movement so the swap-back data is correct.
	var cover_pos: Vector3 = unit.global_position
	var ally_pos: Vector3  = ally.global_position

	# Slide both units to swapped positions simultaneously.
	await _slide_simultaneously(unit, ally_pos, ally, cover_pos)

	# Guard Cover: grant self a one-use Block before the attack resolves.
	if grant_block_amount > 0:
		_grant_block_to_self()

	# Store swap-back data so TurnSystem can reverse the swap at end of turn.
	TurnSystem.instance.pending_cover_swap_back = {
		"cover_unit":       unit,
		"ally":             ally,
		"cover_swapped_to": ally_pos,   # cover_unit is now at ally's original position
		"ally_swapped_to":  cover_pos,  # ally is now at cover_unit's original position
		"cover_return_to":  cover_pos,  # where cover_unit should return
		"ally_return_to":   ally_pos,   # where ally should return
		"slide_speed":      slide_speed,
	}

	# Register the redirect — TurnSystem will pass cover_unit as the attack target.
	TurnSystem.instance.pending_target_redirect = unit

	CombatLog.instance.add_log(unit.ui_name + " covers " + ally.ui_name + "!")
	end_action()


# ─── Private helpers ──────────────────────────────────────────────────────────

## Reads source_target from the passive skill's trigger context.
## TurnSystem._use_passive applies the context to the skill's conditions, and the
## TargetPackage carries the skill reference, so we can retrieve it from there.
func _get_source_target_from_skill(targ_pack: TargetPackage) -> Unit:
	if targ_pack == null:
		return null
	var passive_skill: Skill = targ_pack.get_skill()
	if passive_skill == null:
		return null
	# Conditions had the context stamped onto them by _apply_context_to_all_conditions.
	# The context is also stored on the first condition that has it, or we can read
	# it from the chain group. The most reliable path: read the chain group directly.
	if TurnSystem.instance.chain_group_stack.is_empty():
		return null
	var active_group: TurnSystem.ChainGroup = TurnSystem.instance.chain_group_stack.back()
	return active_group.source_target


## Slides two units to their respective destinations simultaneously.
## Fires both animations without awaiting, then awaits both movement_complete signals
## so the function returns only after the slower slide finishes.
func _slide_simultaneously(
		unit_a: Unit, dest_a: Vector3,
		unit_b: Unit, dest_b: Vector3) -> void:
	var pf: PathfindingSystem = PathfindingSystem.instance

	var pack_a: PathPackage = pf.get_path_package(dest_a, unit_a, true)
	var curve_a: Curve3D    = pack_a.get_curve_3d_from_path()
	var len_a: float        = curve_a.get_baked_length()

	var pack_b: PathPackage = pf.get_path_package(dest_b, unit_b, true)
	var curve_b: Curve3D    = pack_b.get_curve_3d_from_path()
	var len_b: float        = curve_b.get_baked_length()

	# Fire both — deliberately no await so they run in parallel.
	# stopping_distance = 0.0: must land exactly at the destination, not short of it.
	# Any stopping_distance > 0 causes cumulative drift on repeated swaps.
	unit_a.movement_controller.animate_movement_along_curve(slide_speed, curve_a, len_a, 0.0, 0.0, 0.0, 8.0)
	unit_b.movement_controller.animate_movement_along_curve(slide_speed, curve_b, len_b, 0.0, 0.0, 0.0, 8.0)

	await unit_a.movement_controller.movement_complete
	await unit_b.movement_controller.movement_complete


## Heavy Cover: moves the covering unit to the nearest open slot adjacent to the ally,
## speed-limited so the animation matches the unit's actual movement budget.
func _rush_adjacent_to(ally: Unit) -> void:
	var pf: PathfindingSystem = PathfindingSystem.instance
	var speed_value: float = float(unit.get_attributes_container().get_attribute_current_value("speed"))
	var max_distance: float = speed_value * 2.0

	# Find the nearest open ring slot around the ally.
	var candidates: Array[Vector3] = pf.get_radial_points_surrounding_unit(
		ally, approach_avoid_radius, approach_sample_number
	)
	pf.sort_positions_by_distance_inplace(candidates, unit.global_position)

	var destination: Vector3 = Vector3.ZERO
	var found: bool = false
	for candidate in candidates:
		if _is_occupied(candidate):
			continue
		var test_pack: PathPackage = pf.get_path_package(candidate, unit, true)
		var test_len: float = test_pack.get_curve_3d_from_path().get_baked_length()
		if test_len <= max_distance + 0.01:
			destination = candidate
			found = true
			break

	if !found:
		return  # can't reach — skip the rush, still do the swap from current position

	var pack: PathPackage = pf.get_path_package(destination, unit, true)
	var curve: Curve3D    = pack.get_curve_3d_from_path()
	var length: float     = minf(curve.get_baked_length(), max_distance)

	unit.movement_controller.animate_movement_along_curve(slide_speed, curve, length, 0.0, 0.0, 0.05, 8.0)
	await unit.movement_controller.movement_complete


## Grants a one-use Block status to the covering unit.
func _grant_block_to_self() -> void:
	var controller: StatusController = unit.get_status_controller()
	if controller == null:
		return
	var block: BlockStatus = BlockStatus.new()
	block.status_level   = grant_block_amount
	block.expire_timing  = Status.ExpireTiming.OnUse
	block.ui_name        = "Block"
	controller.add_status(block)
	Utilities.spawn_text_line(unit, "Guard! +" + str(grant_block_amount), Color.AQUA)


## Returns true if any other unit occupies pos within approach_avoid_radius.
func _is_occupied(pos: Vector3) -> bool:
	for other in UnitManager.instance.get_all_units():
		if other == unit:
			continue
		if other.global_transform.origin.distance_to(pos) < approach_avoid_radius:
			return true
	return false
