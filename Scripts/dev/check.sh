#!/usr/bin/env -S bash
set -euo pipefail

root_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root_dir"

run() {
    echo
    echo ">>> $*"
    "$@"
}

mapfile -t shell_files < <(find Scripts .github -type f \( -name '*.sh' -o -name '*.bash' \) | sort)

if [ ${#shell_files[@]} -gt 0 ]; then
    run shellcheck "${shell_files[@]}"
    run shfmt -d -i 4 -ci "${shell_files[@]}"
fi

run ./Scripts/dev/qmllint.sh
run ./Scripts/dev/qmlfmt.sh
run git diff --exit-code -- . ':(exclude)examples/**'
run python3 Scripts/dev/build-settings-search-index.py
run git diff --exit-code -- Assets/settings-search-index.json
