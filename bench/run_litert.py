#!/usr/bin/env python3
"""Same bake-off as run.py, but on LiteRT-LM: the runtime the apps ship (Swift on iOS, Kotlin on Android).

One process per model, so the peak physical footprint belongs to that model alone.
Needs `pip install litert-lm` (Python 3.10+).

    python bench/run_litert.py --model ~/models/litert/gemma-4-E2B-it.litertlm --name gemma4-e2b \
        --prompt v2 --runs 2 [--constrained]
"""
import argparse, json, os, sys, time
from pathlib import Path

import litert_lm

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import ROOT, OPTIONS, phys_footprint, system_contract, user_prompt  # noqa: E402


def line_format_regex(n_labels):
    """The answer contract as a regex, so the decoder cannot leave the format (LiteRT-LM LL_GUIDANCE).
    Every action line must end with at least one citation that exists in this prompt."""
    cite = f"( ?\\[E[1-{n_labels}]\\])+"
    item = f"- [^\\n\\[<>*]{{2,160}}{cite}\\n"
    return ("TRANG_THAI: (CO_CAN_CU|MAU_THUAN)\\n"
            f"TOM_TAT: [^\\n<>*]{{4,260}}\\n"
            f"LAM_NGAY:\\n({item}){{1,6}}"
            f"KHONG_DUOC:\\n({item}){{0,5}}"
            f"CAP_CUU: [^\\n\\[<>*]{{2,160}}{cite}"
            "|TRANG_THAI: KHONG_DU_CAN_CU\\nTOM_TAT: [^\\n<>*]{4,260}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--prompt", default="v0")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--backend", default="gpu")
    ap.add_argument("--constrained", action="store_true")
    ap.add_argument("--merge-system", action="store_true",
                    help="put the contract at the top of the user turn instead of the system turn (what the Android CLI does)")
    ap.add_argument("--only", nargs="*", help="case ids (smoke test); results go to results/smoke_*.jsonl")
    args = ap.parse_args()

    cases = json.loads((ROOT / "data/cases.json").read_text())
    evidence = json.loads((ROOT / "data/evidence.json").read_text())
    system = system_contract(args.prompt)
    if args.only: cases = [c for c in cases if c["id"] in args.only]
    tag = args.prompt + ("+cd" if args.constrained else "") + ("+merged" if args.merge_system else "")
    out = ROOT / f"results/{'smoke' if args.only else 'raw'}_{tag}.jsonl"; out.parent.mkdir(parents=True, exist_ok=True)
    model = f"litert/{args.name}"

    t0 = time.perf_counter()
    backend = litert_lm.Backend.GPU() if args.backend == "gpu" else litert_lm.Backend.CPU()
    engine = litert_lm.Engine(os.path.expanduser(args.model), backend=backend, max_num_tokens=4096,
                              enable_benchmark=True, cache_dir=str(Path.home() / "models/litert/.cache"))
    init_s = time.perf_counter() - t0

    def ask(case, seed):
        n = len(case["blocks"])
        cd = litert_lm.ConstrainedDecodingConfig(provider=litert_lm.LiteRtLmConstraintProviderType.LL_GUIDANCE) \
            if args.constrained else None
        conv = engine.create_conversation(
            system_message=None if args.merge_system else system, max_output_tokens=OPTIONS["num_predict"],
            thinking_config=litert_lm.ThinkingConfig(enable_thinking=False),
            sampler_config=litert_lm.SamplerConfig(temperature=OPTIONS["temperature"], top_p=OPTIONS["top_p"],
                                                   top_k=OPTIONS["top_k"], seed=seed),
            constrained_decoding_config=cd)
        fmt = litert_lm.ResponseFormat.regex(line_format_regex(n)) if args.constrained else None
        t = time.perf_counter(); deltas, ttft = [], None
        with conv:
            user = user_prompt(case, evidence, args.prompt)
            if args.merge_system: user = system + "\n\n" + user
            for chunk in conv.send_message_async(user, response_format=fmt):
                text = "".join(c.get("text", "") for c in chunk.get("content", []) if c.get("type", "text") == "text")
                if text:
                    now = time.perf_counter() - t
                    if ttft is None: ttft = now
                    deltas.append([round(now, 4), text])
            total = time.perf_counter() - t
            b = conv.get_benchmark_info()
        full = "".join(d[1] for d in deltas)
        return dict(deltas=deltas, ttft=ttft, total=total, thinking_chars=0,
                    prompt_tokens=b.last_prefill_token_count,
                    prompt_ns=int(b.last_prefill_token_count / b.last_prefill_tokens_per_second * 1e9)
                    if b.last_prefill_tokens_per_second else None,
                    gen_tokens=b.last_decode_token_count,
                    gen_ns=int(b.last_decode_token_count / b.last_decode_tokens_per_second * 1e9)
                    if b.last_decode_tokens_per_second else None,
                    load_ns=None, done_reason="length" if b.last_decode_token_count >= OPTIONS["num_predict"] else "stop",
                    engine_ttft=b.time_to_first_token_in_second, chars=len(full))

    cold = ask(cases[0], 0)
    for run in range(args.runs):
        for case in cases:
            r = ask(case, run + 1)
            r.update(model=model, prompt=tag, run=run, case=case["id"], critical=case["critical"],
                     labels=[f"E{i}" for i in range(1, len(case["blocks"]) + 1)])
            with out.open("a") as f: f.write(json.dumps(r, ensure_ascii=False) + "\n")
            if args.only: print("".join(d[1] for d in r["deltas"]))
            print(f"{model} {tag} run{run} {case['id']:<24} ttft={r['ttft'] or 0:.2f}s total={r['total']:.1f}s "
                  f"tok={r['gen_tokens']}", flush=True)
    peak = phys_footprint(os.getpid())[1]
    if args.only: print(f"init {init_s:.1f}s peak footprint {peak / 2**30:.2f} GiB"); return
    with (ROOT / "results/models.jsonl").open("a") as f:
        f.write(json.dumps(dict(model=model, prompt=tag, init_s=init_s, cold_total=cold["total"],
                                cold_ttft=cold["ttft"], peak_rss=peak, peak_footprint=peak,
                                file_gb=os.path.getsize(os.path.expanduser(args.model)) / 1e9)) + "\n")


if __name__ == "__main__":
    main()
