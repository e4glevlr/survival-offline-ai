#!/usr/bin/env python3
"""Downloads the photo test set from Wikimedia Commons (free licenses) and records author + license.
Files go to bench/images/files/ (not committed); manifest.json is committed."""
import json, re, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "ResQ-bench/0.1 (offline survival app research)"}


def get(url):
    """GET with backoff: Commons answers 429 when requests come too fast."""
    for attempt in range(6):
        try:
            time.sleep(1.5)
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            time.sleep(10 * (attempt + 1))
    raise RuntimeError(f"rate limited: {url}")


def api(**params):
    params.update(format="json", formatversion=2)
    return json.loads(get(API + "?" + urllib.parse.urlencode(params)))


def candidates(query, n=8):
    d = api(action="query", generator="search", gsrsearch=f"{query} filetype:bitmap", gsrnamespace=6, gsrlimit=n,
            prop="imageinfo", iiprop="url|extmetadata|size|mime", iiurlwidth=768)
    pages = sorted(d.get("query", {}).get("pages", []), key=lambda p: p["index"])
    for p in pages:
        ii = p["imageinfo"][0]
        if ii["mime"] != "image/jpeg":
            continue
        meta = ii.get("extmetadata", {})
        yield dict(title=p["title"], thumb=ii["thumburl"], page=ii["descriptionurl"],
                   license=meta.get("LicenseShortName", {}).get("value", ""),
                   author=meta.get("Artist", {}).get("value", ""))


if __name__ == "__main__":
    # `python3 fetch.py list "<query>"` prints candidates; default: download what manifest.json pins.
    if len(sys.argv) > 2 and sys.argv[1] == "list":
        for c in candidates(sys.argv[2]): print(c["title"], "|", c["license"])
        sys.exit()
    manifest = json.loads((HERE / "manifest.json").read_text())
    (HERE / "files").mkdir(exist_ok=True)
    for item in manifest:
        out = HERE / "files" / f"{item['id']}.jpg"
        if out.exists() and item.get("author") is not None: continue
        d = api(action="query", titles=item["commons"], prop="imageinfo", iiprop="url|extmetadata", iiurlwidth=768)
        ii = d["query"]["pages"][0]["imageinfo"][0]
        meta = ii.get("extmetadata", {})
        item["license"] = meta.get("LicenseShortName", {}).get("value", "")
        item["source"] = ii["descriptionurl"]
        item["author"] = re.sub(r"<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        if not out.exists(): out.write_bytes(get(ii["thumburl"]))
        print("ok", item["id"], item["license"])
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n")
