#!/bin/bash
# Updates Rokit tools, Wally packages, package patches, sourcemap, and generated types.

set -e
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 1 ]]; then
    echo "Usage: bash update.sh [project-name|project.project.json]" >&2
    exit 1
fi

PROJECT_FILE="${1:-default.project.json}"
if [[ "$PROJECT_FILE" != *.project.json ]]; then
    PROJECT_FILE+=.project.json
fi
if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Project file not found: $PROJECT_FILE" >&2
    exit 1
fi

echo "Starting update..."
rokit install || true
rm -f wally.lock
wally install
bash "$SCRIPT_DIR/scripts/apply-package-patches.sh"
bash "$SCRIPT_DIR/refresh-sourcemap.sh" "$PROJECT_FILE"
wally-package-types --sourcemap sourcemap.json Packages/
bash "$SCRIPT_DIR/generate-reflex-types.sh"
