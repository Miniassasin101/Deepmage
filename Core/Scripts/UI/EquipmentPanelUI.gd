## [b]Class:[/b] EquipmentPanelUI
## Planning-phase panel that shows a unit's equipment slots and lets the player
## swap items between slots by clicking two slots in sequence.
##
## [b]Usage[/b][br]
## 1. Add this node to your planning-phase scene.[br]
## 2. Call [method show_for_unit] whenever the selected unit changes.[br]
## 3. The panel rebuilds itself and connects to [EquipmentContainer.equipment_changed]
##    so it stays current after every swap.
##
## [b]Two-click swap flow[/b][br]
## • First click  → selects a slot (highlights it).[br]
## • Second click → swaps the selected slot with the new slot and refreshes.
class_name EquipmentPanelUI
extends PanelContainer

# ─── Slot display order ────────────────────────────────────────────────────
const SLOT_ORDER: Array[StringName] = [
	EquipmentContainer.WEAPON_MAIN,
	EquipmentContainer.ARMOR,
]

const SLOT_LABELS: Dictionary = {
	EquipmentContainer.WEAPON_MAIN: "Main Hand",
	EquipmentContainer.ARMOR:       "Armor",
}

# ─── State ─────────────────────────────────────────────────────────────────
var _unit: Unit = null
var _pending_slot: StringName = &""   # first-clicked slot waiting for a swap partner

# ─── Child refs (created in _build_ui) ─────────────────────────────────────
var _slot_buttons: Dictionary = {}    # StringName → Button
var _vbox: VBoxContainer = null


func _ready() -> void:
	_build_ui()
	hide()


# ─── Public API ────────────────────────────────────────────────────────────

## Point the panel at [param unit] and show it.  Pass null to hide.
func show_for_unit(unit: Unit) -> void:
	_disconnect_previous()
	_unit = unit

	if _unit == null:
		hide()
		return

	var ec := _get_ec()
	if ec != null:
		if !ec.equipment_changed.is_connected(_on_equipment_changed):
			ec.equipment_changed.connect(_on_equipment_changed)

	_pending_slot = &""
	_refresh()
	show()


# ─── Internal ──────────────────────────────────────────────────────────────

func _get_ec() -> EquipmentContainer:
	if _unit == null or _unit.character_sheet == null:
		return null
	return _unit.character_sheet.equipment_container


func _disconnect_previous() -> void:
	if _unit == null:
		return
	var ec := _get_ec()
	if ec != null and ec.equipment_changed.is_connected(_on_equipment_changed):
		ec.equipment_changed.disconnect(_on_equipment_changed)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)

	var title := Label.new()
	title.text = "Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	_vbox.add_child(HSeparator.new())

	for slot: StringName in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_vbox.add_child(row)

		var label_name := Label.new()
		label_name.text = SLOT_LABELS.get(slot, String(slot)) + ":"
		label_name.custom_minimum_size = Vector2(80, 0)
		row.add_child(label_name)

		var btn := Button.new()
		btn.text = "(empty)"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(btn)

		_slot_buttons[slot] = btn


func _refresh() -> void:
	var ec := _get_ec()
	for slot: StringName in SLOT_ORDER:
		var btn: Button = _slot_buttons.get(slot)
		if btn == null:
			continue

		var item: BuildSource = ec.get_item(slot) if ec != null else null
		btn.text = item.ui_name if item != null else "(empty)"
		btn.modulate = Color.YELLOW if slot == _pending_slot else Color.WHITE


func _on_slot_pressed(slot: StringName) -> void:
	var ec := _get_ec()
	if ec == null:
		return

	if _pending_slot == &"":
		# First click — select this slot.
		_pending_slot = slot
		_refresh()
	elif _pending_slot == slot:
		# Clicked the same slot twice — deselect.
		_pending_slot = &""
		_refresh()
	else:
		# Second click on a different slot — perform the swap.
		ec.swap_slots(_pending_slot, slot)
		_pending_slot = &""
		# _refresh() is called automatically via _on_equipment_changed.


func _on_equipment_changed(_slot: StringName, _item: BuildSource) -> void:
	_refresh()
