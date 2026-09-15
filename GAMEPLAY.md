# Mutation Farm (bản Godot) — Tài liệu Gameplay

Đây là bản dựng game mobile bằng **Godot 4** (GDScript), xây dựng lại từ
prototype giao diện HTML gốc (`mutation-farm/index.html`). Tài liệu này mô tả
những gì đang chạy được, cách chơi, và những phần còn thiếu.

## Cách xem thử ngay

- **Cách nhanh nhất (không cần cài gì):** mở các ảnh trong
  `screenshots/result/frame*.png` — đây là các khung hình chụp trực tiếp từ
  game đang chạy thật (không phải mock-up).
- **Chạy thật trên máy:** mở Godot Engine (`Godot_v4.7.2-stable_win64.exe`
  bạn đã tải), chọn **Import**, trỏ vào thư mục
  `C:\Users\Admin\New folder\mutation-farm-godot\project.godot`, rồi bấm nút
  ▶ (Run) ở góc trên phải. Cửa sổ game (khung dọc, tỉ lệ điện thoại) sẽ mở ra
  và bạn thao tác bằng chuột y như chạm tay trên điện thoại.

## Vòng lặp chơi chính (đã hoạt động)

1. **Mua con vật** — bấm nút 🐭 / 🐷 / 🐤 ở thanh dưới, tốn 500 coin, sinh ra
   một con Tier 1 ngẫu nhiên vị trí trên nông trại.
2. **Kéo để ghép (merge)** — kéo một con thả lên một con **cùng loài, cùng
   bậc** → cả hai biến mất, sinh ra một con bậc cao hơn (Tier+1).
3. **Kéo để lai tạo (crossbreed)** — kéo một con thả lên một con **khác
   loài nhưng cùng bậc** → có tỉ lệ thành công (xem bảng bên dưới), thất bại
   thì mất cả hai con, thành công thì ra một con bậc cao hơn thuộc 1 trong 2
   loài (50/50).
4. **Đột biến hiếm (Rare Mutation)** — mỗi lần một con được tạo ra (mua mới
   hoặc từ ghép/lai) có 1% cơ hội là bản **hiếm**, đổi tên và có màu sắc lấp
   lánh riêng theo bậc.
5. **Thu nhập thụ động** — mỗi giây, nông trại tự cộng coin dựa trên tổng
   (bậc × 2 + 1 nếu hiếm) của mọi con vật đang nuôi, và cộng thêm XP để lên
   cấp nông trại.
6. **Sổ Sưu Tầm** — bấm icon rương ở góc trên phải để xem đã khám phá được
   bao nhiêu trong tổng số 36 dạng (3 loài × 6 bậc × thường/hiếm).
7. **Lưu game tự động** — game tự lưu mỗi 8 giây và khi thoát, không mất
   tiến trình.

## Loài & bậc tiến hóa (giống hệt prototype gốc)

| Bậc | Tên (thường) | Tên bản hiếm |
|---|---|---|
| 1 | Chuột / Heo Con / Gà Con | Shiny ___ |
| 2 | Fat ___ | Golden ___ |
| 3 | Big ___ | Crystal ___ |
| 4 | Three-Eyed ___ | Neon ___ |
| 5 | Alien ___ | Cosmic ___ |
| 6 | Nuclear ___ | Radioactive ___ (bậc tối đa) |

3 loài khởi điểm: **Mouse (🐭)**, **Piglet (🐷)**, **Chick (🐤)** — cùng một
"khuôn" tiến hóa (6 bậc), chỉ khác tông màu.

## Tỉ lệ lai tạo khác loài theo bậc

| Bậc đang lai | Tỉ lệ thành công |
|---|---|
| 1 | 70% |
| 2 | 55% |
| 3 | 40% |
| 4 | 25% |
| 5 | 12% |

Ghép cùng loài (merge) luôn **100% thành công** — không có rủi ro.

## Đã xây xong

- Nông trại + kéo-thả ghép/lai tạo, đúng công thức gốc.
- 3 currency: Coin, Gem, DNA (Gem/DNA hiện chưa có nơi tiêu — xem phần dưới).
- Thu nhập thụ động + lên cấp nông trại (XP).
- Sổ sưu tầm 36 ô, mở khóa dần.
- Lưu/tải game.
- Giao diện điện thoại dọc (720×1280), theo đúng tông màu kem/pastel của
  bản HTML gốc.

## Chưa làm (so với prototype HTML đầy đủ)

Prototype gốc còn có **PK/Đấu Trường** (`battleView.js`), **Adventure/bản đồ
theo chương với boss** (`adventureView.js`), và **cửa hàng đầy đủ**
(mua Food, Gem Pouch, Mystery Egg — `shopView.js`). Bản Godot này mới tập
trung làm chắc **vòng lặp Nông Trại** trước — đây là phần lõi/vui nhất của
game, nên tôi ưu tiên làm nó chỉn chu trước khi mở rộng sang các màn hình
khác. Nói cho tôi biết bạn muốn tôi làm tiếp phần nào.

Ngoài ra: **xuất file cài đặt cho điện thoại (APK Android)** chưa làm — cần
tải thêm Godot Export Templates (~1GB) và cấu hình Android SDK/JDK, tôi sẽ
xin phép bạn trước khi tải vì khá nặng.

## Cấu trúc code (cho tham khảo)

- `scripts/Game.gd` — toàn bộ dữ liệu & luật chơi (loài, bậc, tỉ lệ, merge,
  lai tạo, lưu/tải) — không dính UI, dễ test/mở rộng.
- `scripts/Main.gd` — dựng giao diện bằng code, vòng lặp game, xử lý kéo-thả.
- `scripts/Critter.gd` — hiển thị một con vật (đổi khung hình, màu, kích cỡ).
- `assets/` — sprite và icon lấy trực tiếp từ prototype gốc.
