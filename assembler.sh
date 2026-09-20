#!/bin/bash
set -euo pipefail

# no argument is provided
if [ "$#" -eq 0 ]; then
    echo "usage: no argument is provided"
    exit 1
fi

# more than one argument is provided
if [ "$#" -gt 1 ]; then
    echo "usage: more than one arguments are provided"
    exit 1
fi

# sets variables for input and output files
input_file="$1"
#creating the output file name by replacing the .vsc extension with .bin
output_file="${input_file%.vsc}.bin"

#variable for if its an adding or subtracting instruction
is_add_or_sub=false
only_quit=true
instr_count=0

# if the argument is not a file nor does it exist
if [ ! -f "$input_file" ]; then
    echo "usage: input is not a file or it does not exist"
    exit 1
fi

# invalid file extension
if [[ "$input_file" != *.vsc ]]; then
    echo "usage: input does not have the extension .vsc"
    exit 1
fi

# emtpy file
if [ ! -s "$input_file" ]; then
    echo "usage: the file is empty – no .bin file is produced"
    exit 1
fi


# mapping of instruction names to their corresponding opcode values
declare -A OPCODES=([LOAD]=1 [STORE]=2 [ADD]=3 [SUB]=4 [QUIT]=8 [PRINT]=9)

# read every line from the input file into an array, ignoring empty lines
mapfile -t lines < <(tr -d '\r' < "$input_file" | grep -v '^[[:space:]]*$'; echo)

#reads the first line - the number of static values (bytes) - into a variable
n_values="${lines[0]}"

bytes=()

# write n_values, then each static value, as raw bytes
if [ "$n_values" -gt 0 ]; then
    for ((i=1; i<=n_values; i++)); do
        bytes+=("${lines[$i]}")
    done
fi


# encode and write instructions
start=$((n_values + 1))
for ((i=start; i<${#lines[@]}; i++)); do
    line="${lines[i]}"

    # split name, reg and addr into seperate fields, trimming whitespace and converting name to uppercase
    IFS=',' read -r name reg addr <<< "$line"
    
    #normalise instruction name to uppercase and remove whitespace from name, reg and addr
    name="$(echo "$name" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"

    # strip whitespace from reg and addr
    reg="$(echo "$reg" | tr -d '[:space:]')"
    addr="$(echo "$addr" | tr -d '[:space:]')"


    #look up the opcode value for the instruction name, and check if it is valid
    opcode_value="${OPCODES[$name]:-}"
    if [ -z "$opcode_value" ]; then
        echo "Error: Unknown opcode '$name' in line $((i+1))." >&2
        exit 1
    fi

    instr_count=$((instr_count + 1))

    if [ "$name" == "ADD" ] || [ "$name" == "SUB" ]; then
        is_add_or_sub=true
    fi
    if [ "$name" != "QUIT" ]; then
        only_quit=true
    fi

    # 6 bit opcode (shifted by 2 bits) and 2 bit register number are combined into a single byte
    byte1=$(( (opcode_value <<2 ) | (reg & 0x03) ))

    # the 6 byte memory address
    byte2=$(( addr & 0xFF ))

    # write the two bytes to the output file as raw bytes
    bytes+=("$byte1")
    bytes+=("$byte2")

    # if opcode is QUIT then exit the loop and do not write any more instructions
    if [ "$name" == "QUIT" ]; then
        break
    fi

done

# creates the output .bin file, ready to append the data
: > "$output_file"
for byte in "${bytes[@]}"; do
    printf "$(printf '\\x%02x' "$byte")" >> "$output_file"
done


if [ "$n_values" -eq 0 ] && [ "$instr_count" -eq 1 ] && [ "$only_quit" = true ]; then
    echo "It is a QUIT program"
    echo "The content of the .bin file is"
    for b in "${bytes[@]}"; do
        printf "%02x\n" "$b"
    done
    exit 0
elif ["$is_add_or_sub" = true] then
    echo "This is an ADD/SUB program"
    echo "The content of the .bin file is"
    for b in "${bytes[@]}"; do
        printf "%02x\n" "$b"
    done
    exit 0
else
    for b in "${bytes[@]}"; do
        printf "%02x\n" "$b" >> "$output_file"
    done
    exit 0
fi
