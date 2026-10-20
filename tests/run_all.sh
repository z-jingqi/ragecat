#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --editor --import --quit
for suite in model_tests integration_tests boss_tests bow_tests combo_tests stress_tests; do
  "$GODOT" --headless --script "tests/$suite.gd"
done
