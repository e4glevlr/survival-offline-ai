#!/usr/bin/env python3
"""Photo stage of the bake-off: image + question -> 4-line description (LOAI / DAC_DIEM / TU_KHOA / CANH_BAO).

    python3 bench/run_images.py --runtime ollama --models gemma4:e4b-it-qat --runs 2
    python  bench/run_images.py --runtime litert --models ~/models/litert/gemma-4-E4B-it.litertlm --runs 2
"""
import argparse, base64, json, os, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import OLLAMA, OPTIONS, ROOT, phys_footprint, post, unload_all, llama_server_pid  # noqa: E402

IMAGES = ROOT / "images"
SYSTEM = (ROOT / "prompts/image_v1.txt").read_text().strip()
MAX_OUT = 200


def ollama_ask(model, item, seed):
    b64 = base64.b64encode((IMAGES / "files" / f"{item['id']}.jpg").read_bytes()).decode()
    payload = dict(model=model, stream=True, think=False, keep_alive="10m",
                   options=dict(OPTIONS, seed=seed, num_predict=MAX_OUT),
                   messages=[{"role": "system", "content": SYSTEM},
                             {"role": "user", "content": item["q"], "images": [b64]}])
    t0 = time.perf_counter(); deltas, ttft, final = [], None, {}
    with post("/api/chat", payload, stream=True) as r:
        for line in r:
            ev = json.loads(line); c = ev.get("message", {}).get("content", "")
            if c:
                now = time.perf_counter() - t0
                if ttft is None: ttft = now
                deltas.append([round(now, 4), c])
            if ev.get("done"): final = ev
    return dict(deltas=deltas, ttft=ttft, total=time.perf_counter() - t0,
                prompt_tokens=final.get("prompt_eval_count"), gen_tokens=final.get("eval_count"),
                decode_tps=final["eval_count"] / (final["eval_duration"] / 1e9) if final.get("eval_duration") else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runtime", choices=["ollama", "litert"], required=True)
    ap.add_argument("--models", nargs="+", required=True)
    ap.add_argument("--runs", type=int, default=2)
    args = ap.parse_args()
    items = json.loads((IMAGES / "manifest.json").read_text())
    out = ROOT / "results/img_raw.jsonl"

    for model in args.models:
        if args.runtime == "ollama":
            unload_all(); time.sleep(2)
            name, ask = model, (lambda it, seed: ollama_ask(model, it, seed))
            cold = ask(items[0], 0)
        else:
            import litert_lm
            name = "litert/" + Path(model).stem
            t0 = time.perf_counter()
            engine = litert_lm.Engine(os.path.expanduser(model), backend=litert_lm.Backend.GPU(),
                                      vision_backend=litert_lm.Backend.GPU(), max_num_tokens=4096,
                                      max_num_images=1, enable_benchmark=True,
                                      cache_dir=str(Path.home() / "models/litert/.cache"))
            init_s = time.perf_counter() - t0

            def ask(item, seed, engine=engine):
                conv = engine.create_conversation(
                    system_message=SYSTEM, max_output_tokens=MAX_OUT,
                    thinking_config=litert_lm.ThinkingConfig(enable_thinking=False),
                    sampler_config=litert_lm.SamplerConfig(temperature=OPTIONS["temperature"], top_p=OPTIONS["top_p"],
                                                           top_k=OPTIONS["top_k"], seed=seed))
                msg = {"role": "user", "content": [
                    {"type": "image", "path": str(IMAGES / "files" / f"{item['id']}.jpg")},
                    {"type": "text", "text": item["q"]}]}
                t = time.perf_counter(); deltas, ttft = [], None
                with conv:
                    for chunk in conv.send_message_async(msg):
                        text = "".join(c.get("text", "") for c in chunk.get("content", []) if c.get("type", "text") == "text")
                        if text:
                            now = time.perf_counter() - t
                            if ttft is None: ttft = now
                            deltas.append([round(now, 4), text])
                    total = time.perf_counter() - t
                    b = conv.get_benchmark_info()
                return dict(deltas=deltas, ttft=ttft, total=total, prompt_tokens=b.last_prefill_token_count,
                            gen_tokens=b.last_decode_token_count, decode_tps=b.last_decode_tokens_per_second)
            cold = ask(items[0], 0)
        for run in range(args.runs):
            for item in items:
                r = ask(item, run + 1)
                r.update(model=name, run=run, image=item["id"])
                with out.open("a") as f: f.write(json.dumps(r, ensure_ascii=False) + "\n")
                print(f"{name} run{run} {item['id']:<14} ttft={r['ttft'] or 0:.2f}s total={r['total']:.1f}s", flush=True)
        if args.runtime == "ollama":
            pid = llama_server_pid(); peak = phys_footprint(pid)[1] if pid else 0; init_s = None
        else:
            peak = phys_footprint(os.getpid())[1]
        with (ROOT / "results/img_models.jsonl").open("a") as f:
            f.write(json.dumps(dict(model=name, cold_ttft=cold["ttft"], cold_total=cold["total"], init_s=init_s,
                                    peak_footprint=peak)) + "\n")
    if args.runtime == "ollama": unload_all()


if __name__ == "__main__":
    main()
