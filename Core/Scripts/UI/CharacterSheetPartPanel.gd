class_name CharacterSheetPartPanel
extends PanelContainer


var part_name_label: Label
var armor_point_value_label: Label
var health_points_label: Label

func _ready() -> void:
	var hitcontainer: HBoxContainer = get_child(0)
	part_name_label = hitcontainer.get_child(0)
	armor_point_value_label = hitcontainer.get_child(1)
	health_points_label = hitcontainer.get_child(2)


func _testfunc() -> void:
	var test: String = get_child(0).get_child(0).text
	print("Test: ", test)

func set_part_data(part_name: String, armor_value: int, health_value: int, max_health_value: int) -> void:
	if part_name_label == null:
		construct_labels()
	# Update this panel's labels based on the given data
	part_name_label.text = part_name
	armor_point_value_label.text = str(armor_value)
	health_points_label.text = (str(health_value) + "/" + str(max_health_value))

func construct_labels() -> void:
	var hitcontainer: HBoxContainer = get_child(0)
	part_name_label = hitcontainer.get_child(0)
	armor_point_value_label = hitcontainer.get_child(1)
	health_points_label = hitcontainer.get_child(2)
