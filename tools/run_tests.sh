#!/usr/bin/env bash
# Тесты чистого ядра мастерской в CLI luau (https://github.com/luau-lang/luau/releases)
# Использование: tools/run_tests.sh [путь к luau]
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${1:-luau}"
mkdir -p build
python3 tools/bundle_tests.py build/tests.luau
"$LUAU" build/tests.luau
python3 tools/lint_ui_text.py
