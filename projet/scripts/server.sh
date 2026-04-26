#!/bin/bash
# =============================================================================
# Serveur LO14 - Serveur d'archives VSH
# Utilise netcat avec FIFO pour communication bidirectionnelle
# =============================================================================

PORT="$1"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <PORT>"
    exit 1
fi

ARCHIVES_DIR="archives"
mkdir -p "$ARCHIVES_DIR"

FIFO="/tmp/vsh_server_$$"
rm -f "$FIFO"
mkfifo "$FIFO"

# Nettoyer le FIFO a la fermeture
cleanup() {
    rm -f "$FIFO"
    echo "[SERVER] Arret du serveur" >&2
    exit 0
}
trap cleanup EXIT INT TERM

echo "[SERVER] Serveur d'archives VSH demarre sur le port $PORT" >&2
echo "[SERVER] Repertoire des archives: $ARCHIVES_DIR" >&2
echo "[SERVER] Appuyez sur Ctrl+C pour arreter" >&2

# =============================================================================
# COMMANDES SERVEUR
# =============================================================================

commande_LIST() {
    local files=$(ls "$ARCHIVES_DIR" 2>/dev/null)
    if [ -z "$files" ]; then
        echo "(aucune archive)"
    else
        echo "$files"
    fi
}

commande_CREATE() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Nom de l'archive manquant"
        return
    fi
    # Lire le contenu jusqu'a END_ARCHIVE
    local content=""
    while IFS= read -r line; do
        [ "$line" = "END_ARCHIVE" ] && break
        content="${content}${line}"$'\n'
    done
    echo -n "$content" > "$ARCHIVES_DIR/$name"
    echo "OK: Archive '$name' creee"
    echo "[SERVER] Archive '$name' creee" >&2
}

commande_EXTRACT() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Nom de l'archive manquant"
        return
    fi
    if [ ! -f "$ARCHIVES_DIR/$name" ]; then
        echo "ERROR: Archive '$name' introuvable"
        return
    fi
    cat "$ARCHIVES_DIR/$name"
    echo "[SERVER] Archive '$name' envoyee" >&2
}

commande_DELETE() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Nom de l'archive manquant"
        return
    fi
    if [ ! -f "$ARCHIVES_DIR/$name" ]; then
        echo "ERROR: Archive '$name' introuvable"
        return
    fi
    rm -f "$ARCHIVES_DIR/$name"
    echo "OK: Archive '$name' supprimee"
    echo "[SERVER] Archive '$name' supprimee" >&2
}

commande_UPDATE() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Nom de l'archive manquant"
        return
    fi
    local content=""
    while IFS= read -r line; do
        [ "$line" = "END_ARCHIVE" ] && break
        content="${content}${line}"$'\n'
    done
    echo -n "$content" > "$ARCHIVES_DIR/$name"
    echo "OK: Archive '$name' mise a jour"
    echo "[SERVER] Archive '$name' mise a jour" >&2
}

commande_UNKNOWN() {
    echo "ERROR: Commande inconnue"
}

# =============================================================================
# TRAITEMENT D'UNE REQUETE
# =============================================================================

handle_request() {
    read -r line || return
    
    cmd="${line%% *}"
    args="${line#* }"
    [ "$cmd" = "$args" ] && args=""
    
    echo "[SERVER] Commande: $cmd $args" >&2
    
    case "$cmd" in
        LIST) commande_LIST ;;
        CREATE) commande_CREATE $args ;;
        EXTRACT) commande_EXTRACT $args ;;
        DELETE) commande_DELETE $args ;;
        UPDATE) commande_UPDATE $args ;;
        *) commande_UNKNOWN ;;
    esac
}

# =============================================================================
# BOUCLE PRINCIPALE - Communication bidirectionnelle via FIFO
# =============================================================================

while true; do
    nc -l -p "$PORT" < "$FIFO" | handle_request > "$FIFO" 2>/dev/null
done
