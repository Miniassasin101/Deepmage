class_name Weapon
extends BuildSource

enum WeaponType { UNARMED, SWORD, DAGGER, AXE, SPEAR, MACE, SHIELD, BOW, CROSSBOW, STAFF, ORB, TOME }
enum SocketSlot  { RIGHT_HAND, LEFT_HAND, ORBITING }

@export_group("Weapon Stats")
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var damage_min: int = 3
@export var damage_max: int = 6
@export var is_two_handed: bool = false
@export var weapon_traits: Array[StringName] = []  # &"Reach", &"Thrown", &"Channeling"…

@export_group("Visual")
@export var visual_scene: PackedScene          # 3-D model scene instantiated at the socket
@export var visual_socket: SocketSlot = SocketSlot.RIGHT_HAND

@export_group("On-Hit Effects")
## Applied after every successful hit with any skill that came from this weapon.
@export var inherent_effects: Array[Effect] = []
