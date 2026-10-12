class_name MergeManager
extends Node

func merge(id_a: String, id_b: String) -> Dictionary:
	return Game.merge_animals(id_a, id_b)
