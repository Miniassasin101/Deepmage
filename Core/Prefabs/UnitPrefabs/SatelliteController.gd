class_name SatelliteController
extends Node3D

@export var satellite_prefab: PackedScene = null
@export var spawn_markers: Array[Marker3D]
var satellite_carriers: Array[SatelliteCarrier] = []

var spawn_int: int = 0

func spawn_satellite(in_satellite: Node3D) -> void:
	if in_satellite == null:
		in_satellite = Utilities.create_debug_sphere(self.get_global_position(), 0.5)
		return

	var new_carrier: SatelliteCarrier = satellite_prefab.instantiate()
	new_carrier.sat_controller = self
	var spawn_marker: Marker3D = get_first_free_spawn_marker()
	if spawn_marker == null:
		return

	add_child(new_carrier)                 # <= parent here, not under the marker
	new_carrier.set_anchor(spawn_marker)   # <= tell it which marker to follow
	new_carrier.snap_to_anchor()           # start exactly at anchor, then lag can show after
	new_carrier.add_satellite(in_satellite)

	satellite_carriers.append(new_carrier)

func get_first_free_spawn_marker() -> Marker3D:
	# TODO: replace with a proper free-slot search; for now, first slot
	if spawn_markers.size() == 0:
		return null
	var marker: Marker3D = spawn_markers.get(clampi(spawn_int, 0, spawn_markers.size() - 1))
	spawn_int += 1
	if spawn_int >= spawn_markers.size():
		spawn_int = 0
	return marker

func get_satellite_carriers() -> Array[SatelliteCarrier]:
	return satellite_carriers
