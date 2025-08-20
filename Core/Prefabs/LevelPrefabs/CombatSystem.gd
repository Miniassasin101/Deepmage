class_name CombatSystem
extends Node



static var instance: CombatSystem = null


func _ready() -> void:
	if instance != null:
		push_error("There's more than one CombatSystem! - " + str(instance))
		queue_free()
		return
	instance = self




func declare_attack(action: Action, attacker: Unit, defender: Unit) -> void:
	
	# On attack declared events trigger here 
	
	Utilities.spawn_text_line(attacker, "Attacking " + defender.ui_name + " with " + action.action_name)
	await prompt_player_reaction(defender)
	# Check if target wants to do a reaction
	
	
	
	
	
	pass


func prompt_player_reaction(defender: Unit) -> void:
	UnitActionSystem.instance.prompt_reaction(defender)
	
	var selected_reaction: Action = await UnitActionSystem.instance.reaction_confirmed
	
	if selected_reaction:
		Utilities.spawn_text_line(defender, "Reacting with: " + selected_reaction.action_name)
