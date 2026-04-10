## [b]Class:[/b] GearContainer
## Planning-phase equipment panel.  Shows the unit's five gear slots and lets the
## player manage them:
## • Left-click a slot button  → opens the [GearPickerPanel] side panel for that slot.
## • Right-click a slot button → immediately unequips that slot.
##
## Call [method show_for_unit] whenever the selected unit changes.
## The panel stays in sync via [signal EquipmentContainer.equipment_changed].
class_name GearContainer
extends MarginContainer

# ─── Slot button exports (wired in scene) ─────────────────────────────────
@export_category("Buttons")
@export var main_button: Button
@export var sub_button: Button
@export var armor_button: Button
@export var accessory_button_1: Button
@export var accessory_button_2: Button

# ─── Picker panel ─────────────────────────────────────────────────────────
@export_category("Panels")
@export var gear_picker: GearPickerPanel

# ─── Runtime state ────────────────────────────────────────────────────────
var _unit: Unit = null

# Maps each slot StringName to its Button for quick lookup in _refresh().
var _slot_buttons: Dictionary = {}


func _ready() -> void:
	# Build the slot → button map once.
	_slot_buttons = {
		EquipmentContainer.WEAPON_MAIN: main_button,
		EquipmentContainer.WEAPON_SUB:  sub_button,
		EquipmentContainer.ARMOR:       armor_button,
		EquipmentContainer.ACCESSORY_1: accessory_button_1,
		EquipmentContainer.ACCESSORY_2: accessory_button_2,
	}

	# Wire left-click (pressed) and right-click (gui_input) for each button.
	_connect_button(main_button,         EquipmentContainer.WEAPON_MAIN)
	_connect_button(sub_button,          EquipmentContainer.WEAPON_SUB)
	_connect_button(armor_button,        EquipmentContainer.ARMOR)
	_connect_button(accessory_button_1,  EquipmentContainer.ACCESSORY_1)
	_connect_button(accessory_button_2,  EquipmentContainer.ACCESSORY_2)


# =============================================================================
# Public API
# =============================================================================

## Point the panel at [param unit] and refresh all slot labels.
## Pass null to clear the panel.
func show_for_unit(unit: Unit) -> void:
	_disconnect_previous()
	_unit = unit

	if _unit != null:
		var ec: EquipmentContainer = _get_ec()
		if ec != null and !ec.equipment_changed.is_connected(_on_equipment_changed):
			ec.equipment_changed.connect(_on_equipment_changed)

	# If the picker is open for a different unit, close it.
	if gear_picker != null and gear_picker.visible:
		gear_picker.clear()

	_refresh()


# =============================================================================
# Internal — UI setup
# =============================================================================

func _connect_button(btn: Button, slot: StringName) -> void:
	if btn == null:
		return
	# Left-click via Button.pressed signal.
	btn.pressed.connect(_on_slot_left_clicked.bind(slot))
	# Right-click via gui_input (Button doesn't emit pressed on right-click).
	btn.gui_input.connect(_on_slot_gui_input.bind(slot))


# =============================================================================
# Internal — slot state
# =============================================================================

func _get_ec() -> EquipmentContainer:
	if _unit == null or _unit.character_sheet == null:
		return null
	return _unit.character_sheet.equipment_container


func _disconnect_previous() -> void:
	if _unit == null:
		return
	var ec: EquipmentContainer = _get_ec()
	if ec != null and ec.equipment_changed.is_connected(_on_equipment_changed):
		ec.equipment_changed.disconnect(_on_equipment_changed)


func _refresh() -> void:
	var ec: EquipmentContainer = _get_ec()
	for slot: StringName in _slot_buttons:
		var btn: Button = _slot_buttons[slot]
		if btn == null:
			continue
		var item: BuildSource = ec.get_item(slot) if ec != null else null
		btn.text = item.ui_name if item != null else "Empty"
		btn.modulate = Color.WHITE



# =============================================================================
# Signal handlers
# =============================================================================

func _on_equipment_changed(_slot: StringName, _item: BuildSource) -> void:
	_refresh()
	SignalBus.update_character_sheet.emit(false)


func _on_slot_left_clicked(slot: StringName) -> void:
	if gear_picker == null:
		return
	if _unit == null:
		return
	gear_picker.open_for_slot(_unit, slot)


func _on_slot_gui_input(event: InputEvent, slot: StringName) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var ec: EquipmentContainer = _get_ec()
			if ec != null:
				ec.unequip(slot)
			# Close picker if it was open for this slot.
			if gear_picker != null and gear_picker.visible:
				gear_picker.clear()
