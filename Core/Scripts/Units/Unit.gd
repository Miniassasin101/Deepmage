@tool
class_name Unit
extends Node3D


enum TurnState {
	OUTSIDE_COMBAT,
	IN_QUEUE,
	TURN_STARTED,
	TURN_ENDED
}
#

@export_category("References")
@export_group("Refs")
@export var above_head_marker: Marker3D
@export var nav_agent: NavigationAgent3D
@export var death_vfx_scene: PackedScene
@export var capsule_body: MeshInstance3D
@export var capsule_visor: MeshInstance3D
@export var selection_visual: SelectionSquareVisual
@export var character_sheet: CharacterSheet
@export var movement_controller: MovementController
@export var animation_controller: AnimationController
@export var satellite_controller: SatelliteController
@export var status_controller: StatusController
@export var tactics_controller: TacticsController
@export_group("Sockets")
@export var left_hand_socket: Marker3D
@export var right_hand_socket: Marker3D
@export_group("")


@export_category("Prefabs")
@export var character_sheet_packed_scene: PackedScene = null


@export_category("Tactics")
@export var starting_tactic: Tactic = null

@export_category("Unique Aspects")

@export var ui_name: String = "Unit":
	set(val):
		ui_name = val
		change_node_name_to_unit()

@export var is_enemy: bool = false
@export var visor_color: Color = Color.ALICE_BLUE

@export_category("Visual Modifiers")
@export var white_hit_flash_mat: StandardMaterial3D
@export var hit_flash_time: float = 0.3

@export_category("Tags")
@export var tags: Array[String] = []



var turn_state: TurnState = TurnState.OUTSIDE_COMBAT





func _ready() -> void:
	if Engine.is_editor_hint():
		if not get_parent() is UnitManager:
			print_debug("Parent is not UnitManager")
			return
		if !character_sheet_packed_scene:
			print("Packed Scene Not Found")
			return
		if character_sheet:
			print_debug("Character sheet already found")
			return
		#var char_sheet: CharacterSheet = character_sheet_packed_scene.instantiate() as CharacterSheet

		#add_child(char_sheet)
		#char_sheet.set_owner(get_tree().edited_scene_root)
		#character_sheet = char_sheet
		#print("added child")
		property_list_changed.connect(change_node_name_to_unit)
		return
	setup_navigation()
	call_deferred("setup_mesh_colors")
	_connect_attribute_signals()


# ─────────────────────────────────────────────────────────────────────────────
# State Queries
# ─────────────────────────────────────────────────────────────────────────────

func is_alive() -> bool:
	return !is_downed()


## Returns true if this unit currently has the Downed status applied.
func is_downed() -> bool:
	if status_controller == null:
		return false
	return status_controller.get_status_by_name("Downed") != null


# ─────────────────────────────────────────────────────────────────────────────
# Downed / Revival
# ─────────────────────────────────────────────────────────────────────────────

## Applies the Downed status: zeroes AP/PP, dims visuals, emits defeat signal.
## Called automatically when posture hits 0 (if death_enabled on TurnSystem).
## Can also be called manually for scripted knockouts.
func apply_downed() -> void:
	var downed_status: DownedStatus = DownedStatus.new()
	status_controller.add_status(downed_status)
	UnitManager.instance.register_downed(self)
	SignalBus.on_unit_defeated.emit(self)
	Utilities.spawn_text_line(self, "DOWNED", Color.GRAY)
	CombatLog.instance.add_log(ui_name + " has been downed!")


## Removes the Downed status and restores visuals.
## If revived during the planning phase, also restores AP/PP and re-adds the unit
## to the initiative queue so they can fully participate in the upcoming round.
## If revived during resolution, AP/PP remain at 0 until the next round refresh.
func revive() -> void:
	var downed_status: Status = status_controller.get_status_by_name("Downed")
	if downed_status == null:
		return
	status_controller.remove_status(downed_status)
	UnitManager.instance.register_revived(self)
	SignalBus.on_unit_revived.emit(self)
	Utilities.spawn_text_line(self, "REVIVED!", Color.GREEN)
	CombatLog.instance.add_log(ui_name + " has been revived!")

	# During planning the round's initiative roll and AP/PP refresh have already
	# happened, so we restore them manually and inject the unit into the queue.
	if TurnSystem.instance != null:
		var phase: int = TurnSystem.instance.current_phase
		var in_planning: bool = (phase == TurnSystem.RoundPhase.AI_PLANNING
				or phase == TurnSystem.RoundPhase.PLAYER_PLANNING)
		if in_planning:
			_restore_ap_pp_to_base()
			TurnSystem.instance.add_revived_unit_to_round(self)


## Restores AP and PP to their base (maximum) values.
## Called on planning-phase revival so the unit is ready to act in the upcoming round.
func _restore_ap_pp_to_base() -> void:
	var attrs: AttributesContainer = get_attributes_container()
	var ap: Attribute = attrs.get_attribute("active_points")
	if ap:
		attrs.set_attribute_current_value("active_points", ap.base_value)
	var pp: Attribute = attrs.get_attribute("passive_points")
	if pp:
		attrs.set_attribute_current_value("passive_points", pp.base_value)


# ─────────────────────────────────────────────────────────────────────────────
# Attribute Signal Handlers
# ─────────────────────────────────────────────────────────────────────────────

## Connects to the AttributesContainer's track signals so posture crossing 0
## automatically triggers the downed/revival flow.
## Called from _ready() — children run _ready() before parents in Godot 4,
## so AttributesContainer is guaranteed to be initialized at this point.
func _connect_attribute_signals() -> void:
	if character_sheet == null:
		push_warning(ui_name + ": Cannot connect attribute signals — character_sheet is null.")
		return
	var attrs: AttributesContainer = character_sheet.get_attributes_container()
	if attrs == null:
		push_warning(ui_name + ": Cannot connect attribute signals — AttributesContainer is null.")
		return
	attrs.track_depleted.connect(_on_track_depleted)
	attrs.track_restored.connect(_on_track_restored)


## Fired by AttributesContainer when a Track attribute crosses from above 0 to 0.
## Triggers the downed state if it's posture, the unit isn't already down,
## and death is enabled in TurnSystem (debug toggle).
func _on_track_depleted(attribute_name: String) -> void:
	if attribute_name != "posture":
		return
	if is_downed():
		return  # Already downed; don't apply twice.
	if TurnSystem.instance == null or !TurnSystem.instance.death_enabled:
		return  # Debug immortal mode — skip downed state entirely.
	apply_downed()


## Fired by AttributesContainer when a Track attribute rises from 0 back above 0.
## Triggers revival if the unit is currently downed.
func _on_track_restored(attribute_name: String) -> void:
	if attribute_name != "posture":
		return
	if !is_downed():
		return  # Not downed; nothing to revive.
	revive()



func change_node_name_to_unit() -> void:
	if !Engine.is_editor_hint():
		return
	if (ui_name != "Unit") and (get_name() != ui_name):
		if ui_name.is_empty():
			set_name("Unit")
		else:
			set_name(ui_name)
		print("name changed to " + name)


func setup_mesh_colors() -> void:
	if is_enemy:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.FIREBRICK)
	else:
		Utilities.set_color_on_cel_shaded_mesh(capsule_visor, Color.SKY_BLUE)
	
	Utilities.set_color_on_cel_shaded_mesh(capsule_body, visor_color)


func setup_navigation() -> void:
	if !nav_agent:
		nav_agent = find_child("NavigationAgent3D")


func set_movement_target(movement_target: Vector3):
	nav_agent.set_target_position(movement_target)
	

func flash_white(flash_time: float = hit_flash_time) -> void:
	if flash_time <= 0.1:
		flash_time = 0.1
	var unit_meshes: Array[MeshInstance3D] = get_all_unit_meshes()
	var saved_mat_overrides: Array[StandardMaterial3D] = []
	for mesh in unit_meshes:
		saved_mat_overrides.append(mesh.get_material_override())
		mesh.set_material_override(white_hit_flash_mat)

	await get_tree().create_timer(flash_time).timeout

	for mesh in unit_meshes:
		mesh.set_material_override(saved_mat_overrides.pop_front())

func has_tag(in_tag: String) -> bool:
	if tags.has(in_tag.to_lower()):
		return true
	return false



func get_all_unit_meshes() -> Array[MeshInstance3D]:
	return [capsule_body, capsule_visor]


func get_world_position_above_marker() -> Vector3:
	return above_head_marker.global_position if above_head_marker else Vector3.ZERO

func get_action_container() -> ActionContainer:
	return character_sheet.action_container


func get_attributes_container() -> AttributesContainer:
	return character_sheet.get_attributes_container()

func get_status_controller() -> StatusController:
	return status_controller
