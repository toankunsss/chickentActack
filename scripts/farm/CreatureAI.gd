class_name CreatureAI
extends RefCounted

func step(delta: float) -> void:
	for creature in Game.animals_for_map():
		if creature.get("dragging", false):
			continue
		if creature.walking:
			var direction := Vector2(creature.target_x - creature.x, creature.target_y - creature.y)
			creature.facing = 1 if direction.x >= 0.0 else -1
			var movement := 16.0 * delta
			if direction.length() <= movement:
				creature.x = creature.target_x
				creature.y = creature.target_y
				creature.walking = false
				creature.idle_until = Time.get_ticks_msec() + randi_range(1200, 3600)
			else:
				creature.x += direction.normalized().x * movement
				creature.y += direction.normalized().y * movement
		elif Time.get_ticks_msec() >= creature.idle_until:
			creature.target_x = randf_range(6.0, 86.0)
			creature.target_y = randf_range(12.0, 84.0)
			creature.walking = true
