class_name RangedAttackAction
extends AttackAction

# =========================
# Exports (tune to taste)
# =========================

@export_category("Projectile")
@export var projectile_scene: PackedScene                      # required (any Node3D)
@export var spawn_at_node: NodePath                            # optional muzzle node on attacker
@export var start_height: float = 1.0                          # added if spawn_at_node is empty
@export var target_height: float = 1.0                         # where the projectile aims on defender
@export var cleanup_on_arrival: bool = true                    # free path + projectile (if we spawned it)

@export_group("Path build")
@export var use_path_arc: bool = false                         # false = straight path + carrier parabola
@export var path_arc_height: float = 2.0
@export var path_apex_t: float = 0.5
@export var path_smooth: float = 0.25
@export var bake_interval: float = 0.05                        # tessellation for preview/precision

@export_category("Carrier motion")
@export var projectile_speed: float = 24.0
@export var carrier_arc_height: float = 0.0                    # used only when use_path_arc=false
@export var face_velocity_on: bool = true
@export var yaw_only_facing: bool = true

@export_category("Animation markers")
@export var fire_marker: StringName = &"RELEASE"               # when the projectile leaves the bow/gun
@export var fallback_fire_if_missing: StringName = &"HIT_START" # fallback marker
# NOTE: the base class’s "HIT_START/HIT_END" defines the *attack center* window.

# =========================
# Runtime
# =========================
var projectile_travel_time: float = 0.0
var _path: Path3D = null
var _carrier: ProjectileCarrier = null
var _proj: Node3D = null
var _owned_projectile: bool = false

# ------------------------------------------------------------
# We piggyback on the timing calculation step:
# AttackAction.start_action() calls get_animation_sync().
# Here we override that call to (a) build the projectile path,
# (b) pre-plan travel, and (c) move the hit moment by travel time.
# ------------------------------------------------------------
func get_animation_sync(reaction_anim_pack: AnimationPackage) -> Dictionary:
	# Ask the base class for normal sync first
	var sync := super.get_animation_sync(reaction_anim_pack)

	# Gather launch & target world positions
	var start_pos := _get_fire_world_position()
	var end_pos := _get_target_world_position()

	# Build (or rebuild) a path for this shot
	_cleanup_projectile() # in case something lingers from a previous run
	_path = _build_path(start_pos, end_pos)

	# Add a carrier and configure it
	_carrier = ProjectileCarrier.new()
	_path.add_child(_carrier)
	_carrier.speed_units_per_sec = projectile_speed
	_carrier.arc_height = carrier_arc_height if !use_path_arc else 0.0
	_carrier.face_velocity = face_velocity_on
	_carrier.yaw_only = yaw_only_facing
	_carrier.set_physics_process(true)
	_carrier.set_process(false)

	# Spawn (or attach) projectile
	_proj = _make_or_fetch_projectile()
	if _proj == null:
		push_error("RangedAttackAction: projectile_scene is missing or not a Node3D.")
	else:
		_carrier.attach_projectile(_proj, true)
		

	# PRECOMPUTE travel (this is the key bit you needed)
	projectile_travel_time = _carrier.plan_travel()

	# Figure out WHEN the projectile is released in the attack anim
	var release_t := _safe_marker_time(animation_package, fire_marker)
	if release_t < 0.0:
		release_t = _safe_marker_time(animation_package, fallback_fire_if_missing)
	if release_t < 0.0:
		release_t = 0.0   # last resort: at animation start

	# The base class resolves at: attack_delay + attack_center [+ hit_delay if enabled]
	# We want the *arrival* to be attack_delay + release_t + projectile_travel_time
	# Therefore, choose: hit_delay = (release_t + travel) - attack_center
	var attack_center := float(sync.get("attack_center", 0.0))
	var extra := (release_t + projectile_travel_time) - attack_center
	hit_delay = maxf(0.0, extra)    # never go negative; if travel is short we don't pull the hit earlier
	use_hit_delay = true            # tell AttackAction to use timer-based hit with our delay

	# Schedule the LAUNCH to match the attack playback
	var attack_delay := float(sync.get("attack_delay", 0.0))
	var launch_after := maxf(0.0, attack_delay + release_t)
	_launch_projectile_after(launch_after)

	# Optional: auto-cleanup when the projectile arrives
	if cleanup_on_arrival and _carrier != null:
		_carrier.arrived.connect(func(_p):
			_cleanup_projectile()
		)

	return sync

# =========================
# Helpers
# =========================

func _get_fire_world_position() -> Vector3:
	if spawn_at_node != NodePath() and unit.has_node(spawn_at_node):
		return unit.get_node(spawn_at_node).global_transform.origin
	return unit.right_hand_socket.get_global_position()#.get_global_position() + Vector3(0.0, start_height, 0.0)

func _get_target_world_position() -> Vector3:
	var ev := CombatSystem.instance.current_combat_event_data
	if ev == null or ev.defender == null:
		return Vector3.ZERO
	return ev.defender.get_global_position() + Vector3(0.0, target_height, 0.0)

func _build_path(start_pos: Vector3, end_pos: Vector3) -> Path3D:
	var parent := unit.get_tree().current_scene if unit.get_tree().current_scene != null else unit.get_tree().root
	if use_path_arc:
		return PathBuilder3D.make_path_arc(
			start_pos, end_pos,
			path_arc_height, path_apex_t, path_smooth,
			Vector3.UP, parent, bake_interval
		)
	else:
		return PathBuilder3D.make_path_straight(
			start_pos, end_pos,
			parent, bake_interval
		)

func _make_or_fetch_projectile() -> Node3D:
	if projectile_scene == null:
		return null
	var n = projectile_scene.instantiate()
	if !(n is Node3D):
		return null
	# put it in scene now; attach_projectile() will reparent under carrier
	_path.add_child(n)
	_owned_projectile = true
	return n

func _launch_projectile_after(delay_sec: float) -> void:
	if _carrier == null:
		return
	# place at start immediately (carrier handles that), then activate after delay
	if delay_sec <= 0.0:
		_carrier.activate()
	else:
		var t: SceneTreeTimer = unit.get_tree().create_timer(delay_sec)
		await t.timeout
		# if action got canceled and cleaned up meanwhile, guard:
		if _carrier != null and is_instance_valid(_carrier):
			_carrier.activate()

func _cleanup_projectile() -> void:
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.detach_projectile(true, true)
	if _path != null and is_instance_valid(_path):
		_path.queue_free()
	_path = null
	_carrier = null
	if _owned_projectile and _proj != null and is_instance_valid(_proj):
		_proj.queue_free()
	_proj = null
	_owned_projectile = false
