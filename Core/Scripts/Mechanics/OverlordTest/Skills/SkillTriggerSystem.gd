class_name SkillTriggerSystem
extends Node


## Trigger phases for passive skill reactions.
##
## IMPORTANT: Existing values (0–4) are stored as integers in .tres resource files.
## New phases must always be appended at the END to avoid remapping existing skills.
##
## Reactable phases (go through the chain group in TurnSystem):
##   BEFORE_SKILL_USED    — skill declared, before it executes (Shield Ally, counters)
##   BEFORE_HIT_RESOLVES  — at the hit moment, before damage is applied (Evade, Halve Damage)
##   AFTER_HIT_RESOLVES   — immediately after damage is applied (Thorny Skin, revenge effects)
##   AFTER_SKILL_USED     — after skill fully resolves (follow-up attacks, crit buffs)
##
## Non-reactable phases (fire() path, no chaining):
##   ON_ROUND_START — before any unit acts in the round (Tailwind, initiative buffs)
##   ON_ROUND_END   — after all AP is spent (Parting Shot, end-of-round heals)
enum TriggerPhase {
	NONE,                # 0 — no trigger
	ON_ROUND_START,      # 1 — pre-existing; .tres resources use this value
	BEFORE_SKILL_USED,   # 2 — pre-existing
	AFTER_SKILL_USED,    # 3 — pre-existing
	ON_ROUND_END,        # 4 — pre-existing
	BEFORE_HIT_RESOLVES, # 5 — new in Phase 5
	AFTER_HIT_RESOLVES,  # 6 — new in Phase 5
}

## Maps the string keys used by fire() call sites to TriggerPhase enum values.
## Only ROUND_START and ROUND_END are handled; all others are stubs for future systems.
const _FIRE_PHASE_MAP: Dictionary = {
	"ROUND_START": TriggerPhase.ON_ROUND_START,
	"ROUND_END":   TriggerPhase.ON_ROUND_END,
}


@export var combat_system: CombatSystem = null

static var instance: SkillTriggerSystem

func _ready() -> void:
	if instance != null:
		queue_free()
		return
	instance = self


## Fires a named trigger event. Handles ROUND_START and ROUND_END by iterating the
## initiative queue and executing each unit's matching passive skill without chaining
## (round-boundary passives cannot be reacted to).
##
## All other trigger names (TURN_START, TURN_END, BEFORE_ACTION, AFTER_ACTION) are
## intentional stubs: TURN_START/TURN_END are reserved for a future status-tick system,
## and BEFORE_ACTION/AFTER_ACTION are reserved for future equipment/gear hooks.
func fire(trigger_name: String, context: Dictionary) -> void:
	var t_phase: int = _FIRE_PHASE_MAP.get(trigger_name, TriggerPhase.NONE)
	if t_phase == TriggerPhase.NONE:
		return  # stub — not a skill trigger phase

	if TurnSystem.instance == null:
		return

	# Build the context dict that can_trigger_passive_skill() reads
	var trigger_ctx: Dictionary = {"trigger_phase": t_phase}
	trigger_ctx.merge(context)

	for reactor_unit in TurnSystem.instance.initiative_queue:
		if reactor_unit == null:
			continue
		if !reactor_unit.is_alive():
			continue
		if reactor_unit.tactics_controller == null:
			continue

		var passive_skill: Skill = reactor_unit.tactics_controller.get_first_valid_passive_skill_with_context(trigger_ctx)
		if passive_skill != null:
			await TurnSystem.instance.execute_passive_skill_no_chain(passive_skill, reactor_unit)


## Returns a mapping of units to their valid reactive passive skill for the given context.
## Used by TurnSystem's chain group pipeline for BEFORE/AFTER_SKILL_USED and
## BEFORE/AFTER_HIT_RESOLVES phases.
##
## ctx expects: source_skill, source_user, source_target, trigger_phase
func get_chaining_units_with_context(ctx: Dictionary) -> Dictionary[Unit, Skill]:
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
