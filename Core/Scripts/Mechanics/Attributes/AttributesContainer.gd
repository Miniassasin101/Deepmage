## [b]Class:[/b] AttributesContainer
## [i]Per-unit attribute store with query/mutate helpers and runtime caches.[/i]
##
## [b]Responsibilities[/b][br]
## • Holds a unit’s [code]Attribute[/code] resources and exposes getters/setters with modifier support.[br]
## • Builds fast lookup caches ([member attributes], [member attributes_dict]) from the [member character_sheet].[br]
## • Emits [signal AttributesContainer.attribute_changed] when an attribute value/modifier changes.[br]
##
## [b]Lifecycle[/b][br]
## • On [method Node._ready], calls [_rebuild_runtime_cache] to populate runtime arrays/dicts from the sheet’s profile.[br]
## • [member starting_attributes] is an Inspector-visible snapshot field (not auto-filled here).[br]
##
## [b]Notes[/b][br]
## • The signal is declared without arguments but is emitted with two values ([code]name[/code], [code]value[/code]); ensure listeners handle this pattern.

class_name AttributesContainer
extends Node


## Emitted whenever an attribute changes (value or modifiers).[br]
## [b]Emission payload (as used here):[/b] [code](String attribute_name, int new_current_value)[/code]
signal attribute_changed


@export_category("References")
## Owning unit for context (used by UI or downstream logic).
@export var unit: Unit
## Source-of-truth sheet; its profile is used to create unique attribute instances at runtime.
@export var character_sheet: CharacterSheet

@export_category("Initialization")
## If [code]true[/code], may be used by Editor tooling to auto-apply a profile (not handled in this script).
@export var auto_apply_profile_in_editor: bool = true
## If [code]true[/code], may be used at game start to auto-apply a profile (not handled in this script).
@export var auto_apply_profile_on_play: bool = true

@export_category("Runtime State (read-only at runtime)")
## Inspector-visible snapshot of starting attributes. This script does not auto-populate it.[br]
## Useful for debugging or tooling in the editor.
@export var starting_attributes: Array[Attribute] = []  # Inspector-visible snapshot


## Linear list of live [code]Attribute[/code] resources for iteration.
var attributes: Array[Attribute] = []
## Name → Attribute fast lookup table used by query/mutate helpers.
var attributes_dict: Dictionary[String, Attribute] = {}


## [b]Engine callback:[/b] rebuild internal caches from the [member character_sheet] profile.
func _ready() -> void:
	# Helpful default wiring if you forget to set the reference in the inspector.
	if character_sheet == null:
		character_sheet = get_parent() as CharacterSheet

	# Use your existing flags to control when profiles apply.
	if Engine.is_editor_hint():
		if auto_apply_profile_in_editor:
			_rebuild_runtime_cache()
	else:
		if auto_apply_profile_on_play:
			_rebuild_runtime_cache()


## Public API: Apply a new AttributesProfile at runtime, rebuild cache, and refresh UI.
## This is the "preset loader" you wanted for quick iteration/testing.
func apply_profile(profile: AttributesProfile) -> void:
	if profile == null:
		return

	# Keep the sheet in sync so other systems using character_sheet.attributes_profile see the correct preset.
	if character_sheet != null:
		character_sheet.attributes_profile = profile

	_rebuild_runtime_cache()

	# Notify listeners/UI that values may have changed.
	attribute_changed.emit()
	SignalBus.update_stat_bars.emit()
	SignalBus.update_character_sheet.emit(false)


## Rebuilds the live arrays/dicts from the character sheet’s attribute profile.
## IMPORTANT: this duplicates from the profile, but does NOT modify the profile resource itself.
func _rebuild_runtime_cache() -> void:
	attributes.clear()
	attributes_dict.clear()
	starting_attributes.clear()

	if character_sheet == null:
		return
	if character_sheet.attributes_profile == null:
		return

	var profile: AttributesProfile = character_sheet.attributes_profile
	var attr_array: Array[Attribute] = _make_unique_attributes_from_profile(profile)

	# Inspector-friendly snapshot of the start state (useful while testing).
	starting_attributes = attr_array.duplicate()

	for attribute_resource: Attribute in attr_array:
		if attribute_resource == null:
			continue
		attributes.append(attribute_resource)
		attributes_dict[attribute_resource.attribute_name] = attribute_resource


## Internal helper: duplicates each Attribute deeply so each unit gets unique instances.
func _make_unique_attributes_from_profile(profile: AttributesProfile) -> Array[Attribute]:
	var result: Array[Attribute] = []
	for source_attribute: Attribute in profile.attributes:
		if source_attribute == null:
			continue
		var unique_copy: Attribute = source_attribute.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		unique_copy.resource_local_to_scene = true
		result.append(unique_copy)
	return result


# ---------- Utility / Query API (unchanged semantics) ----------

## Convenience composite: returns a defense-like value from [code]"armor"[/code] + [code]"endurance"[/code].
func get_defence(_only_get_base: bool = false) -> int:
	var defence: int = 0
	defence += get_attribute_current_value("armor")
	defence += get_attribute_current_value("endurance")
	return defence


## Retrieves an [Class Attribute] by [param in_name], or [code]null[/code] if not found.
func get_attribute(in_name: String) -> Attribute:
	if attributes_dict.has(in_name):
		return attributes_dict[in_name]
	return null


## Returns the current [i]modified[/i] value (base + modifiers) of the attribute named [param in_name].[br]
## Returns [code]0[/code] if the attribute does not exist.
func get_attribute_current_value(in_name: String) -> int:
	var att = get_attribute(in_name)
	if att:
		return att.get_current_modified_value()
	return 0


## Sets the [code]current_value[/code] for the attribute named [param in_name] to [param value].[br]
## Emits [signal AttributesContainer.attribute_changed] on success.
func set_attribute_current_value(in_name: String, value: int) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.current_value = value
		attribute_changed.emit()
		SignalBus.update_character_sheet.emit(false)
		return true
	return false


## Adds [param value] (can be negative) to the [code]current_value[/code] of the attribute named [param in_name].[br]
## Emits [signal AttributesContainer.attribute_changed] and [code]SignalBus.update_stat_bars[/code] on success.
func change_attribute_current_value_by(in_name: String, value: int, update_maximum: bool = false) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.current_value += value
		
		if update_maximum:
			att.maximum_value += value
		
		attribute_changed.emit()
		SignalBus.update_stat_bars.emit()
		SignalBus.update_character_sheet.emit(false)
		return true
	return false


## Adds a flat modifier [param modifier_value] to the attribute named [param in_name].[br]
## Emits [signal AttributesContainer.attribute_changed] and [code]SignalBus.update_stat_bars[/code] on success.
func add_attribute_modifier(in_name: String, modifier_value: int, affect_maximum: bool = false) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.add_modifier(modifier_value, affect_maximum)
		attribute_changed.emit()
		SignalBus.update_stat_bars.emit()
		SignalBus.update_character_sheet.emit(false)
		return true
	return false


## Removes a flat modifier [param modifier_value] from the attribute named [param in_name].[br]
## Emits [signal AttributesContainer.attribute_changed] and [code]SignalBus.update_stat_bars[/code] on success.
func remove_attribute_modifier(in_name: String, modifier_value: int, affect_maximum: bool = false) -> bool:
	var att = get_attribute(in_name)
	if att:
		att.remove_modifier(modifier_value, affect_maximum)
		attribute_changed.emit()
		SignalBus.update_stat_bars.emit()
		update_char_sheet_deferred.call_deferred()
		return true
	return false

func update_char_sheet_deferred() -> void:
	SignalBus.update_character_sheet.emit(false)

## Returns [code]true[/code] if an attribute with name [param in_name] exists in this container.
func has_attribute(in_name: String) -> bool:
	return attributes_dict.has(in_name)


## Adds a new attribute by duplicating [param attribute] into this container (avoids shared instances).[br]
## Emits [signal AttributesContainer.attribute_changed] on success. Returns [code]false[/code] if a name collision exists.
func add_attribute(attribute: Attribute) -> bool:
	if has_attribute(attribute.attribute_name):
		return false # Already exists
	var copy = attribute.duplicate()
	attributes.append(copy)
	attributes_dict[copy.attribute_name] = copy
	attribute_changed.emit()
	return true


## Removes the attribute by name [param in_name]. Emits [signal AttributesContainer.attribute_changed] with value [code]0[/code] when removed.
func remove_attribute(in_name: String) -> bool:
	if has_attribute(in_name):
		var att = attributes_dict[in_name]
		attributes.erase(att)
		attributes_dict.erase(in_name)
		emit_signal("attribute_changed", in_name, 0)
		attribute_changed.emit()
		return true
	return false


func set_attribute_modifier(source_id: StringName, in_name: StringName, modifier_value: int, affect_maximum: bool = false) -> bool:
	var attribute_ref: Attribute = get_attribute(String(in_name))
	if attribute_ref != null:
		attribute_ref.set_modifier(source_id, modifier_value, affect_maximum)
		attribute_changed.emit()
		SignalBus.update_stat_bars.emit()
		SignalBus.update_character_sheet.emit(false)
		return true 
	return false


func clear_modifiers_from_source(source_id: StringName) -> void:
	for attribute_ref: Attribute in attributes:
		if attribute_ref != null:
			attribute_ref.clear_modifier(source_id)
	attribute_changed.emit()
	SignalBus.update_stat_bars.emit()
	SignalBus.update_character_sheet.emit(false)





## Returns an array of all attribute names in this container.
func get_all_attribute_names() -> Array[String]:
	return attributes_dict.keys()
