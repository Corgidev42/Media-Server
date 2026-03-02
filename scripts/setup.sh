#!/bin/bash
#==============================================================================
# Setup automatique complet — ArrStack
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
echo -e "${BLUE}║             ArrStack — Installation                 ║${NC}"
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
# Jackett vérifié plus tard via docker exec (API protégée par cookie)
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
# ÉTAPE 5b : Configuration FlareSolverr + indexeurs Prowlarr
#==============================================================================
echo -e "${YELLOW}🔥 [5b/7] Configuration FlareSolverr + indexeurs...${NC}"

PROWLARR_HOST="http://localhost:9696"

# Créer le tag flaresolverr (idempotent)
EXISTING_TAGS=$(curl -sf -H "X-Api-Key: $PROWLARR_API_KEY" "$PROWLARR_HOST/api/v1/tag" 2>/dev/null || echo "[]")
FS_TAG_ID=$(echo "$EXISTING_TAGS" | jq -r '.[] | select(.label == "flaresolverr") | .id')

if [ -z "$FS_TAG_ID" ]; then
    FS_TAG_ID=$(curl -sf -X POST -H "X-Api-Key: $PROWLARR_API_KEY" -H "Content-Type: application/json" \
        -d '{"label":"flaresolverr"}' "$PROWLARR_HOST/api/v1/tag" | jq '.id')
    echo -e "  ${GREEN}✓ Tag 'flaresolverr' créé (ID: $FS_TAG_ID)${NC}"
else
    echo -e "  ${GREEN}✓ Tag 'flaresolverr' existe (ID: $FS_TAG_ID)${NC}"
fi

# Créer le proxy FlareSolverr (idempotent)
EXISTING_PROXIES=$(curl -sf -H "X-Api-Key: $PROWLARR_API_KEY" "$PROWLARR_HOST/api/v1/indexerProxy" 2>/dev/null || echo "[]")
FS_PROXY_EXISTS=$(echo "$EXISTING_PROXIES" | jq '[.[] | select(.implementation == "FlareSolverr")] | length')

if [ "$FS_PROXY_EXISTS" = "0" ]; then
    curl -sf -X POST -H "X-Api-Key: $PROWLARR_API_KEY" -H "Content-Type: application/json" \
        -d "{
            \"name\": \"FlareSolverr\",
            \"implementation\": \"FlareSolverr\",
            \"configContract\": \"FlareSolverrSettings\",
            \"fields\": [
                {\"name\": \"host\", \"value\": \"http://flaresolverr:8191/\"},
                {\"name\": \"requestTimeout\", \"value\": 60}
            ],
            \"tags\": [$FS_TAG_ID]
        }" "$PROWLARR_HOST/api/v1/indexerProxy" > /dev/null 2>&1
    echo -e "  ${GREEN}✓ Proxy FlareSolverr configuré (→ flaresolverr:8191)${NC}"
else
    echo -e "  ${GREEN}✓ Proxy FlareSolverr déjà configuré${NC}"
fi

# Ajouter 1337x avec tag FlareSolverr (idempotent)
EXISTING_INDEXERS=$(curl -sf -H "X-Api-Key: $PROWLARR_API_KEY" "$PROWLARR_HOST/api/v1/indexer" 2>/dev/null || echo "[]")
INDEXER_1337X=$(echo "$EXISTING_INDEXERS" | jq '[.[] | select(.name == "1337x")] | length')

if [ "$INDEXER_1337X" = "0" ]; then
    curl -sf -X POST -H "X-Api-Key: $PROWLARR_API_KEY" -H "Content-Type: application/json" \
        -d "{
            \"name\": \"1337x\",
            \"definitionName\": \"1337x\",
            \"implementation\": \"Cardigann\",
            \"configContract\": \"CardigannSettings\",
            \"protocol\": \"torrent\",
            \"priority\": 25,
            \"enable\": true,
            \"appProfileId\": 1,
            \"tags\": [$FS_TAG_ID],
            \"fields\": [
                {\"name\": \"definitionFile\", \"value\": \"1337x\"},
                {\"name\": \"baseUrl\", \"value\": \"https://1337x.to\"},
                {\"name\": \"torrentBaseSettings.preferMagnetUrl\", \"value\": true},
                {\"name\": \"downloadlink\", \"value\": 0},
                {\"name\": \"downloadlink2\", \"value\": 1},
                {\"name\": \"sort\", \"value\": 2},
                {\"name\": \"type\", \"value\": 1}
            ]
        }" "$PROWLARR_HOST/api/v1/indexer" > /dev/null 2>&1 || true
    echo -e "  ${GREEN}✓ 1337x ajouté (avec FlareSolverr)${NC}"
else
    echo -e "  ${GREEN}✓ 1337x déjà configuré${NC}"
fi

# Ajouter YGG via Jackett (idempotent)
YGG_EXISTING=$(echo "$EXISTING_INDEXERS" | jq '[.[] | select(.name | test("ygg";"i"))] | length')

if [ "$YGG_EXISTING" = "0" ]; then
    # Attendre que Jackett soit prêt
    echo -e "  ${YELLOW}→ Attente Jackett...${NC}"
    JACKETT_READY=false
    for i in $(seq 1 30); do
        if docker exec jackett test -f /config/Jackett/ServerConfig.json 2>/dev/null; then
            JACKETT_READY=true; break
        fi
        sleep 2
    done

    if [ "$JACKETT_READY" = true ]; then
        # Récupérer l'API key et configurer FlareSolverr dans Jackett
        JACKETT_API_KEY=$(docker exec jackett cat /config/Jackett/ServerConfig.json 2>/dev/null | jq -r '.APIKey // empty')

        # Configurer FlareSolverr dans Jackett (une seule fois)
        JACKETT_FS=$(docker exec jackett cat /config/Jackett/ServerConfig.json 2>/dev/null | jq -r '.FlareSolverrUrl // empty')
        if [ -z "$JACKETT_FS" ] || [ "$JACKETT_FS" = "null" ]; then
            docker exec jackett cat /config/Jackett/ServerConfig.json \
                | jq '.FlareSolverrUrl = "http://flaresolverr:8191"' \
                > /tmp/jackett-cfg.json 2>/dev/null
            docker cp /tmp/jackett-cfg.json jackett:/config/Jackett/ServerConfig.json > /dev/null 2>&1
            rm -f /tmp/jackett-cfg.json
            $COMPOSE restart jackett > /dev/null 2>&1
            sleep 5
            echo -e "  ${GREEN}✓ FlareSolverr configuré dans Jackett${NC}"
        fi

        if [ -n "$JACKETT_API_KEY" ]; then
            # Persister Jackett API key dans .env
            if ! grep -q "^JACKETT_API_KEY=" .env; then
                echo "JACKETT_API_KEY=${JACKETT_API_KEY}" >> .env
            else
                sed -i.bak "s|^JACKETT_API_KEY=.*|JACKETT_API_KEY=${JACKETT_API_KEY}|" .env && rm -f .env.bak
            fi
            echo -e "  ${GREEN}✓ Jackett prêt (API key: ${JACKETT_API_KEY:0:8}...)${NC}"

            # Configurer YGG dans Jackett si identifiants fournis
            YGG_USERNAME="${YGG_USERNAME:-}"
            YGG_PASSWORD="${YGG_PASSWORD:-}"

            if [ -n "$YGG_USERNAME" ] && [ -n "$YGG_PASSWORD" ]; then
                # Authentification cookie Jackett (pas de mot de passe par défaut)
                curl -s -c /tmp/jackett-cookie -X POST "http://localhost:9117/UI/Dashboard" \
                    --data-urlencode "password=" > /dev/null 2>&1

                # Configurer l'indexer YGG avec les identifiants
                curl -s -b /tmp/jackett-cookie -X POST \
                    "http://localhost:9117/api/v2.0/indexers/yggtorrent/config" \
                    -H "Content-Type: application/json" \
                    -d "[{\"id\":\"username\",\"value\":\"${YGG_USERNAME}\"},{\"id\":\"password\",\"value\":\"${YGG_PASSWORD}\"}]" > /dev/null 2>&1

                rm -f /tmp/jackett-cookie

                # Vérifier que YGG est bien configuré
                YGG_CONFIGURED=$(curl -s "http://localhost:9117/api/v2.0/indexers?configured=true&apikey=${JACKETT_API_KEY}" 2>/dev/null \
                    | jq '[.[] | select(.id == "yggtorrent")] | length' 2>/dev/null || echo "0")

                if [ "$YGG_CONFIGURED" -gt 0 ] 2>/dev/null; then
                    echo -e "  ${GREEN}✓ YGGTorrent configuré dans Jackett${NC}"

                    # Ajouter le Torznab de YGG dans Prowlarr
                    curl -sf -X POST "$PROWLARR_HOST/api/v1/indexer" \
                        -H "X-Api-Key: $PROWLARR_API_KEY" \
                        -H "Content-Type: application/json" \
                        -d "{
                            \"name\": \"YGGTorrent (Jackett)\",
                            \"implementation\": \"Torznab\",
                            \"implementationName\": \"Torznab\",
                            \"configContract\": \"TorznabSettings\",
                            \"protocol\": \"torrent\",
                            \"enable\": true,
                            \"priority\": 10,
                            \"appProfileId\": 1,
                            \"fields\": [
                                {\"name\": \"baseUrl\", \"value\": \"http://jackett:9117/api/v2.0/indexers/yggtorrent/results/torznab/\"},
                                {\"name\": \"apiPath\", \"value\": \"/api\"},
                                {\"name\": \"apiKey\", \"value\": \"${JACKETT_API_KEY}\"},
                                {\"name\": \"minimumSeeders\", \"value\": 1},
                                {\"name\": \"seedCriteria.seedRatio\", \"value\": \"\"},
                                {\"name\": \"seedCriteria.seedTime\", \"value\": \"\"},
                                {\"name\": \"seedCriteria.discographySeedTime\", \"value\": \"\"}
                            ],
                            \"tags\": []
                        }" > /dev/null 2>&1 || true
                    echo -e "  ${GREEN}✓ YGGTorrent Torznab ajouté dans Prowlarr${NC}"
                else
                    echo -e "  ${YELLOW}⚠  YGG : auth échouée (vérifiez identifiants dans .env)${NC}"
                fi
            else
                echo -e "  ${YELLOW}⚠  YGG_USERNAME/YGG_PASSWORD non définis dans .env${NC}"
                echo -e "  ${YELLOW}   Configurez manuellement : http://localhost:9117${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠  Jackett : API key non trouvée${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  Jackett : timeout (configurez manuellement)${NC}"
    fi
else
    echo -e "  ${GREEN}✓ YGGTorrent déjà configuré dans Prowlarr${NC}"
fi

# Sync des indexers vers Radarr/Sonarr
curl -sf -X POST -H "X-Api-Key: $PROWLARR_API_KEY" -H "Content-Type: application/json" \
    -d '{"name": "AppIndexerSync"}' "$PROWLARR_HOST/api/v1/command" > /dev/null 2>&1 || true
echo -e "  ${GREEN}✓ Sync indexeurs → Radarr/Sonarr${NC}"

echo -e "${GREEN}✅ Indexeurs configurés${NC}\n"

#==============================================================================
# ÉTAPE 6 : Configuration Jellyfin (wizard + bibliothèques)
#==============================================================================
echo -e "${YELLOW}🎬 [6/7] Configuration Jellyfin...${NC}"

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
JELLYFIN_HOST="${JELLYFIN_HOST:-http://localhost:8096}"
JELLYFIN_SERVER_NAME="${JELLYFIN_SERVER_NAME:-ArrStack}"
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
        }" > /dev/null 2>&1 || true

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
        -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' > /dev/null 2>&1 || true

    curl -sf -X POST "${JELLYFIN_HOST}/Startup/Complete" > /dev/null 2>&1 || true
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
        curl -sf -X POST "${JELLYFIN_HOST}/Library/Refresh" -H "X-Emby-Authorization: ${JF_AUTH}" > /dev/null 2>&1 || true

        SERVER_CONFIG=$(curl -sf "${JELLYFIN_HOST}/System/Configuration" -H "X-Emby-Authorization: ${JF_AUTH}" 2>/dev/null || echo "")
        if [ -n "$SERVER_CONFIG" ]; then
            echo "$SERVER_CONFIG" | sed "s/\"ServerName\":\"[^\"]*\"/\"ServerName\":\"${JELLYFIN_SERVER_NAME}\"/" | \
            curl -sf -X POST "${JELLYFIN_HOST}/System/Configuration" \
                -H "Content-Type: application/json" -H "X-Emby-Authorization: ${JF_AUTH}" -d @- > /dev/null 2>&1
        fi
        echo -e "  ${GREEN}✓ Serveur : ${JELLYFIN_SERVER_NAME}${NC}"

        # ── Plugin Trakt ─────────────────────────────────────────────
        TRAKT_GUID="4fe3201ed6ae4f2e8917e12bda571281"
        TRAKT_INSTALLED=$(curl -sf "${JELLYFIN_HOST}/Plugins" -H "X-Emby-Authorization: ${JF_AUTH}" 2>/dev/null \
            | grep -o "\"Id\":\"${TRAKT_GUID}\"" || true)

        if [ -z "$TRAKT_INSTALLED" ]; then
            echo -e "  ${YELLOW}→ Installation plugin Trakt...${NC}"
            TRAKT_VERSION=$(curl -sf "${JELLYFIN_HOST}/Packages" -H "X-Emby-Token: ${JF_TOKEN}" 2>/dev/null \
                | jq -r ".[] | select(.guid==\"${TRAKT_GUID}\") | .versions[0].version" 2>/dev/null || echo "")
            if [ -n "$TRAKT_VERSION" ]; then
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
                    "${JELLYFIN_HOST}/Packages/Installed/${TRAKT_GUID}?assemblyGuid=${TRAKT_GUID}&version=${TRAKT_VERSION}&repositoryUrl=https://repo.jellyfin.org/files/plugin/manifest.json" \
                    -H "X-Emby-Token: ${JF_TOKEN}")
                if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
                    echo -e "  ${GREEN}✓ Plugin Trakt ${TRAKT_VERSION} installé${NC}"
                    echo -e "  ${YELLOW}⚠  Trakt sera actif après redémarrage de Jellyfin${NC}"
                    echo -e "  ${YELLOW}   Configurer : Dashboard > Plugins > Trakt > Authorize${NC}"
                else
                    echo -e "  ${YELLOW}⚠  Installation Trakt échouée (HTTP ${HTTP_CODE})${NC}"
                fi
            else
                echo -e "  ${YELLOW}⚠  Plugin Trakt introuvable dans le catalogue${NC}"
            fi
        else
            echo -e "  ${GREEN}✓ Plugin Trakt déjà installé${NC}"

            # Appliquer la config recommandée si un utilisateur est lié
            TRAKT_CONFIG=$(curl -sf "${JELLYFIN_HOST}/Plugins/${TRAKT_GUID}/Configuration" \
                -H "X-Emby-Token: ${JF_TOKEN}" 2>/dev/null || echo "")
            HAS_USERS=$(echo "$TRAKT_CONFIG" | jq -r '.TraktUsers | length' 2>/dev/null || echo "0")

            if [ "$HAS_USERS" -gt 0 ]; then
                # Appliquer les settings recommandés
                UPDATED_CONFIG=$(echo "$TRAKT_CONFIG" | jq '
                    .TraktUsers[0] |= (
                        .SkipUnwatchedImportFromTrakt = false |
                        .SkipWatchedImportFromTrakt = false |
                        .SkipPlaybackProgressImportFromTrakt = false |
                        .PostWatchedHistory = true |
                        .PostUnwatchedHistory = false |
                        .PostSetWatched = true |
                        .PostSetUnwatched = false |
                        .ExtraLogging = false |
                        .ExportMediaInfo = true |
                        .SynchronizeCollections = true |
                        .Scrobble = true |
                        .DontRemoveItemFromTrakt = true
                    )' 2>/dev/null || echo "")

                if [ -n "$UPDATED_CONFIG" ]; then
                    curl -sf -X POST "${JELLYFIN_HOST}/Plugins/${TRAKT_GUID}/Configuration" \
                        -H "Content-Type: application/json" \
                        -H "X-Emby-Token: ${JF_TOKEN}" \
                        -d "$UPDATED_CONFIG" > /dev/null 2>&1
                    echo -e "  ${GREEN}✓ Config Trakt optimisée (scrobble + sync)${NC}"
                fi
            fi
        fi
    else
        echo -e "  ${YELLOW}⚠  Auth Jellyfin échouée — configurez via ${JELLYFIN_HOST}${NC}"
    fi
else
    echo -e "  ${GREEN}✓ Jellyfin déjà configuré${NC}"
    # Authentification pour les étapes suivantes (Jellyseerr, Jellystat)
    AUTH_RESPONSE=$(curl -sf -X POST "${JELLYFIN_HOST}/Users/AuthenticateByName" \
        -H "Content-Type: application/json" \
        -H "X-Emby-Authorization: MediaBrowser Client=\"Setup\", Device=\"CLI\", DeviceId=\"setup\", Version=\"1.0\"" \
        -d "{\"Username\":\"${ADMIN_USER}\",\"Pw\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "")
    JF_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)
    JF_USER_ID=$(echo "$AUTH_RESPONSE" | grep -o '"Id":"[^"]*"' | head -1 | cut -d'"' -f4)
    JF_AUTH="MediaBrowser Token=\"${JF_TOKEN}\""
    if [ -n "$JF_TOKEN" ]; then
        echo -e "  ${GREEN}✓ Authentifié en tant que '${ADMIN_USER}'${NC}"
    else
        echo -e "  ${YELLOW}⚠  Auth Jellyfin échouée — certaines étapes seront ignorées${NC}"
    fi
fi

echo -e "${GREEN}✅ Jellyfin configuré${NC}\n"

#==============================================================================
# ÉTAPE 6b : Configuration Jellyseerr (Jellyfin + Radarr + Sonarr)
#==============================================================================
echo -e "${YELLOW}🎬 [6b/7] Configuration Jellyseerr...${NC}"

SEERR_HOST="http://localhost:5055"
SEERR_INITIALIZED=$(curl -sf "${SEERR_HOST}/api/v1/settings/public" 2>/dev/null | jq -r '.initialized // false' 2>/dev/null || echo "false")

if [ "$SEERR_INITIALIZED" = "false" ]; then
    # Étape 1 : Initialisation avec Jellyfin
    SEERR_AUTH=$(curl -s -c /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/auth/jellyfin" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASSWORD}\",\"hostname\":\"jellyfin\",\"port\":8096,\"useSsl\":false,\"urlBase\":\"\",\"email\":\"admin@local.host\",\"serverType\":2}" 2>/dev/null)
    SEERR_USER_ID=$(echo "$SEERR_AUTH" | jq -r '.id // empty' 2>/dev/null || echo "")

    if [ -n "$SEERR_USER_ID" ]; then
        echo -e "  ${GREEN}✓ Authentification Jellyfin OK${NC}"

        # Étape 2 : Sync et activation des bibliothèques
        SEERR_LIBS=$(curl -s -b /tmp/seerr-cookie "${SEERR_HOST}/api/v1/settings/jellyfin/library?sync=true" 2>/dev/null)
        LIB_IDS=$(echo "$SEERR_LIBS" | jq -r '.[].id' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        if [ -n "$LIB_IDS" ]; then
            curl -s -b /tmp/seerr-cookie "${SEERR_HOST}/api/v1/settings/jellyfin/library?enable=${LIB_IDS}" > /dev/null 2>&1
            echo -e "  ${GREEN}✓ Bibliothèques activées${NC}"
        fi

        # Étape 3 : Tester et ajouter Radarr
        RADARR_TEST=$(curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/radarr/test" \
            -H "Content-Type: application/json" \
            -d "{\"hostname\":\"radarr\",\"port\":7878,\"apiKey\":\"${RADARR_API_KEY}\",\"useSsl\":false,\"baseUrl\":\"\"}" 2>/dev/null)
        RADARR_PROFILE=$(echo "$RADARR_TEST" | jq -r '.profiles[0].id // 1' 2>/dev/null)
        RADARR_PNAME=$(echo "$RADARR_TEST" | jq -r '.profiles[0].name // "Any"' 2>/dev/null)
        RADARR_RDIR=$(echo "$RADARR_TEST" | jq -r '.rootFolders[0].path // "/data/media/movies"' 2>/dev/null)

        curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/radarr" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Radarr\",\"hostname\":\"radarr\",\"port\":7878,\"apiKey\":\"${RADARR_API_KEY}\",\"useSsl\":false,\"baseUrl\":\"\",\"activeProfileId\":${RADARR_PROFILE},\"activeProfileName\":\"${RADARR_PNAME}\",\"activeDirectory\":\"${RADARR_RDIR}\",\"is4k\":false,\"minimumAvailability\":\"released\",\"tags\":[],\"isDefault\":true,\"syncEnabled\":false,\"preventSearch\":false,\"tagRequests\":false,\"externalUrl\":\"\",\"overrideRule\":[]}" > /dev/null 2>&1
        echo -e "  ${GREEN}✓ Radarr connecté (profil: ${RADARR_PNAME})${NC}"

        # Étape 4 : Tester et ajouter Sonarr
        SONARR_TEST=$(curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/sonarr/test" \
            -H "Content-Type: application/json" \
            -d "{\"hostname\":\"sonarr\",\"port\":8989,\"apiKey\":\"${SONARR_API_KEY}\",\"useSsl\":false,\"baseUrl\":\"\"}" 2>/dev/null)
        SONARR_PROFILE=$(echo "$SONARR_TEST" | jq -r '.profiles[0].id // 1' 2>/dev/null)
        SONARR_PNAME=$(echo "$SONARR_TEST" | jq -r '.profiles[0].name // "Any"' 2>/dev/null)
        SONARR_RDIR=$(echo "$SONARR_TEST" | jq -r '.rootFolders[0].path // "/data/media/tv"' 2>/dev/null)

        curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/sonarr" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Sonarr\",\"hostname\":\"sonarr\",\"port\":8989,\"apiKey\":\"${SONARR_API_KEY}\",\"useSsl\":false,\"baseUrl\":\"\",\"activeProfileId\":${SONARR_PROFILE},\"activeProfileName\":\"${SONARR_PNAME}\",\"activeDirectory\":\"${SONARR_RDIR}\",\"tags\":[],\"is4k\":false,\"isDefault\":true,\"enableSeasonFolders\":true,\"seriesType\":\"standard\",\"animeSeriesType\":\"anime\",\"animeTags\":[],\"monitorNewItems\":\"all\",\"syncEnabled\":false,\"preventSearch\":false,\"tagRequests\":false,\"externalUrl\":\"\",\"overrideRule\":[]}" > /dev/null 2>&1
        echo -e "  ${GREEN}✓ Sonarr connecté (profil: ${SONARR_PNAME})${NC}"

        # Étape 5 : Lancer le scan et finaliser
        curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/jellyfin/sync" \
            -H "Content-Type: application/json" -d '{"start":true}' > /dev/null 2>&1
        curl -s -b /tmp/seerr-cookie -X POST "${SEERR_HOST}/api/v1/settings/initialize" \
            -H "Content-Type: application/json" > /dev/null 2>&1
        echo -e "  ${GREEN}✓ Jellyseerr initialisé (scan en cours)${NC}"

        rm -f /tmp/seerr-cookie
    else
        echo -e "  ${YELLOW}⚠  Jellyseerr auth échouée — configurez via ${SEERR_HOST}${NC}"
    fi
else
    echo -e "  ${GREEN}✓ Jellyseerr déjà initialisé${NC}"
fi

echo -e "${GREEN}✅ Jellyseerr configuré${NC}\n"

#==============================================================================
# ÉTAPE 6c : Configuration Jellystat (connexion Jellyfin)
#==============================================================================
echo -e "${YELLOW}📊 [6c/7] Configuration Jellystat...${NC}"

JELLYSTAT_HOST="http://localhost:6555"

# Vérifier si Jellystat a déjà un utilisateur configuré
JS_CONFIG=$(curl -sf -X POST "${JELLYSTAT_HOST}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "")
JS_TOKEN_VAL=$(echo "$JS_CONFIG" | jq -r '.token // empty' 2>/dev/null || echo "")

if [ -z "$JS_TOKEN_VAL" ]; then
    # Pas de login possible → créer l'utilisateur initial
    JS_CREATE=$(curl -sf -X POST "${JELLYSTAT_HOST}/auth/createuser" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "")
    JS_TOKEN_VAL=$(echo "$JS_CREATE" | jq -r '.token // empty' 2>/dev/null || echo "")

    if [ -n "$JS_TOKEN_VAL" ]; then
        echo -e "  ${GREEN}✓ Utilisateur Jellystat créé${NC}"
    else
        echo -e "  ${YELLOW}⚠  Jellystat : impossible de créer l'utilisateur${NC}"
    fi
else
    echo -e "  ${GREEN}✓ Jellystat : login OK${NC}"
fi

if [ -n "$JS_TOKEN_VAL" ]; then
    # Vérifier si Jellyfin est déjà connecté
    JS_CURRENT=$(curl -sf "${JELLYSTAT_HOST}/api/getconfig" \
        -H "Authorization: Bearer ${JS_TOKEN_VAL}" 2>/dev/null || echo "")
    JS_JF_HOST=$(echo "$JS_CURRENT" | jq -r '.JF_HOST // empty' 2>/dev/null || echo "")

    if [ -z "$JS_JF_HOST" ] || [ "$JS_JF_HOST" = "null" ]; then
        # Créer une API key Jellyfin pour Jellystat
        if [ -n "$JF_TOKEN" ]; then
            # Vérifier si une key "Jellystat" existe déjà
            EXISTING_KEYS=$(curl -sf "${JELLYFIN_HOST}/Auth/Keys" -H "X-Emby-Token: ${JF_TOKEN}" 2>/dev/null || echo "")
            JELLYSTAT_KEY=$(echo "$EXISTING_KEYS" | jq -r '.Items[] | select(.AppName == "Jellystat") | .AccessToken' 2>/dev/null | head -1)

            if [ -z "$JELLYSTAT_KEY" ]; then
                curl -sf -X POST "${JELLYFIN_HOST}/Auth/Keys?app=Jellystat" \
                    -H "X-Emby-Token: ${JF_TOKEN}" > /dev/null 2>&1 || true
                EXISTING_KEYS=$(curl -sf "${JELLYFIN_HOST}/Auth/Keys" -H "X-Emby-Token: ${JF_TOKEN}" 2>/dev/null || echo "")
                JELLYSTAT_KEY=$(echo "$EXISTING_KEYS" | jq -r '.Items[] | select(.AppName == "Jellystat") | .AccessToken' 2>/dev/null | head -1)
                echo -e "  ${GREEN}✓ API key Jellyfin créée pour Jellystat${NC}"
            fi

            if [ -n "$JELLYSTAT_KEY" ]; then
                curl -sf -X POST "${JELLYSTAT_HOST}/api/setconfig" \
                    -H "Authorization: Bearer ${JS_TOKEN_VAL}" \
                    -H "Content-Type: application/json" \
                    -d "{\"JF_HOST\":\"http://jellyfin:8096\",\"JF_API_KEY\":\"${JELLYSTAT_KEY}\"}" > /dev/null 2>&1
                echo -e "  ${GREEN}✓ Jellystat connecté à Jellyfin${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠  Jellystat : token Jellyfin non disponible (configurez manuellement)${NC}"
        fi
    else
        echo -e "  ${GREEN}✓ Jellystat déjà connecté à Jellyfin${NC}"
    fi
fi

echo -e "${GREEN}✅ Jellystat configuré${NC}\n"

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
echo -e "${BLUE}║${NC} Jellystat    : ${GREEN}http://localhost:6555${NC}"
echo -e "${BLUE}║${NC} Radarr       : ${GREEN}http://localhost:7878${NC}"
echo -e "${BLUE}║${NC} Sonarr       : ${GREEN}http://localhost:8989${NC}"
echo -e "${BLUE}║${NC} Prowlarr     : ${GREEN}http://localhost:9696${NC}"
echo -e "${BLUE}║${NC} Jackett      : ${GREEN}http://localhost:9117${NC}"
echo -e "${BLUE}║${NC} qBittorrent  : ${GREEN}http://localhost:8090${NC}"
echo -e "${BLUE}║${NC} RDTClient    : ${GREEN}http://localhost:6500${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} ${YELLOW}Prochaines étapes :${NC}"
echo -e "${BLUE}║${NC}  1. RDTClient     : configurer AllDebrid (http://localhost:6500)"
echo -e "${BLUE}║${NC}  2. Plugin Trakt  : Dashboard > Plugins > Trakt > Authorize"
echo -e "${BLUE}║${NC}  3. Infuse 8      : ajouter serveur Jellyfin"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
