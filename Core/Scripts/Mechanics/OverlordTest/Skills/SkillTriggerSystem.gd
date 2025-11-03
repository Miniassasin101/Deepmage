class_name SkillTriggerSystem
extends Node


enum TriggerPhase {NONE, ON_ROUND_START, BEFORE_SKILL_USED, AFTER_SKILL_USED, ON_ROUND_END}


@export var combat_system: CombatSystem = null

static var instance: SkillTriggerSystem

func _ready() -> void:
	if instance != null:
		queue_free()
		return
	instance = self

func fire(_trigger_name: String, _context: Dictionary) -> void:
	# Later: route to units’ passives/gear/leader auras that subscribed to this trigger_name
	# Example: for equip in context.user.equipment: if trigger_name in equip.triggers: equip.on_trigger(context)
	pass





func get_chaining_units_with_context(ctx: Dictionary) -> Dictionary[Unit, Skill]:
	# ctx expects: source_skill, source_user, source_target, trigger_phase
	var results: Dictionary[Unit, Skill] = {}

	var phase: int = ctx.get("trigger_phase", TriggerPhase.NONE)
	if phase == TriggerPhase.NONE:
		return results

	for reactor_unit in TurnSystem.instance.initiative_queue:
		if reactor_unit == null:
			continue
		if !reactor_unit.is_alive():
			continue
		if TurnSystem.instance.used_p_skill_this_turn.has(reactor_unit):
			continue

		var passive_skill: Skill = reactor_unit.tactics_controller.get_first_valid_passive_skill_with_context(ctx)
		if passive_skill != null:
			results[reactor_unit] = passive_skill

	return results
