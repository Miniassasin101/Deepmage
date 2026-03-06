class_name DownedStatus
extends Status

## Applied when a unit's posture reaches 0.
## Narratively: the unit is knocked out, not dead.
## Removed by healing effects that restore posture above 0.


func _init() -> void:
	ui_name = "Downed"
	status_category = StatusCategory.SPECIAL
	expire_timing = ExpireTiming.Never


func on_added(unit: Unit) -> void:
	# Prevent the unit from taking any actions while downed.
	unit.get_attributes_container().set_attribute_current_value("active_points", 0)
	unit.get_attributes_container().set_attribute_current_value("passive_points", 0)

	# Dim all unit meshes to visually communicate downed state.
	for mesh: MeshInstance3D in unit.get_all_unit_meshes():
		mesh.transparency = 0.6


func on_removed(unit: Unit) -> void:
	# Restore mesh transparency when the unit is revived.
	# AP/PP are restored naturally by TurnSystem at the start of the next round.
	for mesh: MeshInstance3D in unit.get_all_unit_meshes():
		mesh.transparency = 0.0
