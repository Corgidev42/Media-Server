#!/bin/bash
#==============================================================================
# Script de rotation VPN - Change l'IP après chaque téléchargement
# Usage: ./rotate-vpn.sh
#==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Rotation de l'IP VPN (Gluetun)                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# IP actuelle
echo -e "${YELLOW}IP VPN actuelle :${NC}"
OLD_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "Erreur")
echo -e "${GREEN}$OLD_IP${NC}\n"

# Redémarrage de Gluetun
echo -e "${YELLOW}Redémarrage de Gluetun...${NC}"
docker-compose restart gluetun > /dev/null 2>&1

echo -e "${GREEN}✅ Gluetun redémarré${NC}\n"

# Attente de la nouvelle connexion VPN
echo -e "${YELLOW}Attente de la nouvelle connexion VPN (15 secondes)...${NC}"
sleep 15

# Nouvelle IP
echo -e "${YELLOW}Nouvelle IP VPN :${NC}"
NEW_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "En cours...")
echo -e "${GREEN}$NEW_IP${NC}\n"

if [ "$OLD_IP" != "$NEW_IP" ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ IP changée avec succès !                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"
else
    echo -e "${YELLOW}⚠️  Même IP (peut arriver avec NordVPN)${NC}\n"
fi

echo -e "${BLUE}💡 Conseil :${NC} Lancez ce script après chaque grosse session de téléchargements.\n"
