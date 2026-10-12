# MUTATION FARM — BUSINESS & PRODUCTION PLAN

> Cập nhật lần cuối: 05/10/2026
> Trạng thái hiện tại: **Playable Alpha**  
> Tiến độ sản phẩm ước tính: **70%**  
> Mức sẵn sàng phát hành thương mại: **45%**

> Các tỷ lệ trên và bảng trọng số là **ước tính kế hoạch ngày 26/09**, chưa phải kết quả nghiệm thu. Không tăng phần trăm chỉ vì thêm code. Kết quả kiểm chứng mới nhất nằm ở mục 9.

**Ký hiệu:** `[x]` đã xong trong phạm vi ghi rõ; `[-]` đang làm/mới kiểm chứng một phần; `[ ]` chưa hoàn tất; `[?]` cần chốt nghiệp vụ; `[!]` thiếu điều kiện kiểm chứng. Các mục 3 mô tả tính năng đã có; không thay thế checklist Beta/Android.

**Nguồn quyết định:** yêu cầu người dùng đã chốt gần nhất → tài liệu này và code Godot → backlog `../MUTATION_FARM_TASKS.md` → BA prototype `../mutation-farm/docs/GAMEPLAY_BUSINESS_DOCUMENT.md`. Các thông số 3 loài/6 tier trong BA prototype đã được thay bằng 10 dòng gà/10 tier/5 hành tinh.

**Battle đã chốt ngày 03/10:** tập trung 100 skill nhân vật và đối kháng đội hình; làm offline với AI trước, Bluetooth giữa hai điện thoại sau. Loại chapter/boss theo chapter khỏi phạm vi hiện tại. Không loại UFO raid tại Farm. Các phần trăm ước tính cũ bên dưới chưa được chấm lại.

## 1. Tầm nhìn sản phẩm

Mutation Farm là game mobile casual dạng **collect — hatch — merge — fuse — battle**. Người chơi thu thập 100 nhân vật gà thuộc 10 dòng tiến hóa, nâng cấp trứng và UFO, phát triển các nông trại trên nhiều hành tinh, sau đó dùng đội hình để chiến đấu.

### Điểm khác biệt chính

- 100 nhân vật có cùng ngôn ngữ hình ảnh nhưng khác dòng tiến hóa.
- 5 hành tinh có hệ sinh vật và tiến trình trứng/UFO độc lập.
- Merge cùng loài đảm bảo thành công; Fusion khác loài có rủi ro.
- Vòng lặp idle/casual ngắn, phù hợp chơi trên điện thoại.
- Phong cách hình ảnh cartoon đơn giản, dễ mở rộng nội dung.

## 2. Bảng tiến độ tổng quan

| Hạng mục | Trọng số | Hoàn thành | Trạng thái |
|---|---:|---:|---|
| Vòng lặp Farm cốt lõi | 20% | 95% | Gần hoàn thiện |
| Nhân vật và Collection | 15% | 85% | Đã dùng được |
| Egg, UFO và Economy | 15% | 85% | Đã dùng được |
| Hệ thống 5 Map | 15% | 80% | Cần polish và cân bằng |
| Merge/Fusion và hiệu ứng | 10% | 75% | Cần hoàn thiện visual/animation |
| Battle/PvE | 10% | 55% | Prototype có thể chơi |
| UI/UX và localization | 5% | 70% | Đang đồng bộ |
| QA, tối ưu và phát hành | 10% | 25% | Chưa đủ điều kiện release |
| **Tổng tiến độ có trọng số** | **100%** | **~70%** | **Playable Alpha** |

## 3. Những phần đã hoàn thành

### 3.1. Gameplay Farm

- [x] Farm mobile dọc 720×1280.
- [x] Sinh vật di chuyển tự động trong khu vực Farm.
- [x] Kéo thả sinh vật.
- [x] Merge hai sinh vật cùng dòng, cùng Tier.
- [x] Fusion hai sinh vật khác dòng, cùng Tier.
- [x] Tỉ lệ Fusion giảm theo Tier.
- [x] Critical Failure và xử lý mất sinh vật.
- [x] Thu nhập Coin thụ động.
- [x] XP và cấp độ Farm.
- [x] Save/load tự động.
- [x] Migration save cũ.

### 3.2. Nhân vật và tiến hóa

- [x] 10 dòng nhân vật.
- [x] 10 Tier cho mỗi dòng.
- [x] Tổng cấu trúc Collection: 100 nhân vật thường.
- [x] Biến thể Rare/Shiny.
- [x] Nhân vật Tier cao có kích thước lớn hơn.
- [x] Sprite idle/bounce.
- [x] Frame attack.
- [x] Frame hit.
- [x] Tên nhân vật và nội dung runtime bằng tiếng Anh.
- [x] Collection Screen.
- [x] Bộ lọc Species và Tier.
- [x] Popup chi tiết sinh vật.
- [x] Hiệu ứng khám phá sinh vật lần đầu.

### 3.3. Trứng, UFO và Shop

- [x] UFO thân thiện bay vào và thả trứng.
- [x] Quả trứng thật rơi xuống từ UFO.
- [x] Hệ thống sức chứa trứng.
- [x] Mở trứng để nhận sinh vật.
- [x] Shop có Egg Lv.1–Lv.10; UFO chỉ thả Egg Lv.1–Lv.5 theo bảng nâng cấp chất lượng Lv.0–Lv.10.
- [x] Tỉ lệ trứng cấp cao rất thấp.
- [x] Bảng Drop Rate.
- [x] Egg Shop.
- [x] Nâng cấp chất lượng trứng.
- [x] Tỉ lệ nâng cấp thành công/thất bại.
- [x] Modal cảnh báo trước khi nâng cấp có rủi ro.
- [x] Modal kết quả nâng cấp.
- [x] Nâng cấp tốc độ UFO.
- [x] Tiến trình Egg/UFO độc lập theo từng hành tinh.
- [x] Overlay modal chặn thao tác xuyên xuống giao diện.

### 3.4. Map và hành tinh

- [x] Earth/Farm.
- [x] Mars.
- [x] Volcano.
- [x] Ice.
- [x] Saturn.
- [x] Nút chuyển Map.
- [x] Mỗi Map có scene riêng.
- [x] Mỗi Map có mặt đất, border và props theo theme.
- [x] Tile/overlay được phủ trên Map chính.
- [x] Mỗi Map sở hữu hai dòng sinh vật riêng, Tier 1–10.
- [x] Khi chuyển Map chỉ hiển thị sinh vật thuộc Map đó.
- [x] Egg Level, UFO Level và delivery timer được reset/ghi riêng cho từng Map.

### 3.5. UFO địch và Battle

- [x] Enemy UFO raid.
- [x] HP và bộ đếm thời gian bắt cóc.
- [x] Thanh HP boss căn theo sprite, hiển thị HP hiện tại/tối đa; giảm ngay khi bắn, đổi vàng/đỏ khi yếu. Bệ pháo không còn dòng chữ hướng dẫn, vẫn che/khóa bottom tab.
- [x] Người chơi chạm để tấn công UFO.
- [x] Loot sau khi hạ UFO.
- [x] Cơ chế bắt cóc sinh vật.
- [x] Giảm thu nhập tạm thời khi Farm bị tấn công.
- [x] Chọn đội hình Battle.
- [x] Tính Team Power.
- [x] Battle offline với đội hình AI xem trước, Easy/Normal/Hard, countdown và tái đấu (desktop; Android còn chờ nghiệm thu).
- [x] Danh mục 100 skill theo ID nhân vật; tự dùng theo tầm/hồi chiêu, 11 dạng tấn công và 10 hiệu ứng phụ.
- [x] Unit melee/ranged và HP.
- [x] Kết quả thắng/thua và phần thưởng cơ bản.

### 3.6. UI và asset

- [x] Typography Baloo 2 SemiBold/Bold/ExtraBold.
- [x] Phong cách UI cartoon mobile game.
- [x] Egg Upgrade panel.
- [x] Fusion modal riêng thay cho dialog mặc định.
- [x] Asset khung Fusion nền trong suốt.
- [x] Nút bấm có trạng thái chính/phụ/disabled.
- [x] Toast notification.
- [x] Nội dung runtime trong `scripts/` bằng tiếng Anh.

### 3.7. Build và kiểm thử hiện có

- [x] Project chạy bằng Godot 4.7.2.
- [x] Headless startup không có lỗi parser/runtime đã biết.
- [x] Farm smoke test đã được tạo.
- [x] Test xác nhận tổng 10 dòng × 10 Tier.
- [x] Test xác nhận Drop Rate và Egg Upgrade probability.
- [x] Test độc lập tiến trình giữa các hành tinh.
- [x] Đã có APK thử nghiệm.

## 4. Phần đang làm hoặc cần hoàn thiện

### Ưu tiên P0 — Bắt buộc trước bản Beta

- [-] Chạy full regression test sau mỗi thay đổi UI/gameplay. Đã có lệnh chung và test riêng Battle skill/offline; Android/Bluetooth và các tính năng chưa làm không nằm trong phạm vi PASS desktop.
- [ ] Kiểm tra save/load trên thiết bị Android thật.
- [ ] Kiểm tra toàn bộ modal ở nhiều tỉ lệ màn hình.
- [ ] Kiểm tra touch target cho X, Cancel, Upgrade và Map Switch.
  - [x] Egg Upgrade: X đầy đủ ảnh, cùng typography với Fusion; click/chạm mô phỏng đóng không chuyển map bên dưới (desktop, 360×640, 390×844 và 720×1280).
  - [x] Desktop: Cancel/Confirm/Success Egg Upgrade; Cancel/X/Confirm/Continue Fusion; Close Collection; Shop drop-rate; chặn tab/map trong First Discovery ở ba kích thước mục tiêu.
  - [ ] Touch và gesture trên thiết bị Android thật, đặc biệt đội hình/skill Battle.
- [x] Fusion modal trên desktop: glow, tên sinh vật, animation ghép và kết quả thành công/thất bại/critical; xác nhận chỉ xử lý một lần, lưu kết quả trước animation.
- [ ] Cân bằng Economy: giá Egg, tốc độ UFO, thu nhập và chi phí nâng cấp.
- [ ] Cân bằng toàn bộ bảng Drop Rate Lv.1–Lv.10.
- [ ] Cân bằng Fusion failure để không gây cảm giác mất tiến trình quá nặng.
- [-] Sửa warning/error runtime: suite desktop hiện tại đã sạch; còn cần xác nhận log trên Android thật và các luồng chưa có test.
- [ ] Tối ưu dung lượng APK và texture import.

### Ưu tiên P1 — Nội dung cho bản Beta

- [x] Animation Fusion thành công/thất bại/critical trên desktop; Android và âm thanh chưa nghiệm thu.
- [ ] Hoàn thiện animation “Who is it?” khi mở khóa lần đầu.
- [-] Đã tích hợp bộ SFX tổng hợp UI, hatch, merge/fusion, reward, upgrade, cannon và skill nguyên tố; basic-hit riêng và nghiệm thu nghe trên Android còn thiếu. Xem `AUDIO.md`.
- [ ] Thêm nhạc nền riêng cho từng hành tinh.
- [ ] Hoàn thiện Boss UFO có pattern tấn công.
- [x] Đối thủ AI offline, đội hình theo seed và ba độ khó; cân bằng dài hạn còn thiếu.
- [ ] Đấu Bluetooth giữa hai điện thoại: discovery/pairing, truyền dữ liệu, đồng bộ và xử lý mất kết nối.
- Ngoài phạm vi theo yêu cầu mới: Adventure chapter và boss cuối chapter.
- [ ] Daily Quest.
- [ ] Achievement.
- [ ] Tutorial cho người chơi mới.
- [-] Settings: đã có nút góc phải, âm lượng Music/SFX, mute, nghe thử, lưu trên máy; rung, ngôn ngữ và reset save chưa triển khai.

### Ưu tiên P2 — Chuẩn bị phát hành

- [ ] App icon, splash screen và loading screen cuối cùng.
- [ ] Tên thương mại và logo chính thức.
- [ ] Privacy Policy.
- [ ] Terms of Service nếu có tài khoản/IAP.
- [ ] Trang Google Play Store.
- [ ] Screenshot và trailer cửa hàng.
- [ ] Internal testing trên Google Play.
- [ ] Crash reporting và analytics.
- [ ] Kiểm tra hiệu năng trên máy Android cấu hình thấp.
- [ ] Kiểm tra mất mạng và resume app.
- [ ] Chuẩn hóa version code/version name và quy trình release.

## 5. Kế hoạch kinh doanh

### 5.1. Đối tượng người chơi

- Người chơi casual thích merge/idle/collection.
- Độ tuổi mục tiêu ban đầu: 10–35.
- Phiên chơi ngắn: 2–8 phút.
- Thị trường thử nghiệm phù hợp: Việt Nam và các quốc gia dùng tiếng Anh.

### 5.2. Mô hình kiếm tiền đề xuất

Chưa triển khai trong code. Nên ưu tiên mô hình thân thiện với game casual:

- [ ] Rewarded Ad: rút ngắn thời gian UFO.
- [ ] Rewarded Ad: nhận thêm một lần mở trứng.
- [ ] Rewarded Ad: bảo vệ một sinh vật khi Fusion thất bại.
- [ ] Gói loại bỏ quảng cáo.
- [ ] Gói Gem nhỏ/vừa/lớn.
- [ ] Starter Pack một lần.
- [ ] Cosmetic skin và hiệu ứng Map, không tăng sức mạnh trực tiếp.
- [ ] Không bán trực tiếp sinh vật Tier cao trong giai đoạn đầu.

### 5.3. Chỉ số cần theo dõi

- [ ] Tutorial Completion Rate.
- [ ] D1, D7 và D30 Retention.
- [ ] Session Length và Sessions/Day.
- [ ] Số trứng mở mỗi ngày.
- [ ] Số lần Merge/Fusion mỗi ngày.
- [ ] Tỉ lệ rời game sau Fusion thất bại.
- [ ] Thời gian mở khóa Map tiếp theo.
- [ ] Rewarded Ad opt-in rate.
- [ ] ARPDAU và conversion rate nếu triển khai IAP.

## 6. Lộ trình đề xuất

### Milestone A — Stable Alpha

Mục tiêu: khóa vòng lặp Farm và loại bỏ lỗi phá game.

- [x] 5 Map và tiến trình riêng.
- [x] 100 nhân vật theo 10 dòng tiến hóa.
- [x] Egg/UFO/Fusion cơ bản.
- [-] Full regression trên tất cả Map. Đã kiểm chứng scene đúng, roster/egg riêng, UFO level/egg level/timer, chọn sinh vật và round-trip save cho cả 5 map; chưa hoàn tất visual/touch mọi luồng.
- [x] Save migration test tự động: Godot save v2 → v3, progression v1 → v2, chạy lại migration không nhân đôi/mang nâng cấp sang Ice.
- [ ] Android device test.

**Tiến độ Milestone A: 85%**

### Milestone B — Content Beta

Mục tiêu: có đủ nội dung để người chơi thử trong nhiều ngày.

- [x] Battle offline theo đội hình/skill, chọn độ khó và tái đấu.
- [ ] Cân bằng skill và đối thủ qua chơi thử.
- [ ] Bluetooth PvP giữa hai điện thoại; không thay bằng chapter hoặc boss.
- [ ] Boss UFO hoàn chỉnh.
- [ ] Tutorial, Quest và Achievement.
- [ ] Audio/VFX pass.

**Tiến độ Milestone B: 35%**

### Milestone C — Soft Launch

Mục tiêu: phát hành giới hạn và đo retention/economy.

- [ ] Analytics.
- [ ] Crash reporting.
- [ ] Ads/IAP thử nghiệm.
- [ ] Store assets.
- [ ] Privacy/consent flow.
- [ ] Google Play internal/closed testing.

**Tiến độ Milestone C: 10%**

### Milestone D — Global Release

- [ ] Cân bằng dựa trên dữ liệu Soft Launch.
- [ ] Tối ưu onboarding và retention.
- [ ] Hoàn thiện localization.
- [ ] Marketing trailer và chiến dịch launch.
- [ ] LiveOps calendar 30–60 ngày đầu.

**Tiến độ Milestone D: 0%**

## 7. Definition of Done cho bản 1.0

Bản 1.0 chỉ được coi là hoàn thành khi:

- [ ] Không còn lỗi mất save hoặc dùng nhầm dữ liệu giữa các Map.
- [ ] Tất cả luồng Farm, Egg, Merge, Fusion, Battle chạy ổn định trên Android.
- [ ] 100 nhân vật có sprite và animation hợp lệ.
- [ ] Người chơi mới hiểu cách chơi mà không cần hướng dẫn bên ngoài.
- [ ] Có ít nhất 7 ngày nội dung/progression hợp lý.
- [ ] Economy không tạo điểm nghẽn quá sớm hoặc farm vô hạn quá nhanh.
- [ ] UI không bị tràn, lệch hoặc bấm xuyên trên các màn hình mục tiêu.
- [ ] FPS ổn định và thời gian tải chấp nhận được trên thiết bị thấp.
- [ ] Store listing, privacy và build release đã hoàn tất.
- [ ] Có quy trình theo dõi crash, analytics và cập nhật sau phát hành.

## 8. Việc nên làm tiếp theo

1. Nghiệm thu Battle offline trên Android: chọn đội/skill, vuốt picker, pause/resume, x1/x2/x4, rời trận, nhận thưởng và tái đấu. Đã có test simulation và UI desktop; chưa đủ thay thế hai thiết bị thật.
2. Bổ sung audio/VFX sau khi ổn định combat; animation Fusion và First Discovery đã được kiểm chứng desktop, chưa nghiệm thu Android.
3. Chạy APK trên ít nhất hai thiết bị Android: save/load, background/resume, kill/relaunch, touch và hiệu năng.
4. Chốt các khác biệt nghiệp vụ ở mục 9.3 trước khi chỉnh Economy/Drop Rate/Battle.
5. Sau offline, triển khai Bluetooth PvP theo yêu cầu đã xác nhận; loại chapter/boss chapter khỏi lộ trình.
6. Sau đó mới tích hợp analytics, quảng cáo và IAP.

## 9. Nhật ký thực thi và các điểm cần chú ý — 03/10/2026

### 9.1. Đã làm và có bằng chứng

| ID | Hạng mục | Trạng thái | Bằng chứng / phạm vi |
|---|---|---|---|
| A-SAVE-01 | Ghi save qua file tạm, kiểm tra hợp lệ trước khi thay file chính; giữ bản `.bak` | [x] | `scripts/farm/SaveStore.gd`; kiểm tra ghi đè, JSON bị cắt, temp chưa hoàn tất và phục hồi |
| A-SAVE-02 | Validate dữ liệu trước khi sửa state; không ghi đè save hỏng nếu không phục hồi được | [x] | Fixture sai kiểu dữ liệu; wallet không đổi; autosave bị khóa và file gốc còn nguyên |
| A-SAVE-03 | Autosave 5 giây và xử lý pause/close | [x] desktop | Test gọi vòng xử lý App và thông báo vòng đời; **chưa chứng minh trên Android thật** |
| A-MIG-01 | Migration và round-trip 5 hành tinh | [x] | Test save v2/v3, progression v1/v2; giữ ID gà, discovery, đội hình, timer và nâng cấp |
| A-MAP-01 | Chặn mở trứng/chọn sinh vật ở hành tinh khác | [x] | Kiểm tra cả 5 map qua `Game.tscn`; roster và 5 slot trứng độc lập |
| A-MAP-02 | Hủy drag khi đổi map/rời Farm, không chọn view ẩn; từ chối hợp thể khác map ở cả API cũ | [x] desktop | `tests/map_drag_regression.gd`: 168 checks, 20 hướng đổi map; tái hiện lỗi trước sửa tại `qa/map-drag-before.log`, sau sửa không lỗi tại `qa/map-drag-regression.log`; ghép cùng map vẫn tạo đúng tier tiếp theo |
| A-MERGE-01 | Chặn tự ghép một con và Fusion Tier 10 → 11 | [x] | Từ chối đầu vào và giữ nguyên sinh vật |
| A-QA-01 | Lệnh regression dùng save thử riêng | [x] desktop | Chạy lại `tools/run_regression.ps1 -Visual` ngày 03/10: cả 13 nhóm PASS (smoke, save/map, drag, Fusion rules, Battle skills, Egg Upgrade, modal, raid, Fusion layout, Fusion outcome, Shop odds, Shop redesign, Battle visual); không có SCRIPT ERROR/ERROR trong các log. Input mô phỏng qua hit-test của viewport; cặp press/release được gửi liền nhau để chuột/focus của máy test không xen vào giữa |
| A-UI-01 | Cảnh báo xác suất và kết quả nâng chất lượng UFO, không hiển thị một trứng gây hiểu nhầm | [x] desktop | `tests/modal_visual_qa.gd`: tỉ lệ success/failure theo config, 5 icon/drop rate; Cancel không trừ Gold, Confirm trừ một lần, kiểm tra cưỡng bức cả thành công và thất bại |
| A-UI-02 | Collection đúng sprite, popup căn giữa, chặn input nền | [x] desktop | Kiểm tra sprite nhân vật, trạng thái chưa khám phá và nút Close trên ba kích thước |
| A-UI-03 | Fusion tên hai con, glow; First Discovery ở canvas trên cùng | [x] desktop | Cancel/X, Confirm/Continue và reveal tự dọn; chặn tab/map. Animation kết quả được kiểm tra thêm ở A-FUSION-02; Android còn thiếu |
| A-UI-04 | Viền ô gà Fusion không tràn qua viền gỗ | [x] desktop | Hai card nằm trong vùng nền kem, kể cả glow; ảnh/tên là con của card và được clip. `tests/fusion_layout_qa.gd`: 1.365 checks, 5 map × tier 1–9 × 3 kích thước, log `qa/fusion-layout.log`, ảnh `qa/screens/modal_fusion_inset_*` |
| A-RAID-01 | Thanh HP boss và bệ pháo không chữ | [x] desktop | `tests/raid_visual_qa.gd`: 51 checks ở 360×640, 390×844, 720×1280; spawn đầy HP/idle, bấm pháo giảm đúng, HP bám giữa sprite cả lúc rung, màu vàng/đỏ, hạ boss ẩn UI và boss mới hồi đầy thanh |
| A-FUSION-01 | Fusion chỉ tạo dòng thuộc hành tinh hiện tại | [x] | Người dùng đã chốt; recipe dẫn ra map khác dùng 50/50 một trong hai dòng bố/mẹ và tăng một tier. `tests/fusion_regression.gd`: 2.716 checks, 5 map × tier 1–9, invalid pair/recipe, shiny và các nhánh thất bại. Không đổi gà đã lưu |
| A-FUSION-02 | Animation và thông báo kết quả Fusion; chống xác nhận lặp | [x] desktop | `tests/fusion_outcome_visual_qa.gd`: 186 checks, success/failure/critical × 3 kích thước; chạm thật qua hệ thống input, lưu kết quả trước animation, giữ đúng con sống sót, Continue không thực hiện thêm lượt |
| A-SHOP-01 | Popup tỉ lệ trứng theo style game, đóng được và chặn nền | [x] desktop | `scripts/ui/EggDropRatePopup.gd`; `tests/shop_visual_qa.gd`: 1.285 checks, 10 cấp trứng × 3 kích thước; đủ 10 tier, tổng 100%, đúng sampler, 5 hành tinh, thiếu Gold/farm đầy, chạm mua một lần và xác nhận save |
| A-SHOP-02 | Reskin toàn màn Shop theo style cartoon của game | [x] desktop | Scene riêng `scenes/shop/ShopScreen.tscn`; ba PNG trong `assets/ui/shop/` kèm `PROMPTS.md`. Ba tab Eggs/Chickens/Items, BUY/NEED GOLD/FARM FULL, phản hồi mua tại chỗ, đúng hai dòng gà mỗi map; giữ nguyên giá/xác suất. `tests/shop_redesign_qa.gd`: 571 checks ở ba kích thước, năm map, cuộn đến Lv.10, đóng popup, giá và chữ không tràn; vuốt qua BUY không mua nhầm. Ảnh `qa/screens/modal_shop_redesign_*`, report `qa/shop-redesign-report.json`; chưa nghiệm thu Android thật |
| A-DOC-01 | Đồng bộ README/GAMEPLAY và thứ tự ưu tiên BA | [x] | 10 dòng × 10 tier, 5 map, save schema 3 / progression schema 2 |
| A-BATTLE-01 | Battle offline và 100 skill nhân vật | [x] desktop | `BattleSkillCatalog.gd`, `BattleSimulation.gd`, `OfflineOpponent.gd`: 100 chiêu định danh theo sprite, 11 kiểu tấn công/10 hiệu ứng, AI theo seed và độ khó, snapshot JSON. `qa/battle-skill-report.json`: 149.872 assertions lặp qua từng bước mô phỏng, 0 lỗi; gồm all-tier, không trùng ô, shield/status, same-seed và 15v15. Chưa khẳng định đã cân bằng |
| A-BATTLE-02 | Giao diện offline, skill picker, kết quả và tái đấu | [x] desktop | `qa/battle-visual-report.json`: 1.513 checks, 0 lỗi ở 360×640, 390×844, 720×1280; 100 card đúng skill/không tràn, vuốt không chọn nhầm, countdown, x1/x2/x4, pause mô phỏng, rời trận không thưởng, thắng trả một lần, rematch, 30 quân hiển thị và không thay gà Farm. Ảnh `qa/screens/modal_battle_*`. Bluetooth và Android thật chưa nghiệm thu |

| A-BATTLE-03 | Intro 1 → 2 → 3 → BATTLE!, giảm khựng đầu trận, hình chiêu nguyên tố | [x] desktop | `BattleCountdown.gd`: số nảy/lắc, tia sáng/confetti, font Baloo2. Nạp bounce/attack/hit bất đồng bộ trước trận; không chạy timer/damage trong lúc chuẩn bị/đếm số. Gà băng bắn tinh thể/vệt lạnh/bông tuyết, kể cả đòn thường; nước/lửa/điện/lá/đá/gió có hình riêng. Battle visual chạy lại: 1.602 checks, 0 lỗi ở ba kích thước, gồm thoát khi đang nạp rồi vào lại. Sáu nhóm regression headless PASS; chưa chạy lại toàn bộ visual ngoài Battle trong lượt này. Probe 15v15: dựng trận 191,551 → 31,356 ms, nạp nền 447,304 ms, bước cập nhật nạp lớn nhất 3,411 ms trên máy desktop này; không suy ra hiệu năng Android. Xem `BATTLE.md` và `qa/battle-start-after.log`. |

Kết quả: `qa/save-map-regression.json`, `qa/map-drag-report.json`, `qa/modal-visual-report.json`; log tương ứng và `qa/farm-smoke.log`, `qa/egg-upgrade-visual.log`. Ảnh trong `qa/screens/egg_upgrade_fixed_*` và `qa/screens/modal_*`. Đây là chạy desktop với input mô phỏng, không thay thế kiểm thử thiết bị Android.

### Cập nhật Battle — 04/10/2026

- [x] **A-BATTLE-04 — trận đấu toàn màn hình:** intro, trận và kết quả phủ toàn viewport; ẩn TopHUD, BottomMenu và DEV, mở rộng bảng ô cả ngang/dọc. Rời trận trả lại bố cục lobby. Không đổi fullscreen của cửa sổ hệ điều hành.
- Kiểm chứng: `qa/battle-visual-report.json` **1.686 checks, 0 lỗi** ở 360×640, 390×844, 720×1280; kiểm tra kích thước viewport, các nút nằm trong màn hình, ẩn/khôi phục UI, resize ngay trong intro, rematch và kết quả. Đã xem ảnh render; chưa nghiệm thu Android thật. Ảnh: `qa/screens/modal_battle_combat_*`, `modal_battle_result_*`.

### Popup kết quả và nơi nhận hàng — 04/10/2026

- [x] **A-BATTLE-05:** popup thắng/thua/hòa, phần thưởng thực nhận và thống kê; BACK TO TEAM rời trận, REMATCH đấu lại. Chặn input nền, chặn nhấn ngay lúc vừa mở, giữ trả thưởng đúng một lần. Scene chỉnh sửa được: `scenes/battle/BattleResultPopup.tscn`.
- [x] **A-SHOP-03:** tiêu đề EARTH/ICE/... SHOP, banner BUYING FOR và số gà của map, nhãn TO ... FARM trên thẻ gà/trứng, thông báo mua thành công kèm map. Items ghi SHARED REWARDS. Hành tinh mua hàng vẫn là hành tinh đang chọn ở Farm; không thêm cơ chế đổi map ngầm. Nếu dữ liệu map đổi trước khi thẻ cập nhật, chặn mua không trừ Gold và yêu cầu xem lại nơi nhận.
- Kiểm chứng lượt này: Battle visual **1.815 checks**, Shop redesign **730 checks**, đều 0 lỗi trên desktop; 3 kích thước và mua hàng ở đủ 5 map. Đã xem ảnh kết quả/Shop. Không coi đây là nghiệm thu Android thật. Reports: `qa/battle-visual-report.json`, `qa/shop-redesign-report.json`.

### Điểm danh và quà quảng cáo — 04/10/2026

- [x] **A-REWARD-01 — điểm danh:** icon lịch ở Farm, modal 7 ngày thứ Hai–Chủ nhật kèm Gold/Gems, nhận miễn phí 1 lần/ngày, mốc 00:00 UTC+7, lưu cùng ví chung; đổi map/khởi động lại không nhận trùng. Lưu thất bại hoàn tác phần thưởng.
- [-] **A-REWARD-02 — quảng cáo tự nguyện:** icon video, modal quà, hai vị trí (Gold / thêm thưởng điểm danh), tổng 5 lượt/ngày, cooldown 120 giây, lượt thứ 5 thêm 5 Gems. Có adapter contract và kiểm tra callback/id/giới hạn/lưu; **chưa có SDK hoặc ad-unit ID nên chưa xem được quảng cáo thật**, không có mock ad trong bản chơi. Chờ chọn mạng/ID, tích hợp plugin, consent/privacy và test thiết bị.
- QA mới: rewards logic **122 checks**, rewards visual **114 checks**, 0 lỗi ở 3 kích thước; 7 nhóm regression headless PASS. Các kiểm tra quảng cáo dùng provider giả chỉ trong test, không chứng minh quảng cáo thật. Chi tiết và hạn chế đồng hồ offline: `REWARDS.md`.

### Polish điểm danh — 04/10/2026

- [x] Popup tinh nghịch: banner DAILY GOODIES, ô quà dạng sticker, ô TODAY nổi bật, mascot gà dùng sprite có sẵn, bật nhẹ khi mở và nhún/confetti khi nhận thành công. Không đổi lịch/phần thưởng hoặc tạo thêm lượt nhận.
- [x] Shortcut Farm theo yêu cầu mới: chỉ icon lịch và chữ **ĐIỂM DANH** bên dưới, bỏ khung nút ngang; AD GIFT đồng bộ cách trình bày. Vùng chạm vẫn đủ lớn và không kích hoạt gà/trứng phía sau icon.
- Kiểm thử rewards logic 122 checks; giao diện/motion/shortcut được kiểm tra lại ở ba kích thước trong `qa/rewards-visual-report.json`. Quảng cáo thật vẫn chờ SDK/ID như mục A-REWARD-02; không mở rộng sang BE trong lượt polish này.

### Âm thanh và Settings — 04/10/2026

- [x] Bộ âm thanh tổng hợp ban đầu: 3 loop Farm/Battle/UFO raid + 23 cue, phát offline từ asset sẵn, không tạo âm thanh trên main thread lúc chơi.
- [x] Modal Settings ở góc phải: font Baloo, chỉnh riêng Music/SFX, mute, nghe thử, ghi nhớ lựa chọn; chặn map/tab/kéo gà phía sau.
- [x] Desktop: kiểm tra Settings ở 360×640, 390×844, 720×1280; lưu/nạp prefs, mute/zero volume, nhạc theo chế độ, background/resume và giới hạn SFX. Bằng chứng mới nhất: `qa/audio-settings-report.json`. Bảy nhóm regression headless gameplay PASS.
- [!] Chưa nghiệm thu chất lượng nghe thực tế/Android. Đây là bộ nhạc synth ban đầu dùng chung Farm cho các hành tinh, không phải 5 bản nhạc hành tinh hay 100 bộ voice riêng. Chi tiết `AUDIO.md`.
- Kết quả lượt này: Settings/audio **170 checks**, Battle visual **1815 checks**, đều 0 failures; vẫn còn warning anchor cũ của tutorial trong bài Battle.

### Battle / Farm HUD / Shop theo ngày — 05/10/2026

- [x] Icon cài đặt dùng ảnh con căn giữa, độc lập với slot icon mặc định của Button. Điểm danh/AD Gift chuyển xuống dải thao tác bên dưới chuồng, không che vùng nuôi gà.
- [x] Audio dịu hơn: hạ octave, giảm harmonic/noise và nhịp nhạc; giữ bộ synth offline, cần người chơi nghe thử thực tế.
- [x] Battle: palette kem/xanh, đội hình/timer rõ hơn; di chuyển nội suy, HP/charge mượt, nhún/lunge khi đánh, bóng chân, số sát thương và fade khi bị hạ. Không đổi thuật toán sát thương.
- [x] Năng lượng trừ một lần khi trận thực sự bắt đầu và lưu cùng save. Tạm dùng 5/trận, không hồi theo thời gian; quảng cáo tự nguyện +20 Energy, cap 240; chưa coi đây là thông số cân bằng đã chốt.
- [x] Shop: seed theo ngày UTC+7 được lưu, 4 trứng + 4 gà mỗi hành tinh (giữ trứng Lv.1 và hai gà Tier-1 cơ bản), giá cố định theo loại/tier. Không reroll do mở lại hoặc chuyển map; chặn quote cũ và rollback khi lưu lỗi. Feed/Gem pouch giữ nguyên. Xem `PLAY_ECONOMY.md`.
- QA desktop: polish/economy 84 checks, Shop 664 checks, Battle 1815 checks, zero failures; 7 nhóm regression headless PASS. Android vẫn chờ nghiệm thu; warning anchor tutorial cũ vẫn tồn tại.

### Battle Energy / Win Reward — 05/10/2026

- [x] Battle/tái đấu tốn 5 Energy sau countdown; thiếu điểm hoặc lưu thất bại thì không bắt đầu. Thoát trước combat không mất điểm, thoát sau khi đánh không hoàn điểm.
- [x] Thắng nhận 150 Gold + 10 Gold/ô đang kiểm soát và 20 XP; lobby báo trước, popup hiện thưởng thực nhận. Thua/hòa/bỏ trận không thưởng.
- [x] Rollback Gold/XP khi lưu lỗi; popup PENDING cho RETRY SAVE, không trừ thêm Energy và không nhận thưởng lặp. Chưa có khôi phục thưởng pending khi buộc tắt app.
- QA: economy **62 checks**, Battle visual **1815 checks**, zero failures; **7 nhóm headless PASS**. Đã xem bố cục 360×640, 390×844, 720×1280. Android thật và cân bằng kinh tế vẫn cần nghiệm thu.

### Farm HUD shortcut pass — 08/10/2026

- [x] Chuyển `ĐIỂM DANH` và `AD GIFT` từ footer lên ngay dưới thanh tiến độ UFO; hàng shortcut kết thúc trước `FarmGround`, không che gà và không chạm nút đổi map.
- [x] Cân lại thanh UFO thành ba vùng icon / thời gian / progress, tăng chiều dài track và giữ kích thước bấm mobile cho hai shortcut.
- QA desktop: Daily/Battle polish **99 checks**, Rewards visual **201 checks**, zero failures ở 360×640, 390×844 và 720×1280; **7 nhóm headless PASS**. Warning anchor cũ của tutorial vẫn không liên quan.

### Top HUD / Energy ad pass — 08/10/2026

- [x] Loại nút `?` trùng chức năng khỏi Top HUD; xem lại hướng dẫn vẫn có trong Settings.
- [x] Bỏ hồi Energy theo thời gian/offline. Battle vẫn tốn 5 Energy; quảng cáo tự nguyện thường là nguồn tăng Energy duy nhất, +20/lượt đến cap 240. Khi đầy Energy, nút quảng cáo bị khóa để tránh xem mà không nhận được gì.
- [x] Quảng cáo nhân đôi điểm danh vẫn nhân đôi đúng quà ngày, không đổi thành Energy. Callback sai/trùng, đóng quảng cáo, timeout và lưu thất bại vẫn không trả thưởng lặp.
- QA desktop: Daily/Battle **99 checks**, Rewards visual **201 checks**, Settings/audio **170 checks**, Battle economy **62 checks**, zero failures; **7 nhóm headless PASS**.

### Runtime warning và QA ổn định — 12/10/2026

- [x] Xóa warning anchor lặp lại của Tutorial: `Root` đã neo full-screen nên không còn bị gán `size` thủ công sau `_ready()`.
- [x] Cô lập input test Modal, Raid, Fusion Outcome và Shop khỏi overlay onboarding; mỗi nhóm giữ user-data riêng theo process ID để không đọc nhầm save của lần chạy trước.
- [x] Ổn định cannon tap mô phỏng bằng cách giữ pointer tại hit target trong cả press/release; Raid visual chạy lặp hai lần sạch.
- Kiểm chứng desktop: 7 nhóm headless PASS; Battle economy, Daily/Battle, Settings/audio, Rewards, Tutorial, Egg Upgrade, Modal, Raid, Fusion Layout/Outcome, Shop/Shop Redesign và Battle visual đều PASS. Các log cuối không còn `WARNING`, `SCRIPT ERROR`, `ERROR` hoặc assertion failure. Android thật vẫn chưa được thay thế bởi kết quả này.

### 9.2. Chưa đủ điều kiện đánh dấu hoàn tất

- [!] Android thật: kiểm tra lại `adb devices -l` ngày 03/10 vẫn chưa có thiết bị kết nối. Không suy ra APK ổn định từ kết quả desktop.
- [-] Full UI regression: có Egg warning/success, Fusion, Shop, Collection, First Discovery và Battle offline; còn nghiệm thu Android thật và Bluetooth chưa triển khai.
- [x] Collection detail dùng `Game.creature_texture`/`creature_color`, bỏ placeholder; nhân vật khóa hiển thị silhouette.
- [x] First Discovery nằm ở CanvasLayer 110; test chặn tab/map trong reveal và trả điều khiển khi kết thúc.
- [-] Battle đã có mô phỏng fixed-step theo seed, x1/x2/x4 và skill có tác dụng thật; chưa nghiệm thu cân bằng/Android/Bluetooth. Không coi snapshot JSON là kết nối multiplayer đã hoàn thành.
- [-] Tutorial cần nghiệm thu thiết bị; Daily Quest/Achievement chưa hoàn tất. Settings/audio đã có kiểm tra desktop, còn nghiệm thu Android và chất lượng nghe thực tế.

### 9.3. Cần chốt nghiệp vụ trước phần phụ thuộc

- [x] **Fusion cùng hành tinh — đã chốt:** chỉ tạo giống thuộc map hiện tại. Recipe cũ dẫn ra map khác chuyển sang quy tắc dự phòng hiện có: 50/50 dòng bố/mẹ, Tier +1 khi thành công. Không chuyển hoặc xóa sinh vật đã có trong save.
- [x] **Hướng Battle:** offline AI trước, Bluetooth giữa hai điện thoại sau; 100 skill nhân vật, không chapter boss. Giữ tạm thời lượng hiện có 30 giây; cân bằng thời lượng/reward vẫn cần chơi thử, không coi thông số này là bản cân bằng cuối.
- [?] **UFO thất bại:** BA prototype ghi không mất gà/penalty 45 giây; game và yêu cầu gần đây có bắt cóc/penalty 600 giây. Giữ hành vi hiện tại, cần chốt hợp đồng Beta trước khi cân bằng hoặc viết tutorial chính thức.
- [?] **Economy:** cần mục tiêu thời gian mở khóa/nâng cấp và dữ liệu chơi thử. Bảng xác suất đúng tổng 100% không đồng nghĩa đã cân bằng.

---

Khi hoàn thành một đầu việc, đổi `- [ ]` thành `- [x]` kèm bằng chứng và phạm vi kiểm thử, cập nhật ngày ở đầu tài liệu. Chỉ đổi phần trăm khi có tiêu chí đo/denominator rõ ràng; không coi các ước tính cũ là kết quả nghiệm thu.
