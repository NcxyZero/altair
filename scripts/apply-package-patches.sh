#!/usr/bin/env bash
# Applies the tracked fixes in patches/*.patch to generated Wally package sources.
# Each patch is applied once; a patch that is already applied is skipped, and a patch
# that no longer matches its installed package stops the script.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PATCHES_DIR="$REPOSITORY_DIR/patches"

cd "$REPOSITORY_DIR"

apply_package_patch() {
    local patch_path="$1"
    local patch_name
    patch_name="$(basename "$patch_path")"

    if git apply --check "$patch_path" 2>/dev/null; then
        git apply "$patch_path"
        echo "$patch_name applied."
    elif git apply --reverse --check "$patch_path" 2>/dev/null; then
        echo "$patch_name is already applied."
    else
        echo "$patch_name does not match the installed package. Update the patch or the package version." >&2
        exit 1
    fi
}

if [[ ! -d "$PATCHES_DIR" ]]; then
    exit 0
fi

shopt -s nullglob
patch_paths=( "$PATCHES_DIR"/*.patch )
shopt -u nullglob

if [[ ${#patch_paths[@]} -eq 0 ]]; then
    exit 0
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Git is not available on PATH; it is required to apply the package patches in patches/." >&2
    exit 1
fi

for patch_path in "${patch_paths[@]}"; do
    apply_package_patch "$patch_path"
done
