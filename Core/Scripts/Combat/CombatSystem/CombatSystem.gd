## [b]Class:[/b] CombatSystem
## [i]Central coordinator for resolving combat actions using a Gubat Banwa–style flow.[/i]
##
## [b]Responsibilities[/b][br]
## • Owns the active [code]CombatEventData[/code] for an in-progress attack.[br]
## • Applies GB dice logic: EVD gate, melee chaining (top-or-higher), ranged crit (top-or-higher), Prowess/Defense, and minimum damage rules.[br]
## • Determines and awaits defender [b]Reactions[/b] via [ReactionResolver] and the unit's [ReactionPack].[br]
## • Emits detailed logs when [member combat_debug_enabled] is [code]true[/code].
##
## [b]Design Notes[/b][br]
## • Singleton-like: first instance sets [code]CombatSystem.instance[/code]; later instances self-remove in [method Node._ready].[br]
## • Core resolution lives in [method _resolve_attack_darkest_dungeon]. Hit/crit rolling delegates to [HitResolver]; damage delegates to [DamageCalculator].[br]
## • Formula constants (weapon range, crit multiplier, accuracy bonus) live in [CombatFormulaResource] assigned to [member formula].[br]
## • Inline comments explain the sequence; documentation comments use BBCode so tooltips render nicely in the Inspector and class reference.
class_name CombatSystem
extends Node


## If [code]true[/code], emit a step-by-step debug dump to [code]CombatLog[/code] during resolution.
@export var combat_debug_enabled: bool = false

## Optional reference to a system that handles skill-related triggers, hooks, and events.
@export var skill_trigger_system: SkillTriggerSystem = null
@export var fallback_skill: Skill = null

@export_category("Libraries")
## Reference to the global [Class SkillLibrary] used for skill lookups and shared data.
@export var skill_library: SkillLibrary = null

## Reference to the global [Class ConditionLibrary] used for condition lookups and shared data.
@export var condition_library: ConditionLibrary = null

@export_category("Constants")
## Formula constants (weapon range, crit multiplier, accuracy bonus).
## If unassigned, a default instance is created at runtime with standard values.
@export var formula: CombatFormulaResource = null


## The working record for the currently executing combat event; populated throughout resolution.
var current_combat_event_data: CombatEventData = null

var _hit_resolver: HitResolver = HitResolver.new()
var _damage_calculator: DamageCalculator = DamageCalculator.new()


## Singleton-style static pointer to the active [Class CombatSystem] instance.
static var instance: CombatSystem = null


## [b]Engine callback:[/b] sets the singleton [member instance] and guards against duplicates.
## If another instance exists, logs an error via [method Object.push_error] and frees this node with [method Node.queue_free].
func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self


## Declare and resolve an attack from [param attacker] to [param defender] using [param action].
## Initializes a fresh [code]CombatEventData[/code], logs, runs resolution, then selects and runs the defender's Reaction.
##
## [b]Parameters[/b][br]
## • [param action]: [Class CombatAction] — the action to resolve.[br]
## • [param attacker]: [Class Unit] — the attacking unit.[br]
## • [param defender]: [Class Unit] — the defending unit.
##
## [b]Side Effects[/b][br]
## • Populates [member current_combat_event_data] with dice results, flags, and totals.[br]
## • May spawn floating text via [code]Utilities.spawn_text_line[/code].[br]
## • Selects a Reaction from the defender's [ReactionPack] via [ReactionResolver] and awaits it.
func declare_attack(action: CombatAction, attacker: Unit, defender: Unit, skill: Skill = null) -> void:
	current_combat_event_data = CombatEventData.new()

	# Set combat event participants
	current_combat_event_data.attacker = attacker
	current_combat_event_data.defender = defender

	# Set Combat Event Action
	current_combat_event_data.action = action

	# Set Skill
	current_combat_event_data.skill = skill if skill != null else action.fallback_skill

	# Resolve the active weapon from the attacker's EquipmentContainer (if present).
	var _ec: EquipmentContainer = null
	if attacker.character_sheet != null:
		_ec = attacker.character_sheet.equipment_container
	if _ec != null:
		current_combat_event_data.weapon = _ec.get_active_weapon_for_skill(current_combat_event_data.skill)

	# High-level log of the attempt
	CombatLog.instance.add_log()
	CombatLog.instance.add_log(attacker.ui_name + " attacks " + defender.ui_name + " with " + current_combat_event_data.skill.skill_name)

	# Hook point: "ally attacked", "enemy attacked", etc. (left as a placeholder)


	# Resolve using Darkest Dungeon-style steps
	if skill == null or skill.skill_type != Skill.SkillType.ATTACK:
		return
	#await _resolve_attack_gubat_banwa(action, attacker, defender, skill)
	_resolve_attack_darkest_dungeon(action, attacker, defender, current_combat_event_data.skill)

	# Pre-evaluate BEFORE_HIT_RESOLVES passives now — before any animation begins and before
	# the reaction is selected. This ensures is_hit is final (e.g. Dodge already flipped it)
	# when determine_reaction() picks which animation the defender plays.
	if TurnSystem.instance != null:
		TurnSystem.instance.evaluate_pre_hit_passives(current_combat_event_data)

	await determine_reaction(current_combat_event_data)

	_debug_dump_current_event()


func _resolve_attack_darkest_dungeon(action: CombatAction, attacker: Unit, defender: Unit, skill: Skill) -> void:
	var cd: CombatEventData = current_combat_event_data

	# Reset
	cd.per_die_results.clear()
	cd.total_initial_damage = 0
	cd.total_after_defense = 0
	cd.was_crit_any = false
	
	
	var attacker_attrs := attacker.get_attributes_container()
	var defender_attrs := defender.get_attributes_container()

	var might_value: int = attacker_attrs.get_attribute_current_value(skill.prowess_attribute)
	var defense_value: int = defender_attrs.get_attribute_current_value(skill.defense_attribute)
	var acc_value: int = attacker_attrs.get_attribute_current_value("accuracy", true)
	var evd_value: int = defender_attrs.get_attribute_current_value("evade", true)
	var base_crit_chance: int = attacker_attrs.get_attribute_current_value("critical")
	var crit_value: int = base_crit_chance + skill.crit_mod

	acc_value += skill.base_accuracy + _get_formula().accuracy_base_bonus
	acc_value -= evd_value

	# Build context for triggers (shared by blessings/afflictions)
	cd.context = {
		"attacker": attacker,
		"defender": defender,
		"skill": skill,
		"action": action,
		"target": defender,
	}

	# Initialize pending roll inputs (mutable by status hooks)
	cd.pending_power_percent = skill.base_power
	cd.pending_accuracy = acc_value
	cd.pending_crit_chance = crit_value
	cd.pending_defense_value = defense_value
	cd.force_crit = false
	cd.force_miss = false
	cd.pre_roll_notes.clear()

	for s in cd.skill.skill_modifying_statuses:
		if s._conditions_pass(cd):
			cd.attacker.status_controller.add_status(s, false)

	# Pre-roll status hooks: statuses may modify pending inputs before rolling
	var attacker_statuses: StatusController = attacker.get_status_controller()
	if attacker_statuses != null:
		attacker_statuses.before_attack_roll(attacker, cd)
	var defender_statuses: StatusController = defender.get_status_controller()
	if defender_statuses != null:
		defender_statuses.before_attack_roll(defender, cd)

	# Hit and crit resolution
	_hit_resolver.resolve(cd)
	cd.accuracy = cd.pending_accuracy

	# Damage calculation (base damage minus defense; no status multipliers yet)
	_damage_calculator.calculate(cd, might_value, _get_formula())

	# Extra damage components: weapon enchantments (if uses_weapon) + skill-inherent components.
	# Calculated only on a hit, before damage_multiplier so post-roll Potency buffs scale everything.
	# NOTE: pending_defense_value / pending_power_percent (pre-roll status hooks) affect the primary
	#       component only. Components are intentionally isolated — Block reduces martial damage but
	#       not a flame enchantment's channel damage.
	if cd.is_hit:
		var formula := _get_formula()
		var w_min: int = cd.weapon.damage_min if cd.weapon != null else formula.weapon_damage_min
		var w_max: int = cd.weapon.damage_max if cd.weapon != null else formula.weapon_damage_max

		var components: Array = []
		if skill.uses_weapon and cd.weapon != null:
			components.append_array(cd.weapon.enchantment_components)
		components.append_array(skill.extra_damage_components)

		for comp in components:
			if comp.prowess_attribute.is_empty() or comp.defense_attribute.is_empty():
				push_error("DamageComponent on '%s' has empty prowess or defense attribute — skipped." % skill.skill_name)
				continue
			var comp_prowess: int = attacker_attrs.get_attribute_current_value(comp.prowess_attribute)
			var comp_defense: int = defender_attrs.get_attribute_current_value(comp.defense_attribute)
			cd.effective_damage += _damage_calculator.calculate_component(
				w_min, w_max, comp_prowess, comp.power_percent,
				comp_defense, cd.is_critical_success, formula)

	# Post-roll status hooks: statuses may modify cd.damage_multiplier (100-based)
	if attacker_statuses != null:
		attacker_statuses.before_damage_applied(cd)
	if defender_statuses != null:
		defender_statuses.before_damage_applied(cd)

	var final_damage_multiplier: float = cd.damage_multiplier / 100.0
	cd.effective_damage = int(cd.effective_damage * final_damage_multiplier)
	if cd.effective_damage < 0:
		cd.effective_damage = 0

	# Combat logs
	if not cd.is_hit:
		CombatLog.instance.add_log("Evaded")
	else:
		if cd.is_critical_success:
			CombatLog.instance.add_log("Critical Hit!")
		CombatLog.instance.add_log("Initial Damage: %d" % cd.total_initial_damage)


## Returns [member formula] if assigned; otherwise creates and caches a default [CombatFormulaResource].
func _get_formula() -> CombatFormulaResource:
	if formula == null:
		formula = CombatFormulaResource.new()
	return formula


## Choose and run the defender's Reaction using the ReactionPack system.[br]
## Delegates selection to [ReactionResolver], which evaluates the defender's [ReactionPack]
## rules (highest priority first) against the current [CombatEventData].[br]
## Respects [member CombatEventData.reaction_override] set by passives at BEFORE_HIT_RESOLVES.[br]
## If a Reaction is found, awaits its [signal Action.on_action_ended] before continuing.
func determine_reaction(cd: CombatEventData) -> void:
	var reaction: Reaction = ReactionResolver.resolve(cd, cd.defender)
	cd.reaction = reaction
	if reaction == null:
		return
	var run: Action = cd.defender.get_action_container().use_action(reaction, cd.defender, true)
	if run == null:
		push_error("Invalid Reaction on defender")
	await run.on_action_ended
	pass


## Emit a multi-section debug dump to [code]CombatLog[/code]: header, core stats, gates snapshot,
## per-die lines, totals/flags, and the chosen Reaction (if any). Only runs if [member combat_debug_enabled] is true.
func _debug_dump_current_event() -> void:
	if not combat_debug_enabled:
		return
	var cd := current_combat_event_data
	if cd == null:
		return

	var attacker_name := cd.attacker.ui_name if cd.attacker else "<none>"
	var defender_name := cd.defender.ui_name if cd.defender else "<none>"
	var action_name := cd.action.action_name if cd.action else "<none>"
	var skill_name := cd.skill.skill_name if cd.skill else "<none>"

	# Header
	var header := "[DEBUG] %s -> %s  (%s)" % [attacker_name, defender_name, skill_name]
	CombatLog.instance.add_log(header)

	# Core stats
	var core := (
		"  Type: %s | Base DMG: %d - %d | Skill: %s | DEF: %s | Melee: %s"
		% [
			cd.action.get_class(),
			cd.initial_low_damage,
			cd.initial_high_damage,
			cd.skill.prowess_attribute,
			cd.skill.defense_attribute,
			str(cd.action.is_melee)
		]
	)
	CombatLog.instance.add_log(core)


	# Gates snapshot (at resolution)
	var attacker_attrs := cd.attacker.get_attributes_container()
	var defender_attrs := cd.defender.get_attributes_container()
	var prowess_val := attacker_attrs.get_attribute_current_value(cd.skill.prowess_attribute)
	var defense_val := defender_attrs.get_attribute_current_value(cd.skill.defense_attribute)
	var evd_val := defender_attrs.get_attribute_current_value("evade")
	var acc_val := cd.accuracy

	var gates := "  Gates: %s=%d | %s=%d | EVD=%d | ACCU=%d" % [cd.skill.prowess_attribute.to_pascal_case(), prowess_val, cd.skill.defense_attribute.to_pascal_case(), defense_val, evd_val, acc_val]
	CombatLog.instance.add_log(gates)

	CombatLog.instance.add_log("  Damage Multiplier: " + str(cd.pending_power_percent / 100.0))


	var flags := "  Flags: is_hit=%s | is_success=%s | is_crit=%s | is_graze=%s | dmg=%d" % [
		str(cd.is_hit), str(cd.is_success), str(cd.is_critical_success), str(cd.is_graze), cd.effective_damage]
	CombatLog.instance.add_log(flags)


	# Reaction (if any)
	if cd.reaction != null:
		var react_line: String = "  Reaction: %s" % [cd.reaction.action_name]
		CombatLog.instance.add_log(react_line)


## Get the global [Class SkillLibrary] reference.
func get_skill_library() -> SkillLibrary:
	return skill_library

## Get the global [Class ConditionLibrary] reference.
func get_condition_library() -> ConditionLibrary:
	return condition_library
