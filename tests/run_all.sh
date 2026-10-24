#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TEST_HOME="$(mktemp -d)"
LOG="$TEST_HOME/run.log"
trap 'rm -rf "$TEST_HOME"' EXIT
# Language/persistence tests must never inherit or overwrite the player's settings.
export HOME="$TEST_HOME/home"
export XDG_DATA_HOME="$TEST_HOME/data"
export XDG_CONFIG_HOME="$TEST_HOME/config"
export XDG_CACHE_HOME="$TEST_HOME/cache"
export LANG=en_US.UTF-8
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
run_checked() {
  "$GODOT" "$@" 2>&1 | tee "$LOG"
  # Godot can exit zero after runtime errors, including the original UI bug.
  if grep -Eq '^(ERROR|SCRIPT ERROR):' "$LOG"; then
    echo "FAIL: Godot reported an engine or script error" >&2
    return 1
  fi
}
run_checked --headless --editor --import --quit
for suite in arena_follow_camera_tests archer_dash_feedback_tests archer_dash_motion_tests archer_dash_asset_coverage_tests archer_dash_direction_tests projectile_visual_config_tests fire_explosion_presentation_tests fireball_volume_presentation_tests arrow_presentation_tests arrow_spawn_frame_tests hostile_fireball_tests dark_distortion_contracts fire_material_visual_contracts ice_dark_presentation_contracts natural_hazard_visual_contracts archer_asset_lifecycle_tests archer_asset_coverage_tests archer_projectile_presentation_tests archer_presentation_data_tests archer_pose_selector_tests archer_pose_runtime_tests resolved_damage_popup_tests impact_fade_contracts knockback_progression_tests window_draft_tests practice_reset_tests bow_cadence_tests playtest_workflow_tests mountainbreaker_pressure_tests window_application_tests atlas_animation_contracts boss_atlas_vfx_tests composition_architecture_tests catalog_composition_tests overlay_hud_tests full_playfield_boundary_tests concise_interface_tests projectile_critical_tests lightning_visual_tests window_reentrancy_tests window_settings_tests boss_lifecycle_edge_tests boss_simulation_tests boss_encounter_tests boss_player_damage_tests roster_integration_tests practice_boss_controls_tests practice_boss_integration_tests element_visual_contracts names_localization_tests entity_migration_tests critical_cap_tests model_tests integration_tests boss_tests bow_tests combo_tests stress_tests ui_lifecycle_tests feedback_tests defense_knockback_tests pierce_range_tests dash_cooldown_tests boundary_regressions transition_status_edges feedback_bounds_tests upgrade_catalog_tests firing_pattern_regressions config_combat_tests boss_config_tests ranged_config_tests damage_upgrade_tests damage_combinations_tests enchantment_foundation_tests ice_status_tests element_damage_combinations element_switch_contracts element_proc_combinations element_popup_contracts display_settings_tests gravity_runtime_contracts arrow_mode_ui_contracts arrow_mode_independent_tests ice_shatter_shock_tests fire_burn_tests chinese_ui_names_tests status_independent_contracts feedback_audio_tests feedback_integration_tests feedback_independent_contracts feedback_performance_tests localization_independent_tests audio_teardown_tests controller_navigation_tests achievement_profile_tests pacing_campaign_tests fixed_charge_tests progression_campaign_independent_tests weighted_offer_tests weighted_offer_independent_tests; do
  run_checked --headless --script "tests/$suite.gd"
done
