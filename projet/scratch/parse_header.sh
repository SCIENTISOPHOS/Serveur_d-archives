#!/bin/bash

# cela sert a ✔️ arrêter awk à @ ✔️ différencier directory / file ✔️ accéder aux champs $1 … $6 ✔️ parser sans charger en mémoire


ARCH="$1"

if [ ! -f "$ARCH" ]; then
    echo "archive introuvable"
    exit 1
fi

awk '
$0 == "@" { exit }

$1 == "directory" {
    print "[DIR]", $2
}

$1 == "file" {
    print "[FILE] path=" $2 \
          " perms=" $3 \
          " size=" $4 \
          " start=" $5 \
          " lines=" $6
}
' "$ARCH"
