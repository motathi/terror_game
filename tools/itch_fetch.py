#!/usr/bin/env python3
"""Baixa assets GRATUITOS do itch.io e registra a licença de cada um.

Uso:
  python3 tools/itch_fetch.py info  <url_do_asset> [...]        # mostra preço, licença e arquivos
  python3 tools/itch_fetch.py fetch <url_do_asset> <destino> [--only substring]

Só funciona para assets gratuitos / "name your price" (usa o fluxo
"No thanks, just take me to the downloads"). Sempre confira a licença
impressa antes de usar o asset em um build comercial.
"""
import html
import http.cookiejar
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) asset-fetcher"


def _opener():
    jar = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    op.addheaders = [("User-Agent", UA)]
    return op


def _get(op, url):
    with op.open(url, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def _post_json(op, url, data):
    body = urllib.parse.urlencode(data).encode()
    with op.open(urllib.request.Request(url, data=body, method="POST"), timeout=60) as r:
        return json.loads(r.read().decode())


def _csrf(page):
    m = re.search(r'name="csrf_token" value="([^"]+)"', page)
    return m.group(1) if m else None


def info(url, op=None):
    op = op or _opener()
    page = _get(op, url)
    title = re.search(r"<title>([^<]*)</title>", page)
    rows = dict(
        (html.unescape(re.sub(r"<[^>]+>", "", k)).strip(), html.unescape(re.sub(r"<[^>]+>", " ", v)).strip())
        for k, v in re.findall(r"<tr><td>(.*?)</td><td>(.*?)</td></tr>", page)
    )
    uploads = []
    for m in re.finditer(r'title="([^"]+)" class="name">.*?class="file_size"><span>([^<]+)', page, re.S):
        uploads.append({"name": html.unescape(m.group(1)), "size": m.group(2)})
    price = re.search(r'class="buy_message">(.*?)</span></span>', page, re.S)
    return {
        "url": url,
        "title": html.unescape(title.group(1)) if title else url,
        "license": rows.get("License", rows.get("Asset license", "?")),
        "author": rows.get("Author", "?"),
        "price": re.sub(r"<[^>]+>", "", price.group(1)).strip() if price else "?",
        "uploads": uploads,
        "_page": page,
    }


def fetch(url, dest, only=None):
    op = _opener()
    meta = info(url, op)
    try:
        purchase = _get(op, url.rstrip("/") + "/purchase")
        token = _csrf(purchase) or _csrf(meta["_page"])
        dl_page_url = _post_json(op, url.rstrip("/") + "/download_url", {"csrf_token": token})["url"]
        dl_page = _get(op, dl_page_url)
    except urllib.error.HTTPError:
        # asset 100% gratuito: os botões de download ficam na própria página
        dl_page = meta["_page"]
    token = _csrf(dl_page) or _csrf(meta["_page"])
    key = re.search(r'init_GameDownload\([^;]*"key":"([^"]+)"', dl_page)
    files = []
    for block in re.findall(r'<div class="upload">(.*?)</div></div>', dl_page, re.S):
        uid = re.search(r'data-upload_id="(\d+)"', block)
        name = re.search(r'<strong[^>]*title="([^"]+)"', block)
        if uid and name:
            files.append((uid.group(1), name.group(1)))
    if not files:
        raise SystemExit("nenhum arquivo encontrado na página de download (asset pago?)")
    os.makedirs(dest, exist_ok=True)
    got = []
    for uid, name in files:
        name = html.unescape(name)
        if only and only.lower() not in name.lower():
            continue
        params = {"source": "game_download", "after_download_lightbox": "1", "as_props": "1"}
        if key:
            params["key"] = key.group(1)
        r = _post_json(op, f"{url.rstrip('/')}/file/{uid}?" + urllib.parse.urlencode(params), {"csrf_token": token})
        if "url" not in r:
            print(f"  ERRO {name}: {r}")
            continue
        out = os.path.join(dest, os.path.basename(name))
        with op.open(r["url"], timeout=300) as resp, open(out, "wb") as f:
            while chunk := resp.read(1 << 16):
                f.write(chunk)
        print(f"  ok  {out} ({os.path.getsize(out)} bytes)")
        got.append(os.path.basename(name))
    meta.pop("_page")
    meta["files"] = got
    with open(os.path.join(dest, "SOURCE.json"), "w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    return meta


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "info":
        for u in sys.argv[2:]:
            m = info(u)
            m.pop("_page")
            print(json.dumps(m, indent=1, ensure_ascii=False))
    elif cmd == "fetch":
        only = None
        args = sys.argv[2:]
        if "--only" in args:
            i = args.index("--only")
            only = args[i + 1]
            args = args[:i] + args[i + 2:]
        fetch(args[0], args[1], only)
