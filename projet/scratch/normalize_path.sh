#!/bin/bash

CURRENT="$1"
INPUT="$2"

# Si chemin absolu (dans l'archive)
if [[ "$INPUT" == /* ]]; then
    PATH="$INPUT"
else
    [ "$CURRENT" = "." ] && PATH="$INPUT" || PATH="$CURRENT/$INPUT"
fi

# Normalisation : . et ..
IFS='/' read -ra PARTS <<< "$PATH"

stack=()

for p in "${PARTS[@]}"; do
    case "$p" in
        ""|".")
            continue
            ;;
        "..")
            [ ${#stack[@]} -gt 0 ] && unset stack[-1]
            ;;
        *)
            stack+=("$p")
            ;;
    esac
done

# Reconstruction
if [ ${#stack[@]} -eq 0 ]; then
    echo "."
else
    echo "${stack[*]}" | sed 's| |/|g'
fi
