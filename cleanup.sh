#!/bin/bash
#==============================================================================
# Script de Nettoyage Radical - Stack Servarr
# Description: Supprime tous les conteneurs, volumes et configs locales
# Usage: chmod +x cleanup.sh && ./cleanup.sh
#==============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Nettoyage Radical de la Stack Servarr ===${NC}\n"

# Confirmation de sécurité
read -p "⚠️  ATTENTION: Cette action va supprimer TOUS les conteneurs, volumes et configurations. Continuer? (oui/non): " confirmation
if [ "$confirmation" != "oui" ]; then
    echo -e "${RED}Annulation du nettoyage.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Étape 1: Arrêt et suppression des conteneurs Docker...${NC}"

# Liste des conteneurs Servarr à supprimer
CONTAINERS=(
    "prowlarr"
    "radarr" 
    "sonarr"
    "seerr"
    "overseerr"
    "qbittorrent"
    "flaresolverr"
    "gluetun"
    "jellyfin"
    "plex"
    "tautulli"
)

for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "  ${RED}→${NC} Suppression de ${container}..."
        docker stop "$container" 2>/dev/null || true
        docker rm -f "$container" 2>/dev/null || true
    fi
done

# Supprimer tous les conteneurs restants (optionnel - décommentez si nécessaire)
# echo -e "\n${YELLOW}Suppression de TOUS les conteneurs...${NC}"
# docker stop $(docker ps -aq) 2>/dev/null || true
# docker rm -f $(docker ps -aq) 2>/dev/null || true

echo -e "\n${YELLOW}Étape 2: Suppression des volumes Docker...${NC}"

# Liste des volumes à supprimer
VOLUMES=(
    "prowlarr_config"
    "radarr_config"
    "sonarr_config"
    "seerr_config"
    "overseerr_config"
    "qbittorrent_config"
    "flaresolverr_config"
    "gluetun_config"
)

for volume in "${VOLUMES[@]}"; do
    if docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
        echo -e "  ${RED}→${NC} Suppression du volume ${volume}..."
        docker volume rm "$volume" 2>/dev/null || true
    fi
done

# Supprimer tous les volumes orphelins
echo -e "  ${YELLOW}→${NC} Nettoyage des volumes orphelins..."
docker volume prune -f

echo -e "\n${YELLOW}Étape 3: Suppression des réseaux Docker...${NC}"
docker network rm media-network 2>/dev/null || true
docker network prune -f

echo -e "\n${YELLOW}Étape 4: Suppression des dossiers de configuration locaux...${NC}"

# Dossiers dans ~/Library/Application Support/
CONFIG_DIRS=(
    "$HOME/Library/Application Support/prowlarr"
    "$HOME/Library/Application Support/radarr"
    "$HOME/Library/Application Support/sonarr"
    "$HOME/Library/Application Support/overseerr"
    "$HOME/Library/Application Support/seerr"
    "$HOME/Library/Application Support/qbittorrent"
    "$HOME/Library/Application Support/Plex Media Server"
    "$HOME/Library/Application Support/jellyfin"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${RED}→${NC} Suppression de ${dir}..."
        rm -rf "$dir"
    fi
done

# Autres dossiers résiduels possibles
RESIDUAL_DIRS=(
    "$HOME/.config/prowlarr"
    "$HOME/.config/radarr"
    "$HOME/.config/sonarr"
    "$HOME/.config/qBittorrent"
)

for dir in "${RESIDUAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${RED}→${NC} Suppression de ${dir}..."
        rm -rf "$dir"
    fi
done

echo -e "\n${YELLOW}Étape 5: Nettoyage final Docker...${NC}"
docker system prune -a -f --volumes

echo -e "\n${GREEN}✅ Nettoyage terminé avec succès!${NC}"
echo -e "${YELLOW}Vous pouvez maintenant déployer la nouvelle stack avec:${NC}"
echo -e "  ${GREEN}docker-compose up -d${NC}\n"
