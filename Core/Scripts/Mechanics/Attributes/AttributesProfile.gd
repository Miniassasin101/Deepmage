@tool

class_name AttributesProfile
extends Resource

## A reusable preset of starting attributes that you assign per Unit.
## Edit this once, reuse across many Units, but Units get UNIQUE copies.

@export_tool_button("Make Unique") 
var button = make_unique_attribute_array

@export var attributes: Array[Attribute] = []




func make_unique_attribute_array() -> Array[Attribute]:
	var result: Array[Attribute] = []
	for source_attribute in attributes:
		var unique_copy: Attribute = source_attribute.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		unique_copy.resource_local_to_scene = true
		result.append(unique_copy)
	
	if !result.is_empty():
		attributes = result
		print_debug("Made Attributes Unique")
	
	return result
