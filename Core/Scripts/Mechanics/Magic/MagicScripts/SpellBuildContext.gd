# spell_build_context.gd
class_name SpellBuildContext
extends Resource

var caster: Unit
var primary_target: TargetPackage
var base_magnitude: float = 1.0

# Shared runtime stash while steps execute
var conjured_nodes: Array[Node3D] = []
var created_subject: Node3D = null  # e.g., the “force orb”
var delivery_type: String = ""      # "satellite", "projectile", "beam", etc.
var projectile_scene: PackedScene = null
var projectile_speed: float = 24.0
var satellite_offset: Vector3 = Vector3(0, 1.2, 0)
