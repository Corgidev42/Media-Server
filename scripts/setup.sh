#!/bin/bash
# Setup automatique stack Media Server

set -e

echo "=== Setup Media Server ==="
echo ""

# Vérifications
command -v docker >/dev/null || { echo "Docker manquant"; exit 1; }
command -v docker-compose >/dev/null || { echo "docker-compose manquant"; exit 1; }
command -v jq >/dev/null || { echo "jq manquant - install avec: brew install jq"; exit 1; }

# Vérifier .env
if [ ! -f .env ]; then
    echo ".env manquant - creation depuis .env.example"
    cp .env.example .env
    echo "Editez .env et ajoutez vos credentials NordVPN, puis relancez"
    exit 0
fi

# Charger variables
export $(grep -v '^#' .env | xargs)

echo "[1/6] Creation structure dossiers..."
mkdir -p ${DATA_PATH}/downloads/{incomplete,complete}
mkdir -p ${DATA_PATH}/media/{movies,tv}
mkdir -p ./backups ./config-exports ./prowlarr ./radarr ./sonarr

echo "[2/6] Pre-configuration services (API Keys + Auth)..."

# Remplacer les placeholders dans les templates
sed "s|%%PROWLARR_API_KEY%%|${PROWLARR_API_KEY:-$(openssl rand -hex 16)}|g" \
    config-templates/prowlarr-config.xml > ./prowlarr/config.xml

sed "s|%%RADARR_API_KEY%%|${RADARR_API_KEY:-$(openssl rand -hex 16)}|g" \
    config-templates/radarr-config.xml > ./radarr/config.xml

sed "s|%%SONARR_API_KEY%%|${SONARR_API_KEY:-$(openssl rand -hex 16)}|g" \
    config-templates/sonarr-config.xml > ./sonarr/config.xml

echo "  ✓ Prowlarr pré-configuré"
echo "  ✓ Radarr pré-configuré"
echo "  ✓ Sonarr pré-configuré"

echo "[3/6] Demarrage conteneurs..."
docker-compose up -d

echo "[4/6] Attente demarrage (60s)..."
sleep 60

echo "[5/6] Sauvegarde des API Keys generates..."

# S'ils n'étaient pas dans .env, les générer et les sauvegarder
PROWLARR_KEY=$(docker exec prowlarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "")
RADARR_KEY=$(docker exec radarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "")
SONARR_KEY=$(docker exec sonarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "")

# Updater .env pour les futures sessions
if [ -n "$PROWLARR_KEY" ]; then
    sed -i.bak "s/^PROWLARR_API_KEY=.*/PROWLARR_API_KEY=$PROWLARR_KEY/" .env
fi

if [ -n "$RADARR_KEY" ]; then
    sed -i.bak "s/^RADARR_API_KEY=.*/RADARR_API_KEY=$RADARR_KEY/" .env
fi

if [ -n "$SONARR_KEY" ]; then
    sed -i.bak "s/^SONARR_API_KEY=.*/SONARR_API_KEY=$SONARR_KEY/" .env
fi

echo "  ✓ API Keys sauvegardees dans .env"

# Import config si disponible
if [ -d "./config-exports" ] && [ "$(ls -A ./config-exports 2>/dev/null)" ]; then
    echo ""
    echo "[6/6] Restauration de la configuration..."
    if [ -f "./scripts/import-config.sh" ]; then
        bash ./scripts/import-config.sh 2>&1 | tail -20
        echo "  ✓ configuration importée"
    fi
fi

# VPN check
VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "Erreur")
echo ""
echo "=== Installation terminee ==="
echo "IP VPN: $VPN_IP"
echo ""
echo "Services:"
echo "- Prowlarr: http://localhost:9696"
echo "- Radarr: http://localhost:7878"
echo "- Sonarr: http://localhost:8989"
echo "- qBittorrent: http://localhost:8090"
echo "- Plex: http://localhost:32400/web"
echo ""
echo "Next: Configurez via Web UI puis: make export-config"
