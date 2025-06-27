class_name DebugConsoleController
extends Node




func _ready() -> void:
	Console.add_command("hello", console_hello, 0, 0, "Prints Hello")
	Console.add_command("print_text", print_text_on_first_unit, 1, 1, "Prints Inputted Text on first Unit in manager")





func console_hello() -> void:
	Console.print_line("Hello!", true)

func print_text_on_first_unit(text: String) -> void:
	
	var first_u: Unit = UnitManager.instance.get_first_unit()
	if !first_u:
		return
	
	Utilities.spawn_text_line(first_u, text)
