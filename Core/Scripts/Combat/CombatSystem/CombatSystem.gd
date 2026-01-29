## [b]Class:[/b] CombatSystem
## [i]Central coordinator for resolving combat actions using a Gubat Banwa–style flow.[/i]
## 
## [b]Responsibilities[/b][br]
## • Owns the active [code]CombatEventData[/code] for an in-progress attack.[br]
## • Applies GB dice logic: EVD gate, melee chaining (top-or-higher), ranged crit (top-or-higher), Prowess/Defense, and minimum damage rules.[br]
## • Determines and awaits defender [b]Reactions[/b] (e.g. [code]"Block"[/code], [code]"Evade"[/code]).[br]
## • Emits detailed logs when [member combat_debug_enabled] is [code]true[/code].
##
## [b]Design Notes[/b][br]
## • Singleton-like: first instance sets [code]CombatSystem.instance[/code]; later instances self-remove in [method Node._ready].[br]
## • Core resolution lives in [method _resolve_attack_gubat_banwa]. Per-die meta is handled by [method _roll_single_die_meta].[br]
## • A legacy single-die helper exists as [method _process_single_violence_die] (kept for reference/tests).[br]
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
@export var crit_dmg_multiplier: float = 1.5


## The working record for the currently executing combat event; populated throughout resolution.
var current_combat_event_data: CombatEventData = null



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
## Initializes a fresh [code]CombatEventData[/code], logs, runs GB resolution, then resolves any queued Reaction.
##
## [b]Parameters[/b][br]
## • [param action]: [Class AttackAction] — the action to resolve.[br]
## • [param attacker]: [Class Unit] — the attacking unit.[br]
## • [param defender]: [Class Unit] — the defending unit.
##
## [b]Side Effects[/b][br]
## • Populates [member current_combat_event_data] with dice results, flags, and totals.[br]
## • May spawn floating text via [code]Utilities.spawn_text_line[/code].[br]
## • May enqueue/resolve a Reaction on the defender via their [code]ActionContainer[/code].
func declare_attack(action: AttackAction, attacker: Unit, defender: Unit, skill: Skill = null) -> void:
	current_combat_event_data = CombatEventData.new()

	# Set combat event participants 
	current_combat_event_data.attacker = attacker
	current_combat_event_data.defender = defender

	# Set Combat Event Action
	current_combat_event_data.action = action
	
	# Set Skill
	current_combat_event_data.skill = skill if skill != null else action.fallback_skill
	

	# High-level log of the attempt
	CombatLog.instance.add_log()
	CombatLog.instance.add_log(attacker.ui_name + " attacks " + defender.ui_name + " with " + current_combat_event_data.skill.skill_name)

	# Hook point: “ally attacked”, “enemy attacked”, etc. (left as a placeholder)
	
	
	# 2) Resolve using Gubat Banwa steps
	if skill == null or skill.skill_type != Skill.SkillType.ATTACK:
		return
	#await _resolve_attack_gubat_banwa(action, attacker, defender, skill)
	_resolve_attack_darkest_dungeon(action, attacker, defender, current_combat_event_data.skill)
	
	await determine_reaction(current_combat_event_data)
	
	_debug_dump_current_event()
	
	# Execute a queued Reaction (if any)
	if current_combat_event_data.reaction:
	
		current_combat_event_data.reaction.resolve_reaction()


func _resolve_attack_darkest_dungeon(action: AttackAction, attacker: Unit, defender: Unit, skill: Skill) -> void:
	var cd: CombatEventData = current_combat_event_data
	
	# Reset
	cd.per_die_results.clear()
	cd.total_initial_damage = 0
	cd.total_after_defense = 0
	cd.any_die_hit = false
	cd.was_crit_any = false
	cd.chained_count = 0
	
	var attacker_attrs := attacker.get_attributes_container()
	var defender_attrs := defender.get_attributes_container()
	
	var might_value: int = attacker_attrs.get_attribute_current_value(action.prowess_attribute)
	var defense_value: int = defender_attrs.get_attribute_current_value(action.defense_attribute)   # PAR/RES
	var acc_value: int = attacker_attrs.get_attribute_current_value("accuracy")
	var evd_value: int = defender_attrs.get_attribute_current_value("evade")                    # EVD

	# NEW: allow a crit chance attribute; still honors skill.crit_mod
	var base_crit_chance: int =  attacker_attrs.get_attribute_current_value("critical")
	var crit_value: int = base_crit_chance + skill.crit_mod

	
	acc_value += skill.base_accuracy + 5
	acc_value -= evd_value
	
	var weapon_low_dmg: int = 1
	var weapon_high_dmg: int = 3
	
	var min_base_dmg: int = weapon_low_dmg + might_value
	var max_base_dmg: int = weapon_high_dmg + might_value
	
	var base_power: float = float(skill.base_power)
	var damage_multiplier: float = base_power/100
	
	var modded_low_dmg: float = min_base_dmg * damage_multiplier
	var modded_high_dmg: float = max_base_dmg * damage_multiplier
	
	var is_crit: bool = roll_crit(crit_value)
	
	# roll damage floors the low and high damage, always rounding down if a decimal
	var dmg_roll: int = roll_damage(modded_low_dmg, modded_high_dmg, is_crit)
	
	var is_hit: bool = roll_hit(acc_value)
	
	
	
	cd.is_hit = is_hit
	cd.accuracy = acc_value
	cd.was_crit_any = is_crit
	cd.is_success = is_hit
	cd.is_critical_success = is_crit
	cd.is_graze = false
	cd.initial_low_damage = int(modded_low_dmg)
	cd.initial_high_damage = int(modded_high_dmg)
	cd.total_initial_damage = dmg_roll
	# NOTE: Protection and defense calculations here
	
	var damage_post_defense: int = dmg_roll - defense_value
	
	cd.effective_damage = damage_post_defense
	
	

	
	# NOTE: condition and effect Damage modifiers here (ex: +50% dmg vs Soaked targets)
	
	
	# === let ATTACKER statuses modify the pending result (e.g., Blind, PotencyUp) ===
	var attacker_statuses: StatusController = attacker.get_status_controller()
	if attacker_statuses != null:
		attacker_statuses.before_damage_applied(cd)
	# === DEFENDER statuses (e.g., Block, CritSealIncoming, PotencyDown) ===
	var defender_statuses: StatusController = defender.get_status_controller()
	if defender_statuses != null:
		defender_statuses.before_damage_applied(cd)
	
	var final_damage_multiplier: float = cd.damage_multiplier/100.0
	
	var curr_eff_dmg: float = cd.effective_damage
	curr_eff_dmg *= final_damage_multiplier
	
	
	
	cd.effective_damage = int(curr_eff_dmg) # rounds down
	
	
	
		# Clamp after status math
	if cd.effective_damage < 0:
		cd.effective_damage = 0


	# Combat Logs
	if not is_hit:
		CombatLog.instance.add_log("Evaded")
	else:
		if is_crit:
			CombatLog.instance.add_log("Critical Hit!")
		CombatLog.instance.add_log("Initial Damage: %d" % cd.total_initial_damage)
		




func roll_crit(crit_chance: int) -> bool:
	if crit_chance <= 0:
		return false
	
	if crit_chance >= 100:
		return true
	
	var random_num: int = randi_range(1, 100)
	
	if random_num <= crit_chance:
		return true
	
	return false


# Roll Under hit chance function
func roll_hit(hit_chance: int) -> bool:
	if hit_chance >= 100:
		return true
	if hit_chance <= 0:
		return false
	
	var rolled_num: int = randi_range(1, 100)
	
	if rolled_num <= hit_chance:
		return true
	
	return false


func roll_damage(low_dmg: float, high_dmg: float, is_crit: bool) -> int:
	
	if is_crit:
		return int(high_dmg * crit_dmg_multiplier)
	
	var rolled_num: int = randi_range(int(low_dmg), int(high_dmg))
	
	return rolled_num
	
	





## Choose and run the defender’s Reaction based on the event flags.[br]
## If [member CombatEventData.is_hit] is true → try [code]"Block"[/code]; otherwise → [code]"Evade"[/code].[br]
## If a Reaction is found and used, waits for its [signal Reaction.on_action_ended] before continuing.
func determine_reaction(cd: CombatEventData) -> void:
	if cd.is_hit:
		cd.reaction = cd.defender.get_action_container().get_action_by_name("Block")
	else:
		cd.reaction = cd.defender.get_action_container().get_action_by_name("Evade")
	if cd.reaction:
		var react: Reaction = cd.defender.get_action_container().use_action(cd.reaction, cd.defender)
		await react.on_action_ended
	return


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
			cd.action.prowess_attribute,
			cd.action.defense_attribute,
			str(cd.action.is_melee_attack)
		]
	)
	CombatLog.instance.add_log(core)


	# Gates snapshot (at resolution)
	var attacker_attrs := cd.attacker.get_attributes_container()
	var defender_attrs := cd.defender.get_attributes_container()
	var prowess_val := attacker_attrs.get_attribute_current_value(cd.action.prowess_attribute)
	var defense_val := defender_attrs.get_attribute_current_value(cd.action.defense_attribute)
	var evd_val := defender_attrs.get_attribute_current_value("evade")
	var acc_val := cd.accuracy

	var gates := "  Gates: %s=%d | %s=%d | EVD=%d | ACCU=%d" % [cd.action.prowess_attribute.to_pascal_case(), prowess_val, cd.action.defense_attribute.to_pascal_case(), defense_val, evd_val, acc_val]
	CombatLog.instance.add_log(gates)
	
	CombatLog.instance.add_log("  Damage Multiplier: " + str(cd.damage_multiplier / 100.0))


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
