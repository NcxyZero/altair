#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/altair-dependencies.toml"
MANIFEST_NAME="dependency.toml"

DEFAULT_REPOSITORY_NAME="altair-utils"
DEFAULT_REPOSITORY_URL="https://github.com/NcxyZero/altair-utils"

INSTALL_PATH="src/util"
REPOSITORY_NAMES=()
REPOSITORY_URLS=()
REPOSITORY_BRANCHES=()
REPOSITORY_PATHS=()
REPOSITORY_ROOTS=()

FORCE=0
LIST=0
REQUESTED=()

QUEUE=()
QUEUE_EXPLICIT=()
PROCESSED=()
INSTALLED=()
FAILED=()

WORK_DIR=""

usage() {
  cat <<'EOF'
Usage: ./require-dependency.sh [options] <dependency> [dependency...]

Installs dependencies (for example Math, Camera, Audio) from the repositories
listed in altair-dependencies.toml into the configured install path.

When a dependency exists in more than one repository, you choose which ones to
install from by typing their numbers, for example "1 2 3", "1 2" or "2".

Options:
  -l, --list     List dependencies available in every configured repository
  -f, --force    Reinstall already installed dependencies without asking
  -h, --help     Show this help

Examples:
  ./require-dependency.sh Math
  ./require-dependency.sh Math Camera Audio
  ./require-dependency.sh --list
EOF
}

info() {
  printf '%s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

error() {
  printf 'Error: %s\n' "$*" >&2
}

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

parse_toml_string() {
  local raw
  raw="$(trim "$1")"

  if [[ "$raw" == \"* ]]; then
    raw="${raw#\"}"
    printf '%s' "${raw%%\"*}"
  elif [[ "$raw" == \'* ]]; then
    raw="${raw#\'}"
    printf '%s' "${raw%%\'*}"
  else
    trim "${raw%%#*}"
  fi
}

parse_toml_array() {
  local raw
  raw="$(trim "$1")"
  raw="${raw#\[}"
  raw="${raw%%\]*}"

  local item
  local items
  IFS=',' read -ra items <<< "$raw"
  for item in ${items[@]+"${items[@]}"}; do
    item="$(parse_toml_string "$item")"
    if [[ -n "$item" ]]; then
      printf '%s\n' "$item"
    fi
  done
}

read_toml_key() {
  local file="$1"
  local wanted="$2"
  local line

  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "${line%$'\r'}")"

    if [[ "$line" == \[* ]]; then
      return 0
    fi

    if [[ "$line" == *=* && "$(trim "${line%%=*}")" == "$wanted" ]]; then
      trim "${line#*=}"

      return 0
    fi
  done < "$file"
}

add_repository() {
  REPOSITORY_NAMES+=("$1")
  REPOSITORY_URLS+=("$2")
  REPOSITORY_BRANCHES+=("$3")
  REPOSITORY_PATHS+=("$4")
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "altair-dependencies.toml not found, using the default repository ($DEFAULT_REPOSITORY_NAME)."
    add_repository "$DEFAULT_REPOSITORY_NAME" "$DEFAULT_REPOSITORY_URL" "" ""

    return 0
  fi

  local section=""
  local index=-1
  local line_number=0
  local line
  local key
  local value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="$(trim "${line%$'\r'}")"

    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi

    if [[ "$line" == "[[repository]]" ]]; then
      section="repository"
      index=$((index + 1))
      add_repository "" "" "" ""

      continue
    fi

    if [[ "$line" == \[* ]]; then
      section="unknown"

      continue
    fi

    if [[ "$line" != *=* ]]; then
      error "altair-dependencies.toml:$line_number: expected 'key = value'."

      exit 1
    fi

    key="$(trim "${line%%=*}")"
    value="$(parse_toml_string "${line#*=}")"

    case "$section:$key" in
      ":install-path") INSTALL_PATH="$value" ;;
      "repository:name") REPOSITORY_NAMES[index]="$value" ;;
      "repository:url") REPOSITORY_URLS[index]="$value" ;;
      "repository:branch") REPOSITORY_BRANCHES[index]="$value" ;;
      "repository:path") REPOSITORY_PATHS[index]="$value" ;;
      *) warn "altair-dependencies.toml:$line_number: unknown key '$key' ignored." ;;
    esac
  done < "$CONFIG_FILE"

  local i
  for ((i = 0; i < ${#REPOSITORY_URLS[@]}; i++)); do
    if [[ -z "${REPOSITORY_URLS[i]}" ]]; then
      error "altair-dependencies.toml: repository #$((i + 1)) has no url."

      exit 1
    fi

    if [[ -z "${REPOSITORY_NAMES[i]}" ]]; then
      local url="${REPOSITORY_URLS[i]%/}"
      url="${url%.git}"
      REPOSITORY_NAMES[i]="${url##*/}"
    fi
  done

  if [[ ${#REPOSITORY_URLS[@]} -eq 0 ]]; then
    error "altair-dependencies.toml does not list any [[repository]]."

    exit 1
  fi
}

fetch_repositories() {
  WORK_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t altair-dependencies)"
  trap cleanup EXIT

  local i
  for ((i = 0; i < ${#REPOSITORY_URLS[@]}; i++)); do
    local destination="$WORK_DIR/$i"
    local arguments=(clone --quiet --depth 1)

    if [[ -n "${REPOSITORY_BRANCHES[i]}" ]]; then
      arguments+=(--branch "${REPOSITORY_BRANCHES[i]}")
    fi

    info "Fetching ${REPOSITORY_NAMES[i]} (${REPOSITORY_URLS[i]})..."

    if git "${arguments[@]}" "${REPOSITORY_URLS[i]}" "$destination" >/dev/null 2>&1; then
      local root="$destination"
      if [[ -n "${REPOSITORY_PATHS[i]}" ]]; then
        root="$destination/${REPOSITORY_PATHS[i]}"
      fi

      if [[ -d "$root" ]]; then
        REPOSITORY_ROOTS[i]="$root"
      else
        warn "Path '${REPOSITORY_PATHS[i]}' does not exist in ${REPOSITORY_NAMES[i]}, skipping it."
        REPOSITORY_ROOTS[i]=""
      fi
    else
      warn "Could not fetch ${REPOSITORY_NAMES[i]}, skipping it."
      REPOSITORY_ROOTS[i]=""
    fi
  done
}

is_dependency_dir() {
  local directory="$1"
  local name
  name="$(basename "$directory")"

  [[ "$name" != .* ]] || return 1
  [[ -f "$directory/$MANIFEST_NAME" ]] && return 0

  find "$directory" -type f -name '*.luau' -print -quit 2>/dev/null | grep -q .
}

find_dependency() {
  local root="$1"
  local wanted
  wanted="$(lowercase "$2")"

  [[ -n "$root" ]] || return 1

  local directory
  for directory in "$root"/*/; do
    [[ -d "$directory" ]] || continue
    directory="${directory%/}"

    local name
    name="$(basename "$directory")"
    if [[ "$(lowercase "$name")" == "$wanted" ]] && is_dependency_dir "$directory"; then
      printf '%s' "$name"

      return 0
    fi
  done

  return 1
}

list_dependencies() {
  local i
  for ((i = 0; i < ${#REPOSITORY_URLS[@]}; i++)); do
    info ""
    info "[$((i + 1))] ${REPOSITORY_NAMES[i]} (${REPOSITORY_URLS[i]})"

    local root="${REPOSITORY_ROOTS[i]}"
    if [[ -z "$root" ]]; then
      info "  unavailable"

      continue
    fi

    local found=0
    local directory
    for directory in "$root"/*/; do
      [[ -d "$directory" ]] || continue
      directory="${directory%/}"
      is_dependency_dir "$directory" || continue

      local name
      local description
      local status=""
      name="$(basename "$directory")"
      description="$(parse_toml_string "$(read_toml_key "$directory/$MANIFEST_NAME" description)")"

      if [[ -d "$SCRIPT_DIR/$INSTALL_PATH/$name" ]]; then
        status=" (installed)"
      fi

      if [[ -n "$description" ]]; then
        info "  $name$status - $description"
      else
        info "  $name$status"
      fi

      found=1
    done

    if [[ $found -eq 0 ]]; then
      info "  no dependencies found"
    fi
  done
}

was_processed() {
  local wanted
  wanted="$(lowercase "$1")"

  local name
  for name in ${PROCESSED[@]+"${PROCESSED[@]}"}; do
    if [[ "$name" == "$wanted" ]]; then
      return 0
    fi
  done

  return 1
}

confirm() {
  local answer
  if ! read -rp "$1 [y/N]: " answer; then
    echo

    return 1
  fi

  [[ "$(lowercase "$(trim "$answer")")" == y || "$(lowercase "$(trim "$answer")")" == yes ]]
}

select_repositories() {
  local name="$1"
  shift

  local matches=("$@")
  local count=${#matches[@]}

  {
    info ""
    info "\"$name\" was found in $count/${#REPOSITORY_URLS[@]} repositories:"

    local number
    for ((number = 1; number <= count; number++)); do
      local index="${matches[number - 1]}"
      info "  $number) ${REPOSITORY_NAMES[index]} (${REPOSITORY_URLS[index]})"
    done
  } >&2

  while true; do
    local answer
    if ! read -rp "Select repositories to install from (for example \"1 2\"), Enter for 1: " answer; then
      echo >&2
      warn "No input, installing from 1) only."
      answer="1"
    fi

    answer="$(trim "${answer//,/ }")"
    if [[ -z "$answer" ]]; then
      answer="1"
    fi

    local valid=1
    local chosen=()
    local token
    for token in $answer; do
      if [[ ! "$token" =~ ^[0-9]+$ ]] || ((token < 1 || token > count)); then
        valid=0

        break
      fi

      local duplicate=0
      local existing
      for existing in ${chosen[@]+"${chosen[@]}"}; do
        if [[ "$existing" == "$token" ]]; then
          duplicate=1
        fi
      done

      if [[ $duplicate -eq 0 ]]; then
        chosen+=("$token")
      fi
    done

    if [[ $valid -eq 1 ]]; then
      for token in "${chosen[@]}"; do
        printf '%s\n' "${matches[token - 1]}"
      done

      return 0
    fi

    printf 'Please type numbers between 1 and %s separated by spaces.\n' "$count" >&2
  done
}

copy_dependency_files() {
  local source="$1"
  local target="$2"
  local repository_name="$3"
  local copied=0
  local relative

  while IFS= read -r relative; do
    relative="${relative#./}"

    if [[ "$relative" == "$MANIFEST_NAME" ]]; then
      continue
    fi

    local destination="$target/$relative"
    if [[ -e "$destination" ]]; then
      warn "$relative from $repository_name skipped, a file with that name was already installed from another repository."

      continue
    fi

    mkdir -p "$(dirname "$destination")"
    cp "$source/$relative" "$destination"
    copied=$((copied + 1))
  done < <(cd "$source" && find . -type f | sort)

  info "  + $copied file(s) from $repository_name"
}

check_packages() {
  local name="$1"
  local manifest="$2"
  local wally_file="$SCRIPT_DIR/wally.toml"
  local package

  while IFS= read -r package; do
    [[ -n "$package" ]] || continue

    if [[ ! -f "$wally_file" ]] || ! grep -Eq "^[[:space:]]*\"?$package\"?[[:space:]]*=" "$wally_file"; then
      warn "$name needs the Wally package '$package', which is not in wally.toml."
    fi
  done < <(parse_toml_array "$(read_toml_key "$manifest" packages)")
}

queue_dependencies() {
  local manifest="$1"
  local dependency

  while IFS= read -r dependency; do
    if [[ -n "$dependency" ]]; then
      QUEUE+=("$dependency")
      QUEUE_EXPLICIT+=(0)
    fi
  done < <(parse_toml_array "$(read_toml_key "$manifest" dependencies)")
}

install_dependency() {
  local requested="$1"
  local explicit="$2"

  local matches=()
  local name=""
  local i
  for ((i = 0; i < ${#REPOSITORY_URLS[@]}; i++)); do
    local found
    if found="$(find_dependency "${REPOSITORY_ROOTS[i]}" "$requested")"; then
      matches+=("$i")
      if [[ -z "$name" ]]; then
        name="$found"
      fi
    fi
  done

  if [[ ${#matches[@]} -eq 0 ]]; then
    error "Dependency \"$requested\" was not found in any repository. Run with --list to see what is available."
    FAILED+=("$requested")

    return 0
  fi

  local install_root="$SCRIPT_DIR/$INSTALL_PATH"
  local target="$install_root/$name"

  if [[ "$(lowercase "$name")" == "core" ]]; then
    error "Cannot install \"$name\": the Core folder is reserved for Altair's core utilities."
    FAILED+=("$name")

    return 0
  fi

  if [[ -e "$install_root/$name.luau" ]]; then
    error "Cannot install \"$name\": $INSTALL_PATH/$name.luau already exists and would clash with it."
    FAILED+=("$name")

    return 0
  fi

  if [[ -d "$target" ]]; then
    if [[ "$explicit" -eq 0 ]]; then
      info "$name is already installed, skipping."

      return 0
    fi

    if [[ $FORCE -eq 0 ]] && ! confirm "$name is already installed in $INSTALL_PATH/$name. Reinstall it (the folder will be replaced)?"; then
      info "Skipped $name."

      return 0
    fi
  fi

  local selected=()
  if [[ ${#matches[@]} -eq 1 ]]; then
    selected=("${matches[0]}")
  else
    local index
    while IFS= read -r index; do
      selected+=("$index")
    done < <(select_repositories "$name" "${matches[@]}")
  fi

  rm -rf "$target"
  mkdir -p "$target"

  info "Installing $name into $INSTALL_PATH/$name"

  local index
  for index in "${selected[@]}"; do
    local source
    source="${REPOSITORY_ROOTS[index]}/$(find_dependency "${REPOSITORY_ROOTS[index]}" "$name")"

    copy_dependency_files "$source" "$target" "${REPOSITORY_NAMES[index]}"
    check_packages "$name" "$source/$MANIFEST_NAME"
    queue_dependencies "$source/$MANIFEST_NAME"
  done

  INSTALLED+=("$name")
}

refresh_sourcemap() {
  if ! command -v rojo >/dev/null 2>&1; then
    warn "rojo not found, run 'bash refresh-sourcemap.sh' after installing it."

    return 0
  fi

  if ! (cd "$SCRIPT_DIR" && bash refresh-sourcemap.sh >/dev/null 2>&1); then
    warn "refresh-sourcemap.sh failed."
  fi
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage

        exit 0
        ;;
      -l|--list) LIST=1 ;;
      -f|--force) FORCE=1 ;;
      -*)
        error "Unknown option: $1"
        usage

        exit 1
        ;;
      *) REQUESTED+=("$1") ;;
    esac

    shift
  done

  if [[ $LIST -eq 0 && ${#REQUESTED[@]} -eq 0 ]]; then
    usage

    exit 1
  fi
}

main() {
  parse_arguments "$@"

  if ! command -v git >/dev/null 2>&1; then
    error "git is required."

    exit 1
  fi

  load_config
  fetch_repositories

  if [[ $LIST -eq 1 ]]; then
    list_dependencies

    exit 0
  fi

  local requested
  for requested in "${REQUESTED[@]}"; do
    QUEUE+=("$requested")
    QUEUE_EXPLICIT+=(1)
  done

  local position=0
  while [[ $position -lt ${#QUEUE[@]} ]]; do
    local name="${QUEUE[position]}"
    local explicit="${QUEUE_EXPLICIT[position]}"
    position=$((position + 1))

    if was_processed "$name"; then
      continue
    fi

    PROCESSED+=("$(lowercase "$name")")
    install_dependency "$name" "$explicit"
  done

  info ""

  if [[ ${#INSTALLED[@]} -gt 0 ]]; then
    refresh_sourcemap
    info "Installed: ${INSTALLED[*]}"
    info "Installed into: $INSTALL_PATH/<Dependency>"
  else
    info "Nothing was installed."
  fi

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    error "Failed: ${FAILED[*]}"

    exit 1
  fi
}

main "$@"
