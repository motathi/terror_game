#!/usr/bin/env python3
"""Gera vozes, efeitos e ambientes do jogo com a API do ElevenLabs.

Chave da API: variável ELEVENLABS_API_KEY (ou arquivo .env na raiz com
ELEVENLABS_API_KEY=...). Nunca coloque a chave dentro do jogo: os áudios são
gerados aqui, uma vez, e o jogo só toca os arquivos .mp3.

Comandos:
  python3 tools/elevenlabs_gen.py design <personagem>        # gera 3 vozes de teste (mp3) para ouvir
  python3 tools/elevenlabs_gen.py save <personagem> <n>      # salva a prévia n como voz definitiva
  python3 tools/elevenlabs_gen.py lines [--only prefixo] [--force] [--dry-run]
  python3 tools/elevenlabs_gen.py sfx   [--force] [--dry-run]  # efeitos + ambientes
  python3 tools/elevenlabs_gen.py music [--force] [--dry-run]  # trilha sonora (Eleven Music)
  python3 tools/elevenlabs_gen.py all   [--dry-run]

Pós-processamento (precisa de ffmpeg): as vozes recebem o efeito da cena
"queimado" no arquivo (telefone, TV/rádio, abafado atrás da porta) e
volume normalizado, porque no navegador o Godot não aplica efeitos de bus.
O áudio cru fica em tools/.elevenlabs_cache/raw/.

As falas vêm de game/story/*.json. Cada fala vira game/audio/vo/<locale>/<id>.mp3.
Um cache (tools/.elevenlabs_cache/manifest.json) guarda o hash de texto+voz+
configuração: só falas alteradas são regeradas (economiza créditos).
"""
import base64
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(ROOT, "tools", "audio_config.json")
CACHE_DIR = os.path.join(ROOT, "tools", ".elevenlabs_cache")
MANIFEST = os.path.join(CACHE_DIR, "manifest.json")
API = "https://api.elevenlabs.io"


# --- infraestrutura -------------------------------------------------------------

def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    env = os.path.join(ROOT, ".env")
    if not key and os.path.exists(env):
        for line in open(env):
            if line.strip().startswith("ELEVENLABS_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"')
    if not key:
        sys.exit("Defina ELEVENLABS_API_KEY (variável de ambiente ou .env na raiz do repo).")
    return key


def request(path, body, query="", expect_json=False, retries=4):
    url = f"{API}{path}" + (f"?{query}" if query else "")
    data = json.dumps(body).encode()
    for attempt in range(retries):
        req = urllib.request.Request(url, data=data, method="POST", headers={
            "xi-api-key": api_key(),
            "Content-Type": "application/json",
            "Accept": "application/json" if expect_json else "audio/mpeg",
        })
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                raw = r.read()
                return json.loads(raw) if expect_json else raw
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:500]
            if e.code in (429, 500, 502, 503) and attempt < retries - 1:
                wait = 2 ** attempt * 3
                print(f"    HTTP {e.code}, tentando de novo em {wait}s...")
                time.sleep(wait)
                continue
            raise SystemExit(f"Erro HTTP {e.code} em {path}: {detail}")
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                time.sleep(3)
                continue
            raise SystemExit(f"Falha de rede em {path}: {e}")


def load_config():
    return json.load(open(CONFIG_PATH, encoding="utf-8"))


def save_config(cfg):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")


def load_manifest():
    if os.path.exists(MANIFEST):
        return json.load(open(MANIFEST))
    return {}


def save_manifest(m):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(MANIFEST, "w") as f:
        json.dump(m, f, indent=1, sort_keys=True)


def digest(*parts):
    return hashlib.sha256(json.dumps(parts, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


# --- pós-processamento (ffmpeg) ------------------------------------------------------

FX = {
    "": "",
    "phone": "highpass=f=380,lowpass=f=3200,acrusher=bits=11:mix=0.25,acompressor=threshold=-20dB:ratio=5,",
    "radio": "highpass=f=260,lowpass=f=4200,aecho=0.8:0.55:35:0.22,acrusher=bits=12:mix=0.15,",
    "muffled": "lowpass=f=850,aecho=0.8:0.45:18:0.3,volume=1.8,",
}


def ffmpeg(src, dst, filt):
    if not shutil.which("ffmpeg"):
        shutil.copyfile(src, dst)
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", filt,
                    "-ar", "44100", "-b:a", "128k", dst], check=True)


def process_voice(raw, dst, fx):
    ffmpeg(raw, dst, FX.get(fx, "") + "loudnorm=I=-16:TP=-1.5:LRA=11")


# --- vozes ------------------------------------------------------------------------

def cmd_design(char):
    cfg = load_config()
    v = cfg["voices"].get(char) or sys.exit(f"personagem '{char}' não está em audio_config.json")
    res = request("/v1/text-to-voice/design", {
        "voice_description": v["description"],
        "model_id": cfg["voice_design"]["model_id"],
        "text": cfg["voice_design"]["preview_text"],
    }, query="output_format=mp3_44100_128", expect_json=True)
    out_dir = os.path.join(CACHE_DIR, "previews")
    ids = []
    for i, p in enumerate(res.get("previews", [])):
        path = os.path.join(out_dir, f"{char}_{i}.mp3")
        write(path, base64.b64decode(p["audio_base_64"]))
        ids.append(p["generated_voice_id"])
        print(f"  prévia {i}: {path}")
    v["_previews"] = ids
    save_config(cfg)
    print(f"Ouça as prévias e rode: python3 tools/elevenlabs_gen.py save {char} <n>")


def cmd_save(char, n):
    cfg = load_config()
    v = cfg["voices"][char]
    gen_id = v.get("_previews", [])[int(n)]
    res = request("/v1/text-to-voice", {
        "voice_name": f"escolha-me_{char}",
        "voice_description": v["description"],
        "generated_voice_id": gen_id,
    }, expect_json=True)
    v["voice_id"] = res["voice_id"]
    v.pop("_previews", None)
    save_config(cfg)
    print(f"  {char} -> voice_id {res['voice_id']} (salvo em audio_config.json)")


# --- falas ------------------------------------------------------------------------

def collect_lines():
    """Todas as falas dubladas de todas as histórias, com contexto vizinho."""
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "game", "story", "*.json"))):
        story = json.load(open(path, encoding="utf-8"))
        if "nodes" not in story:
            continue  # ex.: campanhas.json
        chars = story["characters"]
        for node in story["nodes"].values():
            lines = node.get("lines", [])
            phone_char = node.get("cast", {}).get("phone", {}).get("char")
            for i, ln in enumerate(lines):
                ch = chars.get(ln["who"], {})
                if not ch.get("voiced", True):
                    continue
                prev = lines[i - 1]["text"] if i > 0 and lines[i - 1]["who"] == ln["who"] else None
                fx = "phone" if (ln.get("phone") or phone_char == ln["who"]) else {"Radio": "radio", "Muffled": "muffled"}.get(ch.get("bus", ""), "")
                out.append({**ln, "previous_text": prev, "fx": fx})
        # narração dos finais (lida na cinemática de cada final)
        for eid, e in story.get("endings", {}).items():
            out.append({"id": f"fim_{story['id']}_{eid}", "who": "sistema", "text": e["text"], "previous_text": None, "fx": ""})
    return out


def cmd_lines(only=None, force=False, dry=False):
    cfg = load_config()
    tts = cfg["tts"]
    manifest = load_manifest()
    out_dir = os.path.join(ROOT, "game", "audio", "vo", tts["locale_dir"])
    todo, chars, missing_voice = [], 0, set()
    for ln in collect_lines():
        if only and not ln["id"].startswith(only):
            continue
        voice = cfg["voices"].get(ln["who"], {})
        if not voice.get("voice_id"):
            missing_voice.add(ln["who"])
            continue
        text = (ln.get("tags", voice.get("default_tags", "")) + " " + ln["text"]).strip()
        h = digest(text, voice["voice_id"], voice.get("settings"), tts["model_id"])
        path = os.path.join(out_dir, ln["id"] + ".mp3")
        raw = os.path.join(CACHE_DIR, "raw", ln["id"] + ".mp3")
        fx_key = "fx/" + ln["id"]
        if not force and manifest.get("vo/" + ln["id"]) == h and os.path.exists(path):
            if not os.path.exists(raw) and fx_key not in manifest:
                os.makedirs(os.path.dirname(raw), exist_ok=True)
                shutil.copyfile(path, raw)  # arquivo antigo, ainda sem efeito
            if os.path.exists(raw) and manifest.get(fx_key) != ln["fx"] + "/v1" and not dry:
                process_voice(raw, path, ln["fx"])
                manifest[fx_key] = ln["fx"] + "/v1"
                save_manifest(manifest)
            continue
        todo.append((ln, voice, text, h, path))
        chars += len(text)
    if missing_voice:
        print("Sem voice_id (pulei):", ", ".join(sorted(missing_voice)), "-> rode 'design' e 'save'.")
    print(f"{len(todo)} falas para gerar (~{chars} caracteres).")
    if dry:
        for ln, _, text, _, _ in todo:
            print(f"  {ln['id']:28s} {ln['who']:9s} {text[:70]}")
        return
    for ln, voice, text, h, path in todo:
        body = {
            "text": text,
            "model_id": tts["model_id"],
            "language_code": tts["language_code"],
            "voice_settings": voice.get("settings", {}),
            "seed": int(h[:8], 16),
        }
        if ln.get("previous_text"):
            body["previous_text"] = ln["previous_text"]
        print(f"  [{ln['who']}] {ln['id']} {ln['fx']}")
        raw = os.path.join(CACHE_DIR, "raw", ln["id"] + ".mp3")
        write(raw, request(f"/v1/text-to-speech/{voice['voice_id']}", body, query="output_format=" + tts["output_format"]))
        process_voice(raw, path, ln["fx"])
        manifest["fx/" + ln["id"]] = ln["fx"] + "/v1"
        manifest["vo/" + ln["id"]] = h
        save_manifest(manifest)
    print("Pronto. Abra o Godot para ele importar os novos arquivos.")


# --- efeitos e ambientes --------------------------------------------------------------

def cmd_sfx(force=False, dry=False):
    cfg = load_config()
    manifest = load_manifest()
    for group, folder, loop in (("sfx", "sfx", False), ("ambience", "amb", True)):
        model = cfg[group]["model_id"]
        for key, item in cfg[group]["items"].items():
            path = os.path.join(ROOT, "game", "audio", folder, key + ".mp3")
            h = digest(item, model, loop)
            if not force and manifest.get(f"{folder}/{key}") == h and os.path.exists(path):
                continue
            print(f"  [{folder}] {key}: {item['prompt'][:60]}")
            if dry:
                continue
            body = {
                "text": item["prompt"],
                "duration_seconds": item.get("duration"),
                "prompt_influence": item.get("prompt_influence", 0.4),
                "loop": loop,
                "model_id": model,
            }
            write(path, request("/v1/sound-generation", body, query="output_format=mp3_44100_128"))
            manifest[f"{folder}/{key}"] = h
            save_manifest(manifest)


def cmd_music(force=False, dry=False):
    cfg = load_config()
    manifest = load_manifest()
    model = cfg["music"]["model_id"]
    for key, item in cfg["music"]["items"].items():
        path = os.path.join(ROOT, "game", "audio", "music", key + ".mp3")
        h = digest(item, model)
        if not force and manifest.get("music/" + key) == h and os.path.exists(path):
            continue
        print(f"  [music] {key} ({item['duration']}s): {item['prompt'][:60]}")
        if dry:
            continue
        raw = os.path.join(CACHE_DIR, "raw", "music_" + key + ".mp3")
        write(raw, request("/v1/music", {
            "prompt": item["prompt"],
            "music_length_ms": int(item["duration"] * 1000),
            "model_id": model,
            "force_instrumental": True,
        }, query="output_format=mp3_44100_128"))
        d = float(item["duration"])
        looping = not key.startswith("final_")
        # loops: entrada e saída suaves para a emenda não estalar
        filt = f"afade=t=in:d=0.8,afade=t=out:st={max(d - 2.0, 0)}:d=2.0," if looping else f"afade=t=out:st={max(d - 3.0, 0)}:d=3.0,"
        ffmpeg(raw, path, filt + "loudnorm=I=-20:TP=-2:LRA=14")
        manifest["music/" + key] = h
        save_manifest(manifest)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    force, dry = "--force" in args, "--dry-run" in args
    only = args[args.index("--only") + 1] if "--only" in args else None
    cmd = args[0]
    if cmd == "design":
        cmd_design(args[1])
    elif cmd == "save":
        cmd_save(args[1], args[2])
    elif cmd == "lines":
        cmd_lines(only, force, dry)
    elif cmd == "sfx":
        cmd_sfx(force, dry)
    elif cmd == "music":
        cmd_music(force, dry)
    elif cmd == "all":
        cmd_sfx(force, dry)
        cmd_music(force, dry)
        cmd_lines(only, force, dry)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
