#!/usr/bin/env -S bash
set -euo pipefail

# QML Formatter Script

# Suppress Qt debug logging from qmlformat
export QT_LOGGING_RULES="qt.qmldom.*=false"

# Find qmlformat binary
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! QMLFORMAT="$($script_dir/find-qt-tool.sh qmlformat)"; then
    echo "To proceed, install it via 'qt6-tools', 'qt6-declarative-tools' or 'qt6-qtdeclarative-devel'" >&2
    exit 1
fi

# Detect qmlformat version for flag compatibility
EXTRA_FLAGS=""
if version=$("$QMLFORMAT" --version 2>&1) && [[ "$version" =~ ([0-9]+\.[0-9]+) ]]; then
    if [[ "$(printf '%s\n6.10\n' "${BASH_REMATCH[1]}" | sort -V | head -1)" == "6.10" ]]; then
        EXTRA_FLAGS="-S --semicolon-rule always"
    fi
fi

format_file() {
    ${QMLFORMAT} -w 2 -W 360 ${EXTRA_FLAGS} -i "$1" || { echo "Failed: $1" >&2; return 1; }
}

export -f format_file
export QMLFORMAT EXTRA_FLAGS

search_root="${1:-.}"
if [ "$search_root" = "." ]; then
    mapfile -t all_files < <(find . \
        -path './examples' -prune -o \
        -name "*.qml" -type f -print)
else
    mapfile -t all_files < <(find "$search_root" -name "*.qml" -type f)
fi
[ ${#all_files[@]} -eq 0 ] && { echo "No QML files found"; exit 0; }

echo "Formatting ${#all_files[@]} files..."
printf '%s\0' "${all_files[@]}" | \
    xargs -0 -P "${QMLFMT_JOBS:-$(nproc)}" -I {} bash -c 'format_file "$@"' _ {} \
    && echo "Done" || { echo "Errors occurred" >&2; exit 1; }
