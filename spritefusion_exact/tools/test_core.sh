#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$HERE/../godot"
TEMP="$(mktemp -d /tmp/spritefusion-core.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CACHE_HOME="$TEMP/cache" XDG_DATA_HOME="$TEMP/data" XDG_CONFIG_HOME="$TEMP/config"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
if [[ $# -gt 0 ]]; then
  node --disable-warning=ExperimentalWarning "$HERE/generate_core_vectors.mjs" "$1"
fi
"${GODOT:-godot}" --headless --path "$PROJECT" --script res://tests/core/test_core.gd

"${GODOT:-godot}" --headless --path "$PROJECT" --script res://tests/core/test_source_px.gd

"${GODOT:-godot}" --headless --path "$PROJECT" --script res://tests/core/test_v8_math.gd

"${GODOT:-godot}" --headless --path "$PROJECT" --script res://tests/core/test_glow_fastpath.gd
