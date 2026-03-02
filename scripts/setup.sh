#!/bin/bash
#==============================================================================
# Setup automatique complet — Stack Media Server
# Configure tout via CLI : structure, API keys, auth *arr, Jellyfin wizard,
# bibliothèques, import config, VPN check
#==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

# ── Charger le .env ─────────────────────────────────────────────────────
if [ ! -f .env ]; then
    echo -e "${YELLOW}📋 .env manquant — création depuis .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}❌ Éditez .env et ajoutez vos credentials, puis relancez.${NC}"
    exit 0
fi

set -a
. .env
set +a

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Setup Media Server — Installation          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# ── Vérifications ────────────────────────────────────────────────────────
echo -e "${YELLOW}🔍 Vérifications préalables...${NC}"
command -v docker >/dev/null    || { echo -e "${RED}❌ Docker manquant${NC}"; exit 1; }
command -v docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null || { echo -e "${RED}❌ docker-compose manquant${NC}"; exit 1; }
command -v jq >/dev/null       || { echo -e "${RED}❌ jq manquant — brew install jq${NC}"; exit 1; }
command -v curl >/dev/null     || { echo -e "${RED}❌ curl manquant${NC}"; exit 1; }

# Choisir le bon binaire compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi
echo -e "${GREEN}✅ Dépendances OK${NC}\n"

#==============================================================================
# ÉTAPE 1 : Structure de dossiers
#==============================================================================
echo -e "${YELLOW}📁 [1/7] Création structure de dossiers...${NC}"
mkdir -p "${DATA_PATH}/downloads"/{incomplete,complete}
mkdir -p "${DATA_PATH}/media"/{movies,tv}
mkdir -p ./backups ./config-exports ./prowlarr ./radarr ./sonarr
echo -e "${GREEN}✅ Structure créée${NC}\n"

#==============================================================================
# ÉTAPE 2 : Génération des config.xml (API keys depuis .env)
#==============================================================================
echo -e "${YELLOW}🔑 [2/7] Génération des config.xml (API keys)...${NC}"

generate_key() { openssl rand -hex 16; }

PROWLARR_API_KEY="${PROWLARR_API_KEY:-$(generate_key)}"
RADARR_API_KEY="${RADARR_API_KEY:-$(generate_key)}"
SONARR_API_KEY="${SONARR_API_KEY:-$(generate_key)}"

sed "s|%%PROWLARR_API_KEY%%|${PROWLARR_API_KEY}|g" \
    config-templates/prowlarr-config.xml > ./prowlarr/config.xml

sed "s|%%RADARR_API_KEY%%|${RADARR_API_KEY}|g" \
    config-templates/radarr-config.xml > ./radarr/config.xml

sed "s|%%SONARR_API_KEY%%|${SONARR_API_KEY}|g" \
    config-templates/sonarr-config.xml > ./sonarr/config.xml

echo -e "  ${GREEN}✓ Prowlarr config.xml${NC}"
echo -e "  ${GREEN}✓ Radarr   config.xml${NC}"
echo -e "  ${GREEN}✓ Sonarr   config.xml${NC}"

# Persister les clés dans .env
for VAR_NAME in PROWLARR_API_KEY RADARR_API_KEY SONARR_API_KEY; do
    VAR_VALUE="${!VAR_NAME}"
    if ! grep -q "^${VAR_NAME}=" .env; then
        echo "${VAR_NAME}=${VAR_VALUE}" >> .env
    else
        sed -i.bak "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" .env
    fi
done
rm -f .env.bak
echo -e "${GREEN}✅ API keys sauvegardées dans .env${NC}\n"

#==============================================================================
# ÉTAPE 3 : Démarrage des conteneurs
#==============================================================================
echo -e "${YELLOW}🐳 [3/7] Démarrage des conteneurs...${NC}"
$COMPOSE up -d --remove-orphans
echo -e "${GREEN}✅ Conteneurs lancés${NC}\n"

#==============================================================================
# ÉTAPE 4 : Attente des services
#==============================================================================
echo -e "${YELLOW}⏳ [4/7] Attente du démarrage des services...${NC}"

wait_for_service() {
    local NAME=$1 URL=$2 MAX_WAIT=${3:-60}
    local COUNT=0
    while ! curl -sf "$URL" > /dev/null 2>&1; do
        COUNT=$((COUNT + 1))
        if [ $COUNT -ge $MAX_WAIT ]; then
            echo -e "  ${RED}✗ $NAME ne répond pas après ${MAX_WAIT}s${NC}"
            return 1
        fi
        sleep 1
    done
    echo -e "  ${GREEN}✓ $NAME prêt${NC}"
}

wait_for_service "Radarr"   "http://localhost:7878/api/v3/system/status?apikey=${RADARR_API_KEY}" 90
wait_for_service "Sonarr"   "http://localhost:8989/api/v3/system/status?apikey=${SONARR_API_KEY}" 90
wait_for_service "Prowlarr" "http://localhost:9696/api/v1/system/status?apikey=${PROWLARR_API_KEY}" 90
wait_for_service "Jellyfin" "http://localhost:8096/health" 90
echo -e "${GREEN}✅ Services prêts${NC}\n"

#==============================================================================
# ÉTAPE 5 : Auth Radarr / Sonarr / Prowlarr
#==============================================================================
echo -e "${YELLOW}🔐 [5/7] Configuration authentification *arr...${NC}"

configure_arr_auth() {
    local NAME=$1 HOST=$2 KEY=$3 API_VER=$4

    local CONF
    CONF=$(curl -sf "$HOST/api/$API_VER/config/host" -H "X-Api-Key: $KEY") || {
        echo -e "  ${RED}✗ $NAME — impossible de lire la config${NC}"; return 1
    }

    echo "$CONF" | python3 -c "
import sys, json
c = json.load(sys.stdin)
c['username'] = '$ADMIN_USER'
c['password'] = '$ADMIN_PASSWORD'
c['passwordConfirmation'] = '$ADMIN_PASSWORD'
c['authenticationMethod'] = 'forms'
c['authenticationRequired'] = 'disabledForLocalAddresses'
json.dump(c, sys.stdout)
" | curl -sf -o /dev/null -w "" -X PUT "$HOST/api/$API_VER/config/host" \
        -H "X-Api-Key: $KEY" \
        -H "Content-Type: application/json" \
        -d @- 2>/dev/null

    echo -e "  ${GREEN}✓ $NAME — user: $ADMIN_USER (forms + local bypass)${NC}"
}

configure_arr_auth "Radarr"   "http://localhost:7878" "$RADARR_API_KEY"   "v3"
configure_arr_auth "Sonarr"   "http://localhost:8989" "$SONARR_API_KEY"   "v3"
configure_arr_auth "Prowlarr" "http://localhost:9696" "$PROWLARR_API_KEY" "v1"

echo -e "${GREEN}✅ Auth *arr configurée${NC}\n"

#==============================================================================
# ÉTAPE 6 : Configuration Jellyfin (wizard + bibliothèques)
#==============================================================================
echo -e "${YELLOW}🎬 [6/7] Configuration Jellyfin...${NC}"

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
JELLYFIN_HOST="${JELLYFIN_HOST:-http://localhost:8096}"
JELLYFIN_SERVER_NAME="${JELLYFIN_SERVER_NAME:-Media Server}"
JELLYFIN_LANG="${JELLYFIN_LANG:-fr}"
JELLYFIN_COUNTRY="${JELLYFIN_COUNTRY:-FR}"
MOVIES_PATH="/data/media/movies"
TV_PATH="/data/media/tv"

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}🔑 Mot de passe admin :${NC}"
    read -s -p "  Password: " ADMIN_PASSWORD
    echo ""
fi

# Vérifier si le wizard est encore actif
STARTUP_CHECK=$(curl -sf "${JELLYFIN_HOST}/Startup/Configuration" 2>/dev/null) || true

if [ -n "$STARTUP_CHECK" ]; then
    # ── Wizard : langue + métadonnées ────────────────────────────────
    echo -e "  ${YELLOW}→ Langue & métadonnées (${JELLYFIN_LANG}/${JELLYFIN_COUNTRY})...${NC}"
    curl -sf -X POST "${JELLYFIN_HOST}/Startup/Configuration" \
        -H "Content-Type: application/json" \
        -d "{
            \"UICulture\": \"${JELLYFIN_LANG}\",
            \"MetadataCountryCode\": \"${JELLYFIN_COUNTRY}\",
            \"PreferredMetadataLanguage\": \"${JELLYFIN_LANG}\"
        }" > /dev/null

    # ── Wizard : utilisateur admin ───────────────────────────────────
    echo -e "  ${YELLOW}→ Création utilisateur admin...${NC}"
    RETRY=0
    while [ $RETRY -lt 15 ]; do
        FIRST_USER=$(curl -sf "${JELLYFIN_HOST}/Startup/User" 2>/dev/null || echo "")
        echo "$FIRST_USER" | grep -q '"Name"' && break
        RETRY=$((RETRY + 1))
        sleep 2
    done

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${JELLYFIN_HOST}/Startup/User" \
        -H "Content-Type: application/json" \
        -d "{\"Name\":\"${ADMIN_USER}\",\"Password\":\"${ADMIN_PASSWORD}\"}")

    WIZARD_FIRST=false
    [ "$HTTP_CODE" != "204" ] && [ "$HTTP_CODE" != "200" ] && WIZARD_FIRST=true

    # ── Wizard : accès distant + compléter ───────────────────────────
    curl -sf -X POST "${JELLYFIN_HOST}/Startup/RemoteAccess" \
        -H "Content-Type: application/json" \
        -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' > /dev/null

    curl -sf -X POST "${JELLYFIN_HOST}/Startup/Complete" > /dev/null
    echo -e "  ${GREEN}✓ Wizard complété${NC}"

    # ── Authentification ─────────────────────────────────────────────
    AUTH_USER="${ADMIN_USER}"
    AUTH_PW="${ADMIN_PASSWORD}"
    [ "${WIZARD_FIRST}" = "true" ] && AUTH_USER="root" && AUTH_PW=""

    AUTH_RESPONSE=$(curl -sf -X POST "${JELLYFIN_HOST}/Users/AuthenticateByName" \
        -H "Content-Type: application/json" \
        -H "X-Emby-Authorization: MediaBrowser Client=\"Setup\", Device=\"CLI\", DeviceId=\"setup\", Version=\"1.0\"" \
        -d "{\"Username\":\"${AUTH_USER}\",\"Pw\":\"${AUTH_PW}\"}" 2>/dev/null || echo "")

    JF_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)
    JF_USER_ID=$(echo "$AUTH_RESPONSE" | grep -o '"Id":"[^"]*"' | head -1 | cut -d'"' -f4)
    JF_AUTH="MediaBrowser Token=\"${JF_TOKEN}\""

    # Fallback : renommer user + définir mot de passe
    if [ "${WIZARD_FIRST}" = "true" ] && [ -n "$JF_USER_ID" ] && [ -n "$JF_TOKEN" ]; then
        USER_PROFILE=$(curl -sf "${JELLYFIN_HOST}/Users/${JF_USER_ID}" -H "X-Emby-Authorization: ${JF_AUTH}")
        echo "$USER_PROFILE" | sed "s/\"Name\":\"[^\"]*\"/\"Name\":\"${ADMIN_USER}\"/" | \
        curl -sf -X POST "${JELLYFIN_HOST}/Users/${JF_USER_ID}" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: ${JF_AUTH}" -d @- > /dev/null 2>&1

        curl -sf -X POST "${JELLYFIN_HOST}/Users/${JF_USER_ID}/Password" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: ${JF_AUTH}" \
            -d "{\"CurrentPw\":\"\",\"NewPw\":\"${ADMIN_PASSWORD}\"}" > /dev/null 2>&1

        # Re-auth
        AUTH_RESPONSE=$(curl -sf -X POST "${JELLYFIN_HOST}/Users/AuthenticateByName" \
            -H "Content-Type: application/json" \
            -H "X-Emby-Authorization: MediaBrowser Client=\"Setup\", Device=\"CLI\", DeviceId=\"setup\", Version=\"1.0\"" \
            -d "{\"Username\":\"${ADMIN_USER}\",\"Pw\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "")
        JF_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)
        JF_AUTH="MediaBrowser Token=\"${JF_TOKEN}\""
        echo -e "  ${GREEN}✓ Utilisateur '${ADMIN_USER}' configuré (fallback)${NC}"
    fi

    if [ -n "$JF_TOKEN" ]; then
        echo -e "  ${GREEN}✓ Authentifié en tant que '${ADMIN_USER}'${NC}"

        # ── Bibliothèques ────────────────────────────────────────────
        echo -e "  ${YELLOW}→ Ajout bibliothèques...${NC}"
        curl -sf -X POST "${JELLYFIN_HOST}/Library/VirtualFolders?name=Films&collectionType=movies&refreshLibrary=false" \
            -H "Content-Type: application/json" -H "X-Emby-Authorization: ${JF_AUTH}" \
            -d "{\"LibraryOptions\":{\"EnableRealtimeMonitor\":true,\"EnableAutomaticSeriesGrouping\":true,\"PreferredMetadataLanguage\":\"${JELLYFIN_LANG}\",\"MetadataCountryCode\":\"${JELLYFIN_COUNTRY}\",\"PathInfos\":[{\"Path\":\"${MOVIES_PATH}\"}]}}" > /dev/null 2>&1 \
            && echo -e "  ${GREEN}✓ Films → ${MOVIES_PATH}${NC}" \
            || echo -e "  ${YELLOW}⚠  Films déjà existante${NC}"

        curl -sf -X POST "${JELLYFIN_HOST}/Library/VirtualFolders?name=S%C3%A9ries&collectionType=tvshows&refreshLibrary=false" \
            -H "Content-Type: application/json" -H "X-Emby-Authorization: ${JF_AUTH}" \
            -d "{\"LibraryOptions\":{\"EnableRealtimeMonitor\":true,\"EnableAutomaticSeriesGrouping\":true,\"PreferredMetadataLanguage\":\"${JELLYFIN_LANG}\",\"MetadataCountryCode\":\"${JELLYFIN_COUNTRY}\",\"PathInfos\":[{\"Path\":\"${TV_PATH}\"}]}}" > /dev/null 2>&1 \
            && echo -e "  ${GREEN}✓ Séries → ${TV_PATH}${NC}" \
            || echo -e "  ${YELLOW}⚠  Séries déjà existante${NC}"

        # ── Scan + nom serveur ───────────────────────────────────────
        curl -sf -X POST "${JELLYFIN_HOST}/Library/Refresh" -H "X-Emby-Authorization: ${JF_AUTH}" > /dev/null 2>&1

        SERVER_CONFIG=$(curl -sf "${JELLYFIN_HOST}/System/Configuration" -H "X-Emby-Authorization: ${JF_AUTH}" 2>/dev/null || echo "")
        if [ -n "$SERVER_CONFIG" ]; then
            echo "$SERVER_CONFIG" | sed "s/\"ServerName\":\"[^\"]*\"/\"ServerName\":\"${JELLYFIN_SERVER_NAME}\"/" | \
            curl -sf -X POST "${JELLYFIN_HOST}/System/Configuration" \
                -H "Content-Type: application/json" -H "X-Emby-Authorization: ${JF_AUTH}" -d @- > /dev/null 2>&1
        fi
        echo -e "  ${GREEN}✓ Serveur : ${JELLYFIN_SERVER_NAME}${NC}"
    else
        echo -e "  ${YELLOW}⚠  Auth Jellyfin échouée — configurez via ${JELLYFIN_HOST}${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠  Jellyfin déjà configuré (wizard complété)${NC}"
fi

echo -e "${GREEN}✅ Jellyfin configuré${NC}\n"

#==============================================================================
# ÉTAPE 7 : Import config existante + VPN check
#==============================================================================
echo -e "${YELLOW}📦 [7/7] Import configuration & vérification VPN...${NC}"

if [ -d "./config-exports" ] && [ "$(ls -A ./config-exports 2>/dev/null)" ]; then
    if [ -f "./scripts/import-config.sh" ]; then
        bash ./scripts/import-config.sh 2>&1 | tail -5
        echo -e "  ${GREEN}✓ Configuration importée${NC}"
    fi
fi

VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "N/A")

# ── Résumé final ─────────────────────────────────────────────────────────
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ✅ Installation terminée !                 ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} VPN IP       : ${GREEN}${VPN_IP}${NC}"
echo -e "${BLUE}║${NC} Admin        : ${GREEN}${ADMIN_USER}${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} Jellyfin     : ${GREEN}http://localhost:8096${NC}"
echo -e "${BLUE}║${NC} Jellyseerr   : ${GREEN}http://localhost:5055${NC}"
echo -e "${BLUE}║${NC} Jellystat    : ${GREEN}http://localhost:3000${NC}"
echo -e "${BLUE}║${NC} Radarr       : ${GREEN}http://localhost:7878${NC}"
echo -e "${BLUE}║${NC} Sonarr       : ${GREEN}http://localhost:8989${NC}"
echo -e "${BLUE}║${NC} Prowlarr     : ${GREEN}http://localhost:9696${NC}"
echo -e "${BLUE}║${NC} qBittorrent  : ${GREEN}http://localhost:8090${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} ${YELLOW}Prochaines étapes :${NC}"
echo -e "${BLUE}║${NC}  1. Plugin Trakt : Dashboard > Plugins > Catalogue"
echo -e "${BLUE}║${NC}  2. Jellyseerr   : connecter Jellyfin + Radarr/Sonarr"
echo -e "${BLUE}║${NC}  3. Jellystat    : connecter à Jellyfin (API key)"
echo -e "${BLUE}║${NC}  4. Infuse 8     : ajouter serveur Jellyfin"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
