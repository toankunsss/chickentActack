# Battle Tileset V1

Sprite sheet đơn giản dành cho map chiến đấu mobile.

## Files

- `battle_ground_4x4_256.png`: atlas nền 4 x 4, mỗi ô 256 x 256 px.
- `battle_props_4x4_256.png`: atlas đạo cụ 4 x 4, mỗi ô 256 x 256 px, nền trong suốt.
- `ground/`: 16 tile nền đã được cắt riêng.
- `props/`: 16 đạo cụ đã được cắt riêng.
- `placement_cells/`: atlas và 16 trạng thái ô đặt sinh vật, mỗi ô 256 x 256 px.

## Godot import

- Filter: On (phong cách vẽ mượt, không phải pixel art).
- Mipmaps: Off cho camera cố định; On nếu map có zoom xa.
- Repeat: Enabled cho các tile nền cần lặp.
- Tile size: 256 x 256 px.
- Không đặt ground và props chung một `TileMapLayer`: dùng `GroundTileLayer` và `DecorationTileLayer` riêng để dễ chỉnh `z_index`.
- Ô đặt sinh vật nên nằm trên ground nhưng dưới creature: ví dụ `GroundTileLayer.z_index = 0`, `PlacementCellLayer.z_index = 5`, `CreatureLayer.z_index = 10`.

## Placement cell states

- `friendly_01` tới `friendly_04`: ô thuộc phe người chơi.
- `enemy_01` tới `enemy_04`: ô thuộc phe địch.
- `neutral_01` tới `neutral_03`: ô trung lập.
- `boundary_striped`: hàng giáp ranh.
- `selected_cyan`: ô đang được chọn.
- `placement_valid`: có thể đặt sinh vật.
- `placement_invalid`: không thể đặt sinh vật.
- `disabled`: ô bị khóa.

## Sheet order

Ground (trái sang phải, trên xuống dưới):

1. grass_bright_01, grass_bright_02, grass_bright_03, grass_bright_04
2. grass_dark_01, grass_dark_02, enemy_dry_01, enemy_dry_02
3. dirt_light_01, dirt_light_02, boundary_01, boundary_02
4. water_01, water_02, stone_path, worn_grass_path

Props (trái sang phải, trên xuống dưới):

1. bush_round, tree_leafy, rocks_small, grass_tuft
2. fence_horizontal, fence_vertical, crate, mushrooms
3. river_straight, bridge_wood, cave_entrance, animal_hut
4. campfire, flowers_blue, grass_dry, enemy_gate
