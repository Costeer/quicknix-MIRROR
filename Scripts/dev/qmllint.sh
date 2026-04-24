#!/usr/bin/env -S bash
set -euo pipefail

# QML Linter Script

# Suppress noisy Qt DOM logging
export QT_LOGGING_RULES="qt.qmldom.*=false"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! QMLLINT="$($script_dir/find-qt-tool.sh qmllint)"; then
    echo "To proceed, install it via 'qt6-tools', 'qt6-declarative-tools' or 'qt6-qtdeclarative-devel'" >&2
    exit 1
fi

root_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root_dir"

mapfile -t all_files < <(find . \
    -path './examples' -prune -o \
    -name '*.qml' -type f -print | sort)

if [ ${#all_files[@]} -eq 0 ]; then
    echo "No QML files found"
    exit 0
fi

echo "Linting ${#all_files[@]} QML files..."
"$QMLLINT" "${all_files[@]}"
echo "Done"
