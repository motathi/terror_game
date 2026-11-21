#!/usr/bin/env bash
# Build do jogo para web, rodado pela Vercel a cada push (ver vercel.json).
# Também funciona local/CI: bash tools/vercel_build.sh  -> saída em dist/
#
# 1. baixa o Godot (headless) e só os templates web da versão fixada
# 2. baixa os pacotes de assets que não ficam no git (tools/fetch_assets.py)
# 3. importa o projeto, exporta o preset "Web" e roda um teste de fumaça
set -euo pipefail

GODOT_VERSION="4.7"
REL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/.tools"
GODOT="$TOOLS/godot"
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

mkdir -p "$TOOLS"

unzip_py() {  # unzip_py <zip> <destino> [arquivos...]  (sem depender do unzip)
  python3 - "$@" <<'PY'
import sys, zipfile, os
zpath, dest, wanted = sys.argv[1], sys.argv[2], set(sys.argv[3:])
with zipfile.ZipFile(zpath) as z:
    for info in z.infolist():
        if info.is_dir() or (wanted and info.filename not in wanted):
            continue
        out = os.path.join(dest, os.path.basename(info.filename))
        with z.open(info) as src, open(out, "wb") as f:
            f.write(src.read())
        os.chmod(out, 0o755)
        print("  extraído", out)
PY
}

if [ ! -x "$GODOT" ]; then
  echo ">> Baixando Godot ${GODOT_VERSION}"
  curl -fsSL -o "$TOOLS/godot.zip" "$REL/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip_py "$TOOLS/godot.zip" "$TOOLS" "Godot_v${GODOT_VERSION}-stable_linux.x86_64"
  mv "$TOOLS/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$GODOT"
  rm -f "$TOOLS/godot.zip"
fi

if [ ! -f "$TPL_DIR/web_nothreads_release.zip" ]; then
  echo ">> Baixando templates de exportação (só web)"
  mkdir -p "$TPL_DIR"
  curl -fsSL -o "$TOOLS/templates.tpz" "$REL/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  unzip_py "$TOOLS/templates.tpz" "$TPL_DIR" \
    templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt
  rm -f "$TOOLS/templates.tpz"
fi

echo ">> Assets de terceiros"
# Sem os pacotes o jogo sai com modelos provisórios (esferas): melhor falhar o build
# e manter no ar a versão anterior. ALLOW_PLACEHOLDERS=1 libera (testes).
if ! python3 "$ROOT/tools/fetch_assets.py"; then
  if [ "${ALLOW_PLACEHOLDERS:-0}" = "1" ]; then
    echo "AVISO: fetch_assets falhou; o build segue com modelos provisórios."
  else
    echo "ERRO: fetch_assets falhou (itch.io fora do ar ou limitando downloads). Build cancelado para não publicar modelos provisórios."
    exit 1
  fi
fi

echo ">> Importando projeto"
"$GODOT" --headless --path "$ROOT/game" --import 2>&1 \
  | grep -vE "^\[ *[0-9]+% \]|DONE|^.\[0m$" | tail -n 80 || true

echo ">> Exportando Web"
rm -rf "$ROOT/dist" && mkdir -p "$ROOT/dist"
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$ROOT/dist/index.html" 2>&1 \
  | grep -vE "^\[ *[0-9]+% \]|DONE|^.\[0m$" | tail -n 80
test -f "$ROOT/dist/index.pck" || { echo "ERRO: exportação não gerou dist/index.pck"; exit 1; }
# PWA desligado: no lugar do service worker antigo vai um que apaga o cache e se
# desregistra (quem abriu o jogo antes deixa de ver a versão velha guardada).
cp "$ROOT/tools/web/index.service.worker.js" "$ROOT/dist/index.service.worker.js"

echo ">> Teste de fumaça (menu, jogo e cenários)"
for scene in res://scenes/main_menu.tscn res://scenes/game.tscn res://scenes/location_preview.tscn; do
  timeout 90 "$GODOT" --headless --path "$ROOT/game" "$scene" --quit-after 600 > "$TOOLS/smoke.log" 2>&1 || true
  if grep -qE "SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Cannot " "$TOOLS/smoke.log"; then
    echo "!! Erros em $scene:"
    grep -E -A3 "SCRIPT ERROR|Parse Error|ERROR" "$TOOLS/smoke.log" | head -n 80
  else
    echo "   ok  $scene"
  fi
done

ls -la "$ROOT/dist"
