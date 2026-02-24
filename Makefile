# ============================================================================
# Makefile - Stack Media Server (Servarr + Plex + VPN)
# ============================================================================
# Usage: make <command>
# Exemple: make start, make logs-radarr, make backup-all
# ============================================================================

.PHONY: help start stop restart status logs clean update backup restore vpn

# Couleurs pour l'affichage
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Variables
COMPOSE := docker-compose
BACKUP_DIR := ./backups
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

# ============================================================================
# AIDE - Affiche toutes les commandes disponibles
# ============================================================================

help: ## Affiche l'aide
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Stack Media Server - Commandes Makefile$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)📦 GESTION DES SERVICES :$(NC)"
	@echo "  make start              - Démarrer tous les services"
	@echo "  make stop               - Arrêter tous les services"
	@echo "  make restart            - Redémarrer tous les services"
	@echo "  make status             - Voir l'état des services"
	@echo "  make ps                 - Voir les conteneurs actifs"
	@echo ""
	@echo "$(YELLOW)🔍 LOGS :$(NC)"
	@echo "  make logs               - Voir tous les logs"
	@echo "  make logs-radarr        - Logs Radarr (films)"
	@echo "  make logs-sonarr        - Logs Sonarr (séries)"
	@echo "  make logs-prowlarr      - Logs Prowlarr (indexeurs)"
	@echo "  make logs-qbit          - Logs qBittorrent"
	@echo "  make logs-plex          - Logs Plex"
	@echo "  make logs-gluetun       - Logs VPN"
	@echo "  make logs-seerr         - Logs Seerr"
	@echo ""
	@echo "$(YELLOW)🔄 MISE À JOUR :$(NC)"
	@echo "  make update             - Mettre à jour tous les services"
	@echo "  make update-radarr      - Mettre à jour Radarr uniquement"
	@echo "  make update-sonarr      - Mettre à jour Sonarr uniquement"
	@echo "  make update-plex        - Mettre à jour Plex uniquement"
	@echo "  make update-seerr       - Mettre à jour Seerr uniquement"
	@echo ""
	@echo "$(YELLOW)📂 BACKUP & RESTORE :$(NC)"
	@echo "  make backup-all         - Sauvegarder toutes les configs"
	@echo "  make backup-radarr      - Sauvegarder Radarr"
	@echo "  make backup-sonarr      - Sauvegarder Sonarr"
	@echo "  make backup-prowlarr    - Sauvegarder Prowlarr"
	@echo "  make backup-plex        - Sauvegarder Plex"
	@echo "  make restore-radarr     - Restaurer Radarr"
	@echo "  make restore-sonarr     - Restaurer Sonarr"
	@echo "  make list-backups       - Liste des sauvegardes"
	@echo ""
	@echo "$(YELLOW)🌐 VPN & RÉSEAU :$(NC)"
	@echo "  make vpn-check          - Vérifier l'IP VPN"
	@echo "  make vpn-rotate         - Changer de serveur VPN"
	@echo "  make vpn-restart        - Redémarrer le VPN"
	@echo "  make network-test       - Tester la connectivité"
	@echo ""
	@echo "$(YELLOW)🧹 NETTOYAGE :$(NC)"
	@echo "  make clean              - Nettoyer les images inutilisées"
	@echo "  make clean-all          - Nettoyage complet (containers + volumes)"
	@echo "  make clean-downloads    - Nettoyer les téléchargements"
	@echo "  make prune              - Supprimer tout ce qui est inutilisé"
	@echo ""
	@echo "$(YELLOW)🔧 DIAGNOSTIC :$(NC)"
	@echo "  make check              - Vérification complète du système"
	@echo "  make disk-usage         - Usage disque des volumes"
	@echo "  make qbit-password      - Afficher le mot de passe qBittorrent"
	@echo "  make health             - État de santé des services"
	@echo ""
	@echo "$(YELLOW)🎬 MEDIA :$(NC)"
	@echo "  make media-scan         - Forcer scan Plex"
	@echo "  make media-stats        - Statistiques média"
	@echo "  make test-download      - Tester un téléchargement"
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"

# ============================================================================
# GESTION DES SERVICES
# ============================================================================

start: ## Démarrer tous les services
	@echo "$(GREEN)🚀 Démarrage de la stack Media Server...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)✅ Stack démarrée ! Attendez 10-15 secondes que tout soit prêt.$(NC)"
	@sleep 5
	@make status

stop: ## Arrêter tous les services
	@echo "$(YELLOW)⏸️  Arrêt de tous les services...$(NC)"
	@$(COMPOSE) stop
	@echo "$(GREEN)✅ Services arrêtés$(NC)"

restart: ## Redémarrer tous les services
	@echo "$(YELLOW)🔄 Redémarrage de tous les services...$(NC)"
	@$(COMPOSE) restart
	@echo "$(GREEN)✅ Services redémarrés$(NC)"

status: ## État des services
	@echo "$(BLUE)📊 État des services :$(NC)"
	@$(COMPOSE) ps

ps: status ## Alias pour status

down: ## Arrêter et supprimer les conteneurs
	@echo "$(RED)⚠️  Arrêt et suppression des conteneurs...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✅ Conteneurs supprimés$(NC)"

# ============================================================================
# LOGS
# ============================================================================

logs: ## Voir tous les logs
	@$(COMPOSE) logs -f --tail=100

logs-radarr: ## Logs Radarr
	@echo "$(BLUE)📺 Logs Radarr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f radarr --tail=100

logs-sonarr: ## Logs Sonarr
	@echo "$(BLUE)📺 Logs Sonarr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f sonarr --tail=100

logs-prowlarr: ## Logs Prowlarr
	@echo "$(BLUE)🔍 Logs Prowlarr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f prowlarr --tail=100

logs-qbit: ## Logs qBittorrent
	@echo "$(BLUE)📥 Logs qBittorrent (Ctrl+C pour quitter)$(NC)"
	@docker logs -f qbittorrent --tail=100

logs-plex: ## Logs Plex
	@echo "$(BLUE)🎬 Logs Plex (Ctrl+C pour quitter)$(NC)"
	@docker logs -f plex --tail=100

logs-gluetun: ## Logs VPN
	@echo "$(BLUE)🔐 Logs Gluetun VPN (Ctrl+C pour quitter)$(NC)"
	@docker logs -f gluetun --tail=100

logs-seerr: ## Logs Seerr
	@echo "$(BLUE)🎫 Logs Seerr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f seerr --tail=100

logs-flaresolverr: ## Logs Flaresolverr
	@echo "$(BLUE)🔥 Logs Flaresolverr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f flaresolverr --tail=100

# ============================================================================
# MISE À JOUR DES SERVICES
# ============================================================================

update: ## Mettre à jour tous les services
	@echo "$(YELLOW)📦 Mise à jour de tous les services...$(NC)"
	@$(COMPOSE) pull
	@$(COMPOSE) up -d
	@echo "$(GREEN)✅ Mise à jour terminée !$(NC)"
	@make clean

update-radarr: ## Mettre à jour Radarr
	@echo "$(YELLOW)📦 Mise à jour de Radarr...$(NC)"
	@$(COMPOSE) pull radarr
	@$(COMPOSE) up -d radarr
	@echo "$(GREEN)✅ Radarr mis à jour$(NC)"

update-sonarr: ## Mettre à jour Sonarr
	@echo "$(YELLOW)📦 Mise à jour de Sonarr...$(NC)"
	@$(COMPOSE) pull sonarr
	@$(COMPOSE) up -d sonarr
	@echo "$(GREEN)✅ Sonarr mis à jour$(NC)"

update-prowlarr: ## Mettre à jour Prowlarr
	@echo "$(YELLOW)📦 Mise à jour de Prowlarr...$(NC)"
	@$(COMPOSE) pull prowlarr
	@$(COMPOSE) up -d prowlarr
	@echo "$(GREEN)✅ Prowlarr mis à jour$(NC)"

update-plex: ## Mettre à jour Plex
	@echo "$(YELLOW)📦 Mise à jour de Plex...$(NC)"
	@$(COMPOSE) pull plex
	@$(COMPOSE) up -d plex
	@echo "$(GREEN)✅ Plex mis à jour$(NC)"

update-seerr: ## Mettre à jour Seerr
	@echo "$(YELLOW)📦 Mise à jour de Seerr...$(NC)"
	@$(COMPOSE) pull seerr
	@$(COMPOSE) up -d seerr
	@echo "$(GREEN)✅ Seerr mis à jour$(NC)"

update-qbit: ## Mettre à jour qBittorrent
	@echo "$(YELLOW)📦 Mise à jour de qBittorrent...$(NC)"
	@$(COMPOSE) pull qbittorrent
	@$(COMPOSE) up -d qbittorrent
	@echo "$(GREEN)✅ qBittorrent mis à jour$(NC)"

update-gluetun: ## Mettre à jour Gluetun
	@echo "$(YELLOW)📦 Mise à jour de Gluetun...$(NC)"
	@$(COMPOSE) pull gluetun
	@$(COMPOSE) up -d gluetun
	@echo "$(GREEN)✅ Gluetun mis à jour$(NC)"

# ============================================================================
# BACKUP & RESTORE
# ============================================================================

backup-all: backup-radarr backup-sonarr backup-prowlarr backup-plex backup-qbit backup-seerr ## Sauvegarder tout
	@echo "$(GREEN)✅ Sauvegarde complète terminée dans $(BACKUP_DIR)/$(NC)"
	@ls -lh $(BACKUP_DIR)

backup-radarr: ## Sauvegarder Radarr
	@echo "$(YELLOW)💾 Sauvegarde de Radarr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v radarr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/radarr_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Radarr sauvegardé : $(BACKUP_DIR)/radarr_$(TIMESTAMP).tar.gz$(NC)"

backup-sonarr: ## Sauvegarder Sonarr
	@echo "$(YELLOW)💾 Sauvegarde de Sonarr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v sonarr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/sonarr_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Sonarr sauvegardé : $(BACKUP_DIR)/sonarr_$(TIMESTAMP).tar.gz$(NC)"

backup-prowlarr: ## Sauvegarder Prowlarr
	@echo "$(YELLOW)💾 Sauvegarde de Prowlarr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v prowlarr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/prowlarr_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Prowlarr sauvegardé : $(BACKUP_DIR)/prowlarr_$(TIMESTAMP).tar.gz$(NC)"

backup-plex: ## Sauvegarder Plex
	@echo "$(YELLOW)💾 Sauvegarde de Plex...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v plex_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/plex_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Plex sauvegardé : $(BACKUP_DIR)/plex_$(TIMESTAMP).tar.gz$(NC)"

backup-qbit: ## Sauvegarder qBittorrent
	@echo "$(YELLOW)💾 Sauvegarde de qBittorrent...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v qbittorrent_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/qbittorrent_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ qBittorrent sauvegardé : $(BACKUP_DIR)/qbittorrent_$(TIMESTAMP).tar.gz$(NC)"

backup-seerr: ## Sauvegarder Seerr
	@echo "$(YELLOW)💾 Sauvegarde de Seerr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v seerr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/seerr_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Seerr sauvegardé : $(BACKUP_DIR)/seerr_$(TIMESTAMP).tar.gz$(NC)"

restore-radarr: ## Restaurer Radarr (make restore-radarr FILE=radarr_20240224.tar.gz)
	@echo "$(YELLOW)📥 Restauration de Radarr depuis $(FILE)...$(NC)"
	@docker run --rm -v radarr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/$(FILE) -C /"
	@echo "$(GREEN)✅ Radarr restauré$(NC)"
	@make restart

restore-sonarr: ## Restaurer Sonarr
	@echo "$(YELLOW)📥 Restauration de Sonarr depuis $(FILE)...$(NC)"
	@docker run --rm -v sonarr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/$(FILE) -C /"
	@echo "$(GREEN)✅ Sonarr restauré$(NC)"
	@make restart

list-backups: ## Lister les sauvegardes
	@echo "$(BLUE)📂 Sauvegardes disponibles dans $(BACKUP_DIR)/ :$(NC)"
	@ls -lh $(BACKUP_DIR) 2>/dev/null || echo "$(YELLOW)Aucune sauvegarde trouvée$(NC)"

# ============================================================================
# VPN & RÉSEAU
# ============================================================================

vpn-check: ## Vérifier l'IP VPN
	@echo "$(BLUE)🌐 Vérification de l'IP VPN...$(NC)"
	@echo "$(YELLOW)Votre IP publique :$(NC)"
	@curl -s https://ipinfo.io/ip
	@echo ""
	@echo "$(YELLOW)IP du VPN (qBittorrent) :$(NC)"
	@docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "$(RED)❌ VPN non accessible$(NC)"
	@echo ""

vpn-rotate: ## Changer de serveur VPN
	@echo "$(YELLOW)🔄 Rotation du serveur VPN...$(NC)"
	@./rotate-vpn.sh

vpn-restart: ## Redémarrer le VPN
	@echo "$(YELLOW)🔄 Redémarrage du VPN...$(NC)"
	@$(COMPOSE) restart gluetun
	@echo "$(YELLOW)⏳ Attente de la reconnexion (30 secondes)...$(NC)"
	@sleep 30
	@$(COMPOSE) restart qbittorrent
	@echo "$(GREEN)✅ VPN redémarré$(NC)"
	@make vpn-check

vpn-status: ## Statut du VPN
	@echo "$(BLUE)📊 Statut Gluetun :$(NC)"
	@docker exec gluetun sh -c "wget -qO- http://localhost:8000/v1/openvpn/status 2>/dev/null" || echo "$(YELLOW)Status endpoint non disponible$(NC)"

network-test: ## Tester la connectivité
	@echo "$(BLUE)🔌 Test de connectivité réseau...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Test Internet général :$(NC)"
	@curl -s -o /dev/null -w "Google : %{http_code}\n" https://google.com
	@echo ""
	@echo "$(YELLOW)2. Test VPN :$(NC)"
	@docker exec gluetun wget -qO- https://ipinfo.io 2>/dev/null | head -10 || echo "$(RED)Échec$(NC)"

# ============================================================================
# NETTOYAGE
# ============================================================================

clean: ## Nettoyer les images inutilisées
	@echo "$(YELLOW)🧹 Nettoyage des images Docker inutilisées...$(NC)"
	@docker image prune -f
	@echo "$(GREEN)✅ Nettoyage terminé$(NC)"

clean-downloads: ## Nettoyer les téléchargements terminés
	@echo "$(YELLOW)🧹 Nettoyage des téléchargements terminés...$(NC)"
	@echo "$(RED)⚠️  Cette action supprimera /Users/dev/data/downloads/complete/*$(NC)"
	@read -p "Continuer ? (oui/non) : " confirm && [ "$$confirm" = "oui" ] || exit 1
	@rm -rf /Users/dev/data/downloads/complete/*
	@echo "$(GREEN)✅ Téléchargements nettoyés$(NC)"

clean-all: ## Nettoyage complet (ATTENTION : supprime tout !)
	@echo "$(RED)⚠️  ATTENTION : Cette action supprime TOUS les conteneurs et volumes !$(NC)"
	@./cleanup.sh

prune: ## Supprimer tout ce qui est inutilisé
	@echo "$(YELLOW)🧹 Nettoyage complet Docker...$(NC)"
	@docker system prune -a --volumes -f
	@echo "$(GREEN)✅ Nettoyage terminé$(NC)"

# ============================================================================
# DIAGNOSTIC
# ============================================================================

check: ## Vérification complète du système
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Vérification complète du système$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)1. État des services :$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@echo "$(YELLOW)2. Santé des conteneurs :$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(gluetun|radarr|sonarr|prowlarr|qbit|plex|seerr)" || true
	@echo ""
	@echo "$(YELLOW)3. Usage disque :$(NC)"
	@df -h /Users/dev/data 2>/dev/null || echo "$(RED)Dossier /Users/dev/data non trouvé$(NC)"
	@echo ""
	@echo "$(YELLOW)4. Vérification VPN :$(NC)"
	@make vpn-check
	@echo ""
	@echo "$(YELLOW)5. Volumes Docker :$(NC)"
	@docker volume ls | grep -E "(radarr|sonarr|prowlarr|plex|qbit|seerr|gluetun)"
	@echo ""
	@echo "$(GREEN)✅ Vérification terminée$(NC)"

health: ## État de santé des services
	@echo "$(BLUE)🏥 État de santé des services :$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(gluetun|radarr|sonarr|prowlarr|qbit|plex|seerr|flare)"

disk-usage: ## Usage disque des volumes
	@echo "$(BLUE)💾 Usage disque des volumes Docker :$(NC)"
	@docker system df -v | grep -E "(radarr|sonarr|prowlarr|plex|qbit|seerr|gluetun)" || true
	@echo ""
	@echo "$(BLUE)💾 Usage disque /Users/dev/data :$(NC)"
	@du -sh /Users/dev/data/* 2>/dev/null || echo "$(RED)Dossier non trouvé$(NC)"

qbit-password: ## Afficher le mot de passe qBittorrent
	@echo "$(BLUE)🔑 Mot de passe temporaire qBittorrent :$(NC)"
	@docker logs qbittorrent 2>&1 | grep "temporary password" | tail -1 || echo "$(YELLOW)Mot de passe déjà changé ou non trouvé$(NC)"

# ============================================================================
# MEDIA
# ============================================================================

media-scan: ## Forcer scan Plex
	@echo "$(YELLOW)📡 Démarrage du scan Plex...$(NC)"
	@docker exec plex sh -c "curl -X GET 'http://localhost:32400/library/sections/all/refresh?X-Plex-Token=token'" 2>/dev/null || echo "$(YELLOW)Scan lancé (si Plex est configuré)$(NC)"
	@echo "$(GREEN)✅ Scan Plex lancé$(NC)"

media-stats: ## Statistiques média
	@echo "$(BLUE)📊 Statistiques des médias :$(NC)"
	@echo ""
	@echo "$(YELLOW)Films :$(NC)"
	@find /Users/dev/data/media/movies -type f -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" 2>/dev/null | wc -l | xargs echo "Nombre de fichiers :"
	@du -sh /Users/dev/data/media/movies 2>/dev/null | awk '{print "Espace utilisé : " $$1}'
	@echo ""
	@echo "$(YELLOW)Séries :$(NC)"
	@find /Users/dev/data/media/tv -type f -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" 2>/dev/null | wc -l | xargs echo "Nombre de fichiers :"
	@du -sh /Users/dev/data/media/tv 2>/dev/null | awk '{print "Espace utilisé : " $$1}'
	@echo ""
	@echo "$(YELLOW)Téléchargements en cours :$(NC)"
	@du -sh /Users/dev/data/downloads/incomplete 2>/dev/null | awk '{print "Espace utilisé : " $$1}'
	@echo ""
	@echo "$(YELLOW)Téléchargements terminés :$(NC)"
	@du -sh /Users/dev/data/downloads/complete 2>/dev/null | awk '{print "Espace utilisé : " $$1}'

test-download: ## Tester un téléchargement (magnet test)
	@echo "$(YELLOW)🧪 Cette commande nécessite un magnet link de test$(NC)"
	@echo "$(BLUE)Utilisez qBittorrent Web UI : http://localhost:8090$(NC)"

# ============================================================================
# RACCOURCIS & ALIAS
# ============================================================================

up: start ## Alias pour start
d: down ## Alias pour down
r: restart ## Alias pour restart
l: logs ## Alias pour logs

# Redémarrages rapides
restart-radarr: ## Redémarrer Radarr
	@$(COMPOSE) restart radarr
	@echo "$(GREEN)✅ Radarr redémarré$(NC)"

restart-sonarr: ## Redémarrer Sonarr
	@$(COMPOSE) restart sonarr
	@echo "$(GREEN)✅ Sonarr redémarré$(NC)"

restart-prowlarr: ## Redémarrer Prowlarr
	@$(COMPOSE) restart prowlarr
	@echo "$(GREEN)✅ Prowlarr redémarré$(NC)"

restart-plex: ## Redémarrer Plex
	@$(COMPOSE) restart plex
	@echo "$(GREEN)✅ Plex redémarré$(NC)"

restart-qbit: ## Redémarrer qBittorrent
	@$(COMPOSE) restart gluetun
	@sleep 30
	@$(COMPOSE) restart qbittorrent
	@echo "$(GREEN)✅ qBittorrent redémarré$(NC)"

# URLs rapides
urls: ## Afficher les URLs d'accès
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  URLs d'accès aux services$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Prowlarr      :$(NC) http://localhost:9696"
	@echo "$(YELLOW)Radarr        :$(NC) http://localhost:7878"
	@echo "$(YELLOW)Sonarr        :$(NC) http://localhost:8989"
	@echo "$(YELLOW)Seerr         :$(NC) http://localhost:5055"
	@echo "$(YELLOW)qBittorrent   :$(NC) http://localhost:8090"
	@echo "$(YELLOW)Plex          :$(NC) http://localhost:32400/web"
	@echo "$(YELLOW)Flaresolverr  :$(NC) http://localhost:8191"
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"

# Installation
install: ## Installation complète (première fois)
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Installation de la Stack Media Server$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Création de la structure de dossiers...$(NC)"
	@mkdir -p /Users/dev/data/downloads/incomplete
	@mkdir -p /Users/dev/data/downloads/complete
	@mkdir -p /Users/dev/data/media/movies
	@mkdir -p /Users/dev/data/media/tv
	@echo "$(GREEN)✅ Structure créée$(NC)"
	@echo ""
	@echo "$(YELLOW)2. Vérification du fichier .env...$(NC)"
	@test -f .env && echo "$(GREEN)✅ .env trouvé$(NC)" || echo "$(RED)❌ .env non trouvé - créez-le !$(NC)"
	@echo ""
	@echo "$(YELLOW)3. Démarrage des services...$(NC)"
	@make start
	@echo ""
	@echo "$(GREEN)✅ Installation terminée !$(NC)"
	@echo ""
	@make urls

# Default target
.DEFAULT_GOAL := help
