class_name CollectionManager
extends Node

func is_discovered(type_id: String) -> bool:
	return Game.discovered.has(type_id)

func discovered_count() -> int:
	return Game.discovered.size()
