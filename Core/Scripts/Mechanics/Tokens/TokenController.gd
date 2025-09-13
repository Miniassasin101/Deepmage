class_name TokenController
extends Node

@export var unit: Unit

@export var tokens: Array[Token] = []

var effect_tokens: Array[Token] = []


func _ready() -> void:
	make_tokens_unique()


func make_tokens_unique() -> void:
	if tokens.is_empty():
		return
	var temp_tokens: Array[Token] = []
	for token in tokens:
		temp_tokens.append(token.duplicate())
	tokens = temp_tokens
