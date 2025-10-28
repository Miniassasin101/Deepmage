# cast_spell_action.gd
class_name CastSpellAction
extends AttackAction

@export var spell: Spell

func _ready() -> void:
	if spell:
		action_name = "Cast: " + spell.ui_name


func get_accuracy_attributes() -> Array[String]:
	if spell and spell.compiled_plan:
		return [""]
	return [""]



func start_action(targ_pack: TargetPackage = null) -> void:
	
	action_container.on_action_started(self)
	
	if targ_pack == null:
		targ_pack = TargetPackage.new() # Only allows self only spells
	
	spell.compile(unit, targ_pack)
	
	var plan: SpellPlan = spell.compiled_plan
	var ctx: SpellBuildContext = plan.context
	
	# Copy delivery into RangedAttackAction fields (if projectile)
	if plan.uses_projectile:
		#projectile_scene = ctx.projectile_scene
		#projectile_speed = ctx.projectile_speed
		pass
	
	# Utility vs Offensive split
	if !plan.is_offensive:
		#await _play_cast_animation_then_run_steps(plan)
		end_action()
		return
	
	# Offensive: reuse AttackAction pipeline (movement/rotation/reaction/tests/resolve)
	#await move_to_target_if_required()
	spawn_action_name_text()
	if targ_pack != null and targ_pack.get_unit() != null:
		await rotate_towards_target(targ_pack.unit)
	
	# Declare to CombatSystem so reactions/tests can occur prior
	await CombatSystem.instance.declare_attack(self, unit, targ_pack.get_unit())
	
	# Build sync, install projectile travel timing as in base RangedAttackAction
	var reaction_pack: AnimationPackage = get_reaction_anim_pack()
	var sync: Dictionary = get_animation_sync(reaction_pack)
	modify_shake_and_hitstop()
	_play_attack_with_delay(animation_package, sync)
	_play_reaction_with_delay(reaction_pack, sync)
	
	
	# Wait for hit moment then resolve rules and steps (damage happens in base; forms add extra)
	await _resolve_at_hit_moment_or_timer(sync)
	
	
	
	
	
	
