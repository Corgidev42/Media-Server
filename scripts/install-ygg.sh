#!/bin/bash
#==============================================================================
# [DÉPRÉCIÉ] Installation YGGTorrent API pour Prowlarr (Docker)
# Basé sur : https://haste.laiteux.dev/raw/gyenbr
#
# ⚠️  CE SCRIPT EST DÉPRÉCIÉ — Utilisez Jackett à la place.
#     Jackett gère nativement YGGTorrent avec FlareSolverr.
#     Configurez YGG dans l'UI Jackett : http://localhost:9117
#     Voir setup.sh (étape 5b) pour l'intégration automatique.
#==============================================================================

set -e

echo ""
echo "⚠️  ATTENTION : Ce script est DÉPRÉCIÉ."
echo "   Utilisez Jackett pour accéder à YGGTorrent."
echo "   → http://localhost:9117"
echo ""
read -rp "Continuer quand même ? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Annulé."
    exit 0
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Installation YGGTorrent API pour Prowlarr       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# Vérifier que Prowlarr est en cours d'exécution
if ! docker ps | grep -q prowlarr; then
    echo -e "${RED}❌ Prowlarr n'est pas démarré.${NC}"
    echo -e "${YELLOW}Lancez 'docker-compose up -d' d'abord.${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Étape 1/5 : Création du dossier Custom...${NC}"
docker exec prowlarr mkdir -p /config/Definitions/Custom
echo -e "${GREEN}✅ Dossier créé${NC}\n"

echo -e "${YELLOW}📥 Étape 2/5 : Téléchargement des définitions YGG...${NC}"
curl -s -o /tmp/ygg-api.yml https://haste.laiteux.dev/raw/gyenbr
curl -s -o /tmp/ygg-api-magnet.yml https://haste.laiteux.dev/raw/gyenbr

if [ -f /tmp/ygg-api.yml ] && [ -f /tmp/ygg-api-magnet.yml ]; then
    echo -e "${GREEN}✅ Fichiers téléchargés ($(ls -lh /tmp/ygg-api.yml | awk '{print $5}') chacun)${NC}\n"
else
    echo -e "${RED}❌ Échec du téléchargement${NC}"
    exit 1
fi

echo -e "${YELLOW}📤 Étape 3/5 : Copie dans Prowlarr...${NC}"
docker cp /tmp/ygg-api.yml prowlarr:/config/Definitions/Custom/ygg-api.yml
docker cp /tmp/ygg-api-magnet.yml prowlarr:/config/Definitions/Custom/ygg-api-magnet.yml
echo -e "${GREEN}✅ Fichiers installés${NC}\n"

echo -e "${YELLOW}🔄 Étape 4/5 : Redémarrage de Prowlarr...${NC}"
docker-compose restart prowlarr > /dev/null 2>&1
echo -e "${GREEN}✅ Prowlarr redémarré${NC}\n"

echo -e "${YELLOW}⏳ Étape 5/5 : Attente du démarrage (15 secondes)...${NC}"
sleep 15

# Vérifier que Prowlarr est bien démarré
if curl -s http://localhost:9696/ping | grep -q "OK"; then
    echo -e "${GREEN}✅ Prowlarr est opérationnel${NC}\n"
else
    echo -e "${RED}⚠️  Prowlarr met du temps à démarrer, attendez encore 10 secondes${NC}\n"
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅ Installation terminée avec succès !      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}📋 ÉTAPES SUIVANTES (CRITIQUES) :${NC}\n"

echo -e "${YELLOW}1️⃣  Récupérer votre Passkey YGG :${NC}"
echo -e "   ${BLUE}→${NC} Allez sur ${GREEN}https://yggtorrent.fi${NC}"
echo -e "   ${BLUE}→${NC} Connectez-vous"
echo -e "   ${BLUE}→${NC} Cliquez sur votre pseudo (haut à droite) ${BLUE}→${NC} ${GREEN}Mon Compte${NC}"
echo -e "   ${BLUE}→${NC} Copiez votre ${GREEN}Passkey${NC} (pas le mot de passe !)\n"

echo -e "${YELLOW}2️⃣  Dans Prowlarr (${GREEN}http://localhost:9696${YELLOW}) :${NC}"
echo -e "   ${BLUE}→${NC} Allez dans ${GREEN}System → Tasks${NC}"
echo -e "   ${BLUE}→${NC} Cherchez la ligne ${GREEN}\"Indexer Definition Update\"${NC}"
echo -e "   ${BLUE}→${NC} Cliquez sur l'icône ${GREEN}▶️ (Play)${NC} à droite"
echo -e "   ${BLUE}→${NC} Attendez 30 secondes que la tâche se termine\n"

echo -e "${YELLOW}3️⃣  Ajouter l'indexeur YGG :${NC}"
echo -e "   ${BLUE}→${NC} ${GREEN}Indexers → Add Indexer${NC}"
echo -e "   ${BLUE}→${NC} Cherchez ${GREEN}\"YGGApi\"${NC} (il devrait maintenant apparaître !)"
echo -e "   ${BLUE}→${NC} Cliquez dessus et configurez :"
echo -e "      • ${GREEN}Passkey${NC} : Collez votre Passkey YGG"
echo -e "      • ${GREEN}Tracker Domain${NC} : yggtorrent.fi (ou votre domaine actuel)"
echo -e "   ${BLUE}→${NC} Cliquez sur ${GREEN}Test${NC} (✅ coche verte = OK)"
echo -e "   ${BLUE}→${NC} Cliquez sur ${GREEN}Save${NC}\n"

echo -e "${GREEN}🎉 C'est tout ! YGGTorrent sera connecté à Prowlarr !${NC}\n"

# Nettoyage
rm -f /tmp/ygg-api.yml /tmp/ygg-api-magnet.yml

echo -e "${BLUE}💡 Astuce :${NC} Vous pouvez relancer ce script à tout moment si YGG cesse de fonctionner.\n"
