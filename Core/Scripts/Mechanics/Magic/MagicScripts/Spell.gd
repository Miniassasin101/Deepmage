class_name Spell
extends Resource

@export var ui_name: String = "None"
@export var spellforms: Array[SpellForm] = []
@export var base_magnitude: float = 1.0
@export var is_prepared: bool = false
@export var notes: String = ""


# Derived at compile time
var compiled_plan: SpellPlan = null

func compile(caster_unit: Unit, target_package: TargetPackage) -> SpellPlan:
	var build_context: SpellBuildContext = SpellBuildContext.new()
	build_context.caster = caster_unit
	build_context.primary_target = target_package
	build_context.base_magnitude = base_magnitude

	var plan: SpellPlan = SpellPlan.new()
	plan.spell = self
	plan.context = build_context

	for spellform in spellforms:
		spellform.contribute(plan, build_context)

	plan.finish_derivations(is_prepared)
	compiled_plan = plan
	return plan
