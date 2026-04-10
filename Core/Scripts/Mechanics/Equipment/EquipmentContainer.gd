class_name EquipmentContainer
extends Node

## Emitted whenever a slot's contents change (item may be null when emptied).
signal equipment_changed(slot: StringName, item: BuildSource)

@export var unit: Unit

# ─── Slot name constants ───────────────────────────────────────────────────
const WEAPON_MAIN  := &"weapon_main"
const WEAPON_SUB   := &"weapon_sub"
const ARMOR        := &"armor"
const ACCESSORY_1  := &"accessory_1"
const ACCESSORY_2  := &"accessory_2"

## Live slot contents.  StringName → BuildSource (or absent when empty).
var slots: Dictionary = {}

## Spawned 3-D visual nodes per slot, freed on unequip.
var slot_visuals: Dictionary = {}  # StringName → Node3D

## All gear the unit is carrying.  Picker panels read from this list.
## Items in an equipped slot remain in this array — equipping never removes them.
@export var carried_gear: Array[BuildSource] = []


func _ready() -> void:
	if unit == null:
		# EquipmentContainer sits inside CharacterSheet which sits inside Unit.
		var cs := get_parent() as CharacterSheet
		if cs:
			unit = cs.unit
		else:
			unit = get_parent() as Unit


# =============================================================================
# Public API
# =============================================================================

## Equip [param item] into [param slot].  Any current occupant is unequipped first.
func equip(item: BuildSource, slot: StringName) -> void:
	if slots.get(slot) != null:
		unequip(slot)

	# Block sub-weapon if main weapon is two-handed.
	if slot == WEAPON_SUB:
		var main := slots.get(WEAPON_MAIN) as Weapon
		if main != null and main.is_two_handed:
			push_warning("EquipmentContainer: cannot equip sub-weapon while main is two-handed.")
			return

	# Unequip sub-weapon when equipping a two-hander into main.
	if slot == WEAPON_MAIN and item is Weapon and (item as Weapon).is_two_handed:
		unequip(WEAPON_SUB)

	slots[slot] = item
	_apply_item_to_build(item, slot)
	_spawn_visual(item, slot)
	equipment_changed.emit(slot, item)


## Remove whatever is in [param slot].  Returns the removed item (or null).
func unequip(slot: StringName) -> BuildSource:
	var item: BuildSource = slots.get(slot, null)
	if item == null:
		return null
	slots.erase(slot)
	_remove_item_from_build(item)
	_destroy_visual(slot)
	equipment_changed.emit(slot, null)
	return item


## Swap the contents of two slots (handles visuals and build effects atomically).
func swap_slots(slot_a: StringName, slot_b: StringName) -> void:
	var item_a: BuildSource = slots.get(slot_a, null)
	var item_b: BuildSource = slots.get(slot_b, null)

	# Tear down both sides first.
	if item_a != null:
		_remove_item_from_build(item_a)
		_destroy_visual(slot_a)
	if item_b != null:
		_remove_item_from_build(item_b)
		_destroy_visual(slot_b)

	# Reassign.
	if item_b != null:
		slots[slot_a] = item_b
	else:
		slots.erase(slot_a)
	if item_a != null:
		slots[slot_b] = item_a
	else:
		slots.erase(slot_b)

	# Rebuild both sides in their new positions.
	if item_b != null:
		_apply_item_to_build(item_b, slot_a)
		_spawn_visual(item_b, slot_a)
	if item_a != null:
		_apply_item_to_build(item_a, slot_b)
		_spawn_visual(item_a, slot_b)

	equipment_changed.emit(slot_a, slots.get(slot_a))
	equipment_changed.emit(slot_b, slots.get(slot_b))


## Returns the item in [param slot], or null.
func get_item(slot: StringName) -> BuildSource:
	return slots.get(slot, null)


## Returns the Weapon in [param slot], or null.
func get_weapon(slot: StringName) -> Weapon:
	return slots.get(slot, null) as Weapon


## True if any weapon slot holds a weapon of [param type].
func has_weapon_of_type(type: Weapon.WeaponType) -> bool:
	return !find_slot_with_weapon_type(type).is_empty()


## Returns the first weapon slot that holds [param type], or an empty StringName.
func find_slot_with_weapon_type(type: Weapon.WeaponType) -> StringName:
	for slot: StringName in [WEAPON_MAIN, WEAPON_SUB]:
		var w := slots.get(slot, null) as Weapon
		if w != null and w.weapon_type == type:
			return slot
	return &""


## Returns carried_gear items that are valid for [param slot].
## – weapon_main / weapon_sub → Weapon instances
## – armor                   → BuildSource with tag "armor"
## – accessory_1 / _2        → BuildSource with tag "accessory"
func get_compatible_gear(slot: StringName) -> Array[BuildSource]:
	var result: Array[BuildSource] = []
	for item: BuildSource in carried_gear:
		if item == null:
			continue
		if _item_fits_slot(item, slot):
			result.append(item)
	return result


func _item_fits_slot(item: BuildSource, slot: StringName) -> bool:
	match slot:
		WEAPON_MAIN, WEAPON_SUB:
			return item is Weapon
		ARMOR:
			return item.tags.has("armor")
		ACCESSORY_1, ACCESSORY_2:
			return item.tags.has("accessory")
	return false


## Returns the weapon most relevant to [param skill]:
## – if the skill was granted by a specific weapon, that weapon;
## – otherwise whatever is in the main-hand slot.
func get_active_weapon_for_skill(skill: Skill) -> Weapon:
	if skill != null and skill.source_item is Weapon:
		return skill.source_item as Weapon
	return slots.get(WEAPON_MAIN, null) as Weapon


## Ensures a weapon of [param type] is in the main-hand slot, swapping if needed.
## Returns true on success, false if no such weapon is equipped anywhere.
func ensure_weapon_type_in_main_hand(type: Weapon.WeaponType) -> bool:
	var main := slots.get(WEAPON_MAIN, null) as Weapon
	if main != null and main.weapon_type == type:
		return true
	var other_slot := find_slot_with_weapon_type(type)
	if other_slot.is_empty():
		return false
	swap_slots(WEAPON_MAIN, other_slot)
	return true


# =============================================================================
# Build integration (delegates to ClassManager)
# =============================================================================

func _apply_item_to_build(item: BuildSource, slot: StringName) -> void:
	if unit == null or unit.character_sheet == null:
		return
	var cm: ClassManager = unit.character_sheet.class_manager
	if cm == null:
		return
	cm.equip_gear(item)

	# Push weapon-granted skills into TacticsController.
	var tc: TacticsController = unit.tactics_controller
	if tc == null:
		return
	for sk: Skill in item.grant_skills:
		if sk == null:
			continue
		var sk_inst: Skill = sk.duplicate(true)
		sk_inst.source_item = item
		tc.add_equipment_skill(sk_inst)


func _remove_item_from_build(item: BuildSource) -> void:
	if unit == null or unit.character_sheet == null:
		return
	var cm: ClassManager = unit.character_sheet.class_manager
	if cm != null:
		cm.unequip_gear(item)

	var tc: TacticsController = unit.tactics_controller
	if tc == null:
		return
	tc.remove_equipment_skills_from_source(item)


# =============================================================================
# Visuals
# =============================================================================

func _spawn_visual(item: BuildSource, slot: StringName) -> void:
	var weapon := item as Weapon
	if weapon == null or weapon.visual_scene == null:
		return
	if unit == null:
		return

	var visual: Node3D = weapon.visual_scene.instantiate()

	match weapon.visual_socket:
		Weapon.SocketSlot.RIGHT_HAND:
			if unit.right_hand_socket:
				unit.right_hand_socket.add_child(visual)
		Weapon.SocketSlot.LEFT_HAND:
			if unit.left_hand_socket:
				unit.left_hand_socket.add_child(visual)
		Weapon.SocketSlot.ORBITING:
			if unit.satellite_controller:
				unit.satellite_controller.spawn_satellite(visual)

	slot_visuals[slot] = visual


func _destroy_visual(slot: StringName) -> void:
	var visual: Node3D = slot_visuals.get(slot, null)
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	slot_visuals.erase(slot)
