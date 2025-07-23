#!/bin/bash

SEARCH_DIRS=("src/client" "src/shared" "src/server" "src/preload")
OUTPUT_FILE="src/shared/types.luau"

echo "-- Auto-generated types file. Do not edit manually." > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "export type Path = {" >> "$OUTPUT_FILE"

for dir in "${SEARCH_DIRS[@]}"; do
    find "$dir" -name "*.luau" | while read -r file; do
        basefile=$(basename "$file" .luau)
        basefile_clean="${basefile//[^a-zA-Z0-9_]/_}"

        in_typedef=0
        typedef_body=""

        while IFS= read -r line || [ -n "$line" ]; do
            if [[ $in_typedef -eq 0 && "$line" =~ ^[[:space:]]*export[[:space:]]+type[[:space:]]+Default[[:space:]]*=[[:space:]]*(.*) ]]; then
                typedef_body="${BASH_REMATCH[1]}"
                open=$(grep -o "{" <<< "$typedef_body" | wc -l)
                close=$(grep -o "}" <<< "$typedef_body" | wc -l)
                if [ "$open" -gt "$close" ]; then
                    in_typedef=1
                else
                    echo "	$basefile_clean: $typedef_body," >> "$OUTPUT_FILE"
                    typedef_body=""
                fi
            elif [[ $in_typedef -eq 1 ]]; then
                typedef_body="${typedef_body}
$line"
                open=$(grep -o "{" <<< "$typedef_body" | wc -l)
                close=$(grep -o "}" <<< "$typedef_body" | wc -l)
                if [ "$open" -eq "$close" ]; then
                    echo "	$basefile_clean: $typedef_body," >> "$OUTPUT_FILE"
                    in_typedef=0
                    typedef_body=""
                fi
            fi
        done < "$file"
    done
done

echo "}" >> "$OUTPUT_FILE"