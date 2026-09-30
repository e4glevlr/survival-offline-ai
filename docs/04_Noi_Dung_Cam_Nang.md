# Nội dung cẩm nang: nguồn, danh mục và cách cập nhật

Ngày: 30/09/2026. Trạng thái: **bản nháp để thử nghiệm, chưa qua chuyên gia duyệt.**
Dữ liệu: `ios/ResQKit/Sources/ResQUI/Resources/guides.json`. Thẻ khẩn cấp: `ios/ResQKit/Sources/ResQUI/GuideLibrary.swift`.

## Tóm tắt

- Tab Cẩm nang có **36 bài**, chia đều cho 6 trụ cột, cùng **9 thẻ khẩn cấp**. Trước đây app có 1 bài và 7 thẻ.
- Phần sinh tồn viết lại từ **US Army FM 21-76**, tài liệu công cộng. Phần sơ cứu tự viết theo **IFRC International First Aid Guidelines 2020** và **WHO**. Không dùng tài liệu có bản quyền, nên khi phát hành chính thức không phải xin phép hay mua license.
- Có hai bài không dựa trên tài liệu gốc nào (nút dây, vắt đỉa) và được gắn **cấp C** để phân biệt.
- Toàn bộ nội dung vẫn là nháp. Phần sơ cứu phải được bác sĩ duyệt trước khi phát hành. Danh sách điểm cần duyệt ở mục 7.

## 1. Nguồn và giấy phép

| Nguồn | Dùng cho | Giấy phép | Ghi chú |
|---|---|---|---|
| US Army FM 21-76 *Survival* (bản 1992, tái bản 2006) | Lửa, nước, thức ăn, chỗ trú, định hướng, tín hiệu | Phạm vi công cộng (tài liệu Chính phủ Mỹ) | Bản chữ: [archive.org/details/USArmyFM2176](https://archive.org/details/USArmyFM2176). Bản thay thế FM 3-05.70 cũng thuộc phạm vi công cộng. |
| IFRC International First Aid, Resuscitation and Education Guidelines 2020 | Vết thương, bong gân, ong đốt, sốc phản vệ, nằm nghiêng an toàn, 3 thẻ mới | Dùng làm căn cứ, không chép nguyên văn | Nội dung trong app là lời văn tự viết. |
| WHO | Khử trùng nước (đun sôi, phơi nắng SODIS), công thức nước bù điện giải tự pha | Dùng làm căn cứ, không chép nguyên văn | |
| Tự biên soạn | `knots`, `aid-leech` | Nội dung tự viết | Gắn cấp C. |

Vì sao không dùng SAS Survival Handbook như bản BA ban đầu: sách có bản quyền, không đóng gói vào app được nếu không mua license. Xem `docs/01`, mục 8.

Cấp nguồn hiển thị trên bài ("Nguồn cấp B") khớp với `TrustTier` trong `ResQCore`. Chưa bài nào được gắn cấp A, vì cấp A dành cho nội dung đã có cơ quan y tế hoặc chuyên gia xác nhận.

## 2. Nguyên tắc biên soạn

**Viết lại, không dịch nguyên văn.** Mỗi bài có một câu tóm tắt, 4–9 bước, rồi các lưu ý. Mỗi bước mở đầu bằng cụm in đậm để người đọc lướt nhanh được. Câu ngắn, dạng mệnh lệnh, tránh thuật ngữ.

**Khi FM 21-76 đã cũ thì theo hướng dẫn mới hơn.** Những chỗ đã sửa so với bản gốc:

| Chủ đề | FM 21-76 viết | Trong app |
|---|---|---|
| Thời gian đun sôi | 1 phút, cộng 1 phút cho mỗi 300 m độ cao, hoặc 10 phút | Sôi sùng sục 1 phút, trên 2.000 m là 3 phút (WHO/CDC) |
| Giun đất | Ăn sống được sau khi cho nhả đất | Nấu chín trước khi ăn |
| Nhiễm từ kim bằng lụa, tóc | Là cách chính | Ghi rõ là yếu, ưu tiên nam châm hoặc pin |
| Phép thử cây ăn được | Quy trình đầy đủ nhiều bước | Rút gọn, chỉ dùng khi không còn gì ăn, ghi rõ không áp dụng cho nấm |
| Sơ cứu (chương 4) | Có garô, xử lý theo quân y năm 1992 | Không dùng chương này. Sơ cứu viết theo IFRC 2020 |
| Cá hỏng | "Gây nôn nếu có triệu chứng" | Bỏ. Chỉ giữ dấu hiệu nhận biết và lời khuyên bỏ đi |

**Chỉnh cho bối cảnh Việt Nam:**

- Số khẩn cấp: 115 (cấp cứu), 112 (tìm kiếm cứu nạn), 114 (cứu hoả, cứu nạn), 113 (công an).
- Cây độc hay gây chết người ở Việt Nam: lá ngón, sắn sống, hạt củ đậu, nấm độc. Rau dại quen thuộc: rau má, rau dền, rau sam, măng, chuối rừng.
- Ký sinh trùng hay gặp: sán lá phổi (cua suối sống), sán lá gan (gỏi cá nước ngọt), giun gây viêm màng não (ốc sống).
- Ong vò vẽ, ong đất đốt nhiều nốt gây suy thận, cần vào viện dù chưa có triệu chứng.
- Mẹo dân gian cần cấm rõ: bôi kem đánh răng, nước mắm lên vết bỏng; đắp lá, thuốc lào lên vết thương; bôi vôi chỗ ong đốt; xoa dầu nóng, bóp rượu chỗ bong gân.
- Định hướng: Việt Nam nằm trong vùng nhiệt đới, nên vào mùa hè mặt trời giữa trưa có lúc lệch về phía Bắc. Miền Nam khoảng cuối tháng 4 đến giữa tháng 8, miền Bắc khoảng cuối tháng 5 đến cuối tháng 7. Cách xem hướng bằng đồng hồ vì vậy kém tin cậy. Sao Bắc Cực nằm thấp, khoảng 9° ở Cà Mau và 23° ở Hà Giang. Việt Nam không dùng giờ mùa hè.
- Pháp luật: bài đặt bẫy ghi rõ săn bắt trong vườn quốc gia, khu bảo tồn là vi phạm. Bài câu cá cấm dùng thuốc nổ, kích điện, chất độc.
- Thiên tai: có dấu hiệu lũ quét (nước đục dần, cành lá trôi, tiếng ầm từ thượng nguồn) và cảnh báo dông sét khi chọn chỗ trú.

## 3. Danh mục

### 3.1 Thẻ khẩn cấp

Thẻ nằm trong `GuideLibrary.cards` (Swift). Thẻ có `intent` khớp với `RiskRouter` sẽ tự hiện trong câu trả lời, qua bảng `DemoResponder.cardForIntent`.

| id | Tiêu đề | Intent của router | Mới |
|---|---|---|---|
| `ec-bleed` | Chảy máu nặng | `severe_bleeding` | |
| `ec-cpr` | Bất tỉnh, ép tim | `unconscious` | |
| `ec-snake` | Rắn cắn | `snake_bite` | |
| `ec-cold` | Hạ thân nhiệt | `hypothermia` | |
| `ec-heat` | Sốc nhiệt | `heat_stroke` | |
| `ec-drown` | Đuối nước | `drowning` | |
| `ec-burn` | Bỏng | chưa có intent | ✓ |
| `ec-choke` | Hóc dị vật | `choking` | ✓ |
| `ec-fracture` | Gãy xương | `fracture` | ✓ |

Mọi thẻ vẫn mang nhãn `sourceLabel: "Nội dung mẫu"` và `reviewedAt: "chờ duyệt"`.

### 3.2 Bài viết

**Lửa và giữ nhiệt**

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `fire-site` | Chọn chỗ nhóm lửa | 5 | 3 | FM 21-76, ch.7 | B |
| `fire-lay` | Bùi nhùi, củi mồi và cách xếp củi | 6 | 2 | FM 21-76, ch.7 | B |
| `fire-no-match` | Tạo lửa khi không có diêm | 6 | 2 | FM 21-76, ch.7 | B |
| `fire-bow-drill` | Tạo lửa bằng cung khoan | 7 | 2 | FM 21-76, ch.7 | B |
| `fire-keep-out` | Giữ lửa qua đêm và dập lửa | 5 | 2 | FM 21-76, ch.7 | B |
| `warmth` | Giữ ấm khi trời lạnh, ướt | 7 | 3 | FM 21-76, ch.5, ch.15 | B |

**Nước sạch**

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `water-bottle-filter` | Lọc nước bằng chai nhựa | 5 | 2 | FM 21-76 | B |
| `water-purify` | Khử trùng nước uống | 7 | 3 | FM 21-76, ch.6; WHO | B |
| `water-find` | Tìm nguồn nước trong rừng | 7 | 3 | FM 21-76, ch.6 | B |
| `water-still-bag` | Hứng nước bằng túi nilon trùm lá | 6 | 2 | FM 21-76, ch.6 | B |
| `water-still-pit` | Hố chưng cất nước | 7 | 3 | FM 21-76, ch.6 | B |
| `water-ration` | Mất nước: uống gì, không uống gì | 5 | 2 | FM 21-76, ch.6, ch.13 | B |

**Kiếm ăn và bẫy**

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `food-insects` | Côn trùng, giun, ốc: đồ ăn dễ kiếm | 6 | 2 | FM 21-76, ch.8 | B |
| `food-plants` | Cây dại: cách tránh ngộ độc | 5 | 3 | FM 21-76, ch.9 | B |
| `food-shellfish` | Bắt cua, tôm, ốc ở suối và ven biển | 5 | 3 | FM 21-76, ch.8 | B |
| `food-fishing` | Câu cá bằng dụng cụ tự chế | 6 | 2 | FM 21-76, ch.8 | B |
| `food-traps` | Chỗ đặt bẫy và che mùi | 7 | 3 | FM 21-76, ch.8 | B |
| `food-fish-prep` | Sơ chế cá và nhận biết cá hỏng | 6 | 3 | FM 21-76, ch.8 | B |

**Trú ẩn, nút dây**

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `shelter-site` | Chọn chỗ dựng chỗ trú | 8 | 2 | FM 21-76, ch.5 | B |
| `shelter-tarp` | Mái che bằng tấm bạt hoặc áo mưa | 7 | 2 | FM 21-76, ch.5 | B |
| `shelter-leanto` | Lều mái nghiêng bằng cành cây | 6 | 2 | FM 21-76, ch.5 | B |
| `shelter-debris` | Lều lá giữ ấm | 7 | 2 | FM 21-76, ch.5 | B |
| `shelter-raised` | Giường sàn tránh nước, côn trùng | 6 | 2 | FM 21-76, ch.5 | B |
| `knots` | Năm nút dây cần biết | 6 | 2 | Tự biên soạn | C |

**Định hướng**

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `nav-shadow` | Tìm hướng bằng bóng que | 6 | 2 | FM 21-76, ch.18 | B |
| `nav-watch` | Tìm hướng bằng đồng hồ kim | 5 | 1 | FM 21-76, ch.18 | B |
| `nav-stars` | Tìm hướng ban đêm bằng sao và trăng | 6 | 1 | FM 21-76, ch.18 | B |
| `nav-compass` | La bàn tự chế bằng kim khâu | 6 | 1 | FM 21-76, ch.18 | B |
| `nav-signal` | Phát tín hiệu cầu cứu | 9 | 3 | FM 21-76, ch.19 | B |
| `nav-lost` | Khi bị lạc | 8 | 2 | FM 21-76, ch.1 | B |

**Sơ cứu dã ngoại** (ngoài 9 thẻ khẩn cấp)

| id | Tiêu đề | Bước | Lưu ý | Nguồn | Cấp |
|---|---|---|---|---|---|
| `aid-wound` | Vết thương nhỏ, trầy xước | 6 | 2 | IFRC 2020 | B |
| `aid-sprain` | Bong gân, trật khớp | 6 | 2 | IFRC 2020 | B |
| `aid-sting` | Ong đốt, côn trùng cắn, sốc phản vệ | 8 | 2 | IFRC 2020 | B |
| `aid-leech` | Vắt, đỉa bám | 4 | 3 | Tự biên soạn | C |
| `aid-ors` | Tiêu chảy, mất nước: pha nước bù điện giải | 5 | 3 | WHO | B |
| `aid-recovery` | Tư thế nằm nghiêng an toàn | 7 | 2 | IFRC 2020 | B |

## 4. Định dạng dữ liệu

`guides.json` có ba khoá: `version`, `note` và `articles`. Mỗi phần tử của `articles`:

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | string | Khoá duy nhất, kebab-case. Không đổi sau khi phát hành, vì sau này mục đã lưu và gói tri thức sẽ tham chiếu theo id. |
| `pillar` | string | Phải khớp **chính xác** một `title` trong `GuideLibrary.pillars`, nếu không bài sẽ không hiện trong trụ cột nào. |
| `icon` | string | Tên SF Symbol, phải có trên iOS 17. |
| `title` | string | Tiêu đề. Mục "Đã lưu" hiện đang tìm bài theo tiêu đề nên tiêu đề cũng phải là duy nhất. |
| `minutes` | int | Thời gian đọc ước tính, hiện trên thẻ bài. |
| `source` | string | Nhãn nguồn ngắn, hiện trên bài, ví dụ `"FM 21-76, ch.7"`. |
| `trust` | `"A"` \| `"B"` \| `"C"` | Cấp nguồn. C hiện màu xám, A và B hiện màu xanh. |
| `license` | string | Giấy phép của nguồn. App chưa hiển thị, dùng khi build gói tri thức. |
| `summary` | string | Một hai câu dưới tiêu đề. |
| `steps` | [string] | Các bước, hiện thành checklist bấm được. Cụm đầu bước bọc `**…**` để in đậm. |
| `warnings` | [string] | Hiện trong khung "LƯU Ý" màu vàng dưới các bước. Có thể rỗng. |

Ví dụ rút gọn:

```json
{
  "id": "nav-shadow", "pillar": "Định hướng", "icon": "sun.min.fill", "minutes": 3,
  "title": "Tìm hướng bằng bóng que",
  "source": "FM 21-76, ch.18", "trust": "B", "license": "Phạm vi công cộng",
  "summary": "Một cây que và 15 phút nắng là đủ để biết Đông, Tây, Nam, Bắc.",
  "steps": ["**Cắm một que dài khoảng 1 m** thẳng đứng trên chỗ đất bằng, có nắng.", "…"],
  "warnings": ["Không nhìn thẳng vào mặt trời."]
}
```

## 5. App dùng dữ liệu thế nào

- **Nạp.** `GuideLibrary.articles` giải mã `guides.json` từ `Bundle.module` một lần, lúc được dùng lần đầu. Tệp được đóng gói nhờ `resources: [.process("Resources")]` trong `ResQKit/Package.swift`. JSON sai định dạng sẽ làm app crash lần đầu đọc danh sách bài (tab Cẩm nang, màn Cài đặt). Cố ý để vậy, cho lỗi lộ ra ngay lúc phát triển.
- **Trụ cột.** `Pillar.articles` lọc bài theo `pillar`. Màu biểu tượng của bài lấy theo màu trụ cột. Trụ cột "Sơ cứu dã ngoại" hiện cả bài lẫn thẻ khẩn cấp.
- **Màn bài viết.** `ArticleSheet(article:)` hiện đường dẫn trụ cột, tiêu đề, thời gian đọc, cấp nguồn, nhãn nguồn, tóm tắt, checklist có thanh tiến độ, khung lưu ý và nút "Hỏi ResQ về bài này". Nút này gửi tiêu đề bài sang tab Hỏi. Riêng bài `water-bottle-filter` có thêm sơ đồ `FilterDiagram`.
- **Đọc to và lưu.** Nút loa đọc tiêu đề, các bước và lưu ý. Nút lưu ghi bài vào `UserStore` theo tiêu đề. Bấm vào mục đã lưu sẽ mở lại đúng bài. Nếu không còn bài trùng tiêu đề (bài đã bị đổi tên), app mở bản chữ đã lưu.
- **Tìm kiếm.** `GuideLibrary.search` so khớp không dấu, không phân biệt hoa thường, trên tiêu đề, trụ cột, tóm tắt và toàn bộ các bước. Gõ "cung khoan" hay "sao bac cuc" đều ra.
- **Thẻ khẩn cấp** vẫn nằm trong Swift vì `DemoResponder`, `SOSScreen` và `EmergencyPassView` dùng trực tiếp. Biểu tượng của thẻ đặt trong `GuideLibrary.icon(for:)`.

## 6. Thêm hoặc sửa bài

1. Sửa `guides.json`. Giữ bài cùng trụ cột nằm cạnh nhau, vì thứ tự trong tệp là thứ tự hiện trong app.
2. Kiểm tra JSON và id trùng:
   ```bash
   python3 -c "import json,collections as c;a=json.load(open('ios/ResQKit/Sources/ResQUI/Resources/guides.json'))['articles'];print(len(a),c.Counter(x['pillar'] for x in a));assert len({x['id'] for x in a})==len(a)"
   ```
3. Kiểm tra biểu tượng có tồn tại: dùng `NSImage(systemSymbolName:accessibilityDescription:)` trên macOS, hoặc tra trong app SF Symbols.
4. Build và chạy UI test Cẩm nang. Test này mở trụ cột "Lửa và giữ nhiệt", mở bài "Giữ ấm khi trời lạnh, ướt" và chụp màn hình vào `$SCREENSHOT_DIR`:
   ```bash
   cd ios/ResQApp
   TEST_RUNNER_SCREENSHOT_DIR=/tmp/resq-shots xcodebuild test -project ResQApp.xcodeproj -scheme ResQApp \
     -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build \
     -only-testing:ResQAppUITests/ScreenTour/test06Guides
   ```
5. Thêm thẻ khẩn cấp: thêm `card(...)` trong `GuideLibrary.cards`, thêm biểu tượng trong `icon(for:)`. Nếu router có intent tương ứng thì thêm vào `DemoResponder.cardForIntent`.

Văn phong: câu ngắn, mệnh lệnh, số liệu cụ thể (cm, phút, lít). Không viết "có thể cân nhắc", "nên lưu ý rằng". Lời cấm bắt đầu bằng "Không". Mỗi câu nguy hiểm nếu hiểu sai phải có căn cứ từ nguồn ghi ở trường `source`.

## 7. Cần chuyên gia duyệt trước khi phát hành

Ưu tiên cao: nội dung y tế, nếu sai có thể gây hại.

| Mục | Cần kiểm tra |
|---|---|
| `ec-burn` | Thời gian làm mát 20 phút (một số hướng dẫn ghi tối thiểu 10 phút). Dùng màng bọc thực phẩm. Ngưỡng phải đi viện. |
| `ec-choke` | Thứ tự vỗ lưng và ép bụng. Cách làm với trẻ dưới 1 tuổi (thẻ chỉ ghi "không ép bụng", chưa hướng dẫn ép ngực). |
| `ec-fracture` | Cách xử lý gãy hở. Lời khuyên về nghi chấn thương cột sống. |
| `aid-sting` | Liều và cách tiêm adrenaline tự động, thời điểm tiêm liều hai. Ngưỡng "nhiều nốt" với ong vò vẽ nên ghi thành con số. |
| `aid-ors` | Công thức tự pha (6 thìa đường, ½ thìa muối, 1 lít nước), lượng uống cho trẻ em. |
| `aid-wound` | Rửa vết cắn 15 phút, chỉ định tiêm uốn ván và phòng dại. |
| `aid-recovery` | Các bước lật người, thời gian đổi bên. |
| `aid-leech` | Bài tự viết, chưa có nguồn. Cần nguồn y khoa hoặc bỏ. |
| 6 thẻ cũ | Vẫn mang nhãn "Nội dung mẫu", chưa ai duyệt. |

Ưu tiên trung bình: sai thì gây ngộ độc hoặc làm người dùng lạc hướng.

| Mục | Cần kiểm tra |
|---|---|
| `food-plants` | Danh sách rau dại ăn được và cây độc của Việt Nam. Phép thử cây rút gọn có nên giữ hay bỏ hẳn. |
| `food-insects`, `food-shellfish`, `food-fish-prep` | Tên ký sinh trùng và nguồn lây. |
| `water-purify` | Liều i-ốt, đối tượng không nên dùng. Điều kiện phơi nắng SODIS. |
| `nav-watch`, `nav-stars` | Mốc tháng mặt trời lệch Bắc và độ cao sao Bắc Cực đã được tính theo vĩ độ Cà Mau và Hà Giang. Nên có người đối chiếu lại. |
| `nav-signal` | Gọi 112 hoặc 115 khi không có SIM có thực sự kết nối được ở Việt Nam không. |
| `knots` | Tên tiếng Việt của các nút (nút dẹt, ghế đơn, thuyền chài, thợ dệt) theo cách gọi của Hướng đạo. Bài tự viết. |

Khi một bài đã được duyệt: đổi `trust` nếu phù hợp, ghi người duyệt và ngày duyệt. Schema hiện chưa có trường cho việc này, xem mục 8.

## 8. Hạn chế và việc tiếp theo

- **Chưa vào pipeline RAG.** Bài chỉ hiện ở tab Cẩm nang và trong tìm kiếm. Câu trả lời AI vẫn dựa trên `bench/data/evidence.json` và các chủ đề mẫu trong `DemoResponder`. Bước tiếp theo là để pack builder cắt `guides.json` thành chunk cha–con (một bài là cha, mỗi bước kèm lưu ý liên quan là con) và điền cột `license`, theo `docs/01`.
- **Schema chưa có trường duyệt.** Cần thêm `reviewedBy`, `reviewedAt`, `sourceUrl` và `version` cho từng bài, rồi hiện trên màn bài giống thẻ khẩn cấp.
- **Mới có một sơ đồ.** Chỉ bài lọc nước có hình minh hoạ. Các bài cung khoan, lều lá, hố chưng cất, nút dây và ký hiệu mặt đất cần hình mới dễ hiểu. FM 21-76 có hình gốc thuộc phạm vi công cộng, có thể vẽ lại.
- **Thẻ khẩn cấp vẫn nằm trong code.** Nên chuyển sang cùng tệp dữ liệu khi làm gói tri thức, để Android dùng chung.
- **Mục đã lưu tham chiếu bằng tiêu đề.** Đổi tiêu đề một bài thì mục đã lưu cũ chỉ mở được bản chữ. Nên chuyển sang lưu theo `id`.
- **Chưa có trụ cột thiên tai.** Lũ quét, sạt lở, bão và sét mới chỉ được nhắc trong các bài chọn chỗ trú. Với người dùng Việt Nam, nên có một trụ cột riêng cho thiên tai.
