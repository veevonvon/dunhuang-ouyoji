#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
mkdir -p test-results/checks
touch test-results/.gdignore
run_check() {
    name="$1"
    shift
    log="test-results/checks/$name.log"
    if ! tools/godot.sh "$@" > "$log" 2>&1; then
        cat "$log"
        exit 1
    fi
    if grep -Eq '^(SCRIPT ERROR|ERROR|WARNING):' "$log"; then
        cat "$log"
        exit 1
    fi
    if [ "$name" = import ]; then
        printf '%s\n' 'IMPORT_CHECK: 场景与脚本导入通过。'
    else
        cat "$log"
    fi
}
run_check import --headless --editor --path . --import
python3 tools/check-assets.py
python3 tests/test_landmark_data.py
python3 tools/check-field-assets.py
for suite in domain seals atlas_store games trails scenic_play app audio score field_audio ui_edges journey edition atlas_ui actor_clock companion_audio boy_rig deer_rig action_effects performance_game rest; do
    set -- --headless --path . --script "tests/test_$suite.gd"
    if [ "$suite" = scenic_play ]; then
        set -- "$@" -- --require-seasonal-art
    fi
    run_check "$suite" "$@"
done
printf '%s\n' '全部离线检查通过。安卓运行与实际画面另见验收记录。'
