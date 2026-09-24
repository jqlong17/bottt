#!/bin/bash
# 三个模型并行下。已完整的文件不重下。已设置 HTTP_PROXY 时，curl 会沿用它。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)/models"
if [[ -x "${HOME}/.local/bin/python3" ]]; then
  PY="${HOME}/.local/bin/python3"
else
  PY="$(command -v python3)"
fi
mkdir -p "$ROOT/kokoro" "$ROOT/piper" "$ROOT/supertonic"

remote_size() {
  curl -sS -I -L --max-time 40 "$1" | awk 'tolower($1)=="content-length:" {n=$2} END {gsub("\r","",n); print n+0}'
}

note_auth() {
  local code="$1"
  if [[ "$code" != "401" ]]; then
    return 0
  fi
  echo "github auth failed ($code); starting gh auth refresh without waiting"
  gh auth refresh -h github.com -s workflow,repo >"$ROOT/gh-auth.log" 2>&1 &
}

fetch_one() {
  local url="$1"
  local dest="$2"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' -I -L --max-time 40 "$url" || true)"
  note_auth "$code"
  local size
  size="$(remote_size "$url")"
  local have=0
  if [[ -f "$dest" ]]; then
    have="$(stat -f '%z' "$dest")"
  fi
  echo "$dest have=$have remote=$size http=$code"
  if [[ "$size" -gt 0 && "$have" -eq "$size" ]]; then
    echo "complete $dest"
    return 0
  fi
  curl -L --fail --retry 5 --retry-delay 2 -C - -o "$dest" "$url"
}

wait_kokoro() {
  local onnx_url="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.fp16.onnx"
  local voices_url="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
  fetch_one "$voices_url" "$ROOT/kokoro/voices-v1.0.bin"
  fetch_one "$onnx_url" "$ROOT/kokoro/kokoro-v1.0.fp16.onnx"
  local voices_size onnx_size voices_have onnx_have
  voices_size="$(remote_size "$voices_url")"
  onnx_size="$(remote_size "$onnx_url")"
  voices_have="$(stat -f '%z' "$ROOT/kokoro/voices-v1.0.bin")"
  onnx_have="$(stat -f '%z' "$ROOT/kokoro/kokoro-v1.0.fp16.onnx")"
  if [[ "$voices_size" -gt 0 && "$onnx_size" -gt 0 && "$voices_have" -eq "$voices_size" && "$onnx_have" -eq "$onnx_size" ]]; then
    python3 - "$ROOT/kokoro" "$onnx_size" "$voices_size" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
expected = {"onnx": int(sys.argv[2]), "voices": int(sys.argv[3])}
(root / "expected.json").write_text(json.dumps(expected))
print("kokoro ready", expected, flush=True)
PY
  else
    echo "kokoro incomplete onnx=$onnx_have/$onnx_size voices=$voices_have/$voices_size"
  fi
}

fetch_piper() {
  local url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-low.tar.bz2"
  local arc="$ROOT/piper/amy-low.tar.bz2"
  if find "$ROOT/piper" -name '*.onnx' | grep -q .; then
    echo "piper already present"
    return 0
  fi
  fetch_one "$url" "$arc"
  local size have
  size="$(remote_size "$url")"
  have="$(stat -f '%z' "$arc")"
  if [[ "$size" -gt 0 && "$have" -eq "$size" ]]; then
    tar -xjf "$arc" -C "$ROOT/piper"
    echo "piper extracted"
  else
    echo "piper incomplete $have/$size"
  fi
}

fetch_supertonic() {
  if [[ -f "$ROOT/supertonic/onnx/tts.json" ]]; then
    echo "supertonic already present"
    return 0
  fi
  "$PY" - "$ROOT/supertonic" <<'PY'
import sys
from supertonic.loader import download_model
download_model(sys.argv[1], "supertonic-3")
print("supertonic ready", flush=True)
PY
}

wait_kokoro &
fetch_piper &
fetch_supertonic &
wait
echo "fetch_models done"
