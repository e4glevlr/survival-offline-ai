# bench: chọn model bằng số đo

Benchmark so model cho ResQ trên đúng prompt, đúng parser và đúng validator của app. Kết quả và quyết định nằm trong `docs/03_Benchmark_Chon_Model.md`.

| File | Việc |
|---|---|
| `data/evidence.json` | 27 khối bằng chứng cố định: nguồn, mức tin cậy, heading, nội dung |
| `data/cases.json` | 35 câu hỏi: khối evidence dùng cho câu, trạng thái mong đợi, ý bắt buộc (`must`), ý phải có trong KHONG_DUOC (`must_donot`), lời khuyên cấm (`forbid`). Mẫu so khớp viết không dấu. |
| `data/edge_cases.json` | 14 edge case: prompt injection, đòi in system prompt, tiếng Anh, teencode, một chữ, hai vấn đề một câu, tự xưng bác sĩ đòi liều thuốc, bằng chứng lạc đề, mẹo dân gian, hoảng loạn, nước biển, trấn an sai, ép trả lời một chữ, lạc đề rồi mới hỏi. Chạy: `run.py --cases bench/data/edge_cases.json --out bench/results/edge/raw_v0.jsonl`, chấm: `BENCH_CASES=bench/data/edge_cases.json BENCH_RESULTS=bench/results/edge python3 bench/score.py` |
| `data/user_cases.json`, `data/guide_evidence.json` | 35 câu kiểu người dùng gõ (không dấu, viết tắt, kể lể, chào hỏi, hỏi lại), bằng chứng lấy từ nội dung thật của app. `build_guide_evidence.py` dựng lại bằng chứng, chọn khối cho từng câu và in những câu BM25 trượt bài đúng. Chạy: `run_litert.py --cases bench/data/user_cases.json --evidence bench/data/guide_evidence.json --out bench/results/litert-user/raw_v0.jsonl`, chấm: `BENCH_CASES=bench/data/user_cases.json BENCH_EVIDENCE=bench/data/guide_evidence.json BENCH_RESULTS=bench/results/litert-user python3 bench/score.py` |
| `prompts/` | Các biến thể system prompt. `v0` được đọc thẳng từ `PromptBuilder.swift`. |
| `run.py` | Chạy qua Ollama (llama.cpp), ghi từng delta kèm thời điểm |
| `run_litert.py` | Chạy qua LiteRT-LM, runtime app sẽ dùng. Mỗi model một process để đo bộ nhớ riêng. |
| `Scorer/` | Executable Swift phát lại stream qua `AnswerParser` + `GroundingValidator` |
| `score.py` | Tính tỷ lệ đạt, tốc độ, bộ nhớ. `--compare v0` in khoảng tin cậy bootstrap. |
| `images/` | Bộ 20 ảnh: `manifest.json` (đáp án, câu hỏi, tác giả, giấy phép), `fetch.py` tải ảnh từ Wikimedia Commons về `images/files/` (không commit) |
| `run_images.py`, `score_images.py` | Bước mô tả ảnh, chạy trên Ollama hoặc LiteRT (`--runtime`) |
| `android/` | Chạy trên máy Android qua adb: `runcase.sh` (đo bộ nhớ, nhiệt độ pin), `batch.sh`, `parse_logs.py` chuyển log thành `results/raw_android.jsonl` |
| `results/` | Output thô (`raw_*.jsonl`), `summary.json`, `per_case.json`, `models.jsonl` (bộ nhớ, thời gian nạp) |

Khi thêm câu hỏi, luôn kèm ít nhất một câu thiếu căn cứ hoặc câu đối kháng cho mỗi chủ đề mới. Chạy lại toàn bộ model trước khi đổi model mặc định (RG-19). Lệnh chạy nằm ở mục 8 của `docs/03`.

Kotlin: bộ câu hỏi và cách chấm dùng chung được. Chỉ cần viết lại `run_litert.py` bằng LiteRT-LM Kotlin API để đo trên Android.
