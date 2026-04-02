class_name ClassManager
extends Node

@export var unit: Unit
@export var character_sheet: CharacterSheet
@export var magic_controller: MagicController

@export_group("Build Sources")
@export var race: BuildSource
@export var background: BuildSource
@export var martial_class: BuildSource
@export var magic_class: BuildSource
@export var boons: Array[BuildSource]
@export var feats: Array[BuildSource] = []
@export var gear_sources: Array[BuildSource] = []
@export var progression: BuildSource

var _applied_source_ids: Array[StringName] = []
var _applied_status_instances: Array[Status] = []
var _available_skill_ids: Dictionary = {}

func _ready() -> void:
	call_deferred("rebuild_build")

func rebuild_build() -> void:
	_cache_refs()
	_clear_previous()

	_available_skill_ids.clear()

	var providers: Array[BuildSource] = _get_all_sources()

	# 1) magic types (access)
	var compiled_magic_types: PackedStringArray = []
	for p: BuildSource in providers:
		if p == null:
			continue
		for mt: String in p.grant_magic_types:
			if !compiled_magic_types.has(mt):
				compiled_magic_types.append(mt)

	if magic_controller:
		magic_controller.magic_types = compiled_magic_types

	# 2) attributes + statuses + available skills
	var attrs: AttributesContainer = character_sheet.get_attributes_container()
	for p: BuildSource in providers:
		if p == null:
			continue

		var sid: StringName = _make_source_id(p)
		_applied_source_ids.append(sid)

		# tags on Unit (optional)
		for t: String in p.tags:
			var lower: String = String(t).to_lower()
			if !unit.tags.has(lower):
				unit.tags.append(lower)

		var all_mods: Array[AttributeMod] = []
		all_mods.append_array(p.attribute_mods)

		# Rank / progression can provide computed mods.
		if p.has_method("get_computed_attribute_mods"):
			var computed: Array = p.call("get_computed_attribute_mods")
			for cm in computed:
				if cm is AttributeMod:
					all_mods.append(cm)

		# attribute mods
		for m: AttributeMod in all_mods:
			if m == null:
				continue
			attrs.set_attribute_modifier(sid, m.attribute_name, m.flat, m.affect_maximum)

		# statuses granted by the build (ex: Elementalist mana efficiency)
		for st: Status in p.grant_statuses:
			if st == null:
				continue
			var inst: Status = st.duplicate(true)
			_applied_status_instances.append(inst)
			unit.get_status_controller().add_status(inst)

		# available non-spell skills
		for sk: Skill in p.grant_skills:
			if sk == null:
				continue
			_available_skill_ids[_skill_id(sk)] = true

	# 3) learned spells also become “available” if allowed type
	# Spells granted by the build are learned (so gating works).
		if magic_controller:
			for sp: Skill in p.grant_spells:
				if sp == null:
					continue

				# Optional safety: require access to the magic type of the spell.
				if sp.magic_type != &"" and !magic_controller.has_magic_type(sp.magic_type):
					continue

				magic_controller.learn_spell(sp)


func can_use_skill(skill: Skill) -> bool:
	if skill == null:
		return false
	if DebugSettings.instance != null and DebugSettings.instance.allow_all_skills_in_tactics:
		return true

	# spells must be learned + allowed type
	if skill.has_tag("spell") or skill.magic_type != &"":
		if magic_controller == null:
			return false
		if skill.magic_type != &"" and !magic_controller.has_magic_type(skill.magic_type):
			return false
		return magic_controller.knows_spell(skill)

	# non-spells must be in available list
	return _available_skill_ids.has(_skill_id(skill))

func _cache_refs() -> void:
	if character_sheet == null:
		character_sheet = get_parent() as CharacterSheet
	if unit == null and character_sheet:
		unit = character_sheet.unit
	if magic_controller == null and character_sheet:
		magic_controller = character_sheet.magic_controller

func _get_all_sources() -> Array[BuildSource]:
	var out: Array[BuildSource] = []

	if race:
		out.append(race)
	if background:
		out.append(background)
	if martial_class:
		out.append(martial_class)
	if magic_class:
		out.append(magic_class)
	if progression:
		out.append(progression)

	out.append_array(feats)
	out.append_array(gear_sources)

	return out


func _clear_previous() -> void:
	if unit == null or character_sheet == null:
		return
	var attrs: AttributesContainer = character_sheet.get_attributes_container()
	for sid: StringName in _applied_source_ids:
		attrs.clear_modifiers_from_source(sid)
	_applied_source_ids.clear()
	
	if magic_controller:
		magic_controller.clear_spells()
	
	var status_controller: StatusController = unit.get_status_controller()
	for st: Status in _applied_status_instances:
		status_controller.remove_status(st)
	_applied_status_instances.clear()

# =============================================================================
# Runtime equip / unequip — apply or reverse a single BuildSource without
# triggering a full rebuild.  Called by EquipmentContainer.
# =============================================================================

func equip_gear(item: BuildSource) -> void:
	if !gear_sources.has(item):
		gear_sources.append(item)
	_apply_single_source(item)


func unequip_gear(item: BuildSource) -> void:
	gear_sources.erase(item)
	_remove_single_source(item)


func _apply_single_source(p: BuildSource) -> void:
	_cache_refs()
	if unit == null or character_sheet == null:
		return
	var sid: StringName = _make_source_id(p)
	if _applied_source_ids.has(sid):
		return  # already applied — avoid double-adding
	_applied_source_ids.append(sid)

	var attrs: AttributesContainer = character_sheet.get_attributes_container()

	# Attribute modifiers
	for m: AttributeMod in p.attribute_mods:
		if m == null:
			continue
		attrs.set_attribute_modifier(sid, m.attribute_name, m.flat, m.affect_maximum)

	# Granted statuses
	for st: Status in p.grant_statuses:
		if st == null:
			continue
		var inst: Status = st.duplicate(true)
		_applied_status_instances.append(inst)
		unit.get_status_controller().add_status(inst)

	# Available non-spell skills
	for sk: Skill in p.grant_skills:
		if sk == null:
			continue
		_available_skill_ids[_skill_id(sk)] = true

	# Spells
	if magic_controller:
		for sp: Skill in p.grant_spells:
			if sp == null:
				continue
			if sp.magic_type != &"" and !magic_controller.has_magic_type(sp.magic_type):
				continue
			magic_controller.learn_spell(sp)


func _remove_single_source(p: BuildSource) -> void:
	_cache_refs()
	if unit == null or character_sheet == null:
		return
	var sid: StringName = _make_source_id(p)
	var attrs: AttributesContainer = character_sheet.get_attributes_container()

	# Clear attribute modifiers registered under this source
	attrs.clear_modifiers_from_source(sid)
	_applied_source_ids.erase(sid)

	# Remove non-spell skills from available pool
	for sk: Skill in p.grant_skills:
		if sk == null:
			continue
		_available_skill_ids.erase(_skill_id(sk))

	# Remove statuses that were granted by this source
	var granted_names: Array[String] = []
	for st: Status in p.grant_statuses:
		if st != null:
			granted_names.append(st.ui_name)
	for st in _applied_status_instances.duplicate():
		if granted_names.has(st.ui_name):
			unit.get_status_controller().remove_status(st)
			_applied_status_instances.erase(st)

	# TODO: forget_spell support when MagicController exposes it


func _make_source_id(p: BuildSource) -> StringName:
	var rp: String = p.resource_path
	if rp.is_empty():
		rp = p.ui_name
	return StringName("build:%s:%s" % [str(unit.get_instance_id()), rp])

func _skill_id(skill: Skill) -> StringName:
	if !skill.resource_path.is_empty():
		return StringName(skill.resource_path)
	return StringName(skill.skill_name.to_snake_case())
