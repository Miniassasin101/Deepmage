class_name SpellLaunchSatelliteAction
extends RangedAttackAction

@export var mana_cost: int = 0
@export var spell_name: String = "None"

var times_launched: int = 0

## Applies the combat result to the defender (miss/graze text, damage, and hit reaction + damage label).
func do_resolve() -> void:

	Utilities.spawn_text_line(unit, "Spell Cast: " + spell_name)
	
	unit.get_attributes_container().change_attribute_current_value_by("mana", -mana_cost)
	
	var curr_mana: int = unit.get_attributes_container().get_attribute_current_value("mana")
	
	CombatLog.instance.add_log("Current Mana Left: " + str(curr_mana))
	
	var ev := CombatSystem.instance.current_combat_event_data
	var defender: Unit = ev.defender
	var effective_damage: int = ev.effective_damage
	var is_hit := ev.is_hit
	var is_graze := ev.is_graze

	# Feedback / damage
	if !is_hit:
		if is_graze and ev.is_success:
			Utilities.spawn_text_line(defender, "Graze", Color.AQUA)
			CombatLog.instance.add_log("Result: Graze")
		else:
			Utilities.spawn_text_line(defender, "MISS", Color.AQUA)
			CombatLog.instance.add_log("Result: Miss")
		return

	# On-hit damage
	defender.get_attributes_container().add_attribute_modifier("health", -effective_damage)
	var color: Color
	if effective_damage == 0:
		color = Color.ALICE_BLUE
	else:
		color = Color.FIREBRICK
		defender.animation_controller.play_hit_reaction()
	Utilities.spawn_damage_label(defender, effective_damage, color, 0.5)
	
	ev.reaction.on_impact()
	

func _make_or_fetch_projectile() -> Node3D:
	var sat_carr: SatelliteCarrier = unit.satellite_controller.get_satellite_carriers().front()
	if sat_carr == null:
		return null
	var sphere: TestBall = sat_carr.retrieve_satellite() if sat_carr.satellite \
	else Utilities.create_debug_sphere(sat_carr.global_position, 250)
	if sphere == null:
		return null
	
	#sat_carr.set_follow_lag_seconds(0.01)
	CombatLog.instance.add_log("Carrier Pos: " + str(sat_carr.get_global_position()))
	CombatLog.instance.add_log("Ball Pos: " + str(sphere.get_global_position()))
	
	var n = sat_carr
	if !(n is Node3D):
		return null
	# put it in scene now; attach_projectile() will reparent under carrier
	n.reparent(_path, true)
	
	#_path.add_child(n)
	_owned_projectile = true
	return n


func _get_fire_world_position() -> Vector3:
	var pos: Vector3 = unit.satellite_controller.get_satellite_carriers().front().get_global_position()
	times_launched += 1
	return pos



## Checks if this action can be used on the given target pack (range, self-target, and pathing).
func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if target_pack == null or !target_pack.has_tag("unit"):
		return false
	
	if unit.get_attributes_container().get_attribute_current_value("mana") < mana_cost:
		return false
	
	var target_unit: Unit = target_pack.unit


	if action_container == null:
		return false

	if target_unit == action_container.unit:
		return false
	
	if unit.satellite_controller.get_satellite_carriers().is_empty():
		return false

	if get_distance_to_unit(target_unit) > attack_range:
		return false
	return true
