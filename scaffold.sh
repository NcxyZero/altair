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

declare -A TARGET_ALIASES=(
  [server-controller]="sc"
  [server-tag]="st"
  [client-controller]="cc"
  [client-tag]="ct"
  [client-local-tag]="clt"
  [client-ui]="ui"
)

declare -A ALIAS_TO_TARGET=(
  [sc]="server-controller"
  [st]="server-tag"
  [cc]="client-controller"
  [ct]="client-tag"
  [clt]="client-local-tag"
  [ui]="client-ui"
)

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

print_targets() {
  echo "Available targets:"
  for target in "${TARGETS[@]}"; do
    local alias="${TARGET_ALIASES[$target]-}"
    if [[ -n "$alias" ]]; then
      echo "  - $target ($alias)"
    else
      echo "  - $target"
    fi
  done
}

usage() {
  cat <<'EOF'
Usage: ./scaffold.sh <target> <Name>
       ./scaffold.sh --install-completion   # enable TAB completion for targets
       ./scaffold.sh                        # interactive mode (prompts)

Targets:
  server-controller (sc)     Create src/server/modules/<Name>.luau
  server-tag (st)            Create src/server/modules/<Name>.luau
  client-controller (cc)     Create src/client/modules/<Name>.luau
  client-tag (ct)            Create src/client/modules/<Name>.luau
  client-local-tag (clt)     Create src/client/modules/<Name>.luau
  client-ui (ui)             Create src/client/ui/<Name>.luau

Examples:
  ./scaffold.sh server-controller FishingReplicationController
  ./scaffold.sh client-ui InventoryUI
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

  if [[ -x "$SCRIPT_DIR/refresh-sourcemap.sh" ]]; then
    if ! "$SCRIPT_DIR/refresh-sourcemap.sh" >/dev/null 2>&1; then
      echo "Warning: refresh-sourcemap.sh failed." >&2
    fi
  fi
}

prompt_target() {
  while true; do
    read -rp "Enter target: " selected_raw
    local selected
    selected="$(trim "$selected_raw")"

    if [[ -n "${ALIAS_TO_TARGET[$selected]-}" ]]; then
      selected="${ALIAS_TO_TARGET[$selected]}"
    fi

    for target in "${TARGETS[@]}"; do
      if [[ "$selected" == "$target" ]]; then
        printf "%s" "$selected"

        return 0
      fi
    done

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

install_completion() {
  if [[ -n "${BASH-}" ]]; then
    local fn
    fn="_scaffold_complete_${RANDOM}"
    # shellcheck disable=SC2139
    alias scaffold.sh="$SCRIPT_DIR/scaffold.sh"
    eval "
		${fn}() {
			local cur=\${COMP_WORDS[COMP_CWORD]}
			COMPREPLY=(\$(compgen -W \"${TARGETS[*]} ${!ALIAS_TO_TARGET[*]}\" -- \"\$cur\"))
		}
		complete -F ${fn} scaffold.sh
	"
    echo "Bash completion installed for scaffold.sh (current shell only)."
  else
    echo "Completion install is only supported in Bash."
  fi
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
    install_completion

    exit 0
  elif [[ $# -lt 2 ]]; then
    usage

    exit 1
  fi

  local target="$1"
  local name="$2"

  if [[ -n "${ALIAS_TO_TARGET[$target]-}" ]]; then
    target="${ALIAS_TO_TARGET[$target]}"
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
