#!/usr/bin/env bash
# Regenerates sourcemap.json for editor / luau-lsp resolution.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 1 ]]; then
    echo "Usage: bash refresh-sourcemap.sh [project-name|project.project.json]" >&2
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

ROJO_COMMAND="rojo"
if ! command -v "$ROJO_COMMAND" >/dev/null 2>&1; then
    ROJO_COMMAND="rojo.exe"
fi
if ! command -v "$ROJO_COMMAND" >/dev/null 2>&1; then
    echo "Rojo is not available on PATH. Install it with Rokit or Aftman first." >&2
    exit 1
fi

"$ROJO_COMMAND" sourcemap "$PROJECT_FILE" --output sourcemap.json
