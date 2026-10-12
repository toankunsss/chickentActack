extends SceneTree
## One-shot builder: creates self-contained themed FarmMap scenes so their
## real textures and TileSet are visible directly in the Godot 2D editor.

const BASE_MAP := preload("res://scenes/farm/FarmMap.tscn")
const THEMES := {
	"mars": {"scene": "res://scenes/farm/FarmMapMars.tscn", "ground": Color("e58a50"), "border": Color("713923")},
	"volcano": {"scene": "res://scenes/farm/FarmMapVolcano.tscn", "ground": Color("353138"), "border": Color("160f14")},
	"saturn": {"scene": "res://scenes/farm/FarmMapSaturn.tscn", "ground": Color("8358b7"), "border": Color("35204f")},
	"ice": {"scene": "res://scenes/farm/FarmMapIce.tscn", "ground": Color("d8f3fb"), "border": Color("315f82")},
}

func _initialize() -> void:
	for theme_id in THEMES:
		_bake_theme(theme_id, THEMES[theme_id])
	quit()

func _bake_theme(theme_id: String, config: Dictionary) -> void:
	var map := BASE_MAP.instantiate() as Node2D
	map.name = "FarmMap"
	var farm_ground := map.get_node("FarmGround") as Panel
	var style := farm_ground.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = config.ground
	style.border_color = config.border
	farm_ground.add_theme_stylebox_override("panel", style)
	_apply_ground_tilemap(map, theme_id)
	_apply_theme_assets(map, theme_id)
	var packed := PackedScene.new()
	var pack_error := packed.pack(map)
	if pack_error != OK:
		push_error("Cannot pack %s: %s" % [theme_id, error_string(pack_error)])
	else:
		var save_error := ResourceSaver.save(packed, config.scene)
		if save_error != OK:
			push_error("Cannot save %s: %s" % [theme_id, error_string(save_error)])
		else:
			print("BAKED_FARM_MAP ", theme_id, " -> ", config.scene)
	map.free()

func _apply_ground_tilemap(map: Node2D, theme_id: String) -> void:
	var tile_layer := map.get_node("Background/GroundTileLayer") as TileMapLayer
	var occupied_cells := tile_layer.get_used_cells()
	var themed_tileset := TileSet.new()
	themed_tileset.tile_size = Vector2i(128, 128)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/map/themes/%s/ground.png" % theme_id) as Texture2D
	atlas.texture_region_size = Vector2i(128, 128)
	atlas.create_tile(Vector2i.ZERO)
	var source_id := themed_tileset.add_source(atlas)
	tile_layer.clear()
	tile_layer.tile_set = themed_tileset
	for coords in occupied_cells:
		tile_layer.set_cell(coords, source_id, Vector2i.ZERO)

func _apply_theme_assets(node: Node, theme_id: String) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			var filename := _asset_for_node(child.name)
			if not filename.is_empty():
				child.texture = load("res://assets/map/themes/%s/%s" % [theme_id, filename]) as Texture2D
		_apply_theme_assets(child, theme_id)

func _asset_for_node(node_name: String) -> String:
	if node_name.begins_with("BushRound"):
		return "bush.png"
	if node_name.begins_with("FenceHorizontal"):
		return "fence_horizontal.png"
	if node_name.begins_with("FenceVertical"):
		return "fence_vertical.png"
	if node_name.begins_with("TreeRound"):
		return "tree.png"
	if node_name.begins_with("GrassTuft"):
		return "tuft.png"
	return ""
