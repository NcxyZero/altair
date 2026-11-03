#!/usr/bin/env bash
# Regenerates sourcemap.json, then serves a Rojo project (default.project.json unless another is given).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 1 ]]; then
    echo "Usage: bash serve.sh [project-name|project.project.json]" >&2
    exit 1
fi

PROJECT_FILE="${1:-default.project.json}"
if [[ "$PROJECT_FILE" != *.project.json ]]; then
    PROJECT_FILE+=.project.json
fi

shopt -s nullglob
project_files=( *.project.json )
shopt -u nullglob

if [[ -z "${1-}" && ! -f "$PROJECT_FILE" && ${#project_files[@]} -eq 1 ]]; then
    PROJECT_FILE="${project_files[0]}"
fi
if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Project file not found: $PROJECT_FILE" >&2
    if [[ ${#project_files[@]} -gt 0 ]]; then
        echo "Available projects:" >&2
        for project_file in "${project_files[@]}"; do
            echo "  ${project_file%.project.json}" >&2
        done
    fi
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

echo "Serving $PROJECT_FILE."
bash "$SCRIPT_DIR/refresh-sourcemap.sh" "$PROJECT_FILE"
exec "$ROJO_COMMAND" serve "$PROJECT_FILE"
