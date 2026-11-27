#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
QA_DATA="$(mktemp -d)"
trap 'rm -rf "$QA_DATA"' EXIT
export XDG_DATA_HOME="$QA_DATA"
export GODOT_SILENCE_ROOT_WARNING=1
"$GODOT_BIN" --headless --path "$PWD" --editor --import --single-threaded-scene
for test in test_kernel test_pit_queue test_vehicle_11 test_driver_12 test_racecraft_13; do
  "$GODOT_BIN" --headless --path "$PWD" --script "res://tests/apex2/$test.gd"
done
for test in test_hyper test_calendar benchmark_queue test_persistence test_ui test_menu test_manual_wet test_career; do
  "$GODOT_BIN" --headless --path "$PWD" --script "res://tests/hyper/$test.gd"
done
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/hyper/full_race.gd -- ITA Seco
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/hyper/full_race.gd -- GBR 'Chuva intensa'
