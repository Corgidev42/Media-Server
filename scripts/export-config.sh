#!/bin/bash
#==============================================================================
# Export configuration via API (nettoyée, prête pour import/partage)
# Les champs read-only (id, added, sortName, capabilities) sont retirés
#==============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

[ -f .env ] && export $(grep -v '^#' .env | xargs)

CONFIG_DIR="./config-exports"
mkdir -p "$CONFIG_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Export Configuration (clean)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

#==============================================================================
# PROWLARR
#==============================================================================
echo -e "${YELLOW}📡 Export Prowlarr...${NC}"

if [ -z "$PROWLARR_API_KEY" ]; then
    echo -e "${RED}  ✗ PROWLARR_API_KEY manquante dans .env${NC}"
else
    # Indexeurs (sans id, added, sortName, capabilities)
    curl -s -H "X-Api-Key: $PROWLARR_API_KEY" \
        "http://localhost:9696/api/v1/indexer" \
        | jq 'map(del(.id, .added, .sortName, .capabilities))' \
        > "$CONFIG_DIR/prowlarr-indexers.json"

    # Applications (sans id)
    curl -s -H "X-Api-Key: $PROWLARR_API_KEY" \
        "http://localhost:9696/api/v1/applications" \
        | jq 'map(del(.id))' \
        > "$CONFIG_DIR/prowlarr-applications.json"

    # Download clients (sans id)
    curl -s -H "X-Api-Key: $PROWLARR_API_KEY" \
        "http://localhost:9696/api/v1/downloadclient" \
        | jq 'map(del(.id))' \
        > "$CONFIG_DIR/prowlarr-downloadclients.json"

    echo -e "${GREEN}  ✓ Prowlarr exporté${NC}"
fi

#==============================================================================
# RADARR
#==============================================================================
echo -e "${YELLOW}🎬 Export Radarr...${NC}"

if [ -z "$RADARR_API_KEY" ]; then
    echo -e "${RED}  ✗ RADARR_API_KEY manquante dans .env${NC}"
else
    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/downloadclient" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/radarr-downloadclients.json"

    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/qualityprofile" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/radarr-qualityprofiles.json"

    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/customformat" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/radarr-customformats.json"

    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/rootfolder" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/radarr-rootfolders.json"

    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/indexer" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/radarr-indexers.json"

    # Naming & Media Management (objets simples, pas des tableaux)
    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/config/naming" \
        | jq 'del(.id)' > "$CONFIG_DIR/radarr-naming.json"

    curl -s -H "X-Api-Key: $RADARR_API_KEY" \
        "http://localhost:7878/api/v3/config/mediamanagement" \
        | jq 'del(.id)' > "$CONFIG_DIR/radarr-mediamanagement.json"

    echo -e "${GREEN}  ✓ Radarr exporté${NC}"
fi

#==============================================================================
# SONARR
#==============================================================================
echo -e "${YELLOW}📺 Export Sonarr...${NC}"

if [ -z "$SONARR_API_KEY" ]; then
    echo -e "${RED}  ✗ SONARR_API_KEY manquante dans .env${NC}"
else
    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/downloadclient" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/sonarr-downloadclients.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/qualityprofile" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/sonarr-qualityprofiles.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/customformat" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/sonarr-customformats.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/rootfolder" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/sonarr-rootfolders.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/indexer" \
        | jq 'map(del(.id))' > "$CONFIG_DIR/sonarr-indexers.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/config/naming" \
        | jq 'del(.id)' > "$CONFIG_DIR/sonarr-naming.json"

    curl -s -H "X-Api-Key: $SONARR_API_KEY" \
        "http://localhost:8989/api/v3/config/mediamanagement" \
        | jq 'del(.id)' > "$CONFIG_DIR/sonarr-mediamanagement.json"

    echo -e "${GREEN}  ✓ Sonarr exporté${NC}"
fi

#==============================================================================
# QBITTORRENT
#==============================================================================
echo -e "${YELLOW}📥 Export qBittorrent...${NC}"

QBIT_COOKIE=$(curl -s -i --data "username=admin&password=${QBITTORRENT_PASSWORD:-admin}" \
    "http://localhost:8090/api/v2/auth/login" 2>/dev/null | grep -i "set-cookie" | awk '{print $2}')

if [ -n "$QBIT_COOKIE" ]; then
    curl -s -b "$QBIT_COOKIE" \
        "http://localhost:8090/api/v2/app/preferences" \
        | jq '.' > "$CONFIG_DIR/qbittorrent-preferences.json"
    echo -e "${GREEN}  ✓ qBittorrent exporté${NC}"
else
    echo -e "${RED}  ✗ Connexion qBittorrent échouée${NC}"
fi

#==============================================================================
# Résumé
#==============================================================================
echo ""
echo -e "${GREEN}📁 Fichiers exportés dans $CONFIG_DIR/ :${NC}"
ls -lh "$CONFIG_DIR"/*.json 2>/dev/null | awk '{printf "  › %-45s %s\n", $9, $5}'

echo ""
echo -e "${YELLOW}💡 Pour restaurer : make import${NC}"
echo -e "${YELLOW}⚠️  Pensez aussi à sauvegarder votre .env${NC}"
