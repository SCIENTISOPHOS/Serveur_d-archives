#!/bin/bash
# =============================================================================
# Client VSH - LO14 Projet 2025-2026
# Shell pour explorer les archives sur le serveur
# =============================================================================

# =============================================================================
# VARIABLES GLOBALES
# =============================================================================

SERVER_HOST=""
SERVER_PORT=""
ARCHIVE_NAME=""
ARCHIVE_CONTENT=""
CURRENT_DIR="\\"

# =============================================================================
# FONCTIONS DE COMMUNICATION SERVEUR
# =============================================================================

send_command() {
    local cmd="$1"
    echo "$cmd" | nc -w 3 "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null
}

send_with_content() {
    local cmd="$1"
    local content="$2"
    {
        echo "$cmd"
        echo "$content"
        echo "END_ARCHIVE"
    } | nc -w 3 "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null
}

# =============================================================================
# FONCTIONS UTILITAIRES ARCHIVE
# =============================================================================

get_root_dir() {
    # Récupère la racine sans le backslash final pour concaténation propre
    echo "$ARCHIVE_CONTENT" | grep "^directory " | head -1 | sed 's/^directory //' | sed 's/\\$//'
}

normalize_path() {
    local path="$1"
    local current="$2"
    
    local full_path_to_analyze
    
    # Si chemin absolu (commence par \), on l'utilise tel quel
    if [[ "$path" == \\* ]]; then
        full_path_to_analyze="$path"
    else
        # Si relatif, on le colle au dossier courant
        if [ -z "$current" ] || [ "$current" = "\\" ]; then
            full_path_to_analyze="\\$path"
        else
            full_path_to_analyze="$current\\$path"
        fi
    fi
    
    local IFS='\\'
    local parts=()
    # On découpe le chemin complet
    read -ra segments <<< "${full_path_to_analyze#\\}"
    
    for seg in "${segments[@]}"; do
        [ -z "$seg" ] && continue
        if [ "$seg" = ".." ]; then
            # Gestion du retour arrière
            [ ${#parts[@]} -gt 0 ] && unset 'parts[${#parts[@]}-1]'
        elif [ "$seg" != "." ]; then
            parts+=("$seg")
        fi
    done
    
    if [ ${#parts[@]} -eq 0 ]; then
        echo "\\"
    else
        local res="\\"
        for p in "${parts[@]}"; do
            res="${res}${p}\\"
        done
        echo "${res%\\}"
    fi
}

vsh_to_archive_path() {
    local vsh_path="$1"
    local root_dir=$(get_root_dir)
    
    # Construit le chemin absolu tel qu'écrit dans le Header de l'archive
    if [ "$vsh_path" = "\\" ] || [ -z "$vsh_path" ]; then
        echo "${root_dir}\\"
    else
        # Enlève le premier \ du vsh_path pour éviter le doublon
        local clean_vsh="${vsh_path#\\}"
        echo "${root_dir}\\${clean_vsh}\\"
    fi
}

get_directory_content() {
    local dir_path="$1"
    local in_dir=0
    
    # Lit l'archive ligne par ligne
    while IFS= read -r line; do
        if [ "$in_dir" -eq 1 ]; then
            # Le caractère @ marque la fin d'un dossier
            [[ "$line" == "@"* ]] && break
            [ -n "$line" ] && echo "$line"
        elif [ "$line" = "directory $dir_path" ]; then
            in_dir=1
        fi
    done <<< "$ARCHIVE_CONTENT"
}

directory_exists() {
    # CORRECTION CRITIQUE : Utilisation de grep -F (Fixed string)
    # Les chemins contiennent des '\', que grep classique interprète mal.
    # L'option -x force la correspondance de la ligne entière.
    echo "$ARCHIVE_CONTENT" | grep -F -q -x "directory $1"
}

item_exists() {
    # On stocke le contenu d'abord pour éviter le bug du sous-shell (pipe)
    local content=$(get_directory_content "$2")
    
    # On cherche une ligne qui commence exactement par le nom suivi d'un espace
    # (Format archive : nom droits taille ...)
    echo "$content" | grep -q "^$1 "
}
# =============================================================================
# COMMANDES BROWSE
# =============================================================================

cmd_pwd() {
    echo "$CURRENT_DIR"
}

cmd_ls() {
    local show_long=0 show_all=0 target=""
    
    for arg in "$@"; do
        case "$arg" in
            -l) show_long=1 ;;
            -a) show_all=1 ;;
            -la|-al) show_long=1; show_all=1 ;;
            *) target="$arg" ;;
        esac
    done
    
    local list_path="$CURRENT_DIR"
    [ -n "$target" ] && list_path=$(normalize_path "$target" "$CURRENT_DIR")
    
    local archive_path=$(vsh_to_archive_path "$list_path")
    
    if ! directory_exists "$archive_path"; then
        echo "ls: impossible d'acceder a '$target': Aucun fichier ou dossier de ce type"
        return 1
    fi
    
    if [ "$show_all" -eq 1 ]; then
        if [ "$show_long" -eq 1 ]; then
            echo "drwxr-xr-x  4096  ."
            echo "drwxr-xr-x  4096  .."
        else
            printf ".  ..  "
        fi
    fi
    
    local content=$(get_directory_content "$archive_path")
    local output=""
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Parsing robuste : lit nom, perms, taille et le reste
        read -r name perms size rest <<< "$line"
        
        [ "$show_all" -eq 0 ] && [[ "$name" == .* ]] && continue
        
        # Gestion des suffixes demandés par le sujet
        local suffix=""
        if [[ "$perms" == d* ]]; then
            suffix="\\" 
        elif [[ "$perms" == *x* ]]; then
            suffix="*"
        fi
        
        if [ "$show_long" -eq 1 ]; then
            # Formatage aligné comme l'exemple du sujet [cite: 121]
            printf "%-11s %6s %s\n" "$perms" "$size" "$name"
        else
            # Construction de la ligne pour affichage court
            output="${output}${name}${suffix}  "
        fi
    done <<< "$content"
    
    [ "$show_long" -eq 0 ] && [ -n "$output" ] && echo "$output"
}

cmd_cd() {
    local target="$1"
    
    # Retour racine
    [ -z "$target" ] || [ "$target" = "\\" ] && { CURRENT_DIR="\\"; return 0; }
    
    local new_path=$(normalize_path "$target" "$CURRENT_DIR")
    local archive_path=$(vsh_to_archive_path "$new_path")
    
    if directory_exists "$archive_path"; then
        CURRENT_DIR="$new_path"
        return 0
    fi
    
    echo "cd: $target: Aucun fichier ou dossier de ce type"
    return 1
}

cmd_cat() {
    [ $# -eq 0 ] && { echo "cat: operande de fichier manquant"; return 1; }
    
    local info=$(echo "$ARCHIVE_CONTENT" | head -1)
    # Calcul offset réel du début du body
    local body_start=$(echo "$info" | cut -d':' -f2)
    
    for file in "$@"; do
        local file_path
        [[ "$file" == \\* ]] && file_path="$file" || file_path=$(normalize_path "$file" "$CURRENT_DIR")
        
        local dir_vsh=$(echo "$file_path" | sed 's/\\[^\\]*$//')
        local file_name=$(echo "$file_path" | sed 's/.*\\//')
        [ -z "$dir_vsh" ] && dir_vsh="\\"
        
        local archive_dir=$(vsh_to_archive_path "$dir_vsh")
        local content=$(get_directory_content "$archive_dir")
        local found=0
        
        # Parsing optimisé
        while read -r name perms size start_line num_lines; do
            if [ "$name" = "$file_name" ]; then
                found=1
                [[ "$perms" == d* ]] && { echo "cat: $file: Est un repertoire"; break; }
                
                if [ "$size" -gt 0 ] && [ -n "$start_line" ] && [ "$start_line" != "0" ]; then
                    local real_start=$((body_start + start_line - 1))
                    local real_end=$((real_start + num_lines - 1))
                    # Extraction précise des lignes
                    echo "$ARCHIVE_CONTENT" | sed -n "${real_start},${real_end}p"
                fi
                break
            fi
        done <<< "$content"
        
        [ "$found" -eq 0 ] && echo "cat: $file: Aucun fichier ou dossier de ce type"
    done
}

cmd_rm() {
    local target="$1"
    [ -z "$target" ] && { echo "rm: operande de fichier manquant"; return 1; }
    
    local file_path
    [[ "$target" == \\* ]] && file_path="$target" || file_path=$(normalize_path "$target" "$CURRENT_DIR")
    
    local dir_vsh=$(echo "$file_path" | sed 's/\\[^\\]*$//')
    local file_name=$(echo "$file_path" | sed 's/.*\\//')
    [ -z "$dir_vsh" ] && dir_vsh="\\"
    
    local archive_dir=$(vsh_to_archive_path "$dir_vsh")
    
    if ! item_exists "$file_name" "$archive_dir"; then
        echo "rm: impossible de supprimer '$target': Aucun fichier ou dossier de ce type"
        return 1
    fi
    
    local new_content=""
    local in_target_dir=0
    
    while IFS= read -r line; do
        if [ "$line" = "directory $archive_dir" ]; then
            in_target_dir=1
            new_content="${new_content}${line}"$'\n'
        elif [ "$in_target_dir" -eq 1 ] && [ "$line" = "@" ]; then
            in_target_dir=0
            new_content="${new_content}${line}"$'\n'
        elif [ "$in_target_dir" -eq 1 ]; then
            local entry_name=$(echo "$line" | awk '{print $1}')
            if [ "$entry_name" != "$file_name" ]; then
                new_content="${new_content}${line}"$'\n'
            fi
        else
            new_content="${new_content}${line}"$'\n'
        fi
    done <<< "$ARCHIVE_CONTENT"
    
    ARCHIVE_CONTENT="$new_content"
    send_with_content "UPDATE $ARCHIVE_NAME" "$ARCHIVE_CONTENT" >/dev/null 2>&1
    echo "Supprime: $target"
}

cmd_touch() {
    local target="$1"
    [ -z "$target" ] && { echo "touch: operande de fichier manquant"; return 1; }
    
    local file_path
    [[ "$target" == \\* ]] && file_path="$target" || file_path=$(normalize_path "$target" "$CURRENT_DIR")
    
    local dir_vsh=$(echo "$file_path" | sed 's/\\[^\\]*$//')
    local file_name=$(echo "$file_path" | sed 's/.*\\//')
    [ -z "$dir_vsh" ] && dir_vsh="\\"
    
    local archive_dir=$(vsh_to_archive_path "$dir_vsh")
    
    if ! directory_exists "$archive_dir"; then
        echo "touch: impossible de creer '$target': Repertoire parent inexistant"
        return 1
    fi
    
    if item_exists "$file_name" "$archive_dir"; then
        return 0
    fi
    
    local new_content=""
    while IFS= read -r line; do
        new_content="${new_content}${line}"$'\n'
        if [ "$line" = "directory $archive_dir" ]; then
            new_content="${new_content}${file_name} -rw-r--r-- 0"$'\n'
        fi
    done <<< "$ARCHIVE_CONTENT"
    
    ARCHIVE_CONTENT="$new_content"
    send_with_content "UPDATE $ARCHIVE_NAME" "$ARCHIVE_CONTENT" >/dev/null 2>&1
    echo "Cree: $target"
}

cmd_mkdir() {
    local use_p=0
    local target=""
    
    for arg in "$@"; do
        case "$arg" in
            -p) use_p=1 ;;
            *) target="$arg" ;;
        esac
    done
    
    [ -z "$target" ] && { echo "mkdir: operande manquant"; return 1; }
    
    local dir_path
    [[ "$target" == \\* ]] && dir_path="$target" || dir_path=$(normalize_path "$target" "$CURRENT_DIR")
    
    if [ "$use_p" -eq 1 ]; then
        local IFS='\\'
        local parts
        read -ra parts <<< "${dir_path#\\}"
        local current_path="\\"
        
        for part in "${parts[@]}"; do
            [ -z "$part" ] && continue
            [ "$current_path" = "\\" ] && current_path="\\$part" || current_path="$current_path\\$part"
            create_single_dir "$current_path" quiet
        done
        echo "Repertoire(s) cree(s): $target"
    else
        create_single_dir "$dir_path"
    fi
}

create_single_dir() {
    local target_path="$1"
    local quiet="$2"
    
    local parent_vsh=$(echo "$target_path" | sed 's/\\[^\\]*$//')
    local dir_name=$(echo "$target_path" | sed 's/.*\\//')
    [ -z "$parent_vsh" ] && parent_vsh="\\"
    
    local parent_archive=$(vsh_to_archive_path "$parent_vsh")
    local new_dir_archive=$(vsh_to_archive_path "$target_path")
    
    directory_exists "$new_dir_archive" && return 0
    
    if ! directory_exists "$parent_archive"; then
        [ -z "$quiet" ] && echo "mkdir: impossible de creer '$target_path': Repertoire parent inexistant"
        return 1
    fi
    
    local new_content=""
    local added_entry=0
    
    while IFS= read -r line; do
        new_content="${new_content}${line}"$'\n'
        
        if [ "$line" = "directory $parent_archive" ] && [ "$added_entry" -eq 0 ]; then
            new_content="${new_content}${dir_name} drwxr-xr-x 4096"$'\n'
            added_entry=1
        fi
        
        if [ "$line" = "@" ] && [ "$added_entry" -eq 1 ]; then
            new_content="${new_content}directory ${new_dir_archive}"$'\n'
            new_content="${new_content}@"$'\n'
            added_entry=2
        fi
    done <<< "$ARCHIVE_CONTENT"
    
    ARCHIVE_CONTENT="$new_content"
    send_with_content "UPDATE $ARCHIVE_NAME" "$ARCHIVE_CONTENT" >/dev/null 2>&1
    [ -z "$quiet" ] && echo "Repertoire cree: $dir_name"
}

# =============================================================================
# GENERATION D'ARCHIVE
# =============================================================================

generate_archive() {
    local base_dir="$1"
    local root_name=$(basename "$(cd "$base_dir" && pwd)")
    
    local header=""
    local body=""
    local body_line=1
    
    process_dir() {
        local dir="$1"
        local archive_path="$2"
        
        header="${header}directory ${archive_path}"$'\n'
        
        for item in "$dir"/* "$dir"/.*; do
            [ ! -e "$item" ] && continue
            local name=$(basename "$item")
            [ "$name" = "." ] || [ "$name" = ".." ] && continue
            
            local perms size
            if stat --version &>/dev/null; then
                perms=$(stat -c "%A" "$item" 2>/dev/null)
                size=$(stat -c "%s" "$item" 2>/dev/null)
            else
                perms=$(stat -f "%Sp" "$item" 2>/dev/null)
                size=$(stat -f "%z" "$item" 2>/dev/null)
            fi
            
            [ -z "$perms" ] && perms="-rw-r--r--"
            [ -z "$size" ] && size=0
            
            if [ -d "$item" ]; then
                header="${header}${name} d${perms:1} ${size:-4096}"$'\n'
            elif [ -f "$item" ]; then
                if [ "$size" -eq 0 ]; then
                    header="${header}${name} ${perms} 0"$'\n'
                else
                    local num_lines=$(wc -l < "$item" | tr -d ' ')
                    [ "$num_lines" -eq 0 ] && num_lines=1
                    header="${header}${name} ${perms} ${size} ${body_line} ${num_lines}"$'\n'
                    body="${body}$(cat "$item")"$'\n'
                    body_line=$((body_line + num_lines))
                fi
            fi
        done
        
        header="${header}@"$'\n'
        
        for item in "$dir"/*; do
            [ -d "$item" ] && process_dir "$item" "${archive_path}$(basename "$item")\\"
        done
    }
    
    process_dir "$base_dir" "${root_name}\\"
    
    local header_lines=$(echo -n "$header" | wc -l | tr -d ' ')
    local header_start=3
    local body_start=$((header_start + header_lines))
    
    echo "${header_start}:${body_start}"
    echo ""
    echo -n "$header"
    echo -n "$body"
}

# =============================================================================
# MODES
# =============================================================================

mode_list() {
    echo "=== Archives sur $SERVER_HOST:$SERVER_PORT ==="
    local response=$(send_command "LIST")
    if [ -z "$response" ]; then
        echo "Erreur: Impossible de contacter le serveur"
    else
        echo "$response"
    fi
}

mode_create() {
    echo "Creation de l'archive '$ARCHIVE_NAME'..."
    local archive_content=$(generate_archive "$(pwd)")
    local response=$(send_with_content "CREATE $ARCHIVE_NAME" "$archive_content")
    echo "$response"
}

mode_browse() {
    echo "Connexion au serveur $SERVER_HOST:$SERVER_PORT..."
    ARCHIVE_CONTENT=$(send_command "EXTRACT $ARCHIVE_NAME")
    
    if [ -z "$ARCHIVE_CONTENT" ]; then
        echo "Erreur: Impossible de recuperer l'archive. Verifiez que le serveur est demarre."
        exit 1
    fi
    
    if [[ "$ARCHIVE_CONTENT" == ERROR* ]]; then
        echo "$ARCHIVE_CONTENT"
        exit 1
    fi
    
    echo ""
    echo "=== Mode Browse: $ARCHIVE_NAME ==="
    echo "Commandes: pwd, ls [-l] [-a], cd, cat, rm, touch, mkdir [-p], exit"
    echo ""
    
    CURRENT_DIR="\\"
    
    while true; do
        printf "vsh:%s> " "$CURRENT_DIR"
        read -r input
        
        [ -z "$input" ] && continue
        
        local cmd=$(echo "$input" | awk '{print $1}')
        local args=$(echo "$input" | cut -d' ' -f2-)
        [ "$args" = "$cmd" ] && args=""
        
        case "$cmd" in
            pwd) cmd_pwd ;;
            ls) cmd_ls $args ;;
            cd) cmd_cd $args ;;
            cat) cmd_cat $args ;;
            rm) cmd_rm $args ;;
            touch) cmd_touch $args ;;
            mkdir) cmd_mkdir $args ;;
            help) echo "Commandes: pwd, ls [-l] [-a], cd, cat, rm, touch, mkdir [-p], exit" ;;
            exit|quit|q) echo "Fermeture."; break ;;
            *) echo "Commande inconnue: $cmd" ;;
        esac
    done
}

mode_extract() {
    echo "Extraction de '$ARCHIVE_NAME'..."
    ARCHIVE_CONTENT=$(send_command "EXTRACT $ARCHIVE_NAME")
    
    if [ -z "$ARCHIVE_CONTENT" ] || [[ "$ARCHIVE_CONTENT" == ERROR* ]]; then
        echo "Erreur: $ARCHIVE_CONTENT"
        exit 1
    fi
    
    local info=$(echo "$ARCHIVE_CONTENT" | head -1)
    local header_start=$(echo "$info" | cut -d':' -f1)
    local body_start=$(echo "$info" | cut -d':' -f2)
    local root_dir=$(get_root_dir)
    local current_archive_dir=""
    local line_num=0
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [ "$line_num" -lt "$header_start" ] && continue
        [ "$line_num" -ge "$body_start" ] && break
        
        if [[ "$line" == "directory "* ]]; then
            current_archive_dir=$(echo "$line" | sed 's/^directory //')
            local local_dir=$(echo "$current_archive_dir" | sed "s|^${root_dir}\\\\||" | tr '\\' '/')
            local_dir="${local_dir%/}"
            [ -n "$local_dir" ] && mkdir -p "./$local_dir" || mkdir -p "./$root_dir"
        elif [ "$line" != "@" ] && [ -n "$line" ]; then
            local name_f=$(echo "$line" | awk '{print $1}')
            local perms=$(echo "$line" | awk '{print $2}')
            local size=$(echo "$line" | awk '{print $3}')
            local file_start=$(echo "$line" | awk '{print $4}')
            local file_lines=$(echo "$line" | awk '{print $5}')
            
            [[ "$perms" == d* ]] && continue
            
            local local_dir=$(echo "$current_archive_dir" | sed "s|^${root_dir}\\\\||" | tr '\\' '/')
            local_dir="${local_dir%/}"
            [ -n "$local_dir" ] && local local_path="./$local_dir/$name_f" || local local_path="./$root_dir/$name_f"
            
            if [ "$size" -eq 0 ] || [ -z "$file_start" ]; then
                touch "$local_path"
            else
                local real_start=$((body_start + file_start - 1))
                local real_end=$((real_start + file_lines - 1))
                echo "$ARCHIVE_CONTENT" | sed -n "${real_start},${real_end}p" > "$local_path"
            fi
            echo "  $local_path"
        fi
    done <<< "$ARCHIVE_CONTENT"
    
    echo "Extraction terminee!"
}

# =============================================================================
# MAIN
# =============================================================================

usage() {
    echo "Usage:"
    echo "  $0 -list <serveur> <port>"
    echo "  $0 -create <serveur> <port> <nom_archive>"
    echo "  $0 -browse <serveur> <port> <nom_archive>"
    echo "  $0 -extract <serveur> <port> <nom_archive>"
}

[ $# -lt 1 ] && { usage; exit 1; }

MODE="$1"
SERVER_HOST="$2"
SERVER_PORT="$3"
ARCHIVE_NAME="$4"

case "$MODE" in
    -list)
        [ -z "$SERVER_HOST" ] || [ -z "$SERVER_PORT" ] && { usage; exit 1; }
        mode_list
        ;;
    -create)
        [ -z "$ARCHIVE_NAME" ] && { usage; exit 1; }
        mode_create
        ;;
    -browse)
        [ -z "$ARCHIVE_NAME" ] && { usage; exit 1; }
        mode_browse
        ;;
    -extract)
        [ -z "$ARCHIVE_NAME" ] && { usage; exit 1; }
        mode_extract
        ;;
    *)
        echo "Mode inconnu: $MODE"
        usage
        exit 1
        ;;
esac
