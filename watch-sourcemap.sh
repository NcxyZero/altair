#!/usr/bin/env bash
# Keeps sourcemap.json in sync while files change (macOS: fswatch, Windows: PowerShell).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 1 ]]; then
    echo "Usage: bash watch-sourcemap.sh [project-name|project.project.json]" >&2
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

refresh_sourcemap() {
    echo "[$(date '+%H:%M:%S')] Regenerating sourcemap.json..."
    if ! bash "$SCRIPT_DIR/refresh-sourcemap.sh" "$PROJECT_FILE"; then
        echo "[$(date '+%H:%M:%S')] sourcemap.json refresh failed." >&2
        return 1
    fi

    echo "[$(date '+%H:%M:%S')] sourcemap.json updated."
}

case "$(uname -s)" in
    Darwin)
        if ! command -v fswatch >/dev/null 2>&1; then
            echo "fswatch is required on macOS. Install it with: brew install fswatch" >&2
            exit 1
        fi

        refresh_sourcemap
        echo "Watching src/ and *.project.json for $PROJECT_FILE (fswatch). Press Ctrl+C to stop."

        shopt -s nullglob
        watch_paths=( -r src )
        for project_file in *.project.json; do
            watch_paths+=( "$project_file" )
        done
        shopt -u nullglob

        # A failed refresh (for example a half-saved project file) must not stop the watcher; the first one above does.
        fswatch -l 0.3 -o "${watch_paths[@]}" | while read -r _; do
            refresh_sourcemap || echo "[$(date '+%H:%M:%S')] Still watching for changes." >&2
        done
        ;;
    MINGW*|MSYS*|CYGWIN*)
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./watch-sourcemap.ps1 -Project "$PROJECT_FILE"
        ;;
    *)
        echo "Automatic sourcemap watching is not supported on this platform." >&2
        echo "Use bash refresh-sourcemap.sh or bash update.sh instead." >&2
        exit 1
        ;;
esac
