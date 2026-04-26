#!/bin/bash
# Serveur LO14 – Bash + netcat

PORT="$1"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <PORT>"
    exit 1
fi

ARCHIVES_DIR="archives"
mkdir -p "$ARCHIVES_DIR"

echo "[SERVER] écoute sur le port $PORT" >&2

# ===== COMMANDES SERVEUR =====

commande_LIST() {
    ls "$ARCHIVES_DIR"
}

commande_CREATE() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Le nom de l'archive est manquant" >&2
        return
    fi

    cat > "$ARCHIVES_DIR/$name"
    # On envoie le log vers stderr pour ne pas polluer le flux nc
    echo "[SERVER] Archive $name créée avec succès" >&2
}


commande_EXTRACT() {
    local name="$1"

    if [ -z "$name" ]; then
        echo "ERROR: archive manquante"
        return
    fi

    if [ ! -f "$ARCHIVES_DIR/$name" ]; then
        echo "ERROR: archive not found"
        return
    fi

    # Le serveur NE FAIT RIEN D'AUTRE
    # Il envoie l'archive brute au client
    cat "$ARCHIVES_DIR/$name"
}


commande_UNKNOWN() {
    echo "ERROR: La commande est Inconnu"
}

# ===== BOUCLE PRINCIPALE =====

while true; do
    nc -l -p "$PORT" | {


        read -r line || exit 0

        # Séparation commande / arguments
        cmd="${line%% *}"
        args="${line#* }"

        # Si pas d’arguments
        [ "$cmd" = "$args" ] && args=""

        fun="commande_$cmd"

        if [ "$(type -t "$fun")" = "function" ]; then
            $fun $args
        else
            commande_UNKNOWN
        fi
    }
done

