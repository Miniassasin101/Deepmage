class_name Reaction
extends Action

var accuracy_attribute1: String = "agility"
var accuracy_attribute2: String = "martial"


func resolve_reaction() -> void:
	pass


func get_reaction_package() -> AnimationPackage:
	#push_error("Get reaction package called on base Action class")
	return null


func get_accuracy_attributes() -> Array[String]:
	var accuracy_attributes: Array[String] = [accuracy_attribute1, accuracy_attribute2]
	return accuracy_attributes
