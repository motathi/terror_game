#!/usr/bin/env python3
"""Baixa e extrai todos os pacotes listados em assets_manifest.json.

  python3 tools/fetch_assets.py            # baixa só o que falta
  python3 tools/fetch_assets.py --all      # força baixar tudo de novo
  python3 tools/fetch_assets.py --gitignore  # regenera o bloco de .gitignore

Pacotes com "commit": false não podem ir para o repositório público
(a licença proíbe redistribuir); rode este script depois de clonar.
"""
import fnmatch
import json
import os
import sys
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import itch_fetch  # noqa: E402

MARK_BEGIN = "# >>> assets não redistribuíveis (gerado por tools/fetch_assets.py)"
MARK_END = "# <<< assets não redistribuíveis"


def extract(zpath, pack):
    dest = os.path.join(ROOT, pack["dest"])
    prefix = pack.get("flatten_prefix", "")
    n = 0
    with zipfile.ZipFile(zpath) as z:
        for info in z.infolist():
            name = info.filename
            if info.is_dir() or not any(fnmatch.fnmatch(name, g) for g in pack["include"]):
                continue
            rel = name[len(prefix):] if prefix and name.startswith(prefix) else name
            out = os.path.normpath(os.path.join(dest, rel))
            if not out.startswith(os.path.normpath(dest) + os.sep):
                raise SystemExit(f"caminho suspeito no zip: {name}")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with z.open(info) as src, open(out, "wb") as f:
                f.write(src.read())
            n += 1
    return n


def write_gitignore(packs):
    path = os.path.join(ROOT, ".gitignore")
    text = open(path).read() if os.path.exists(path) else ""
    if MARK_BEGIN in text:
        text = text[: text.index(MARK_BEGIN)] + text[text.index(MARK_END) + len(MARK_END) + 1:]
    block = [MARK_BEGIN] + ["/" + p["dest"] + "/" for p in packs if not p["commit"]] + [MARK_END]
    with open(path, "w") as f:
        f.write(text.rstrip("\n") + "\n\n" + "\n".join(block) + "\n")


def main():
    manifest = json.load(open(os.path.join(ROOT, "assets_manifest.json")))
    packs = manifest["packs"]
    if "--gitignore" in sys.argv:
        write_gitignore(packs)
        return
    force = "--all" in sys.argv
    for pack in packs:
        dest = os.path.join(ROOT, pack["dest"])
        if os.path.isdir(dest) and os.listdir(dest) and not force:
            print(f"[ok]   {pack['id']} já existe")
            continue
        print(f"[get]  {pack['id']}  ({pack['license']})")
        with tempfile.TemporaryDirectory() as tmp:
            meta = itch_fetch.fetch(pack["url"], tmp, pack.get("only"))
            total = sum(extract(os.path.join(tmp, f), pack) for f in meta["files"] if f.lower().endswith(".zip") or zipfile.is_zipfile(os.path.join(tmp, f)))
        print(f"       {total} arquivos -> {pack['dest']}")
    write_gitignore(packs)


if __name__ == "__main__":
    main()
