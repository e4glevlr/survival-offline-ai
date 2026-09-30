#!/usr/bin/env python3
"""Turns on-device litert_lm_main logs into bench rows, so score.py grades them like the desktop runs.

    adb pull /data/local/tmp/litert/out /tmp/out
    python3 bench/android/parse_logs.py /tmp/out/e2b_gpu android/gemma4-e2b-gpu
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOISE = re.compile(r"^(INFO|WARNING|VERBOSE|ERROR|[IWEF]\d{4} )")


def parse(log, case):
    text = log.read_text(errors="replace")
    body = "\n".join(l for l in text.splitlines() if not NOISE.match(l))
    q_line = f"CÂU HỎI: {case['q']}"
    start = body.find(q_line)
    end = body.find("\nBenchmarkInfo:")
    output = body[start + len(q_line):end].strip("\n") if start >= 0 and end > start else ""
    num = lambda pat, cast=float: cast(m.group(1)) if (m := re.search(pat, text)) else None
    meta = dict(re.findall(r"(\w+)=(-?\d+)", text.split("RESQ_META", 1)[1])) if "RESQ_META" in text else {}
    prefill_tokens, prefill_s = num(r"Prefill Turn 1: Processed (\d+) tokens", int), num(r"Prefill Turn 1: Processed \d+ tokens in ([\d.]+)s")
    gen_tokens = num(r"Decode Turn 1: Processed (\d+) tokens", int)
    decode_tps, ttft = num(r"Decode Speed: ([\d.]+)"), num(r"Time to first token: ([\d.]+) s")
    # No per-token timestamps from the CLI: place the first action line at TTFT + its token offset / decode speed.
    first_action = None
    m = re.search(r"LAM_NGAY:\s*\n\s*-[^\n]*\n", output)
    if m and gen_tokens and decode_tps and output:
        first_action = ttft + gen_tokens * (m.end() / len(output)) / decode_tps
    return dict(deltas=[[ttft or 0, output]], ttft=ttft, first_action_est=first_action,
                total=(ttft or 0) + (gen_tokens or 0) / (decode_tps or 1),
                prompt_tokens=prefill_tokens, prompt_ns=int(prefill_s * 1e9) if prefill_s else None,
                gen_tokens=gen_tokens, gen_ns=int(gen_tokens / decode_tps * 1e9) if gen_tokens and decode_tps else None,
                done_reason="stop", init_s=(num(r"Init Total: ([\d.]+) ms") or 0) / 1000,
                min_avail_mb=int(meta.get("min_avail_kb", 0)) / 1024, vmhwm_mb=int(meta.get("vmhwm_kb", 0)) / 1024,
                batt_temp_c=int(meta.get("batt_temp_decic", 0)) / 10, rc=int(meta.get("rc", -1)))


def main():
    src, model = Path(sys.argv[1]), sys.argv[2]
    cases = {c["id"]: c for c in json.loads((ROOT / "data/cases.json").read_text())}
    out = ROOT / "results/raw_android.jsonl"
    rows = [json.loads(l) for l in out.read_text().splitlines()] if out.exists() else []
    rows = [r for r in rows if r["model"] != model]
    for log in sorted(src.glob("*.log"), key=lambda p: p.stat().st_mtime):
        if "RESQ_META" not in log.read_text(errors="replace"):
            continue  # still running
        case = cases[log.stem]
        r = parse(log, case)
        r.update(model=model, prompt="v0", run=0, case=case["id"], critical=case["critical"],
                 labels=[f"E{i}" for i in range(1, len(case["blocks"]) + 1)])
        rows.append(r)
    out.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows))
    print(f"{model}: {sum(r['model'] == model for r in rows)} cases")


if __name__ == "__main__":
    main()
