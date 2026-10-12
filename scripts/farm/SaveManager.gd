class_name SaveManager
extends Node

func save() -> void:
	Game.save_game()

func load() -> bool:
	return Game.load_game()
