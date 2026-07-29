#!/usr/bin/env bash
#
# build-models.sh — export the PVT v2 and CLIP Core AI models and assemble the
# `ImagePredictModels/` folder that the SwiftUIFor27 app bundles.
#
# The folder is git-ignored (the CLIP .aimodel is ~289MB, above GitHub's 100MB
# per-file limit), so run this once after cloning to produce the bundled models.
#
#   ./SwiftUIFor27/Apps/ImagePredict/build-models.sh
#
# Requires: uv (>= 0.9), a local `coreai-models/` checkout at the repo root, and
# an internet connection (downloads timm/transformers weights + CLIP tokenizer).

set -euo pipefail

# Resolve the repo root (two levels up from this script's directory).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COREAI="$REPO_ROOT/coreai-models"
DEST="$REPO_ROOT/ImagePredictModels"

# Prefer a uv >= 0.9 (the standalone install is often newer than Homebrew's).
UV_BIN="uv"
if [ -x "$HOME/.local/bin/uv" ]; then UV_BIN="$HOME/.local/bin/uv"; fi

if [ ! -d "$COREAI" ]; then
  echo "error: $COREAI not found. Clone apple/coreai-models there first." >&2
  exit 1
fi

echo "==> Exporting PVT v2 (float16)…"
"$UV_BIN" run "$COREAI/models/pvt/export.py" --dtype float16 --overwrite

echo "==> Exporting CLIP (float16)… (this downloads ~600MB of weights)"
"$UV_BIN" run "$COREAI/models/clip/export.py" --dtype float16 --overwrite

echo "==> Assembling $DEST"
mkdir -p "$DEST/clip-tokenizer"
rm -rf "$DEST/pvt_v2_b0.aimodel" "$DEST/clip.aimodel"
cp -R "$COREAI/exports/pvt_v2_b0_float16_static.aimodel" "$DEST/pvt_v2_b0.aimodel"
cp -R "$COREAI/exports/clip-vit-base-patch32_float16_static.aimodel" "$DEST/clip.aimodel"

echo "==> Fetching + converting the CLIP tokenizer…"
TOKENIZER_RAW="$(mktemp)"
curl -fsSL -o "$TOKENIZER_RAW" \
  "https://huggingface.co/openai/clip-vit-base-patch32/resolve/main/tokenizer.json"
python3 - "$TOKENIZER_RAW" "$DEST/clip-tokenizer/tokenizer.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
vocab = d["model"]["vocab"]
# CoreAI's CLIPTokenizer expects merges as [[left, right]] pairs, but the HF
# fast tokenizer stores them as "left right" strings — convert here.
pairs = []
for m in d["model"]["merges"]:
    if isinstance(m, str):
        parts = m.split(" ")
        if len(parts) == 2:
            pairs.append(parts)
    elif isinstance(m, list) and len(m) == 2:
        pairs.append(m)
json.dump({"model": {"vocab": vocab, "merges": pairs}}, open(dst, "w"))
print(f"   wrote {dst} ({len(pairs)} merge pairs)")
PY
rm -f "$TOKENIZER_RAW"

echo "==> Done. Bundled models:"
du -sh "$DEST"/* 2>/dev/null || true
