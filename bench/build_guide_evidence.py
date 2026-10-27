#!/usr/bin/env python3
"""Evidence from the content the app actually ships (guides.json + emergency cards), for the user-style cases.

Writes data/guide_evidence.json and fills each case's "blocks" in data/user_cases.json: its "gold" blocks
(what the app's router + hybrid retriever must find) padded with BM25 hits to 4 (ContextBudget.maxBlocks), plus the
hotline block when an emergency card is among them. Also reports where plain BM25 misses the gold block, as a
vocabulary check for the retriever, which is not built yet.

    python3 bench/build_guide_evidence.py
"""
import json, math, re, unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
UI = ROOT.parent / "ios/ResQKit/Sources/ResQUI"


def fold(s):
    s = unicodedata.normalize("NFD", s.lower().replace("đ", "d"))
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def tokens(s):
    w = re.findall(r"[a-z0-9]+", fold(s))
    return w + [a + "_" + b for a, b in zip(w, w[1:])]  # Vietnamese words are mostly two syllables


def cards():
    """card("ec-x", "Title", [steps], [doNot]) calls in GuideLibrary.swift, plus the snake card in DemoResponder."""
    src = (UI / "GuideLibrary.swift").read_text() + (UI / "DemoResponder.swift").read_text()
    strs = lambda s: re.findall(r'"((?:[^"\\]|\\.)*)"', s)
    out = {}
    for m in re.finditer(r'card\("(ec-[\w-]+)", "([^"]+)",\s*\[(.*?)\],\s*\[(.*?)\]\)', src, re.S):
        out[m[1]] = (m[2], strs(m[3]), strs(m[4]))
    m = re.search(r'id: "(ec-snake)".*?title: "([^"]+)",\s*steps: \[(.*?)\],\s*doNot: \[(.*?)\]', src, re.S)
    out[m[1]] = (m[2], strs(m[3]), strs(m[4]))
    return out


def main():
    ev = {}
    for a in json.loads((UI / "Resources/guides.json").read_text())["articles"]:
        text = " ".join([a["summary"]] + [f"- {s}" for s in a["steps"]] + [f"Cảnh báo: {w}" for w in a["warnings"]])
        ev[a["id"]] = dict(source=a["source"], trust=a["trust"], heading=f"{a['pillar']} › {a['title']}",
                           text=text.replace("**", ""))
    for cid, (title, steps, donot) in cards().items():
        ev[cid] = dict(source="Thẻ khẩn cấp", trust="A", heading=f"Khẩn cấp › {title}",
                       text=" ".join(steps) + " Không được: " + "; ".join(donot) + ".")
    ev["hotlines"] = json.loads((ROOT / "data/evidence.json").read_text())["hotlines"]
    (ROOT / "data/guide_evidence.json").write_text(json.dumps(ev, ensure_ascii=False, indent=1) + "\n")

    docs = {k: Counter(tokens(v["heading"] + " " + v["text"])) for k, v in ev.items() if k != "hotlines"}
    avg = sum(sum(d.values()) for d in docs.values()) / len(docs)
    df = Counter(t for d in docs.values() for t in d)

    def bm25(q, d, k1=1.2, b=0.75):
        n = sum(d.values())
        return sum(math.log(1 + (len(docs) - df[t] + .5) / (df[t] + .5)) * d[t] * (k1 + 1)
                   / (d[t] + k1 * (1 - b + b * n / avg)) for t in set(tokens(q)) if t in d)

    path = ROOT / "data/user_cases.json"
    cases = json.loads(path.read_text())
    misses = 0
    for c in cases:
        q = c["q"] + " " + c.get("state", {}).get("subject", "")
        ranked = [k for k, s in sorted(((k, bm25(q, d)) for k, d in docs.items()), key=lambda x: -x[1]) if s > 0]
        # "gold" = what the real retriever (router card + hybrid search) must return; BM25 fills the rest as distractors.
        top = (c["gold"] + [k for k in ranked if k not in c["gold"]])[:4]
        if any(k.startswith("ec-") for k in top): top = top[:3] + ["hotlines"]
        c["blocks"] = top
        miss = [g for g in c["gold"] if g not in ranked[:4]]
        misses += bool(miss)
        print(f"{c['id']:<24} {top}" + (f"   BM25 top4 misses {miss}: {ranked[:4]}" if miss else ""))
    print(f"BM25 alone misses a gold block in {misses}/{sum(bool(c['gold']) for c in cases)} cases")
    path.write_text(json.dumps(cases, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    main()
