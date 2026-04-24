#!/usr/bin/env -S bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <tool-name>" >&2
    exit 1
fi

tool="$1"

for prefix in "/usr/lib64/qt6/bin" "/usr/lib/qt6/bin"; do
    candidate="$prefix/$tool"
    if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        exit 0
    fi
done

if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    exit 0
fi

echo "Could not find '$tool' in standard Qt locations or PATH." >&2
exit 1
