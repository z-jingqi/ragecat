#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
run_checked() {
  "$GODOT" "$@" 2>&1 | tee "$LOG"
  # Godot can exit zero after runtime errors, including the original UI bug.
  if grep -Eq '^(ERROR|SCRIPT ERROR):' "$LOG"; then
    echo "FAIL: Godot reported an engine or script error" >&2
    return 1
  fi
}
run_checked --headless --editor --import --quit
for suite in model_tests integration_tests boss_tests bow_tests combo_tests stress_tests ui_lifecycle_tests feedback_tests defense_knockback_tests pierce_range_tests dash_cooldown_tests boundary_regressions transition_status_edges feedback_bounds_tests upgrade_catalog_tests split_bow_tests; do
  run_checked --headless --script "tests/$suite.gd"
done
