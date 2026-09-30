#!/usr/bin/env python3
"""Model bake-off on a desktop, through Ollama.

Same prompt the app sends (PromptBuilder.systemContract + evidence blocks), fixed evidence per case,
thinking off. Records every streamed delta with its timestamp so the scorer can replay the stream
through the real Swift AnswerParser, and so time-to-first-action can be measured.

    python3 bench/run.py --models gemma4:e2b-it-qat qwen3.5:2b-q4_K_M --runs 3
"""
import argparse, json, re, subprocess, threading, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OLLAMA = "http://127.0.0.1:11434"
OPTIONS = dict(num_ctx=4096, num_predict=512, temperature=0.2, top_p=0.9, top_k=40,
               repeat_penalty=1.0, presence_penalty=0.0, min_p=0.0)


def system_contract(version="v0"):
    """v0 = the prompt shipped in PromptBuilder.swift; others live in bench/prompts/."""
    if version != "v0":
        return (ROOT / f"prompts/{version}.txt").read_text().strip()
    src = (ROOT.parent / "ios/ResQKit/Sources/ResQCore/PromptBuilder.swift").read_text()
    body = re.search(r'systemContract = """\n(.*?)\n\s*"""', src, re.S).group(1)
    return "\n".join(l[4:] if l.startswith("    ") else l for l in body.split("\n"))


# v2: same system prompt as v1 plus a format reminder right after the question (recency helps small models).
REMINDER = {"v2": "\n\nTrả lời bằng các dòng TRANG_THAI, TOM_TAT, LAM_NGAY, KHONG_DUOC, CAP_CUU như ví dụ."}


def user_prompt(case, evidence, version="v0"):
    state = case.get("state", {})
    parts = []
    if state.get("subject"): parts.append(f"chủ đề: {state['subject']}")
    if state.get("environment"): parts.append(f"môi trường: {state['environment']}")
    if state.get("constraints"): parts.append("đồ đang có: " + ", ".join(state["constraints"]))
    out = f"BỐI CẢNH: {'; '.join(parts)}\n" if parts else ""
    for i, bid in enumerate(case["blocks"], 1):
        b = evidence[bid]
        out += f"[E{i} | {b['source']} | {b['heading']}]\n{b['text']}\n\n"
    return out + f"CÂU HỎI: {case['q']}" + REMINDER.get(version, "")


def phys_footprint(pid):
    """(current, lifetime max) physical footprint in bytes: the number iOS jetsam uses. macOS only."""
    import ctypes
    buf = (ctypes.c_uint64 * 42)()
    libc = ctypes.CDLL("/usr/lib/libproc.dylib")
    if libc.proc_pid_rusage(int(pid), 4, ctypes.byref(buf)) != 0:  # RUSAGE_INFO_V4
        return 0, 0
    fields = buf[2:]  # skip the 16-byte uuid
    return fields[7], fields[28]


def llama_server_pid():
    out = subprocess.run(["pgrep", "-f", "llama-server"], capture_output=True, text=True).stdout.split()
    return out[-1] if out else None


def post(path, payload, stream=False):
    req = urllib.request.Request(OLLAMA + path, json.dumps(payload).encode(), {"Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=600) if stream else json.load(urllib.request.urlopen(req, timeout=600))


class RSSSampler(threading.Thread):
    """Peak resident memory of the Ollama model runner (weights are mmapped, so this includes them once touched)."""
    def __init__(self):
        super().__init__(daemon=True); self.peak = 0; self.stop = False

    def run(self):
        while not self.stop:
            out = subprocess.run(["ps", "-axo", "rss=,command="], capture_output=True, text=True).stdout
            rss = sum(int(l.split(None, 1)[0]) for l in out.splitlines() if "llama-server" in l or ("ollama" in l and "runner" in l))
            self.peak = max(self.peak, rss * 1024)
            time.sleep(0.25)


def chat(model, system, user, seed, keep_alive="10m"):
    t0 = time.perf_counter()
    deltas, ttft, thinking, final = [], None, 0, {}
    payload = dict(model=model, stream=True, think=False, keep_alive=keep_alive,
                   options=dict(OPTIONS, seed=seed),
                   messages=[{"role": "system", "content": system}, {"role": "user", "content": user}])
    with post("/api/chat", payload, stream=True) as r:
        for line in r:
            ev = json.loads(line)
            msg = ev.get("message", {})
            if msg.get("thinking"): thinking += len(msg["thinking"])
            c = msg.get("content", "")
            if c:
                now = time.perf_counter() - t0
                if ttft is None: ttft = now
                deltas.append([round(now, 4), c])
            if ev.get("done"): final = ev
    return dict(deltas=deltas, ttft=ttft, total=time.perf_counter() - t0, thinking_chars=thinking,
                prompt_tokens=final.get("prompt_eval_count"), prompt_ns=final.get("prompt_eval_duration"),
                gen_tokens=final.get("eval_count"), gen_ns=final.get("eval_duration"),
                load_ns=final.get("load_duration"), done_reason=final.get("done_reason"))


def unload_all():
    for m in json.load(urllib.request.urlopen(OLLAMA + "/api/ps")).get("models", []):
        post("/api/generate", {"model": m["name"], "keep_alive": 0})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", nargs="+", required=True)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--prompt", default="v0")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    cases = json.loads((ROOT / "data/cases.json").read_text())
    evidence = json.loads((ROOT / "data/evidence.json").read_text())
    system = system_contract(args.prompt)
    out = Path(args.out or ROOT / f"results/raw_{args.prompt}.jsonl"); out.parent.mkdir(parents=True, exist_ok=True)
    meta_path = out.with_name("models.jsonl")

    for model in args.models:
        unload_all(); time.sleep(2)
        sampler = RSSSampler(); sampler.start()
        # Cold load + first prefill of the system prompt (what the user feels on the first question).
        cold = chat(model, system, user_prompt(cases[0], evidence, args.prompt), seed=0)
        loaded = json.load(urllib.request.urlopen(OLLAMA + "/api/ps")).get("models", [])
        for run in range(args.runs):
            for case in cases:
                r = chat(model, system, user_prompt(case, evidence, args.prompt), seed=run + 1)
                r.update(model=model, prompt=args.prompt, run=run, case=case["id"], critical=case["critical"],
                         labels=[f"E{i}" for i in range(1, len(case["blocks"]) + 1)])
                with out.open("a") as f: f.write(json.dumps(r, ensure_ascii=False) + "\n")
                print(f"{model} run{run} {case['id']:<24} ttft={r['ttft'] or 0:.2f}s total={r['total']:.1f}s "
                      f"tok={r['gen_tokens']}", flush=True)
        sampler.stop = True; sampler.join()
        pid = llama_server_pid()
        footprint = phys_footprint(pid)[1] if pid else 0
        with meta_path.open("a") as f:
            f.write(json.dumps(dict(model=model, prompt=args.prompt, cold_total=cold["total"], cold_ttft=cold["ttft"],
                                    cold_load_s=(cold["load_ns"] or 0) / 1e9, peak_rss=sampler.peak, peak_footprint=footprint,
                                    ps=[{k: m.get(k) for k in ("name", "size", "size_vram", "context_length")}
                                        for m in loaded])) + "\n")
    unload_all()


if __name__ == "__main__":
    main()
