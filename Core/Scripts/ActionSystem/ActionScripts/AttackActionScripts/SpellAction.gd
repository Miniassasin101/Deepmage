class_name SpellAction
extends AttackAction

@export var mana_cost: int = 0
@export var spell_name: String = "None"
## Applies the combat result to the defender (miss/graze text, damage, and hit reaction + damage label).
func do_resolve() -> void:

	Utilities.spawn_text_line(unit, "Spell Cast: " + spell_name)
	
	unit.get_attributes_container().change_attribute_current_value_by("mana", -mana_cost)
	
	var curr_mana: int = unit.get_attributes_container().get_attribute_current_value("mana")
	
	CombatLog.instance.add_log("Current Mana Left: " + str(curr_mana))
	
	var sphere: TestBall = Utilities.create_debug_sphere(unit.get_global_position(), 205.0)
	
	var color: Color = pick_random_color([Color.RED, Color.PURPLE, Color.AQUA, Color.YELLOW, Color.WEB_GRAY])
	
	sphere.set_color(color)
	
	var rand_num: float = randf_range(0.88, 1.20)
	sphere.set_scale(Vector3(rand_num, rand_num, rand_num))
	
	unit.satellite_controller.spawn_satellite(sphere)

# --- put at top-level of your spell script (or in a Colors.gd util) ---
var _rng := RandomNumberGenerator.new()



## Returns a random color from `palette`.
## Optional HSV jitter lets you add small natural variation (defaults to none).
##   hsv_jitter = Vector3(hue_delta, sat_delta, val_delta) in 0..1 space.
func pick_random_color(palette: Array[Color], hsv_jitter: Vector3 = Vector3.ZERO) -> Color:
	if palette.is_empty():
		return Color.WHITE
	_rng.randomize()
	var base := palette[_rng.randi_range(0, palette.size() - 1)]
	if hsv_jitter == Vector3.ZERO:
		return base

	var h := base.h
	var s := base.s
	var v := base.v
	h = fposmod(h + _rng.randf_range(-hsv_jitter.x, hsv_jitter.x), 1.0)
	s = clamp(s + _rng.randf_range(-hsv_jitter.y, hsv_jitter.y), 0.0, 1.0)
	v = clamp(v + _rng.randf_range(-hsv_jitter.z, hsv_jitter.z), 0.0, 1.0)
	return Color.from_hsv(h, s, v, base.a)


## Checks if this action can be used on the given target pack (range, self-target, and pathing).
func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if target_pack == null or !target_pack.has_tag("unit"):
		return false
	
	if unit.get_attributes_container().get_attribute_current_value("mana") < mana_cost:
		return false
	
	var target_unit: Unit = target_pack.unit

	if action_container == null:
		return false

	if target_unit != action_container.unit:
		return false

	return true
