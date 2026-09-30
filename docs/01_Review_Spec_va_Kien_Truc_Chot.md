# Review spec v0.2 và kiến trúc chốt v0.3 cho iOS + Android

Ngày: 27/09/2026. Đầu vào: `Survival_Offline_AI_RAG_Technical_Spec_v0.2.docx`, `SURVIVAL_AI_BA_SPECIFICATION.md`, mockup HTML của team.
Đầu ra đi kèm: `design/resq_prototype.html`, `ios/ResQKit` (Swift, 25 test pass), `docs/02_Gioi_Thieu_Tinh_Nang.md`.

## Tóm tắt quyết định

| Hạng mục | Spec v0.2 | Chốt v0.3 | Lý do chính |
|---|---|---|---|
| Nền tảng | Chỉ iPhone 15 Pro | iOS + Android, cùng một lõi logic | Yêu cầu mới |
| Runtime LLM | Chưa chốt (MLX/Core ML ngầm định) | **LiteRT-LM** trên cả hai, cùng một file model | API Swift + Kotlin chính thức, GPU Metal và GPU/NPU Android |
| Model mặc định | Qwen3.5-4B 4-bit | **Gemma 4 E4B** (3,66 GB) cho mọi máy từ 8 GB, máy thấp hơn chỉ tra cứu | Thắng benchmark trên LiteRT-LM: đạt 88,6%, E2B 32,9%, Qwen3.5-4B 14,3% (`docs/03`) |
| Qwen3.5 | Mặc định | **Loại khỏi MVP** | Bản LiteRT cộng đồng hỏng với prompt dài. Qua llama.cpp thua E4B 17 điểm, token đầu chậm hơn (`docs/03`) |
| Số model cài trên máy | 4B + 2B | **Một model mỗi máy** | Tiết kiệm 1,7 GB, không tốn thời gian nạp lại khi đổi |
| Tiết kiệm pin | Đổi sang 2B | Giảm evidence và độ dài output, tắt AI khi pin < 10% | Đổi model tốn thời gian và pin hơn phần tiết kiệm được |
| Embedding | e5-small, Core ML | e5-small dạng **.tflite chạy LiteRT** trên cả hai | Vector giống nhau giữa hai nền tảng, test dùng chung |
| Vector | FP16 | **INT8 + scale theo hàng** | Nhỏ bằng nửa, Kotlin không có phép tính FP16 nhanh |
| Evidence budget | 1,5–2,4K token | **1,1–1,3K token**, tối đa 4 khối | Prefill là phần lớn nhất của TTFT |
| Output | JSON | **Định dạng theo dòng**, nhãn E1…En | Hiện dần khi đang stream, chịu được khi bị cắt giữa chừng |
| FTS5 tiếng Việt | `remove_diacritics 2` | Thêm cột fold tự viết (đ→d) + bigram âm tiết | `unicode61` không fold chữ "đ" |
| UX trả lời | Chat thường | **Evidence-first**: thẻ khẩn cấp và nguồn hiện trước, AI viết sau | Người dùng có việc để làm ngay trong lúc chờ model |

## 1. Đánh giá chung spec v0.2

Spec v0.2 có nền tốt, mình giữ phần lớn. Các quyết định sau đúng và nên giữ nguyên:

- Build-time nặng, run-time nhẹ. Máy chỉ normalize, embed một câu, BM25, dot product, fusion.
- Hybrid FTS5 + dense + RRF, không có neural reranker trong MVP.
- Chunk kiểu parent–child, retrieve child rồi đưa parent vào prompt, không tách warning khỏi bước nó áp dụng.
- Trust tier, conflict group, expired content bị loại khỏi câu trả lời critical.
- Emergency Card bypass, không để việc nạp model chặn hành động khẩn cấp.
- Grounding validator deterministic, không dùng NLI.
- Golden set, ablation và release gates đo bằng dữ liệu.

Những chỗ phải sửa, xếp theo mức nghiêm trọng:

1. **TTFT không khớp với ngân sách context.** Prompt khoảng 2,5–3K token với model 4B mà BA cam kết TTFT 1,2–1,8 giây. Với runtime chưa tối ưu cho kiến trúc hybrid của Qwen3.5, mình không tìm được số đo nào trên điện thoại chứng minh được con số đó. Xem mục 4.
2. **Chưa có câu trả lời cho Android.** FTS5 trong SQLite của Android không đảm bảo có. Core ML và MLX không chạy trên Android. Spec cũng thiếu phân tầng thiết bị theo RAM.
3. **Tìm kiếm tiếng Việt có lỗi âm thầm.** `unicode61 remove_diacritics 2` không đổi "đ" thành "d" vì "đ" không có dạng phân rã. Người gõ "duong" sẽ không khớp "đường". Chi tiết ở mục 5.1.
4. **Nội dung có chỗ sai và rủi ro bản quyền.** Mockup đang nhận diện nhầm một loài nấm ăn được thành nấm độc chết người. BA ghi nguồn là SAS Survival Handbook, một cuốn sách có bản quyền. Xem mục 8.
5. **JSON output khó stream.** Giao diện phải chờ đủ JSON mới hiển thị được, và model nhỏ hay làm hỏng JSON khi bị cắt ở giới hạn token.
6. **Cài hai model và đổi model khi pin yếu.** Tốn thêm 1,75 GB và phải nạp lại model đúng lúc máy yếu nhất.

## 2. Chọn model

### 2.1 Tình hình tháng 9/2026

- **Qwen3.5 Small** gồm 0.8B, 2B, 4B, 9B, license Apache-2.0, đa phương thức với vision encoder, kiến trúc hybrid Gated DeltaNet + gated attention. llama.cpp và MLX hỗ trợ. LiteRT-LM chưa liệt kê Qwen3.5, chỉ có Qwen2.5 và Qwen3-0.6B. Qwen3.6 chỉ có bản 27B và 35B-A3B, không có bản cho điện thoại.
- **Gemma 4 E2B / E4B** phát hành 02/04/2026, Apache-2.0, hơn 140 ngôn ngữ, nhận ảnh và âm thanh. LiteRT-LM có API Swift chính thức với Metal và API Kotlin với GPU/NPU. LiteRT-LM hỗ trợ constrained decoding cho tool calling.
- **Apple Foundation Models** có tiếng Việt, có guided generation và tool calling, miễn phí và không phải tải. Nhược điểm là chỉ có trên iOS, chỉ chạy trên máy có Apple Intelligence và người dùng phải bật, phiên bản model đổi theo iOS nên kết quả eval trôi theo, và có guardrail có thể chặn nội dung sơ cứu. Nhược điểm cuối là giả thuyết, phải thử.

Số đo LiteRT-LM công bố, backend GPU:

| Model | Thiết bị | Prefill tok/s | Decode tok/s | Bộ nhớ |
|---|---|---|---|---|
| Gemma 4 E2B | iPhone 17 Pro | 2.878 | 57 | n/a |
| Gemma 4 E2B | Galaxy S26 Ultra | 3.808 | 52 | n/a |
| Gemma 4 E4B | iPhone 17 Pro | 1.189 | 25 | 3.380 MB |
| Gemma 4 E4B | Galaxy S26 Ultra | 1.293 | 22 | 710 MB |

Các số này đo trên máy đời 2025–2026. GPU của A19 Pro có neural accelerator mà A17 Pro trên iPhone 15 Pro không có, nên 15 Pro sẽ chậm hơn nhiều. Chậm bao nhiêu thì phải đo, đây là việc tuần đầu tiên.

### 2.2 Quyết định

> **Cập nhật 27/09/2026 sau benchmark (`docs/03_Benchmark_Chon_Model.md`):** mặc định đổi sang **Gemma 4 E4B**. File `.litertlm` của E2B chỉ đạt 32,9% trên LiteRT-LM, E4B đạt 88,6%. Qwen3.5 bị loại. Các gạch đầu dòng bên dưới là quyết định cũ, giữ lại để đối chiếu.

- **Mặc định: Gemma 4 E2B qua LiteRT-LM.** Một file `.litertlm` dùng cho cả hai nền tảng. Tokenizer, chat template và sampling giống nhau, nên golden set chạy một lần cho ra kết quả so sánh được giữa iOS và Android.
- **Máy 12 GB: cho chọn E4B** trong cài đặt. Không bật mặc định cho iPhone 15 Pro 8 GB vì 3,4 GB bộ nhớ GPU sát giới hạn jetsam.
- **Qwen3.5-4B / 2B: ứng viên đối chứng** qua adapter llama.cpp (GGUF). Nếu thắng bake-off thì đổi, vì code chỉ phụ thuộc protocol `LocalLanguageModel`.
- **Apple Foundation Models: backend thử nghiệm trên iOS**, không nằm trong MVP.
- **Máy RAM thấp: chế độ chỉ tra cứu.** Tìm kiếm, cẩm nang, thẻ khẩn cấp và SOS vẫn chạy đủ.

Mình nghiêng về Gemma không phải vì chắc nó giỏi tiếng Việt hơn Qwen. Qwen có lợi thế tiếng châu Á và có thể thắng về chất lượng. Lý do là Gemma có đường chạy tối ưu, có số đo công khai trên cả iOS và Android, và dùng chung một file. Qwen3.5 trên điện thoại hiện chưa có con số nào. Bake-off sẽ trả lời câu hỏi chất lượng.

### 2.3 Bake-off (tuần 1–2)

- Dữ liệu: 300 câu hỏi tiếng Việt từ golden set, **cố định evidence** để chỉ so model.
- Chỉ số: grounded action precision, tỷ lệ output đúng định dạng, calibration khi thiếu căn cứ, độ tự nhiên tiếng Việt do người chấm, TTFT, tok/s, bộ nhớ đỉnh, nhiệt sau 30 phút.
- Máy đo: iPhone 15 Pro, một iPhone đời mới, Pixel 9 hoặc 10, Galaxy Snapdragon 8 Gen 3 trở lên, một máy Android tầm trung 8 GB.
- Luật chọn: giữ Gemma 4 E2B trừ khi Qwen3.5 hơn ít nhất 5 điểm grounded precision **và** TTFT p95 vẫn đạt SLO trên iPhone 15 Pro.
- Tắt thinking mode cho mọi câu trả lời. Token suy luận làm TTFT tăng mà người dùng không đọc.
- Nếu tỷ lệ đúng định dạng dưới 98%, fine-tune LoRA nhỏ cho định dạng, sau khi đã có golden set.

## 3. Runtime chung cho hai nền tảng

```
                 ┌──────────── ResQCore (Swift ⇄ Kotlin, logic giống hệt) ────────────┐
câu hỏi ──► QueryNormalizer ► RiskRouter ─┬─► EmergencyCard (hiện ngay, không cần AI)   │
                                          ├─► FTS5 (BM25)  ─┐                           │
                                          └─► Embedder ► DenseIndex ─► HybridFuser (RRF)│
                                                                        ► ContextSelector
                                                                        ► ConfidenceGate
                                                                        ► PromptBuilder
                                                   LocalLanguageModel ◄─┘
                                                   (stream) ► AnswerParser ► GroundingValidator
                 └────────────────────────────────────────────────────────────────────┘
Port nền tảng:   SQLite FTS5 │ LiteRT embedder │ LiteRT-LM │ Knowledge Pack │ DeviceSnapshot
```

| Thành phần | iOS | Android |
|---|---|---|
| LLM | LiteRT-LM Swift, backend GPU (Metal) | LiteRT-LM Kotlin, backend GPU, thử NPU trên Snapdragon |
| Embedding | e5-small .tflite trên LiteRT | cùng file |
| FTS5 | SQLite hệ thống | **Nhúng SQLite riêng có FTS5** |
| Dense scan | Vòng lặp Swift, chuyển sang vDSP nếu p95 > 60 ms | Vòng lặp Kotlin, chuyển sang NEON qua NDK nếu p95 > 60 ms |
| Bộ nhớ | Entitlement `com.apple.developer.kernel.increased-memory-limit` | Theo dõi `onTrimMemory`, nhả model khi bị yêu cầu |
| Tải model sau khi cài | Background Assets | Play Asset Delivery hoặc AI pack của Google Play |
| STT | Nhận dạng giọng nói trên máy của hệ điều hành | `SpeechRecognizer` trên máy, cần gói tiếng Việt offline |
| TTS | `AVSpeechSynthesizer`, giọng tiếng Việt | `TextToSpeech`, cần gói tiếng Việt offline |

Hai dòng tải model cần xác minh lại giới hạn dung lượng và cách phân phối lúc triển khai. Model không nằm trong gói cài đặt. App tải model khi còn Wi-Fi, trong màn hình "Chuẩn bị trước chuyến đi".

Phân tầng thiết bị, đã code trong `DevicePolicy.swift`. Ngưỡng tính theo RAM hệ điều hành báo, thấp hơn con số quảng cáo:

| Hệ điều hành báo | Hạng máy | Tier | Model |
|---|---|---|---|
| ≥ 9,5 GiB | 12 GB | large | E4B tuỳ chọn, E2B mặc định cho tới khi bake-off xong |
| ≥ 6,5 GiB | 8 GB | standard | E2B |
| thấp hơn | 6 GB trở xuống | searchOnly | Không AI. Mở E2B cho máy 6 GB nếu benchmark đạt |

## 4. Độ trễ: tính lại TTFT

TTFT ≈ số token chưa có trong cache ÷ tốc độ prefill + thời gian retrieval.

| Prompt | v0.2 | v0.3 |
|---|---|---|
| System contract | 250–400, tính mỗi lần | ~300, **cache prefix**, chỉ tính lần đầu |
| Câu hỏi + trạng thái | 100–250 | ~150 |
| Evidence | 1.500–2.400 | 1.100–1.300 |
| Tổng phải prefill | ~2.000–3.000 | ~1.300–1.450 |

Với E2B ở ~2.900 tok/s (iPhone 17 Pro), 1.400 token mất khoảng 0,5 giây. Nếu iPhone 15 Pro chậm gấp ba thì khoảng 1,4 giây, vẫn trong cam kết 1,2–1,8 giây của BA. Với Qwen3.5-4B, compute prefill mỗi token cỡ gấp đôi E2B, lại chưa có số đo trên điện thoại. Ước lượng của mình là nó khó đạt 1,8 giây với prompt 2,5K.

Dù model nào thắng, UX không được phụ thuộc vào TTFT:

1. Khoảng 0,1 giây: thẻ khẩn cấp nếu router nhận ra tình huống nguy cấp.
2. Khoảng 0,15 giây: các nguồn tìm được hiện thành thẻ, bấm vào đọc được ngay.
3. Sau đó: AI viết từng dòng, mỗi ý có nhãn nguồn.

`PipelineEvent` trong `RAGPipeline.swift` là hợp đồng cho thứ tự này. Prototype mô phỏng đúng trình tự và thời gian.

## 5. Thay đổi phần RAG

### 5.1 Tiếng Việt trong FTS5

- **Chữ "đ".** `unicode61 remove_diacritics 2` bỏ dấu thanh nhưng giữ nguyên "đ", nên "duong" không khớp "đường". Pack builder phải tự ghi cột folded bằng đúng hàm `QueryNormalizer.fold`: NFD, bỏ combining mark, đổi đ→d. Query dùng cùng hàm đó.
- **Hai cột.** Một cột có dấu, một cột đã fold. Người gõ có dấu thì cột có dấu được weight cao hơn, để "má" không lẫn với "ma", "mà", "mã".
- **Stopword so theo dạng có dấu.** Nếu fold trước thì "lá" thành "la" và bị xoá như từ "là". Test `testStopwordsMatchedOnAccentedForm` bắt lỗi này.
- **Bigram âm tiết.** Từ tiếng Việt thường có hai âm tiết. Thêm cột bigram ("ran can", "ha than nhiet") và truy vấn cả phrase lẫn từ đơn.
- **Router cũng theo quy tắc có dấu.** Fold xong thì "nằm" trùng "nấm", "dao" trùng "đảo". Router so khớp có dấu nếu câu hỏi có dấu, chỉ so bản fold khi người dùng gõ không dấu. Test `testAccentedTextAvoidsFoldedCollisions` bắt lỗi này.
- **Android.** Nhúng một bản SQLite có FTS5, không dựa vào SQLite của hệ điều hành.

### 5.2 Embedding

- Giữ multilingual-e5-small cho MVP. Spec quên một chi tiết của e5: query phải có tiền tố `query: ` và passage phải có `passage: `. Thiếu tiền tố thì recall giảm mà không báo lỗi gì.
- Chạy cùng một file `.tflite` trên LiteRT ở cả hai nền tảng thay vì Core ML trên iOS. Như vậy vector gần như giống hệt và golden set dense dùng chung được.
- Đưa EmbeddingGemma-300M vào ablation như ứng viên thứ hai. Model này làm cho on-device và chạy trên LiteRT.

### 5.3 Vector INT8

INT8 với một scale Float cho mỗi hàng, vector đã L2-normalize. 30k chunk × 384 chiều chiếm 11,5 MB thay vì 23 MB, đọc bằng mmap. Kotlin không có phép tính FP16 nhanh nên FP16 sẽ chậm trên Android. Thêm ablation FP16 vs INT8 và ghi Recall@8 vào release gate.

### 5.4 Chọn context

Đã code trong `ContextSelector.swift`:

- Gom theo parent, lấy điểm cao nhất của từng parent.
- Tối đa 2 khối mỗi bài, bỏ khối gần trùng (Jaccard trigram âm tiết ≥ 0,8).
- Câu hỏi critical: giữ một chỗ cho warning/contraindication tốt nhất, kể cả khi điểm thấp.
- Câu hỏi critical: xếp khối Tier A/B trước, Tier C chỉ lấp chỗ còn trống và không bao giờ đứng một mình. Bản đầu tiên mình viết chỉ kiểm tra "đã có một khối tin cậy chưa" và để Tier C chiếm chỗ của một khối Tier A. Test đã bắt được lỗi đó.
- Nhãn trích dẫn ngắn E1…En thay cho ID nội bộ. Ít token hơn, và model khó bịa ra một nhãn không có trong prompt.

### 5.5 Định dạng output theo dòng

```
TRANG_THAI: CO_CAN_CU | KHONG_DU_CAN_CU | MAU_THUAN
TOM_TAT: ...
LAM_NGAY:
- ... [E1]
KHONG_DUOC:
- ... [E3]
CAP_CUU: ... [E2]
```

`AnswerParser` chỉ nhận dòng đã hoàn chỉnh, nên giao diện không bao giờ hiện nửa nhãn trích dẫn. Nếu model bị cắt ở giới hạn token thì các dòng trước đó vẫn dùng được. `GroundingValidator` xử lý như sau:

- Bỏ nhãn không có trong evidence.
- Bỏ ý hành động không có nguồn nếu câu hỏi critical.
- Hạ trạng thái xuống "không đủ căn cứ" nếu không còn ý nào.
- Thay số điện thoại do model sinh ra. Số khẩn cấp chỉ lấy từ dữ liệu có cấu trúc của thẻ. Bộ lọc không đụng vào "100°C".

### 5.6 Giữ nguyên từ v0.2

RRF k=60 và bộ boost, multi-turn bằng conversation state nhỏ, cache LRU cho query embedding, eval harness, danh sách ablation.

## 6. Ảnh: chỉ mô tả, không phán quyết

Gemma 4 E4B nhận ảnh, nên tính năng chụp ảnh không cần thêm model. Benchmark 20 ảnh ở `docs/03` mục 9: E4B trên LiteRT đạt 90%, trả lời "không ăn" cho cả 7 ảnh nấm, không gọi tên loài lần nào. Chính sách:

1. Model chỉ mô tả đặc điểm nhìn thấy: dáng mũ, màu, vòng cổ, bao gốc, nơi mọc.
2. Đặc điểm đó thành câu truy vấn retrieval. Kết luận đến từ quy tắc trong cẩm nang.
3. App **không bao giờ** nói một loài nấm hay cây là ăn được dựa trên ảnh. Với nấm, câu trả lời luôn là không ăn.
4. Giao diện ghi rõ "mô tả, không phải nhận dạng loài".

Mockup hiện tại cho thấy vì sao cần luật này. Ảnh là nấm có màng lưới trắng, mockup gọi là *Phallus indusiatus* rồi nói nó chứa amatoxin gây suy gan. *Phallus indusiatus* (nấm tre, nấm lưới) là loài ăn được và không chứa amatoxin. Amatoxin và phalloidin thuộc chi *Amanita*. Kết luận "đừng ăn" tình cờ an toàn, nhưng lý do sai hoàn toàn. Model 2–4B sẽ bịa kiểu này nếu được phép nhận dạng loài.

## 7. Giọng nói

- MVP dùng nhận dạng giọng nói trên máy của hệ điều hành và TTS có sẵn. Màn "Chuẩn bị trước chuyến đi" kiểm tra đã có gói tiếng Việt offline chưa.
- Mockup ghi "Whisper cục bộ". Nếu STT của hệ điều hành kém với tiếng Việt, phương án B là PhoWhisper chạy qua whisper.cpp, cùng code cho hai nền tảng. Gemma 4 E2B cũng nhận âm thanh, đáng thử nhưng tốn RAM hơn.

## 8. Nội dung và pháp lý

Đây là phần rủi ro nhất của dự án, lớn hơn phần kỹ thuật.

**Bản quyền.** BA ghi nguồn gồm SAS Survival Handbook. Sách này có bản quyền, không đóng gói vào app được nếu không mua license. US Army FM 21-76 và bản thay thế FM 3-05.70 là tài liệu của chính phủ Mỹ, thuộc phạm vi công cộng, dùng được. Nội dung y tế nên lấy từ Bộ Y tế, WHO, IFRC, và phải kiểm tra license từng nguồn. Schema đã có cột `license`, cần bắt buộc điền.

**Nội dung sai hoặc nguy hiểm tìm thấy trong tài liệu hiện có:**

| Chỗ | Vấn đề | Đề xuất |
|---|---|---|
| Mockup, nấm | Nhận nhầm loài, gán độc tố sai (mục 6) | Không nhận dạng loài từ ảnh |
| BA, trụ cột Lửa | "Đánh lửa bằng pin điện thoại". Chọc thủng pin lithium dễ gây cháy nổ, và người dùng mất luôn thiết bị liên lạc | Bỏ. Mẹo đúng là pin AA hoặc 9V với bùi nhùi thép |
| BA, trụ cột Nước | "Đun sôi lăn tăn 3–5 phút". Lăn tăn là chưa sôi hẳn | Sôi sùng sục ít nhất 1 phút, trên 2.000 m thì 3 phút |
| BA, sơ đồ lọc | "Than củi hấp phụ kim loại nặng". Than bếp không phải than hoạt tính | Nói đúng mức: giảm mùi và cặn, không diệt vi khuẩn, không khử kim loại |
| BA, sơ cứu rắn cắn | "Quấn băng đàn hồi" viết như quy tắc chung. Theo hiểu biết của mình, băng ép bất động chỉ khuyến cáo cho rắn hổ (thần kinh), không cho rắn lục vì làm nặng tổn thương tại chỗ. Việt Nam có cả hai loại | Viết thành decision rule, để bác sĩ duyệt |
| BA + slide | Universal Edibility Test trình bày như công cụ chính | Chỉ là phương án cuối cùng, mất hơn 24 giờ, không dùng cho nấm |

Mọi nội dung sơ cứu trong prototype và code mẫu đều gắn nhãn "nội dung mẫu, chờ duyệt". Phải có chuyên gia y tế ký duyệt trước beta.

## 9. Mâu thuẫn giữa tài liệu BA và spec kỹ thuật

| Mục | BA | Spec v0.2 | Chốt |
|---|---|---|---|
| Thiết bị | iPhone 15 Pro, iOS 17 | iPhone 15 Pro | iOS 17+ và Android 12+, phân tầng theo RAM |
| Tra cứu p50 | < 40 ms | ≤ 120 ms | ≤ 120 ms p50, ≤ 250 ms p95 |
| TTFT | 1,2–1,8 s | Không nêu | p50 ≤ 1,8 s trên iPhone 15 Pro, đo sau bake-off |
| Dung lượng | ≤ 3,5 GB | 4B 3,06 + 2B 1,75 GB | ~2,95 GB (E2B + embedding + pack) |
| Pin yếu | Chuyển sang 2B | Chuyển sang 2B | Rút ngắn câu trả lời, tắt AI dưới 10% |
| Grounding | "Huấn luyện cổng kiểm duyệt" | Validator deterministic | Validator deterministic, không huấn luyện |
| Độ tin cậy | "100% có cơ sở thực nghiệm" | Release gates | Release gates, không dùng câu cam kết không đo được |
| GPS | "Không có GPS ổn định" | Không nêu | GPS chạy không cần sóng di động, chỉ lâu có fix lần đầu |
| Lộ trình | 12 tuần gồm 500 kỹ năng | 100–200 bài curated | 12 tuần chỉ đủ cho ~150 bài đã duyệt y tế. 500 bài là mục tiêu sau |

## 10. Release gates bổ sung

- RG-11: Bộ test conformance (`ios/ResQKit/Tests`) pass 100% trên cả Swift lẫn Kotlin.
- RG-12: Cùng golden set, top-8 chunk ID giữa iOS và Android trùng ≥ 99%.
- RG-13: TTFT p50 ≤ 1,8 s, p95 ≤ 3 s trên iPhone 15 Pro và một máy Android 8 GB tham chiếu.
- RG-14: Thẻ khẩn cấp hiện trong ≤ 300 ms kể cả khi model chưa nạp.
- RG-15: Không câu trả lời nào có ảnh đầu vào khẳng định một loài ăn được.
- RG-16: Recall@8 của vector INT8 không thấp hơn FP16 quá 0,5 điểm.
- RG-17: Mọi nội dung critical có chữ ký duyệt y tế và license hợp lệ.
- RG-18: E4B chạy trên iPhone 15 Pro và một máy Android 8 GB tham chiếu đạt RG-13, không bị hệ điều hành kill sau 30 phút dùng liên tục, và bộ nhớ đỉnh dưới 70% giới hạn của app, kể cả khi đang xử lý ảnh. Nếu trượt, máy 8 GB chuyển sang chế độ chỉ tra cứu. **Kết quả 27/09/2026:** trượt trên OPPO CPH2637 (Dimensity 6300), token đầu 42 s (`docs/03` mục 10). Đã thêm cổng đo tốc độ thật `ModelSpeed` vào `DevicePolicy`.
- RG-19: Model đang dùng đạt ≥ 80% tỷ lệ đạt trên benchmark `bench/` (golden set khi có) và 0% lời khuyên nguy hiểm trong LAM_NGAY.

## 11. Lộ trình điều chỉnh

1. Tuần 1–2: benchmark trên máy thật (E2B, E4B, Qwen3.5-2B/4B) và bake-off. Port `ResQCore` sang Kotlin kèm test.
2. Tuần 1–6, chạy song song: biên tập và duyệt y tế 150 bài đầu, thẻ khẩn cấp, alias tiếng Việt.
3. Tuần 3–5: pack builder (chunker, cột fold, bigram, embedding, INT8, ký manifest), FTS5 trên hai nền tảng.
4. Tuần 5–8: tích hợp LiteRT-LM, evidence-first UI, SOS, chuẩn bị chuyến đi.
5. Tuần 8–10: eval, tune weight và ngưỡng, kiểm tra nhiệt và bộ nhớ.
6. Tuần 10–12: thử thực địa, beta TestFlight và Play internal testing.

## 12. Nguồn đã kiểm tra (27/09/2026)

- LiteRT-LM overview, danh sách model và bảng benchmark: https://developers.google.com/edge/litert-lm/overview
- LiteRT-LM Swift API: https://developers.google.com/edge/litert-lm/swift
- Gemma 4 E4B trên LiteRT-LM, benchmark iPhone 17 Pro và S26 Ultra: https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
- Gemma 4 cho edge: https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/
- Qwen3.5 small models: https://www.therundown.ai/tools/qwen3-5-small và https://unsloth.ai/docs/models/qwen3.5
- Qwen3.6 (chỉ 27B và 35B-A3B): https://unsloth.ai/docs/models/qwen3.6
- Apple Foundation Models thế hệ 3 và ngôn ngữ hỗ trợ: https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models
- Apple Intelligence, danh sách ngôn ngữ: https://www.apple.com/newsroom/2026/06/apple-intelligence-brings-powerful-ai-capabilities-into-everyday-experiences/
