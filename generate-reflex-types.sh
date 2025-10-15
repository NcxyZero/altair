#!/bin/bash
# Auto-generates typed profiles for Reflex by scanning src/shared/reflex
# Output: src/shared/reflex/ProfileTypes.luau

REFLEX_DIR="src/shared/reflex"
OUTPUT_FILE="$REFLEX_DIR/ProfileTypes.luau"

PROFILE_FILES=()
while IFS= read -r file; do
  PROFILE_FILES+=("$file")
done < <(find "$REFLEX_DIR" -maxdepth 1 -type f -name "*Profile.luau" | grep -v "/gameProfile.luau$")

IFS=$'\n' PROFILE_FILES=($(sort <<<"${PROFILE_FILES[*]}"))
unset IFS

PROFILE_KEYS=()
PROFILE_MODS=()

for file in "${PROFILE_FILES[@]}"; do
  base=$(basename "$file" ".luau")
  key=${base%Profile}
  PROFILE_KEYS+=("$key")
  PROFILE_MODS+=("$base")
done

{
  echo "-- Auto-generated file - do not edit manually!"
  echo "-- This file provides combined profile state and producer types"
  echo ""
  echo "-- Keys discovered under src/shared/reflex: ${PROFILE_KEYS[*]}"
  echo ""

  for i in "${!PROFILE_MODS[@]}"; do
    mod=${PROFILE_MODS[$i]}
    printf "local %s = require(script.Parent.%s)\n" "$mod" "$mod"
  done
  echo ""

  echo "export type PlayerState = {"
  for i in "${!PROFILE_KEYS[@]}"; do
    key=${PROFILE_KEYS[$i]}
    mod=${PROFILE_MODS[$i]}
    printf "  %s: typeof(%s.DEFAULT_STATE),\n" "$key" "$mod"
  done
  echo "}"
  echo ""

  if [ ${#PROFILE_KEYS[@]} -gt 0 ]; then
    echo "export type PlayerProducer = "
    first=1
    for i in "${!PROFILE_KEYS[@]}"; do
      mod=${PROFILE_MODS[$i]}
      if [ $first -eq 1 ]; then
        printf "  typeof(%s.CreateProducer(%s.DEFAULT_STATE))\n" "$mod" "$mod"
        first=0
      else
        printf "  & typeof(%s.CreateProducer(%s.DEFAULT_STATE))\n" "$mod" "$mod"
      fi
    done
    echo "  & { getState: () -> PlayerState }"
  else
    printf "export type PlayerProducer = { getState: () -> PlayerState }\n"
  fi

  printf "\nreturn table.freeze({})\n"

} > "$OUTPUT_FILE"

chmod -f +x "$OUTPUT_FILE" >/dev/null 2>&1 || true

if command -v StyLua >/dev/null 2>&1; then
  echo "Formatting $OUTPUT_FILE with StyLua..."
  StyLua "$OUTPUT_FILE" || true
else
  echo "StyLua not found in PATH. Skipping formatting..."
fi

echo "Generated $OUTPUT_FILE with ${#PROFILE_KEYS[@]} profiles"
