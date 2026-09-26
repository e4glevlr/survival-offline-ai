# ResQKit: lõi RAG và UI tham chiếu (Swift → Kotlin)

```
ResQKit/
├── Sources/ResQCore/      Swift thuần (Foundation), port 1:1 sang Kotlin
│   ├── Models.swift            ChunkMeta, ParentBlock, EmergencyCard, Route, EvidenceBlock
│   ├── QueryNormalizer.swift   NFC, bỏ dấu + đ→d, stopword theo dạng có dấu, bigram âm tiết, alias
│   ├── RiskRouter.swift        Rule-based routing, so khớp có dấu nếu người dùng gõ có dấu
│   ├── HybridFuser.swift       RRF + boost metadata + filter vùng/hết hạn
│   ├── DenseIndex.swift        Exact top-K trên vector INT8 + scale theo hàng (mmap)
│   ├── ContextSelector.swift   Gom theo parent, giữ chỗ cho warning, Tier C chỉ lấp chỗ trống
│   ├── PromptBuilder.swift     System contract cố định (cache được) + evidence nhãn E1…En
│   ├── AnswerParser.swift      Parser stream theo dòng (không dùng JSON)
│   ├── GroundingValidator.swift  Bỏ ý thiếu nguồn, bỏ nhãn tự chế, che số điện thoại
│   ├── DevicePolicy.swift      Chọn tier theo RAM; tiết kiệm pin = rút ngắn, không đổi model
│   ├── SOSSignals.swift        Nhịp Morse SOS, định dạng toạ độ
│   ├── SunCalculator.swift     Giờ mặt trời mọc/lặn cho ô "Ánh sáng còn lại" (khớp bản JS đến từng giây)
│   └── RAGPipeline.swift       Điều phối + các "port" nền tảng + PipelineEvent
├── Sources/ResQUI/        SwiftUI tham chiếu cho design/resq_prototype.html
│   ├── Theme.swift             Token 3 giao diện (Tối, Nắng, Nhìn đêm), font, motion, surface
│   ├── ChatViewModel.swift     Nhận PipelineEvent và dựng từng lượt trả lời
│   ├── AnswerComponents.swift  EmergencyPassView (bấm từng bước), AnswerSection, SourcesStrip, Tag
│   ├── ChatScreen.swift        Header, bảng điều khiển thực địa, danh sách tin nhắn, composer kính mờ
│   ├── SOSScreen.swift         Toạ độ + radar, giữ để bật đèn/còi, thanh Morse, số khẩn cấp
│   └── DemoResponder.swift     Dữ liệu giả lập + #Preview
└── Tests/ResQCoreTests/   Bộ test conformance: port sang JUnit, hai app phải cho kết quả giống hệt
```

## Chạy

```bash
swift test                    # 28 test lõi
swift build                   # macOS
xcodebuild -scheme ResQKit-Package -destination 'generic/platform=iOS Simulator' build
```

Mở `Package.swift` bằng Xcode để xem `#Preview("Chat")`, `#Preview("SOS")`, `#Preview("Emergency pass")`.

## Hệ thiết kế

Nguồn gốc là `design/resq_prototype.html`. Token CSS, `ResQPalette` (Swift) và `ResQColors` (Kotlin) dùng cùng tên.

| Nhóm | Token | Ghi chú |
|---|---|---|
| Nền | `bg`, `surface1…3` | Graphite ấm, không dùng đen tuyệt đối trừ chế độ Nhìn đêm |
| Viền | `hair`, `hair2`, `highlight` | Mọi thẻ có viền 1px + ánh sáng 1px ở mép trên (`surface()` trong Swift) |
| Chữ | `text`, `text2`, `text3` | Ba cấp, không thêm cấp thứ tư |
| Nhấn | `accent` | Cam cứu hộ, chỉ dùng cho logo, trạng thái chọn, vòng cung mặt trời |
| Ngữ nghĩa | `red`, `green`, `amber`, `blue` + bản `Soft` | Màu hệ thống iOS; Android dùng cùng mã hex |
| Thẻ khẩn cấp | `passTop`, `passBottom`, `passLine` | Gradient đỏ sẫm kiểu Wallet pass |
| Chữ số | `ResQFont.number()` | Monospaced, tabular. Chữ tiếng Việt không dùng mono |
| Chuyển động | `ResQMotion.spring`, `.ease` | Khớp `--spring`, `--ease` trong CSS |

Ba giao diện: Tối (mặc định), Nắng (tương phản cao ngoài trời), Nhìn đêm (toàn đỏ, không glow). Nút chạm tối thiểu 44 pt.

Hiệu ứng chỉ có trong prototype, cần làm khi code thật:

| Hiệu ứng | iOS | Android |
|---|---|---|
| Chữ AI hiện từng từ, mờ sang rõ | `TextRenderer` (iOS 18) | `AnimatedContent` hoặc alpha theo từng span |
| Sheet kéo xuống để đóng | `.sheet` + `presentationDetents` | `ModalBottomSheet` |
| Shell trượt sang khi mở menu | `offset` + `scaleEffect` trên root | `Modifier.graphicsLayer` |
| Rung phản hồi | `.sensoryFeedback` | `HapticFeedbackConstants` |

## Bảng chuyển sang Kotlin

| Swift | Kotlin / Android |
|---|---|
| `struct … : Sendable, Equatable` | `data class` |
| `enum RiskLevel: Int` | `enum class RiskLevel(val level: Int)` |
| `enum PipelineEvent` (có associated value) | `sealed interface PipelineEvent` |
| `AsyncThrowingStream<PipelineEvent, Error>` | `Flow<PipelineEvent>` (`flow { emit(...) }`) |
| `async let` (BM25 và embedding song song) | `coroutineScope { async { … } }` |
| `Task.checkCancellation()` | `ensureActive()` |
| `@Observable final class ChatViewModel` | `ViewModel` + `StateFlow<List<ChatMessage>>` |
| `String.decomposedStringWithCanonicalMapping` | `Normalizer.normalize(s, Normalizer.Form.NFD)` |
| Lọc scalar `0x0300…0x036F` | `.replace(Regex("\\p{Mn}+"), "")` rồi thay `đ→d`, `Đ→D` |
| `precomposedStringWithCanonicalMapping` | `Normalizer.Form.NFC` |
| `NSRegularExpression` | `Regex` (cú pháp pattern giữ nguyên) |
| `Data(contentsOf:options:.alwaysMapped)` | `FileChannel.map(READ_ONLY)` → `ByteBuffer` |
| Vòng lặp dot product | Giữ vòng lặp Kotlin; nếu p95 > 60 ms thì dùng kernel NEON qua NDK |
| SwiftUI `View` | `@Composable` với cùng tên component |
| `ResQPalette` + `EnvironmentValues.palette` | `ResQColors` + `CompositionLocal` |
| `fullScreenCover` (SOS) | Route riêng trong `NavHost`, không dùng bottom sheet |
| `onLongPressGesture(minimumDuration: 0.65)` (giữ để bật) | `detectTapGestures(onLongPress=…)` + `Animatable` cho thanh tiến độ |
| `matchedGeometryEffect` (segmented) | `animateDpAsState` cho offset của pill |
| `.ultraThinMaterial` | `Modifier.blur` trên nền (API 31+) hoặc màu `glass` đặc |
| `AVCaptureDevice.torchMode` | `CameraManager.setTorchMode(cameraId, on)` |
| `Link("tel:115")` | `Intent(Intent.ACTION_DIAL, Uri.parse("tel:115"))` |

## Phần phải viết riêng cho từng nền tảng (các protocol trong `RAGPipeline.swift`)

| Port | iOS | Android |
|---|---|---|
| `LexicalRetriever` | SQLite hệ thống (có FTS5) | **Nhúng SQLite riêng** (bản build có FTS5), vì SQLite của Android không chắc có FTS5 |
| `QueryEmbedder` | LiteRT (.tflite), cùng file với Android | LiteRT (.tflite) |
| `LocalLanguageModel` | LiteRT-LM Swift API, backend GPU (Metal) | LiteRT-LM Kotlin API, backend GPU, thử NPU |
| `KnowledgeStore` | Đọc gói tri thức (SQLite read-only + `vectors.bin`, `scales.bin`) | như iOS |
| `DeviceSnapshot` | `ProcessInfo.physicalMemory`, `thermalState`, `UIDevice.batteryLevel` | `ActivityManager.MemoryInfo.totalMem`, `PowerManager.currentThermalStatus`, `BatteryManager` |

## Quy tắc khi port

1. Port test trước, rồi mới port code, và giữ nguyên đầu vào lẫn giá trị mong đợi.
2. Không "cải tiến" thuật toán ở một bên. Mọi thay đổi ranking phải sửa ở cả hai bên và cập nhật test.
3. Sắp xếp luôn có tie-break theo id (`HybridFuser`, `ContextSelector`) để hai nền tảng cho cùng thứ tự.
