## [b]Class:[/b] EquipmentConsole
## Debug console commands for testing the weapon & equipment system at runtime.
##
## [b]Command groups[/b][br]
## • [code]eq_slots[/code]   — inspect slot contents on a unit[br]
## • [code]eq_info[/code]    — detailed weapon stats for one slot[br]
## • [code]eq_skills[/code]  — list TacticsController equipment skill lists[br]
## • [code]eq_give_sword[/code] / [code]eq_give_sword_off[/code] — spawn a test Iron Sword and equip it[br]
## • [code]eq_unequip[/code] — remove item from a slot[br]
## • [code]eq_swap[/code]    — swap two slots[br]
## • [code]eq_ensure[/code]  — push a weapon type into the main hand[br]
## • [code]eq_dmg[/code]     — preview the damage range that would be rolled right now[br]
## • [code]eq_clear[/code]   — unequip every slot on a unit[br]
## • [code]eq_load[/code]    — equip a weapon from a full res:// path[br]
## • [code]eq_find[/code]    — equip a weapon by filename (searches the weapons folder)
class_name EquipmentConsole
extends Node

# Slot-name aliases accepted by the console (shorter to type).
## Root folder scanned by eq_find when no path prefix is given.
const WEAPONS_ROOT := "res://Deepmage/Core/Resources/Equipment/Weapons"

const SLOT_ALIASES: Dictionary = {
	"main":        EquipmentContainer.WEAPON_MAIN,
	"weapon_main": EquipmentContainer.WEAPON_MAIN,
	"sub":         EquipmentContainer.WEAPON_SUB,
	"weapon_sub":  EquipmentContainer.WEAPON_SUB,
	"armor":       EquipmentContainer.ARMOR,
	"acc1":        EquipmentContainer.ACCESSORY_1,
	"accessory_1": EquipmentContainer.ACCESSORY_1,
	"acc2":        EquipmentContainer.ACCESSORY_2,
	"accessory_2": EquipmentContainer.ACCESSORY_2,
}

# Weapon-type aliases  (index matches Weapon.WeaponType enum)
const WEAPON_TYPE_NAMES: Array[String] = [
	"unarmed","sword","dagger","axe","spear","mace","bow","crossbow","staff","orb","tome"
]


func _ready() -> void:
	# --- Inspection ---
	Console.add_command("eq_slots",      eq_slots,      ["unit_name"], 1,
		"Print all equipment slot contents for a unit.")
	Console.add_command("eq_info",       eq_info,       ["unit_name", "slot"], 2,
		"Print weapon stats for the item in a specific slot.  slot: main|off|impl|armor|misc1|misc2")
	Console.add_command("eq_skills",     eq_skills,     ["unit_name"], 1,
		"List active/passive skills currently registered from equipment on a unit.")

	# --- Give test weapons ---
	Console.add_command("eq_give_sword", eq_give_sword, ["unit_name", "dmg_min?", "dmg_max?"], 1,
		"Create a test Iron Sword and equip it in weapon_main.  Optional dmg_min, dmg_max (default 4 8).")
	Console.add_command("eq_give_sword_off", eq_give_sword_off, ["unit_name", "dmg_min?", "dmg_max?"], 1,
		"Create a test Iron Sword and equip it in weapon_sub.")
	Console.add_command("eq_give_weapon", eq_give_weapon,
		["unit_name", "slot", "type", "dmg_min", "dmg_max"], 5,
		"Create a generic test weapon.  type: sword|dagger|axe|spear|mace|bow|staff|orb|unarmed.  slot: main|off|impl")

	# --- Equip / unequip ---
	Console.add_command("eq_unequip",    eq_unequip,    ["unit_name", "slot"], 2,
		"Unequip the item in a slot.")
	Console.add_command("eq_clear",      eq_clear,      ["unit_name"], 1,
		"Unequip every slot on the unit.")

	# --- Swap ---
	Console.add_command("eq_swap",       eq_swap,       ["unit_name", "slot_a", "slot_b"], 3,
		"Swap the items between two slots.")
	Console.add_command("eq_ensure",     eq_ensure,     ["unit_name", "weapon_type"], 2,
		"Ensure a weapon type is in the main-hand slot, auto-swapping if needed.  weapon_type: sword|dagger|…")

	# --- Load from file ---
	Console.add_command("eq_load",  eq_load,  ["unit_name", "slot", "res_path"], 3,
		"Load a BuildSource .tres from a full res:// path and equip it.  e.g. eq_load Aldric main res://Deepmage/Core/Resources/Equipment/Weapons/TestWeapons/TestSword.tres")
	Console.add_command("eq_find",  eq_find,  ["unit_name", "slot", "filename"], 3,
		"Search the weapons folder for a .tres whose filename matches (case-insensitive, no extension needed) and equip it.  e.g. eq_find Aldric main TestSword")

	# --- Combat preview ---
	Console.add_command("eq_dmg",        eq_dmg,        ["unit_name"], 1,
		"Preview the weapon damage range (min/max) that would be used in combat right now.")


# =============================================================================
# Helpers
# =============================================================================

func _get_unit(unit_name: String) -> Unit:
	var u: Unit = UnitManager.instance.get_unit_by_name(unit_name)
	if u == null:
		Console.print_line("Unit '%s' not found." % unit_name, true)
	return u


func _get_ec(unit_name: String) -> EquipmentContainer:
	var u: Unit = _get_unit(unit_name)
	if u == null:
		return null
	if u.character_sheet == null:
		Console.print_line("Unit '%s' has no CharacterSheet." % unit_name, true)
		return null
	var ec: EquipmentContainer = u.character_sheet.equipment_container
	if ec == null:
		Console.print_line("Unit '%s' has no EquipmentContainer." % unit_name, true)
	return ec


func _resolve_slot(alias: String) -> StringName:
	var lower: String = alias.to_lower()
	if SLOT_ALIASES.has(lower):
		return SLOT_ALIASES[lower]
	# Accept bare StringName constants too.
	var as_sn: StringName = StringName(alias)
	for v: StringName in SLOT_ALIASES.values():
		if v == as_sn:
			return as_sn
	Console.print_line(
		"Unknown slot '%s'.  Valid: main, sub, armor, acc1, acc2" % alias, true)
	return &""


func _weapon_type_from_string(type_str: String) -> int:
	var lower: String = type_str.to_lower()
	var idx: int = WEAPON_TYPE_NAMES.find(lower)
	if idx == -1:
		Console.print_line(
			"Unknown weapon type '%s'.  Valid: %s" % [type_str, ", ".join(WEAPON_TYPE_NAMES)], true)
		return -1
	return idx


func _make_test_weapon(type_int: int, dmg_min: int, dmg_max: int, label: String = "") -> Weapon:
	var w := Weapon.new()
	w.weapon_type = type_int as Weapon.WeaponType
	w.damage_min  = dmg_min
	w.damage_max  = dmg_max
	var type_name: String = WEAPON_TYPE_NAMES[type_int] if type_int < WEAPON_TYPE_NAMES.size() else "weapon"
	w.ui_name = label if label != "" else "Test %s" % type_name.capitalize()
	return w


func _item_summary(item: BuildSource, slot: StringName) -> String:
	if item == null:
		return "  [%s] (empty)" % slot
	var weapon := item as Weapon
	if weapon != null:
		var two_h: String = " [2H]" if weapon.is_two_handed else ""
		return "  [%s] %s — %s dmg %d–%d%s" % [
			slot,
			weapon.ui_name,
			WEAPON_TYPE_NAMES[weapon.weapon_type] if weapon.weapon_type < WEAPON_TYPE_NAMES.size() else "?",
			weapon.damage_min, weapon.damage_max,
			two_h
		]
	return "  [%s] %s (non-weapon gear)" % [slot, item.ui_name]


# =============================================================================
# Commands — Inspection
# =============================================================================

func eq_slots(unit_name: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	Console.print_line("=== Equipment: %s ===" % unit_name, true)
	for slot: StringName in [
		EquipmentContainer.WEAPON_MAIN, EquipmentContainer.WEAPON_SUB,
		EquipmentContainer.ARMOR,
		EquipmentContainer.ACCESSORY_1, EquipmentContainer.ACCESSORY_2
	]:
		Console.print_line(_item_summary(ec.get_item(slot), slot), true)


func eq_info(unit_name: String, slot_alias: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot: StringName = _resolve_slot(slot_alias)
	if slot == &"":
		return
	var item: BuildSource = ec.get_item(slot)
	if item == null:
		Console.print_line("Slot [%s] on '%s' is empty." % [slot, unit_name], true)
		return

	Console.print_line("=== Slot [%s] on %s ===" % [slot, unit_name], true)
	Console.print_line("  Name : %s" % item.ui_name, true)

	var weapon := item as Weapon
	if weapon != null:
		Console.print_line("  Type        : %s" % WEAPON_TYPE_NAMES[weapon.weapon_type], true)
		Console.print_line("  Damage      : %d – %d" % [weapon.damage_min, weapon.damage_max], true)
		Console.print_line("  Two-handed  : %s" % str(weapon.is_two_handed), true)
		Console.print_line("  Visual scene: %s" % (str(weapon.visual_scene) if weapon.visual_scene else "none"), true)
		Console.print_line("  Traits      : %s" % str(weapon.weapon_traits), true)
		Console.print_line("  Inherent FX : %d effect(s)" % weapon.inherent_effects.size(), true)
		Console.print_line("  Grant skills: %d skill(s)" % weapon.grant_skills.size(), true)
		for sk: Skill in weapon.grant_skills:
			if sk != null:
				Console.print_line("    • %s  [%s]" % [sk.skill_name, Skill.SkillCategory.keys()[sk.skill_category]], true)
	else:
		Console.print_line("  (Non-weapon BuildSource)", true)
		Console.print_line("  Grant skills  : %d" % item.grant_skills.size(), true)
		Console.print_line("  Attribute mods: %d" % item.attribute_mods.size(), true)


func eq_skills(unit_name: String) -> void:
	var u: Unit = _get_unit(unit_name)
	if u == null:
		return
	var tc: TacticsController = u.tactics_controller
	if tc == null:
		Console.print_line("Unit '%s' has no TacticsController." % unit_name, true)
		return

	Console.print_line("=== Equipment skills on %s ===" % unit_name, true)

	if tc.equipment_active_skills.is_empty():
		Console.print_line("  Active  : (none)", true)
	else:
		Console.print_line("  Active (%d):" % tc.equipment_active_skills.size(), true)
		for sk: Skill in tc.equipment_active_skills:
			var src: String = sk.source_item.ui_name if sk.source_item != null else "?"
			Console.print_line("    • %s  ← %s" % [sk.skill_name, src], true)

	if tc.equipment_passive_skills.is_empty():
		Console.print_line("  Passive : (none)", true)
	else:
		Console.print_line("  Passive (%d):" % tc.equipment_passive_skills.size(), true)
		for sk: Skill in tc.equipment_passive_skills:
			var src: String = sk.source_item.ui_name if sk.source_item != null else "?"
			Console.print_line("    • %s  ← %s" % [sk.skill_name, src], true)


# =============================================================================
# Commands — Give test weapons
# =============================================================================

func eq_give_sword(unit_name: String, dmg_min_s: String = "", dmg_max_s: String = "") -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var dmg_min: int = 4 if dmg_min_s == "" else dmg_min_s.to_int()
	var dmg_max: int = 8 if dmg_max_s == "" else dmg_max_s.to_int()
	var sword: Weapon = _make_test_weapon(Weapon.WeaponType.SWORD, dmg_min, dmg_max, "Iron Sword")
	ec.carried_gear.append(sword)
	ec.equip(sword, EquipmentContainer.WEAPON_MAIN)
	Console.print_line("Equipped Iron Sword (dmg %d–%d) → [weapon_main] on %s." % [dmg_min, dmg_max, unit_name], true)


func eq_give_sword_off(unit_name: String, dmg_min_s: String = "", dmg_max_s: String = "") -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var dmg_min: int = 4 if dmg_min_s == "" else dmg_min_s.to_int()
	var dmg_max: int = 8 if dmg_max_s == "" else dmg_max_s.to_int()
	var sword: Weapon = _make_test_weapon(Weapon.WeaponType.SWORD, dmg_min, dmg_max, "Iron Sword")
	ec.carried_gear.append(sword)
	ec.equip(sword, EquipmentContainer.WEAPON_SUB)
	Console.print_line("Equipped Iron Sword (dmg %d–%d) → [weapon_sub] on %s." % [dmg_min, dmg_max, unit_name], true)


func eq_give_weapon(unit_name: String, slot_alias: String, type_str: String,
		dmg_min_s: String, dmg_max_s: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot: StringName = _resolve_slot(slot_alias)
	if slot == &"":
		return
	var type_int: int = _weapon_type_from_string(type_str)
	if type_int == -1:
		return
	var w: Weapon = _make_test_weapon(type_int, dmg_min_s.to_int(), dmg_max_s.to_int())
	ec.carried_gear.append(w)
	ec.equip(w, slot)
	Console.print_line("Equipped %s (dmg %d–%d) → [%s] on %s." % [
		w.ui_name, w.damage_min, w.damage_max, slot, unit_name], true)


# =============================================================================
# Commands — Equip / unequip
# =============================================================================

func eq_unequip(unit_name: String, slot_alias: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot: StringName = _resolve_slot(slot_alias)
	if slot == &"":
		return
	var removed: BuildSource = ec.unequip(slot)
	if removed == null:
		Console.print_line("Slot [%s] on '%s' was already empty." % [slot, unit_name], true)
	else:
		Console.print_line("Unequipped '%s' from [%s] on %s." % [removed.ui_name, slot, unit_name], true)


func eq_clear(unit_name: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var removed_count: int = 0
	for slot: StringName in [
		EquipmentContainer.WEAPON_MAIN, EquipmentContainer.WEAPON_SUB,
		EquipmentContainer.ARMOR,
		EquipmentContainer.ACCESSORY_1, EquipmentContainer.ACCESSORY_2
	]:
		if ec.get_item(slot) != null:
			ec.unequip(slot)
			removed_count += 1
	Console.print_line("Cleared %d slot(s) on %s." % [removed_count, unit_name], true)


# =============================================================================
# Commands — Swap
# =============================================================================

func eq_swap(unit_name: String, slot_a_alias: String, slot_b_alias: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot_a: StringName = _resolve_slot(slot_a_alias)
	var slot_b: StringName = _resolve_slot(slot_b_alias)
	if slot_a == &"" or slot_b == &"":
		return
	if slot_a == slot_b:
		Console.print_line("Cannot swap a slot with itself.", true)
		return

	var item_a_name: String = ec.get_item(slot_a).ui_name if ec.get_item(slot_a) != null else "(empty)"
	var item_b_name: String = ec.get_item(slot_b).ui_name if ec.get_item(slot_b) != null else "(empty)"

	ec.swap_slots(slot_a, slot_b)
	Console.print_line("Swapped [%s]=%s ↔ [%s]=%s on %s." % [
		slot_a, item_a_name, slot_b, item_b_name, unit_name], true)


func eq_ensure(unit_name: String, type_str: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var type_int: int = _weapon_type_from_string(type_str)
	if type_int == -1:
		return
	var success: bool = ec.ensure_weapon_type_in_main_hand(type_int as Weapon.WeaponType)
	if success:
		var w: Weapon = ec.get_weapon(EquipmentContainer.WEAPON_MAIN)
		Console.print_line(
			"Main hand is now %s (%s)." % [
				w.ui_name if w else "?",
				WEAPON_TYPE_NAMES[type_int]
			], true)
	else:
		Console.print_line(
			"No %s found in any weapon slot on %s — swap not possible." % [type_str, unit_name], true)


# =============================================================================
# Commands — Load from file
# =============================================================================

func eq_load(unit_name: String, slot_alias: String, res_path: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot: StringName = _resolve_slot(slot_alias)
	if slot == &"":
		return

	if !ResourceLoader.exists(res_path):
		Console.print_line("Resource not found: %s" % res_path, true)
		return

	var item: BuildSource = ResourceLoader.load(res_path) as BuildSource
	if item == null:
		Console.print_line("Loaded resource is not a BuildSource: %s" % res_path, true)
		return

	if !ec.carried_gear.has(item):
		ec.carried_gear.append(item)
	ec.equip(item, slot)
	Console.print_line("Equipped '%s' → [%s] on %s." % [item.ui_name, slot, unit_name], true)
	_print_weapon_brief(item)


func eq_find(unit_name: String, slot_alias: String, filename: String) -> void:
	var ec: EquipmentContainer = _get_ec(unit_name)
	if ec == null:
		return
	var slot: StringName = _resolve_slot(slot_alias)
	if slot == &"":
		return

	var found_path: String = _search_for_weapon_file(WEAPONS_ROOT, filename)
	if found_path.is_empty():
		Console.print_line(
			"No .tres matching '%s' found under %s" % [filename, WEAPONS_ROOT], true)
		return

	var item: BuildSource = ResourceLoader.load(found_path) as BuildSource
	if item == null:
		Console.print_line("File matched but is not a BuildSource: %s" % found_path, true)
		return

	if !ec.carried_gear.has(item):
		ec.carried_gear.append(item)
	ec.equip(item, slot)
	Console.print_line("Equipped '%s' → [%s] on %s.  (from %s)" % [
		item.ui_name, slot, unit_name, found_path], true)
	_print_weapon_brief(item)


## Recursively searches [param dir] for a .tres file whose stem matches [param name]
## (case-insensitive, .tres extension optional).  Returns the res:// path or "".
func _search_for_weapon_file(dir: String, name: String) -> String:
	var needle: String = name.to_lower().trim_suffix(".tres")
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return ""

	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if da.current_is_dir() and entry != "." and entry != "..":
			var sub_result: String = _search_for_weapon_file(dir + "/" + entry, name)
			if !sub_result.is_empty():
				da.list_dir_end()
				return sub_result
		elif entry.ends_with(".tres"):
			if entry.get_basename().to_lower() == needle:
				da.list_dir_end()
				return dir + "/" + entry
		entry = da.get_next()

	da.list_dir_end()
	return ""


## Prints a one-liner weapon summary (type + damage range) after equipping.
func _print_weapon_brief(item: BuildSource) -> void:
	var weapon := item as Weapon
	if weapon == null:
		return
	var type_name: String = WEAPON_TYPE_NAMES[weapon.weapon_type] \
		if weapon.weapon_type < WEAPON_TYPE_NAMES.size() else "?"
	Console.print_line("  → %s | dmg %d–%d%s" % [
		type_name.capitalize(),
		weapon.damage_min,
		weapon.damage_max,
		" [2H]" if weapon.is_two_handed else ""], true)


# =============================================================================
# Commands — Combat preview
# =============================================================================

func eq_dmg(unit_name: String) -> void:
	var u: Unit = _get_unit(unit_name)
	if u == null:
		return

	var formula: CombatFormulaResource = null
	if CombatSystem.instance != null:
		formula = CombatSystem.instance.formula
	if formula == null:
		formula = CombatFormulaResource.new()

	# Check what weapon is in main hand.
	var weapon: Weapon = null
	if u.character_sheet != null and u.character_sheet.equipment_container != null:
		weapon = u.character_sheet.equipment_container.get_weapon(EquipmentContainer.WEAPON_MAIN)

	var dmg_min: int
	var dmg_max: int
	var source: String

	if weapon != null:
		dmg_min = weapon.damage_min
		dmg_max = weapon.damage_max
		source  = "'%s' (equipped weapon)" % weapon.ui_name
	else:
		dmg_min = formula.weapon_damage_min
		dmg_max = formula.weapon_damage_max
		source  = "formula fallback (no weapon equipped)"

	# Add prowess attribute to damage range if unit has one.
	var prowess: int = 0
	if u.get_attributes_container() != null:
		prowess = u.get_attributes_container().get_attribute_current_value("martial")

	Console.print_line("=== Damage preview: %s ===" % unit_name, true)
	Console.print_line("  Source       : %s" % source, true)
	Console.print_line("  Weapon range : %d – %d" % [dmg_min, dmg_max], true)
	Console.print_line("  Martial      : %d" % prowess, true)
	Console.print_line("  Final range  : %d – %d  (before crit / multipliers)" % [
		dmg_min + prowess, dmg_max + prowess], true)
