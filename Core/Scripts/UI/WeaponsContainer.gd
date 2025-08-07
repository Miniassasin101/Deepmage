class_name WeaponsContainer
extends HBoxContainer


@export var weapon_name_container: VBoxContainer
@export var weapon_damage_container: VBoxContainer
@export var weapon_size_container: VBoxContainer
@export var weapon_ap_container: VBoxContainer
@export var weapon_hp_container: VBoxContainer

## Holds references to any dynamically created rows,
## so we can remove/clear them if we call populate again.
var containers: Array[VBoxContainer] = []
#
### Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	## If you need any setup, do it here.
#
	#containers = [weapon_name_container, weapon_damage_container, weapon_size_container, weapon_ap_container, weapon_hp_container]
	#
	#pass
#
###
## Removes (queue_free) all dynamically created rows from the last populate.
###
#func clear_weapons_display() -> void:
	#for container in containers:
		#for child in container.get_children():
			#child.queue_free()
#
#
###
## Populates up to 7 weapons. Each weapon row:
##  [ Button: Name ] [Label: Damage] [Label: Size] [Label: AP] [Label: HP]
## Pressing the name button calls into the Character Sheet UI's "show_weapon_details_popup" method.
###
#func populate_weapons(weapons: Array[Weapon], sheet_ui: UnitCharacterSheetUI) -> void:
	## First, clear old display.
	#clear_weapons_display()
#
	#if weapons.size() == 0:
		#return  # No weapons to display, do nothing.
#
	## We only show up to 7.
	#var max_weapons :int = mini(weapons.size(), 7)
#
	#for i in range(max_weapons):
		#var weapon: Weapon = weapons[i]
		#
		#
		#
		## 1) Create a button for the weapon name
		#var name_button = Button.new()
		#name_button.name = "WeaponNameBtn"
		#name_button.text = weapon.name
		#name_button.add_theme_font_size_override("font_size", 15)
		## We connect "pressed" to a helper in this script that calls sheet_ui
		#name_button.pressed.connect(_on_weapon_name_pressed.bind(weapon, sheet_ui))
		#
#
#
		#
		## 2) A label for the damage
		#var damage_label = Label.new()
		#damage_label.name = "DamageLabel"
		#damage_label.text = "{0}d{1} + {2}".format([
			#weapon.die_number,
			#weapon.die_type,
			#weapon.flat_damage
		#])
		#damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#
#
		#
		## 3) A label for size
		#var size_label = Label.new()
		#size_label.name = "SizeLabel"
		#size_label.text = str(weapon.size)  # or a function that maps int -> "Small/Medium/etc."
		#size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#
		## 4) A label for AP
		#var ap_label = Label.new()
		#ap_label.name = "APLabel"
		#ap_label.text = str(weapon.armor_points)
		#ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#
		## 5) A label for HP
		#var hp_label = Label.new()
		#hp_label.name = "HPLabel"
		#hp_label.text = str(weapon.hit_points) + "/" + str(weapon.max_hit_points)
		#hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#
		## Add these controls to the row container
		#weapon_name_container.add_child(name_button)
		#weapon_damage_container.add_child(damage_label)
		#weapon_size_container.add_child(size_label)
		#weapon_ap_container.add_child(ap_label)
		#weapon_hp_container.add_child(hp_label)
#
#
#
#
#
###
## Called when a weapon's name button is pressed.
## We pass the Weapon and the UI reference as extra arguments in the connect call.
###
#func _on_weapon_name_pressed(weapon: Weapon, sheet_ui: UnitCharacterSheetUI) -> void:
	## The UnitCharacterSheetUI has a method like "show_weapon_details_popup(weapon)"
	#if sheet_ui:
		#sheet_ui.show_weapon_details_popup(weapon)
