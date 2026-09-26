# ResQ: trợ lý sinh tồn chạy hoàn toàn trên điện thoại

ResQ trả lời câu hỏi sinh tồn và sơ cứu khi không có sóng. Mô hình AI, cẩm nang và công cụ tìm kiếm đều nằm trên máy. Mỗi câu trả lời chỉ ra đoạn cẩm nang nó dựa vào. Tình huống nguy hiểm thì app hiện ngay các bước đã được duyệt, không chờ AI.

Chạy trên iPhone và Android. Cài một lần khi còn Wi-Fi, sau đó dùng ngoại tuyến.

Xem giao diện tương tác: `design/resq_prototype.html` (mở bằng trình duyệt, tốt nhất ở khổ điện thoại).

---

## 0. Màn hình chính: bảng điều khiển thực địa

Mở app là thấy ngay những con số quan trọng khi ở ngoài trời, tính trên máy, không cần mạng:

- **Ánh sáng còn lại** trước khi mặt trời lặn, tính theo toạ độ GPS và ngày hôm nay. Khi trời đã tối, ô này đếm ngược tới lúc trời sáng. Con số này quyết định có kịp dựng lán hay quay về trước khi tối.
- **Pin** và số giờ còn dùng được ở chế độ tiết kiệm.
- **Vị trí** và độ cao.
- **Bắt đầu nhanh** cho các tình huống hay gặp: chụp ảnh tra cứu, rắn cắn, bắt cá với đồ có sẵn, lọc nước, nhóm lửa.

## 1. Hỏi và nhận câu trả lời có nguồn

Người dùng gõ hoặc nói câu hỏi bằng tiếng Việt, có dấu hay không dấu đều được. ResQ trả lời theo ba lớp, lớp sau hiện sau lớp trước:

1. **Thẻ khẩn cấp**, nếu câu hỏi liên quan tới tình huống nguy hiểm tính mạng. Hiện trong khoảng 0,1 giây.
2. **Nguồn tìm được**, là các đoạn cẩm nang liên quan. Hiện trong khoảng 0,15 giây, bấm vào là đọc được.
3. **Câu trả lời của AI**, viết dần từng dòng, chia thành "Làm ngay", "Không được", "Khi nào cần cấp cứu". Mỗi ý có số nhỏ trỏ về nguồn.

Bấm vào một nguồn thì mở ra đoạn cẩm nang gốc, câu mà ResQ dựa vào được tô sáng. Người dùng tự kiểm chứng được, không phải tin mù vào AI.

Mỗi câu trả lời có một nhãn trạng thái:

- **Có căn cứ.** Cẩm nang có hướng dẫn phù hợp.
- **Không đủ căn cứ.** Cẩm nang chưa có hướng dẫn đủ sát. ResQ nói thẳng là không biết và đưa ra các bài gần nhất, thay vì tự bịa.
- **Nguồn mâu thuẫn.** Hai nguồn trong cẩm nang hướng dẫn khác nhau. ResQ cho xem cả hai.

Ví dụ: *"Tôi chỉ có chai nhựa và áo thun, lọc nước suối thế nào?"*. ResQ hướng dẫn làm bình lọc nhiều tầng, rồi nhắc rằng lọc chỉ làm nước trong hơn, vẫn phải đun sôi sùng sục ít nhất 1 phút mới uống được.

## 2. Thẻ khẩn cấp

Các bước ngắn, đánh số, chữ to, cho những tình huống không có thời gian đọc dài:

Chảy máu nặng · Bất tỉnh và ép tim · Rắn cắn · Hạ thân nhiệt · Sốc nhiệt · Đuối nước · Hóc dị vật · Gãy xương

- Nội dung do chuyên gia y tế viết và duyệt, có ngày duyệt. AI không viết thẻ.
- Mỗi thẻ có mục "KHÔNG" cho những việc hay làm sai, ví dụ rạch hay hút nọc rắn.
- Chạm vào từng bước để đánh dấu đã làm. Khi đang hoảng, người sơ cứu biết mình đang ở bước nào.
- Có nút gọi số khẩn cấp phù hợp. Số điện thoại lấy từ dữ liệu đã duyệt, AI không được tự sinh.
- Thẻ vẫn chạy khi AI tắt, khi pin yếu, hay khi máy chưa tải xong mô hình.
- Có thể bật tự đọc to thẻ để hai tay rảnh làm sơ cứu.

## 3. Màn hình SOS

Nút SOS màu đỏ luôn nằm ở góc trên, một chạm là mở.

- **Toạ độ của bạn.** GPS không cần sóng di động. Hiện số thập phân, độ phút giây và độ cao, chữ to đủ để đọc qua điện thoại cho đội cứu hộ.
- **Sao chép hoặc soạn SMS** kèm toạ độ. Khi sóng yếu, tin nhắn thường lọt qua được trong khi cuộc gọi thì không.
- **Đèn SOS.** Đèn flash nháy mã Morse · · · — — — · · · theo đúng nhịp chuẩn. Một thanh hiển thị chấm và gạch sáng theo từng nhịp nháy.
- **Còi báo.** Phát tiếng còi ghi sẵn ở âm lượng tối đa, ba hồi một.
- Đèn và còi phải **giữ nút khoảng nửa giây** mới bật, để không tự bật khi máy nằm trong túi. Chạm lần nữa để tắt.
- **Số khẩn cấp Việt Nam.** 112 cứu nạn, 115 cấp cứu, 114 cứu hỏa, 113 công an.
- **Lối tắt tới các thẻ khẩn cấp.**

## 4. Cẩm nang dã chiến

Cẩm nang đọc được và tìm được mà không cần AI:

| Trụ cột | Ví dụ |
|---|---|
| Lửa và giữ nhiệt | Nhóm lửa khi củi ướt, vót phoi, bếp Dakota |
| Nước sạch | Tìm nguồn nước, lọc nhiều tầng, đun sôi đúng cách |
| Kiếm ăn và bẫy | Bẫy cá bằng chai nhựa, nguồn đạm dễ nhận biết |
| Trú ẩn và nút dây | Lán chữ A, lán dựa vách, nút ghế đơn |
| Định hướng | Bóng gậy mặt trời, sao Bắc Cực, đi xuôi dòng suối |
| Sơ cứu dã ngoại | Cầm máu, nẹp xương, hạ thân nhiệt, say nắng |

- Tìm kiếm chạy trên máy, gõ không dấu vẫn ra, hiểu từ đồng nghĩa ("ép tim" tìm ra "hồi sức tim phổi").
- Bài hướng dẫn có sơ đồ minh hoạ và các bước đánh số.
- Mỗi bài ghi rõ nguồn và mức độ tin cậy của nguồn.
- Nút "Hỏi ResQ về bài này" để hỏi tiếp theo hoàn cảnh riêng.

## 5. Hỏi theo đồ đang có

Nói cho ResQ biết bạn có gì trong ba-lô, ví dụ *"chỉ có một con dao, dây dù và chai nhựa"*. ResQ nhớ danh sách đó trong suốt cuộc hỏi và chỉ gợi ý cách làm dùng được với những thứ đó. Hỏi tiếp *"còn nếu trời mưa thì sao?"* thì ResQ vẫn hiểu đang nói về việc gì.

## 6. Chụp ảnh để tra cứu

Chụp một cây, một cây nấm, một vết thương hay một con côn trùng. ResQ mô tả những gì nhìn thấy (dáng, màu, đặc điểm) rồi tra cẩm nang theo mô tả đó.

ResQ **không bao giờ** nói một loài nấm hay cây là ăn được chỉ dựa trên ảnh. Nấm độc chết người có thể giống hệt nấm ăn được, và ngay cả chuyên gia cũng cần xem mẫu thật. Với nấm hoang dã, câu trả lời luôn là không ăn, kèm hướng dẫn nếu lỡ ăn rồi.

## 7. Giọng nói

- Bấm "Nói" để hỏi bằng giọng, nhận dạng giọng nói chạy trên máy.
- Mỗi câu trả lời có nút đọc to bằng giọng tiếng Việt của máy.

## 8. Dùng được trong điều kiện khó

- **Ba giao diện.** Tối là mặc định. Nắng là nền sáng, tương phản cao, đọc được dưới nắng gắt. Nhìn đêm chuyển toàn bộ sang màu đỏ trên nền đen để mắt không mất khả năng nhìn trong tối.
- **Chữ lớn.** Dễ đọc dưới nắng hoặc khi mệt.
- **Nút to.** Mọi nút có vùng chạm tối thiểu 44 điểm, bấm được khi đeo găng hoặc tay ướt.
- **Rung phản hồi** khi bấm, đánh dấu bước, bật tín hiệu, để biết thao tác đã nhận mà không cần nhìn.

## 9. Tiết kiệm pin

- Pin dưới 20% hoặc máy nóng: câu trả lời ngắn hơn, ít tính toán hơn.
- Pin dưới 10%: tắt AI. Cẩm nang, tìm kiếm, thẻ khẩn cấp và SOS vẫn chạy.
- Thanh trạng thái luôn cho biết đang ngoại tuyến, mô hình nào đang chạy, còn bao nhiêu pin.

## 10. Chuẩn bị trước chuyến đi

Một danh sách kiểm tra để làm khi còn Wi-Fi:

- Mô hình AI đã tải và chạy thử được.
- Cẩm nang là bản mới nhất.
- Đã có giọng đọc và nhận dạng giọng nói tiếng Việt ngoại tuyến.
- Đã cấp quyền vị trí.
- Pin đầy, có sạc dự phòng.

Kèm lời nhắc: báo lộ trình và giờ về cho người ở nhà, bật chế độ máy bay khi không cần gọi để giữ pin. GPS vẫn chạy ở chế độ máy bay.

## 11. Ghim và lưu

- **Ghim vị trí.** Lưu toạ độ hiện tại kèm ghi chú, ví dụ nguồn nước, chỗ nguy hiểm, đường quay lại.
- **Lưu câu trả lời.** Câu trả lời hữu ích được lưu vào mục "Đã lưu" của cẩm nang.
- **Lịch sử.** Các cuộc hỏi cũ nằm trong menu.

## 12. Riêng tư

Mọi thứ chạy trên máy. Câu hỏi, ảnh, giọng nói và vị trí không gửi đi đâu. App chỉ dùng mạng để tải mô hình và cập nhật cẩm nang khi người dùng bấm.

## 13. Những điều ResQ không làm

- Không thay thế bác sĩ hay đội cứu hộ. Tình huống nặng, ResQ luôn nhắc gọi cứu hộ và chỉ rõ dấu hiệu cần cấp cứu.
- Không tự gọi hay gửi tin cứu hộ. Người dùng quyết định.
- Không xác nhận nấm hay cây ăn được qua ảnh.
- Không trả lời khi cẩm nang không có căn cứ.
- Không có bản đồ địa hình trong bản đầu tiên. Có toạ độ, độ cao và các điểm đã ghim.

## 14. Thiết bị hỗ trợ

| Loại máy | Trải nghiệm |
|---|---|
| RAM 12 GB trở lên | Đầy đủ, có thể chọn mô hình chất lượng cao hơn (Gemma 4 E4B) |
| RAM 8 GB, ví dụ iPhone 15 Pro | Đầy đủ với mô hình chuẩn (Gemma 4 E2B) |
| RAM 6 GB trở xuống | Chế độ tra cứu: cẩm nang, tìm kiếm, thẻ khẩn cấp, SOS. Không có AI |

Dung lượng cài đặt khoảng 3 GB, gồm mô hình 2,6 GB, cẩm nang và bộ tìm kiếm.

---

*Nội dung sơ cứu trong tài liệu và bản mẫu là nội dung minh hoạ, đang chờ chuyên gia y tế duyệt.*
