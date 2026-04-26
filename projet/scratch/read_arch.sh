#!/bin/bash

ARCH="$1"

if [ ! -f "$ARCH" ]; then
    echo "archive introuvable"
    exit 1
fi

awk '
BEGIN {
    in_header = 1
}

{
    if ($0 == "@") {
        in_header = 0
        next
    }

    if (in_header) {
        print "[HEADER]", $0
    } else {
        print "[BODY]", $0
    }
}
' "$ARCH"
