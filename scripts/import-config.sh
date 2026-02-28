#!/bin/bash
#==============================================================================
# Import configuration via API
# Lit les fichiers JSON nettoyés depuis ./config-exports/
# et les pousse vers les APIs Prowlarr, Radarr, Sonarr, qBittorrent
#==============================================================================

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Charger .env depuis la racine du projet
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
[ -f .env ] && export $(grep -v '^#' .env | xargs)

CONFIG_DIR="./config-exports"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                Import Configuration                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

[ ! -d "$CONFIG_DIR" ] && { echo -e "${RED}$CONFIG_DIR manquant — lancez d'abord: make export${NC}"; exit 1; }

# Compteurs
TOTAL_OK=0
TOTAL_FAIL=0

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

wait_for_service() {
    local url="$1"
    local name="$2"
    local api_key="$3"
    local attempt=0

    echo -e "${YELLOW}  Attente $name...${NC}"
    while [ $attempt -lt 30 ]; do
        if [ -n "$api_key" ]; then
            code=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $api_key" "$url" 2>/dev/null)
        else
            code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        fi
        [ "$code" = "200" ] && { echo -e "  ${GREEN}$name pret${NC}"; return 0; }
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e "  ${RED}$name timeout (60s)${NC}"
    return 1
}

# Import un tableau d'objets via POST
import_array() {
    local file="$1"
    local endpoint="$2"
    local api_key="$3"
    local label="$4"
    local name_field="${5:-.name}"

    [ ! -f "$file" ] && return
    local count=$(jq 'length' "$file")
    [ "$count" = "0" ] && { echo -e "  ${YELLOW}  skip${NC} $label (vide)"; return; }

    echo -e "${YELLOW}  > $label ($count elements)...${NC}"
    for i in $(seq 0 $((count - 1))); do
        local item=$(jq ".[$i]" "$file")
        local name=$(echo "$item" | jq -r "$name_field // \"item-$i\"")

        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "X-Api-Key: $api_key" \
            -H "Content-Type: application/json" \
            -d "$item" \
            "$endpoint")

        http_code=$(echo "$response" | tail -1)
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
            echo -e "    ${GREEN}ok${NC} $name"
            TOTAL_OK=$((TOTAL_OK + 1))
        else
            error_msg=$(echo "$body" | jq -r '.[0].errorMessage // .message // "unknown"' 2>/dev/null)
            echo -e "    ${RED}FAIL${NC} $name (HTTP $http_code: $error_msg)"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
        fi
    done
}

# Import un objet unique via PUT (naming, mediamanagement)
import_object() {
    local file="$1"
    local endpoint="$2"
    local api_key="$3"
    local label="$4"

    [ ! -f "$file" ] && return

    echo -e "${YELLOW}  > $label...${NC}"

    # GET l'existant pour recuperer l'ID serveur
    existing=$(curl -s -H "X-Api-Key: $api_key" "$endpoint" 2>/dev/null)
    existing_id=$(echo "$existing" | jq '.id // empty' 2>/dev/null)

    local data=$(cat "$file")
    if [ -n "$existing_id" ]; then
        data=$(echo "$data" | jq ".id = $existing_id")
    fi

    response=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$endpoint")

    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        echo -e "    ${GREEN}ok${NC} $label"
        TOTAL_OK=$((TOTAL_OK + 1))
    else
        body=$(echo "$response" | sed '$d')
        echo -e "    ${RED}FAIL${NC} $label (HTTP $http_code)"
        echo "$body" | jq '.' 2>/dev/null | head -5
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

#==============================================================================
# PROWLARR
#==============================================================================
echo -e "\n${BLUE}--- Prowlarr ---${NC}"

if [ -z "$PROWLARR_API_KEY" ]; then
    echo -e "${RED}  PROWLARR_API_KEY manquante dans .env${NC}"
else
    if wait_for_service "http://localhost:9696/api/v1/health" "Prowlarr" "$PROWLARR_API_KEY"; then
        import_array "$CONFIG_DIR/prowlarr-indexers.json" \
            "http://localhost:9696/api/v1/indexer" "$PROWLARR_API_KEY" "Indexeurs"

        import_array "$CONFIG_DIR/prowlarr-applications.json" \
            "http://localhost:9696/api/v1/applications" "$PROWLARR_API_KEY" "Applications"

        import_array "$CONFIG_DIR/prowlarr-downloadclients.json" \
            "http://localhost:9696/api/v1/downloadclient" "$PROWLARR_API_KEY" "Download clients"
    fi
fi

#==============================================================================
# RADARR
#==============================================================================
echo -e "\n${BLUE}--- Radarr ---${NC}"

if [ -z "$RADARR_API_KEY" ]; then
    echo -e "${RED}  RADARR_API_KEY manquante dans .env${NC}"
else
    if wait_for_service "http://localhost:7878/api/v3/health" "Radarr" "$RADARR_API_KEY"; then
        import_array "$CONFIG_DIR/radarr-rootfolders.json" \
            "http://localhost:7878/api/v3/rootfolder" "$RADARR_API_KEY" "Root folders" ".path"

        import_array "$CONFIG_DIR/radarr-customformats.json" \
            "http://localhost:7878/api/v3/customformat" "$RADARR_API_KEY" "Custom formats"

        import_array "$CONFIG_DIR/radarr-qualityprofiles.json" \
            "http://localhost:7878/api/v3/qualityprofile" "$RADARR_API_KEY" "Quality profiles"

        import_array "$CONFIG_DIR/radarr-downloadclients.json" \
            "http://localhost:7878/api/v3/downloadclient" "$RADARR_API_KEY" "Download clients"

        import_array "$CONFIG_DIR/radarr-indexers.json" \
            "http://localhost:7878/api/v3/indexer" "$RADARR_API_KEY" "Indexers"

        import_object "$CONFIG_DIR/radarr-naming.json" \
            "http://localhost:7878/api/v3/config/naming" "$RADARR_API_KEY" "Naming"

        import_object "$CONFIG_DIR/radarr-mediamanagement.json" \
            "http://localhost:7878/api/v3/config/mediamanagement" "$RADARR_API_KEY" "Media management"
    fi
fi

#==============================================================================
# SONARR
#==============================================================================
echo -e "\n${BLUE}--- Sonarr ---${NC}"

if [ -z "$SONARR_API_KEY" ]; then
    echo -e "${RED}  SONARR_API_KEY manquante dans .env${NC}"
else
    if wait_for_service "http://localhost:8989/api/v3/health" "Sonarr" "$SONARR_API_KEY"; then
        import_array "$CONFIG_DIR/sonarr-rootfolders.json" \
            "http://localhost:8989/api/v3/rootfolder" "$SONARR_API_KEY" "Root folders" ".path"

        import_array "$CONFIG_DIR/sonarr-customformats.json" \
            "http://localhost:8989/api/v3/customformat" "$SONARR_API_KEY" "Custom formats"

        import_array "$CONFIG_DIR/sonarr-qualityprofiles.json" \
            "http://localhost:8989/api/v3/qualityprofile" "$SONARR_API_KEY" "Quality profiles"

        import_array "$CONFIG_DIR/sonarr-downloadclients.json" \
            "http://localhost:8989/api/v3/downloadclient" "$SONARR_API_KEY" "Download clients"

        import_array "$CONFIG_DIR/sonarr-indexers.json" \
            "http://localhost:8989/api/v3/indexer" "$SONARR_API_KEY" "Indexers"

        import_object "$CONFIG_DIR/sonarr-naming.json" \
            "http://localhost:8989/api/v3/config/naming" "$SONARR_API_KEY" "Naming"

        import_object "$CONFIG_DIR/sonarr-mediamanagement.json" \
            "http://localhost:8989/api/v3/config/mediamanagement" "$SONARR_API_KEY" "Media management"
    fi
fi

#==============================================================================
# QBITTORRENT
#==============================================================================
echo -e "\n${BLUE}--- qBittorrent ---${NC}"

if [ -f "$CONFIG_DIR/qbittorrent-preferences.json" ]; then
    echo -e "${YELLOW}  Attente qBittorrent...${NC}"
    qbit_ready=false
    for i in $(seq 1 30); do
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8090/api/v2/app/version" 2>/dev/null)
        [ "$code" = "200" ] && { qbit_ready=true; break; }
        sleep 2
    done

    if [ "$qbit_ready" = true ]; then
        echo -e "  ${GREEN}qBittorrent pret${NC}"

        # Login avec cookie jar
        QBIT_SID=$(curl -s -c - --data "username=admin&password=${QBITTORRENT_PASSWORD:-admin}" \
            "http://localhost:8090/api/v2/auth/login" 2>/dev/null | grep SID | awk '{print $NF}')

        if [ -n "$QBIT_SID" ]; then
            # API qBit: parametre "json" contenant le JSON des preferences
            prefs_json=$(cat "$CONFIG_DIR/qbittorrent-preferences.json")

            response=$(curl -s -w "%{http_code}" -o /dev/null \
                -b "SID=$QBIT_SID" \
                --data-urlencode "json=$prefs_json" \
                "http://localhost:8090/api/v2/app/setPreferences")

            if [ "$response" = "200" ]; then
                echo -e "  ${GREEN}ok${NC} Preferences importees"
                TOTAL_OK=$((TOTAL_OK + 1))
            else
                echo -e "  ${RED}FAIL${NC} Preferences (HTTP $response)"
                TOTAL_FAIL=$((TOTAL_FAIL + 1))
            fi
        else
            echo -e "  ${RED}FAIL${NC} Login qBittorrent echoue"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
        fi
    else
        echo -e "  ${RED}FAIL${NC} qBittorrent timeout"
    fi
else
    echo -e "  ${YELLOW}skip${NC} Pas de qbittorrent-preferences.json"
fi

#==============================================================================
# Resume
#==============================================================================
echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Succes : $TOTAL_OK${NC}  |  ${RED}Echecs : $TOTAL_FAIL${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

if [ $TOTAL_FAIL -gt 0 ]; then
    echo -e "${YELLOW}Certains imports ont echoue. Causes possibles :${NC}"
    echo -e "  - Quality profiles referençant des custom formats manquants"
    echo -e "  - Indexers avec credentials expires"
    echo -e "  - Custom formats geres par Recyclarr (doublons normaux)"
    echo -e ""
    echo -e "${YELLOW}Conseil : lancez 'make restore' pour completer avec Recyclarr${NC}"
fi
