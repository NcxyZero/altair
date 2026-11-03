#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(
  server-controller
  server-tag
  client-controller
  client-tag
  client-local-tag
  client-ui
)

alias_for_target() {
  case "$1" in
    server-controller) printf '%s' "sc" ;;
    server-tag) printf '%s' "st" ;;
    client-controller) printf '%s' "cc" ;;
    client-tag) printf '%s' "ct" ;;
    client-local-tag) printf '%s' "clt" ;;
    client-ui) printf '%s' "ui" ;;
    *) return 1 ;;
  esac
}

resolve_target() {
  case "$1" in
    server-controller|sc) printf '%s' "server-controller" ;;
    server-tag|st) printf '%s' "server-tag" ;;
    client-controller|cc) printf '%s' "client-controller" ;;
    client-tag|ct) printf '%s' "client-tag" ;;
    client-local-tag|clt) printf '%s' "client-local-tag" ;;
    client-ui|ui) printf '%s' "client-ui" ;;
    *) return 1 ;;
  esac
}

COMPLETION_WORDS="server-controller server-tag client-controller client-tag client-local-tag client-ui sc st cc ct clt ui"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

print_targets() {
  echo "Available targets:"
  for target in "${TARGETS[@]}"; do
    local alias
    if alias="$(alias_for_target "$target")"; then
      echo "  - $target ($alias)"
    else
      echo "  - $target"
    fi
  done
}

usage() {
  cat <<'EOF'
Usage: bash scaffold.sh <target> <Name>
       bash scaffold.sh --install-completion   # print Bash setup for TAB completion of targets
       bash scaffold.sh                        # interactive mode (prompts)

Targets:
  server-controller (sc)     Create src/server/modules/<Name>.luau
  server-tag (st)            Create src/server/modules/<Name>.luau
  client-controller (cc)     Create src/client/modules/<Name>.luau
  client-tag (ct)            Create src/client/modules/<Name>.luau
  client-local-tag (clt)     Create src/client/modules/<Name>.luau
  client-ui (ui)             Create src/client/ui/<Name>.luau

Examples:
  bash scaffold.sh server-controller FishingReplicationController
  bash scaffold.sh client-ui InventoryUI
EOF
}

fail() {
  echo "Error: $1" >&2
  usage

  return 1
}

validate_name() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "Name is required." >&2

    return 1
  fi

  if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "Name must start with a letter and contain only letters, numbers, or underscores." >&2

    return 1
  fi

  return 0
}

replace_all() {
  local content="$1"
  shift

  if (( $# % 2 != 0 )); then
    fail "Replacement arguments must be provided in pairs."
  fi

  while (( $# )); do
    local from="$1"
    local to="$2"
    shift 2

    content="${content//${from}/${to}}"
  done

  printf "%s" "$content"
}

create_from_template() {
  local template="$1"
  local destination="$2"
  shift 2

  if [[ ! -f "$template" ]]; then
    fail "Template not found: $template"
  fi

  if [[ -e "$destination" ]]; then
    fail "Destination already exists: $destination"
  fi

  if [[ -e "${destination%.luau}" ]]; then
    fail "A module directory already exists: ${destination%.luau}"
  fi

  mkdir -p "$(dirname "$destination")"

  local content
  content="$(<"$template")"
  content="$(replace_all "$content" "$@")"

  printf "%s\n" "$content" > "$destination"

  local relative_destination="$destination"
  if [[ "$relative_destination" == "$SCRIPT_DIR/"* ]]; then
    relative_destination="${relative_destination#"$SCRIPT_DIR/"}"
  fi

  echo "New file: ${relative_destination}:1"

  if [[ -f "$SCRIPT_DIR/refresh-sourcemap.sh" ]]; then
    if ! bash "$SCRIPT_DIR/refresh-sourcemap.sh" >/dev/null 2>&1; then
      echo "Warning: refresh-sourcemap.sh failed." >&2
    fi
  fi
}

prompt_target() {
  while true; do
    read -rp "Enter target: " selected_raw
    local selected
    selected="$(trim "$selected_raw")"

    if resolved="$(resolve_target "$selected" 2>/dev/null)"; then
      printf '%s' "$resolved"
      return 0
    fi

    echo "Invalid target. Please choose one from the list:" >&2
    print_targets >&2
  done
}

prompt_name() {
  while true; do
    read -rp "Enter Name: " provided
    if validate_name "$provided"; then
      printf "%s" "$provided"

      return 0
    fi
  done
}

# Completion cannot be installed from here: this script runs in a child shell, so anything it
# defines is gone when it exits. Print the setup instead for the user's own shell to load.
print_completion() {
  cat <<EOF
# Bash: run scaffold.sh from the project root with TAB completion of its targets.
# Current shell: eval "\$(bash scaffold.sh --install-completion)"
# New shells:    bash scaffold.sh --install-completion >> ~/.bashrc
alias scaffold.sh='bash ./scaffold.sh'
complete -W "${COMPLETION_WORDS}" scaffold.sh
EOF
}

main() {
  if [[ $# -eq 0 ]]; then
    local target
    local name
    print_targets
    target="$(prompt_target)"
    name="$(prompt_name)"

    set -- "$target" "$name"
  elif [[ ${1-} == "--install-completion" ]]; then
    print_completion

    exit 0
  elif [[ ${1-} == "--help" || ${1-} == "-h" ]]; then
    usage

    exit 0
  elif [[ $# -ne 2 ]]; then
    usage

    exit 1
  fi

  local target="$1"
  local name="$2"

  if resolved="$(resolve_target "$target" 2>/dev/null)"; then
    target="$resolved"
  else
    fail "Unknown target: $target"
    exit 1
  fi

  validate_name "$name" || exit 1

  case "$target" in
    server-controller)
      create_from_template \
        "$SCRIPT_DIR/src/server/modules/_TEMPLATEServerController.luau" \
        "$SCRIPT_DIR/src/server/modules/${name}.luau" \
        "ServerControllerTemplate" "$name" \
        "ControllerTemplate" "$name" \
      ;;
    server-tag)
      create_from_template \
        "$SCRIPT_DIR/src/server/modules/_TEMPLATEServerTag.luau" \
        "$SCRIPT_DIR/src/server/modules/${name}.luau" \
        "ServerTagTemplate" "$name" \
      ;;
    client-controller)
      create_from_template \
        "$SCRIPT_DIR/src/client/modules/_TEMPLATEClientController.luau" \
        "$SCRIPT_DIR/src/client/modules/${name}.luau" \
        "ClientControllerTemplate" "$name" \
        "ControllerTemplate" "$name" \
      ;;
    client-tag)
      create_from_template \
        "$SCRIPT_DIR/src/client/modules/_TEMPLATEClientTag.luau" \
        "$SCRIPT_DIR/src/client/modules/${name}.luau" \
        "ClientTagTemplate" "$name" \
      ;;
    client-local-tag)
      create_from_template \
        "$SCRIPT_DIR/src/client/modules/_TEMPLATEClientLocalTag.luau" \
        "$SCRIPT_DIR/src/client/modules/${name}.luau" \
        "ClientLocalTagTemplate" "$name" \
      ;;
    client-ui)
      create_from_template \
        "$SCRIPT_DIR/src/client/ui/_TEMPLATEUI.luau" \
        "$SCRIPT_DIR/src/client/ui/${name}.luau" \
        "TemplateUI" "$name" \
      ;;
    *)
      fail "Unknown target: $target"
      ;;
  esac
}

main "$@"
