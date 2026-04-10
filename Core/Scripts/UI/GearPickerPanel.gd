## [b]Class:[/b] GearPickerPanel
## Sliding side panel that lists the gear items compatible with a given equipment slot.
## Left-clicking an item equips it; the "— Empty —" button at the top unequips the slot.
## Extends [SlidePanelContainer] so it inherits open()/close() slide animation.
class_name GearPickerPanel
extends SlidePanelContainer

@export var title_label: Label
@export var item_list_container: VBoxContainer

var _unit: Unit = null
var _slot: StringName = &""


# =============================================================================
# Public API
# =============================================================================

## Build the item list for [param slot] on [param unit] and slide the panel open.
func open_for_slot(unit: Unit, slot: StringName) -> void:
	_unit = unit
	_slot = slot

	_rebuild_list()
	open()


## Close and clear state.  Inherited open()/close() handle the animation.
func clear() -> void:
	_unit = null
	_slot = &""
	_clear_list()
	close()


# =============================================================================
# Internal
# =============================================================================

func _rebuild_list() -> void:
	_clear_list()

	if title_label != null:
		title_label.text = _slot_display_name(_slot)

	var ec: EquipmentContainer = _get_ec()
	if ec == null:
		return

	# "— Empty —" button always appears first to allow unequipping.
	var empty_btn := Button.new()
	empty_btn.text = "— Empty —"
	empty_btn.pressed.connect(_on_empty_pressed)
	item_list_container.add_child(empty_btn)

	var compatible: Array[BuildSource] = ec.get_compatible_gear(_slot)
	for item: BuildSource in compatible:
		if item == null:
			continue
		var btn := Button.new()
		btn.text = _item_label(item)

		# Highlight the item that is currently in this slot.
		if ec.get_item(_slot) == item:
			btn.modulate = Color(0.6, 1.0, 0.6)  # subtle green tint

		btn.pressed.connect(_on_item_pressed.bind(item))
		item_list_container.add_child(btn)


func _clear_list() -> void:
	if item_list_container == null:
		return
	for child in item_list_container.get_children():
		child.queue_free()


func _get_ec() -> EquipmentContainer:
	if _unit == null or _unit.character_sheet == null:
		return null
	return _unit.character_sheet.equipment_container


func _item_label(item: BuildSource) -> String:
	var weapon := item as Weapon
	if weapon != null:
		var two_h: String = " [2H]" if weapon.is_two_handed else ""
		return "%s  (%d–%d)%s" % [item.ui_name, weapon.damage_min, weapon.damage_max, two_h]
	return item.ui_name


func _slot_display_name(slot: StringName) -> String:
	match slot:
		EquipmentContainer.WEAPON_MAIN:  return "Main Weapon"
		EquipmentContainer.WEAPON_SUB:   return "Sub Weapon"
		EquipmentContainer.ARMOR:        return "Armor"
		EquipmentContainer.ACCESSORY_1:  return "Accessory 1"
		EquipmentContainer.ACCESSORY_2:  return "Accessory 2"
	return String(slot)


func _on_item_pressed(item: BuildSource) -> void:
	var ec: EquipmentContainer = _get_ec()
	if ec != null:
		ec.equip(item, _slot)
	close()


func _on_empty_pressed() -> void:
	var ec: EquipmentContainer = _get_ec()
	if ec != null:
		ec.unequip(_slot)
	close()
