#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"
output_file="${input_file%.vsc}.bin"

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found." >&2
    exit 1
fi

declare -A OPCODES=(
    [LOAD]=1 [STORE]=2 [ADD]=3 [SUB]=4 [QUIT]=8 [PRINT]=9
)

mapfile -t lines < <(grep -v "^[[:space:]]*$" "$input_file")

n_values="${lines[0]}"

: > "$output_file"

# write n_values, then each static value, as raw bytes
printf "$(printf '\\x%02x' "$n_values")" >> "$output_file"
for ((i=1; i<=n_values; i++)); do
    value="${lines[$i]}"
    printf "$(printf '\\x%02x' "$value")" >> "$output_file"
done

# encode and write instructions
start=$((n_values + 1))
for ((i=start; i<${#lines[@]}; i++)); do
    line="${lines[i]}"
    IFS=',' read -r name reg addr <<< "$line"
    name="$(echo "$name" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    reg="$(echo "$reg" | tr -d '[:space:]')"
    addr="$(echo "$addr" | tr -d '[:space:]')"

    opcode_value="${OPCODES[$name:-]}"
    if [ -z "$opcode_value" ]; then
        echo "Error: Unknown opcode '$name' in line $((i+1))." >&2
        exit 1
    fi

    byte1=$(( (opcode_value <<2 ) | (reg & 0x03) ))
    byte2=$(( addr & 0xFF ))

    printf "$(printf '\\x%02x' "$byte1")" >> "$output_file"
    printf "$(printf '\\x%02x' "$byte2")" >> "$output_file"

done

echo "Assembled '$input_file' into '$output_file'."

