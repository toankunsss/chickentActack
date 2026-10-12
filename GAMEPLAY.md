# Mutation Farm — Luật đang chạy trong Godot

Cập nhật 03/10/2026. Đây là mô tả implementation hiện tại, không phải xác nhận
mọi công thức đã được cân bằng. Kế hoạch và hạng mục cần chốt nằm ở `BUSINESS.md`.

## Cách chạy

Mở `D:\workspaceGAme\GameGodot\project.godot` trong Godot 4.7.2, chạy scene
`scenes/Game.tscn`. Giao diện dọc dùng hệ tọa độ cơ sở 720×1280.

## Farm và sinh vật

- 100 nhân vật thường = 10 dòng gà × Tier 1–10, thêm biến thể shiny.
- Earth, Mars, Volcano, Ice, Saturn: mỗi map có hai dòng đủ Tier 1–10.
- Chỉ sinh vật và trứng thuộc map hiện tại được hiển thị/chọn/mở.
- Merge: hai con khác ID, cùng dòng và cùng tier, dưới Tier 10 → Tier +1.
- Fusion: hai dòng khác nhau cùng tier, dưới Tier 10. Tỉ lệ theo FarmConfig:
  `max(20%, 70% - (tier - 1) × 8%)`.
- Fusion thất bại thường mất một con; critical failure (10% trong nhánh thất bại)
  mất cả hai. Không thể dùng cùng một con để merge với chính nó.
- Fusion chỉ tạo dòng thuộc map hiện tại. Recipe cũ dẫn sang map khác dùng
  50/50 dòng bố/mẹ và tăng một tier khi thành công; giữ nguyên gà trong save cũ.
- Kết quả Fusion được lưu trước animation; thành công hiển thị gà mới, thất bại
  hiển thị con sống sót hoặc báo mất cả hai. Continue không thực hiện thêm lượt.
- Tier cao có sprite lớn hơn; collection có filter, ảnh nhân vật thật và detail.

## Trứng và UFO giao hàng

- Mỗi map có tối đa 5 trứng chưa mở và sức chứa sinh vật tối đa 40.
- UFO level, delivery timer và egg upgrade level được lưu riêng theo map.
- Khoảng giao từ 60 giây đến 12 giây qua 11 cấp dữ liệu; giá nâng UFO là
  `round(500 × 1.65^level)` (level nội bộ bắt đầu từ 0).
- UFO chỉ thả Egg Lv.1–5; map mới chỉ thả Egg Lv.1. Nâng chất lượng làm đổi
  phân bố các loại trứng, không nâng trực tiếp một quả trứng cụ thể.
- Egg quality Lv.0–10; ở MAX, tỷ lệ Egg Lv.1–5 là 27/25/25/18/5%.
- Egg Shop bán Lv.1–10. Trứng nở theo bảng `EggDropRateConfig.gd`, không mặc
  định ra sinh vật cùng cấp. Egg Lv.1 luôn ra Tier 1; Egg Lv.10 có 10% ra Tier 10.
- Popup DROP RATE hiển thị đủ Tier 1–10, kể cả mức 0%; chỉ tạo gà thuộc map
  đang chơi. Mở/đóng popup không mua trứng và chặn thao tác vào màn hình phía sau.
- Nâng chất lượng có thể thất bại từ bước Lv.3 → Lv.4; xác nhận hiển thị trước
  khi trừ Gold. Thất bại không tăng cấp và không hoàn Gold.
- Bảng giá/tỷ lệ nguồn: `scripts/config/EggUpgradeConfig.gd`,
  `EggDropRateConfig.gd`, `EggShopConfig.gd`; không sao chép số cũ từ BA prototype.

## Thu nhập, tài nguyên và shop

- Mỗi 2,2 giây cộng thu nhập từ các gà đang sở hữu: `tier × 2`, nhân 1,5 nếu shiny.
- Wallet và collection dùng chung giữa các hành tinh; chỉ phần tiến trình
  Egg/UFO và roster/egg hiển thị tách theo map.
- Khi farm damaged, income còn 40% trong thời hạn hiện tại 600 giây.
- Food: -100 Coins, +15 XP, +60 Coins. Gem Pouch: -800 Coins, +15 Gems.
- Mystery Egg: -50 Gems; Tier 1 70% / Tier 2 30%, shiny 3%, dòng thuộc map hiện tại.
- Shop từ chối thiếu tiền hoặc farm đầy; BA cân bằng Economy vẫn chưa nghiệm thu.
- Shop có ba tab Eggs / Chickens / Items. Tab Chickens hiển thị đúng hai dòng
  Tier 1 của map hiện tại; mua đúng gà đang xem. Farm đầy khóa mua gà/trứng,
  không khóa Food/Gem Pouch. Giá, phần thưởng và tỉ lệ nở giữ nguyên.
- Kết quả mua hiển thị ngay trong Shop; đổi tab không trừ Gold. Nút DROP RATE
  vẫn mở được khi không đủ Gold hoặc farm đã đầy.

## UFO địch và Battle

- Raid hiện có 1.000 HP, chạm bắn gây 10 damage, thời hạn bắt cóc 15 giây.
- Thắng nhận loot theo `LootManager.gd`; thất bại có thể bắt cóc gà.
- Raid chặn chuyển màn/map và hiển thị pháo che bottom navigation.
- Battle offline: chọn tối đa 15 gà, AI có đội riêng xem trước, Easy/Normal/Hard.
- Trận 30 giây với 2 giây đếm ngược; grid 3 cột, 7–11 hàng tùy số lượng quân.
- Mỗi mẫu nhân vật trong 100 con có skill gắn ID cố định: 11 kiểu tấn công và
  10 hiệu ứng phụ, tự dùng theo tầm đánh/hồi chiêu; xem mô tả khi chọn đội.
- HP, shield và trạng thái trong trận là bản sao, không làm mất gà ở Farm.
- Tốc độ x1/x2/x4, chặn tab trong trận; LEAVE cần xác nhận bằng lần chạm thứ hai.
- Thắng nhận Gold theo số ô chiếm và 20 XP; thua/hòa/bỏ trận không thưởng.
  Kết quả chỉ trả thưởng một lần, có REMATCH và thống kê damage/skill/KOs.
- Chapter/boss theo chapter bị loại khỏi phạm vi theo yêu cầu mới. UFO raid Farm giữ nguyên.
- Bluetooth giữa hai điện thoại là giai đoạn sau: hiện chưa có discovery, pairing,
  transport hoặc đồng bộ hai máy. Chi tiết offline và ranh giới ở `BATTLE.md`.

## Lưu tiến trình và kiểm thử

- Save schema 3; planet progression schema 2; hỗ trợ migration từ Godot save v2.
- Autosave 5 giây, pause/close; ghi file tạm, backup `.bak`, phục hồi snapshot hợp lệ.
- Nếu không đọc được bất kỳ save nào, giữ nguyên file và khóa ghi tự động.
- Đã kiểm tra tự động save round-trip cho 5 map, migration, save bị cắt/sai schema,
  và chọn/mở trứng đúng map. Chi tiết chứng cứ: `qa/save-map-regression.json`.
- Android touch, app kill/resume và performance trên thiết bị thật còn phải kiểm tra.
- Lệnh chạy test: `tools/run_regression.ps1 -Godot <path-to-console.exe> -Visual`.
