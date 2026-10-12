extends SceneTree

func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(128, 128)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/map/optimized/grass_tile_128x128.png")
	atlas.texture_region_size = Vector2i(128, 128)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	var error := ResourceSaver.save(tile_set, "res://assets/map/optimized/farm_ground_tileset.tres")
	if error != OK:
		push_error("Không thể lưu farm_ground_tileset.tres: %s" % error_string(error))
	quit(error)
