#!/usr/bin/env bash
# =============================================================================
# cohort360.sh : menu interactif pour lancer / redémarrer les composants Docker
#
# Usage :
#   ./cohort360.sh run       -> choisir un composant à démarrer (docker compose up -d)
#   ./cohort360.sh restart   -> choisir un composant à redémarrer et attendre qu'il soit prêt
#   ./cohort360.sh down      -> choisir un composant à arrêter (docker compose down)
#   ./cohort360.sh down-all  -> arrêter tous les composants (docker compose down)
#
# Navigation : flèches ↑/↓ pour se déplacer, Entrée pour valider, q pour quitter.
# =============================================================================
set -uo pipefail

# Dossier racine du workspace (là où se trouve ce script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="docker-compose.dev.yml"
# Temps max (en secondes) d'attente de la fin du redémarrage
RESTART_TIMEOUT=180

# Composants proposés dans le menu (même index dans les deux tableaux)
LABELS=("Front" "Back-end" "QueryExecutor" "AdministrationPortal" "Documentation")
FOLDERS=("Cohort360-FrontEnd" "Cohort360-Back-end" "Cohort360-QueryExecutor" "Cohort360-AdministrationPortal" "documentation")

# Couleurs
GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; BOLD=$'\e[1m'; REV=$'\e[7m'; RESET=$'\e[0m'

# Toujours réafficher le curseur en sortant (même avec Ctrl+C)
trap 'tput cnorm 2>/dev/null' EXIT

# Lance docker compose dans le dossier du composant
compose() {
    local folder="$1"; shift
    (cd "$ROOT_DIR/$folder" && docker compose -f "$COMPOSE_FILE" "$@")
}

# Vrai si au moins un conteneur du composant est en cours d'exécution
is_running() {
    [[ -n "$(compose "$1" ps -q --status running 2>/dev/null)" ]]
}

# Calcule le statut (démarré / non démarré) de chaque composant
STATUS=()
refresh_status() {
    local i
    for i in "${!FOLDERS[@]}"; do
        if is_running "${FOLDERS[$i]}"; then STATUS[$i]=1; else STATUS[$i]=0; fi
    done
}

# Affiche un menu avec les flèches et met l'index choisi dans SELECTED
# (SELECTED = -1 si l'utilisateur quitte)
SELECTED=0
menu() {
    local title="$1" key i label
    local count=$(( ${#LABELS[@]} + 1 ))   # +1 pour "Quitter"
    tput civis 2>/dev/null
    while true; do
        clear
        echo "${BOLD}============================${RESET}"
        echo "${BOLD}   $title${RESET}"
        echo "${BOLD}============================${RESET}"
        echo "  ↑/↓ : naviguer   Entrée : valider   q : quitter"
        echo
        for (( i = 0; i < count; i++ )); do
            if (( i < ${#LABELS[@]} )); then
                label="${LABELS[$i]}"
                (( STATUS[i] == 1 )) && label+=" ${GREEN}(démarré)${RESET}"
            else
                label="Quitter"
            fi
            if (( i == SELECTED )); then
                echo "  ${REV}> ${label}${RESET}"
            else
                echo "    ${label}"
            fi
        done

        IFS= read -rsn1 key
        if [[ $key == $'\e' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                "[A") SELECTED=$(( (SELECTED - 1 + count) % count )) ;;
                "[B") SELECTED=$(( (SELECTED + 1) % count )) ;;
            esac
        elif [[ $key == "" ]]; then
            break
        elif [[ $key == "q" ]]; then
            SELECTED=$(( count - 1 ))
            break
        fi
    done
    tput cnorm 2>/dev/null
    clear
    (( SELECTED == count - 1 )) && SELECTED=-1
}

# Attend que tous les conteneurs du composant soient "running" (et "healthy"
# s'ils ont un healthcheck). Retourne 1 en cas d'échec ou de timeout.
wait_ready() {
    local folder="$1" start=$SECONDS spin='|/-\' n=0
    local ids id state health all_ok
    ids=$(compose "$folder" ps -aq)
    [[ -z "$ids" ]] && return 1
    while true; do
        all_ok=1
        for id in $ids; do
            read -r state health < <(docker inspect -f \
                '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")
            # Conteneur arrêté / en crash : échec immédiat
            if [[ $state == "exited" || $state == "dead" || $health == "unhealthy" ]]; then
                printf '\r'; return 1
            fi
            if [[ $state != "running" ]] || [[ $health != "none" && $health != "healthy" ]]; then
                all_ok=0
            fi
        done
        (( all_ok )) && { printf '\r%-40s\r' ""; return 0; }
        (( SECONDS - start > RESTART_TIMEOUT )) && { printf '\r'; return 1; }
        printf '\r  Attente du redémarrage... %s' "${spin:n++%4:1}"
        sleep 1
    done
}

# make run : on boucle sur le menu pour pouvoir lancer plusieurs composants
cmd_run() {
    while true; do
        refresh_status
        menu "Cohort360 - Lancer"
        (( SELECTED < 0 )) && exit 0
        local label="${LABELS[$SELECTED]}" folder="${FOLDERS[$SELECTED]}"
        if (( STATUS[SELECTED] == 1 )); then
            echo "${YELLOW}$label est déjà démarré.${RESET}"
        else
            echo "Démarrage de ${BOLD}$label${RESET}..."
            if compose "$folder" up -d; then
                echo "${GREEN}✔ $label démarré.${RESET}"
            else
                echo "${RED}✘ Échec du démarrage de $label.${RESET}"
            fi
        fi
        sleep 1.5
    done
}

# make restart : redémarre un composant et attend qu'il soit prêt
cmd_restart() {
    refresh_status
    menu "Cohort360 - Redémarrer"
    (( SELECTED < 0 )) && exit 0
    local label="${LABELS[$SELECTED]}" folder="${FOLDERS[$SELECTED]}"
    if (( STATUS[SELECTED] == 0 )); then
        echo "${YELLOW}$label n'est pas démarré : lance-le d'abord avec 'make run'.${RESET}"
        exit 1
    fi
    echo "Redémarrage de ${BOLD}$label${RESET}..."
    if ! compose "$folder" restart; then
        echo "${RED}✘ Échec de la commande restart pour $label.${RESET}"
        exit 1
    fi
    if wait_ready "$folder"; then
        echo "${GREEN}✔ $label a bien redémarré.${RESET}"
        compose "$folder" ps
    else
        echo "${RED}✘ $label n'est pas prêt (crash, unhealthy ou timeout ${RESTART_TIMEOUT}s).${RESET}"
        echo "  Voir les logs : cd $folder && docker compose -f $COMPOSE_FILE logs --tail 50"
        exit 1
    fi
}

# make down : on boucle sur le menu pour pouvoir arrêter plusieurs composants
cmd_down() {
    while true; do
        refresh_status
        menu "Cohort360 - Arrêter"
        (( SELECTED < 0 )) && exit 0
        local label="${LABELS[$SELECTED]}" folder="${FOLDERS[$SELECTED]}"
        if (( STATUS[SELECTED] == 0 )); then
            echo "${YELLOW}$label n'est pas démarré.${RESET}"
        else
            echo "Arrêt de ${BOLD}$label${RESET}..."
            if compose "$folder" down; then
                echo "${GREEN}✔ $label arrêté.${RESET}"
            else
                echo "${RED}✘ Échec de l'arrêt de $label.${RESET}"
            fi
        fi
        sleep 1.5
    done
}

# make down-all : docker compose down sur tous les composants
cmd_down_all() {
    local i failed=0
    for i in "${!FOLDERS[@]}"; do
        echo "Arrêt de ${BOLD}${LABELS[$i]}${RESET}..."
        if compose "${FOLDERS[$i]}" down; then
            echo "${GREEN}✔ ${LABELS[$i]} arrêté.${RESET}"
        else
            echo "${RED}✘ Échec de l'arrêt de ${LABELS[$i]}.${RESET}"
            failed=1
        fi
    done
    (( failed )) && exit 1
    echo "${GREEN}✔ Tous les composants sont arrêtés.${RESET}"
}

case "${1:-}" in
    run)      cmd_run ;;
    restart)  cmd_restart ;;
    down)     cmd_down ;;
    down-all) cmd_down_all ;;
    *)        echo "Usage : $0 {run|restart|down|down-all}"; exit 1 ;;
esac
