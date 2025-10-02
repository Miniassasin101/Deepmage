# spell_plan.gd
class_name SpellPlan
extends Resource

@export var spell_steps: Array[SpellStep] = []
var spell: Spell
var context: SpellBuildContext

# Rollups
var mana_cost: int = 0
var cast_speed_units: int = 0
var is_offensive: bool = false
var uses_projectile: bool = false
var needs_unit_target: bool = false
var needs_position_target: bool = false
var base_damage_pool: int = 0
var accuracy_attribute_1: String = "willpower"
var accuracy_attribute_2: String = "spellcasting"

# Derived enums (simple)
enum SpeedClass { QUICK, STANDARD, SLOW }
var speed_class: int = SpeedClass.STANDARD

func add_step(step: SpellStep) -> void:
	spell_steps.append(step)

func add_cost(cost_delta: int) -> void:
	mana_cost = maxi(0, mana_cost + cost_delta)

func add_speed(units_delta: int) -> void:
	cast_speed_units = maxi(0, cast_speed_units + units_delta)

func mark_offensive() -> void:
	is_offensive = true

func set_needs_target(unit_required: bool, pos_required: bool) -> void:
	if unit_required:
		needs_unit_target = true
	if pos_required:
		needs_position_target = true

func finish_derivations(is_prepared: bool) -> void:
	# Convert speed units → coarse class
	if cast_speed_units <= 1:
		speed_class = SpeedClass.QUICK
	elif cast_speed_units <= 3:
		speed_class = SpeedClass.STANDARD
	else:
		speed_class = SpeedClass.SLOW
	
	# Prepared reduces speed class by one step (floor at QUICK)
	if is_prepared and speed_class > SpeedClass.QUICK:
		speed_class -= 1
