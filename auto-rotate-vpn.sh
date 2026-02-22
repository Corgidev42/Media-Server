#!/bin/bash
#==============================================================================
# Rotation VPN automatique - Surveille les téléchargements et change l'IP
# Usage: ./auto-rotate-vpn.sh [interval_heures]
# Exemple: ./auto-rotate-vpn.sh 2  (rotation toutes les 2 heures)
#==============================================================================

INTERVAL_HOURS=${1:-4}  # Par défaut : 4 heures
INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Rotation VPN Automatique (toutes les ${INTERVAL_HOURS}h)       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Mode automatique activé.${NC}"
echo -e "${YELLOW}L'IP VPN sera changée toutes les ${INTERVAL_HOURS} heures.${NC}"
echo -e "${YELLOW}Press Ctrl+C pour arrêter.${NC}\n"

ROTATION_COUNT=0

while true; do
    ROTATION_COUNT=$((ROTATION_COUNT + 1))
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Rotation #${ROTATION_COUNT} - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
    
    # IP actuelle
    OLD_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "Erreur")
    echo -e "${YELLOW}IP actuelle :${NC} ${GREEN}$OLD_IP${NC}"
    
    # Redémarrage
    echo -e "${YELLOW}Redémarrage de Gluetun...${NC}"
    docker-compose restart gluetun > /dev/null 2>&1
    sleep 15
    
    # Nouvelle IP
    NEW_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "En cours...")
    echo -e "${YELLOW}Nouvelle IP  :${NC} ${GREEN}$NEW_IP${NC}"
    
    if [ "$OLD_IP" != "$NEW_IP" ]; then
        echo -e "${GREEN}✅ IP changée avec succès !${NC}"
    else
        echo -e "${YELLOW}⚠️  Même IP (normal avec NordVPN)${NC}"
    fi
    
    echo -e "\n${BLUE}Prochaine rotation dans ${INTERVAL_HOURS} heures...${NC}"
    
    # Attente
    sleep $INTERVAL_SECONDS
done
