# ============================================================================
# Makefile - ArrStack (Jellyfin + Servarr + VPN)
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
	@echo "$(GREEN)  ArrStack - Commandes Makefile$(NC)"
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
	@echo "  make logs-jellyfin      - Logs Jellyfin"
	@echo "  make logs-gluetun       - Logs VPN"
	@echo "  make logs-jellyseerr    - Logs Jellyseerr"
	@echo "  make logs-jellystat     - Logs Jellystat"
	@echo "  make logs-recyclarr     - Logs Recyclarr"
	@echo "  make logs-jackett       - Logs Jackett"
	@echo "  make logs-rdtclient     - Logs RDTClient"
	@echo ""
	@echo "$(YELLOW)🔄 MISE À JOUR :$(NC)"
	@echo "  make update             - Mettre à jour tous les services"
	@echo "  make update-radarr      - Mettre à jour Radarr uniquement"
	@echo "  make update-sonarr      - Mettre à jour Sonarr uniquement"
	@echo "  make update-jellyfin    - Mettre à jour Jellyfin uniquement"
	@echo "  make update-jellyseerr  - Mettre à jour Jellyseerr uniquement"
	@echo "  make update-jellystat   - Mettre à jour Jellystat uniquement"
	@echo "  make update-recyclarr   - Mettre à jour Recyclarr uniquement"
	@echo "  make update-jackett     - Mettre à jour Jackett uniquement"
	@echo "  make update-rdtclient   - Mettre à jour RDTClient uniquement"
	@echo ""
	@echo "$(YELLOW)📂 BACKUP & RESTORE :$(NC)"
	@echo "  make backup-all         - Sauvegarder toutes les configs"
	@echo "  make backup-radarr      - Sauvegarder Radarr"
	@echo "  make backup-sonarr      - Sauvegarder Sonarr"
	@echo "  make backup-prowlarr    - Sauvegarder Prowlarr"
	@echo "  make backup-jellyfin   - Sauvegarder Jellyfin"
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
	@echo "  make media-scan         - Forcer scan Jellyfin"
	@echo "  make media-stats        - Statistiques média"
	@echo "  make test-download      - Tester un téléchargement"
	@echo ""
	@echo "$(YELLOW)🎞️  VF/VO (Gestion langues) :$(NC)"
	@echo "  make check-audio        - Vérifier les pistes audio d'un film"
	@echo "  make list-multi         - Lister les films MULTi (VF+VO)"
	@echo "  make count-languages    - Compter les films par langue"
	@echo ""
	@echo "$(YELLOW) CONFIGURATION :$(NC)"
	@echo "  make setup              - Installation automatique complète"
	@echo "  make export             - Exporter configuration actuelle"
	@echo "  make import             - Importer configuration sauvegardée"
	@echo "  make restore            - Restauration complète → import + recyclarr sync"
	@echo "  make package            - Créer archive à partager"
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"

# ============================================================================
# GESTION DES SERVICES
# ============================================================================

start: ## Démarrer tous les services
	@echo "$(GREEN)🚀 Démarrage de ArrStack...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)✅ Stack démarrée ! Attendez 10-15 secondes que tout soit prêt.$(NC)"
	@sleep 15
	@make status

stop: ## Arrêter tous les services
	@echo "$(YELLOW)⏸️  Arrêt de tous les services...$(NC)"
	@$(COMPOSE) stop
	@echo "$(GREEN)✅ Services arrêtés$(NC)"

restart: ## Redémarrer tous les services
	@echo "$(YELLOW)🔄 Redémarrage de tous les services...$(NC)"
	@$(COMPOSE) restart
	@sleep 15
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

logs-jellyfin: ## Logs Jellyfin
	@echo "$(BLUE)🎬 Logs Jellyfin (Ctrl+C pour quitter)$(NC)"
	@docker logs -f jellyfin --tail=100

logs-gluetun: ## Logs VPN
	@echo "$(BLUE)🔐 Logs Gluetun VPN (Ctrl+C pour quitter)$(NC)"
	@docker logs -f gluetun --tail=100

logs-jellyseerr: ## Logs Jellyseerr
	@echo "$(BLUE)🎫 Logs Jellyseerr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f jellyseerr --tail=100

logs-jellystat: ## Logs Jellystat
	@echo "$(BLUE)📊 Logs Jellystat (Ctrl+C pour quitter)$(NC)"
	@docker logs -f jellystat --tail=100

logs-recyclarr: ## Logs Recyclarr
	@echo "$(BLUE)♻️ Logs Recyclarr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f recyclarr --tail=100

logs-flaresolverr: ## Logs Flaresolverr
	@echo "$(BLUE)🔥 Logs Flaresolverr (Ctrl+C pour quitter)$(NC)"
	@docker logs -f flaresolverr --tail=100

logs-jackett: ## Logs Jackett
	@echo "$(BLUE)🔍 Logs Jackett (Ctrl+C pour quitter)$(NC)"
	@docker logs -f jackett --tail=100

logs-rdtclient: ## Logs RDTClient
	@echo "$(BLUE)💎 Logs RDTClient (Ctrl+C pour quitter)$(NC)"
	@docker logs -f rdtclient --tail=100

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

update-jellyfin: ## Mettre à jour Jellyfin
	@echo "$(YELLOW)📦 Mise à jour de Jellyfin...$(NC)"
	@$(COMPOSE) pull jellyfin
	@$(COMPOSE) up -d jellyfin
	@echo "$(GREEN)✅ Jellyfin mis à jour$(NC)"

update-jellyseerr: ## Mettre à jour Jellyseerr
	@echo "$(YELLOW)📦 Mise à jour de Jellyseerr...$(NC)"
	@$(COMPOSE) pull jellyseerr
	@$(COMPOSE) up -d jellyseerr
	@echo "$(GREEN)✅ Jellyseerr mis à jour$(NC)"

update-jellystat: ## Mettre à jour Jellystat
	@echo "$(YELLOW)📦 Mise à jour de Jellystat...$(NC)"
	@$(COMPOSE) pull jellystat
	@$(COMPOSE) up -d jellystat
	@echo "$(GREEN)✅ Jellystat mis à jour$(NC)"

update-recyclarr: ## Mettre à jour Recyclarr
	@echo "$(YELLOW)📦 Mise à jour de Recyclarr...$(NC)"
	@$(COMPOSE) pull recyclarr
	@$(COMPOSE) up -d recyclarr
	@echo "$(GREEN)✅ Recyclarr mis à jour$(NC)"

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

update-jackett: ## Mettre à jour Jackett
	@echo "$(YELLOW)📦 Mise à jour de Jackett...$(NC)"
	@$(COMPOSE) pull jackett
	@$(COMPOSE) up -d jackett
	@echo "$(GREEN)✅ Jackett mis à jour$(NC)"

update-rdtclient: ## Mettre à jour RDTClient
	@echo "$(YELLOW)📦 Mise à jour de RDTClient...$(NC)"
	@$(COMPOSE) pull rdtclient
	@$(COMPOSE) up -d rdtclient
	@echo "$(GREEN)✅ RDTClient mis à jour$(NC)"

# ============================================================================
# BACKUP & RESTORE
# ============================================================================

backup-all: backup-radarr backup-sonarr backup-prowlarr backup-jellyfin backup-qbit backup-jellyseerr backup-jellystat backup-recyclarr backup-jackett backup-rdtclient ## Sauvegarder tout
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

backup-jellyfin: ## Sauvegarder Jellyfin
	@echo "$(YELLOW)💾 Sauvegarde de Jellyfin...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v jellyfin_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/jellyfin_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Jellyfin sauvegardé : $(BACKUP_DIR)/jellyfin_$(TIMESTAMP).tar.gz$(NC)"

backup-qbit: ## Sauvegarder qBittorrent
	@echo "$(YELLOW)💾 Sauvegarde de qBittorrent...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v qbittorrent_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/qbittorrent_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ qBittorrent sauvegardé : $(BACKUP_DIR)/qbittorrent_$(TIMESTAMP).tar.gz$(NC)"

backup-jellyseerr: ## Sauvegarder Jellyseerr
	@echo "$(YELLOW)💾 Sauvegarde de Jellyseerr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v jellyseerr_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/jellyseerr_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Jellyseerr sauvegardé : $(BACKUP_DIR)/jellyseerr_$(TIMESTAMP).tar.gz$(NC)"

backup-jellystat: ## Sauvegarder Jellystat
	@echo "$(YELLOW)💾 Sauvegarde de Jellystat...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v jellystat_db:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/jellystat_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Jellystat sauvegardé : $(BACKUP_DIR)/jellystat_$(TIMESTAMP).tar.gz$(NC)"

backup-recyclarr: ## Sauvegarder Recyclarr
	@echo "$(YELLOW)💾 Sauvegarde de Recyclarr...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@tar czf $(BACKUP_DIR)/recyclarr_$(TIMESTAMP).tar.gz recyclarr/
	@echo "$(GREEN)✅ Recyclarr sauvegardé : $(BACKUP_DIR)/recyclarr_$(TIMESTAMP).tar.gz$(NC)"

backup-jackett: ## Sauvegarder Jackett
	@echo "$(YELLOW)💾 Sauvegarde de Jackett...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v jackett_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/jackett_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ Jackett sauvegardé : $(BACKUP_DIR)/jackett_$(TIMESTAMP).tar.gz$(NC)"

backup-rdtclient: ## Sauvegarder RDTClient
	@echo "$(YELLOW)💾 Sauvegarde de RDTClient...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm -v rdtclient_config:/data -v $(PWD)/$(BACKUP_DIR):/backup alpine tar czf /backup/rdtclient_$(TIMESTAMP).tar.gz /data
	@echo "$(GREEN)✅ RDTClient sauvegardé : $(BACKUP_DIR)/rdtclient_$(TIMESTAMP).tar.gz$(NC)"

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
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(gluetun|radarr|sonarr|prowlarr|jackett|qbit|jellyfin|jellyseerr|jellystat|rdtclient)" || true
	@echo ""
	@echo "$(YELLOW)3. Usage disque :$(NC)"
	@df -h /Users/dev/data 2>/dev/null || echo "$(RED)Dossier /Users/dev/data non trouvé$(NC)"
	@echo ""
	@echo "$(YELLOW)4. Vérification VPN :$(NC)"
	@make vpn-check
	@echo ""
	@echo "$(YELLOW)5. Volumes Docker :$(NC)"
	@docker volume ls | grep -E "(radarr|sonarr|prowlarr|jackett|jellyfin|qbit|jellyseerr|jellystat|gluetun|rdtclient)"
	@echo ""
	@echo "$(GREEN)✅ Vérification terminée$(NC)"

health: ## État de santé des services
	@echo "$(BLUE)🏥 État de santé des services :$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(gluetun|radarr|sonarr|prowlarr|jackett|qbit|jellyfin|jellyseerr|jellystat|flare|rdtclient)"

disk-usage: ## Usage disque des volumes
	@echo "$(BLUE)💾 Usage disque des volumes Docker :$(NC)"
	@docker system df -v | grep -E "(radarr|sonarr|prowlarr|jackett|jellyfin|qbit|jellyseerr|jellystat|gluetun|rdtclient)" || true
	@echo ""
	@echo "$(BLUE)💾 Usage disque /Users/dev/data :$(NC)"
	@du -sh /Users/dev/data/* 2>/dev/null || echo "$(RED)Dossier non trouvé$(NC)"

qbit-password: ## Afficher le mot de passe qBittorrent
	@echo "$(BLUE)🔑 Mot de passe temporaire qBittorrent :$(NC)"
	@docker logs qbittorrent 2>&1 | grep "temporary password" | tail -1 || echo "$(YELLOW)Mot de passe déjà changé ou non trouvé$(NC)"

# ============================================================================
# MEDIA
# ============================================================================

media-scan: ## Forcer scan Jellyfin
	@echo "$(YELLOW)📡 Démarrage du scan Jellyfin...$(NC)"
	@curl -sf -X POST "http://localhost:8096/Library/Refresh" -H "X-Emby-Authorization: MediaBrowser Token=\"$$(grep JELLYFIN_API_KEY .env 2>/dev/null | cut -d= -f2)\"" 2>/dev/null || echo "$(YELLOW)Scan lancé (si Jellyfin est configuré)$(NC)"
	@echo "$(GREEN)✅ Scan Jellyfin lancé$(NC)"

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

restart-jellyfin: ## Redémarrer Jellyfin
	@$(COMPOSE) restart jellyfin
	@echo "$(GREEN)✅ Jellyfin redémarré$(NC)"

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
	@echo "$(YELLOW)Jackett       :$(NC) http://localhost:9117"
	@echo "$(YELLOW)Radarr        :$(NC) http://localhost:7878"
	@echo "$(YELLOW)Sonarr        :$(NC) http://localhost:8989"
	@echo "$(YELLOW)Jellyfin      :$(NC) http://localhost:8096"
	@echo "$(YELLOW)Jellyseerr    :$(NC) http://localhost:5055"
	@echo "$(YELLOW)Jellystat     :$(NC) http://localhost:3000"
	@echo "$(YELLOW)qBittorrent   :$(NC) http://localhost:8090"
	@echo "$(YELLOW)RDTClient     :$(NC) http://localhost:6500"
	@echo "$(YELLOW)Flaresolverr  :$(NC) http://localhost:8191"
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"

# Installation
install: ## Installation complète (première fois)
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Installation de ArrStack$(NC)"
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

# ============================================================================
# VF/VO - Gestion des langues
# ============================================================================

check-audio: ## Vérifier les pistes audio d'un fichier
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Vérification des pistes audio$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@read -p "$(YELLOW)Nom du film (ex: Inception) : $(NC)" movie; \
	file=$$(find /Users/dev/data/media/movies -iname "*$$movie*" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) | head -1); \
	if [ -z "$$file" ]; then \
		echo "$(RED)❌ Film non trouvé !$(NC)"; \
	else \
		echo "$(GREEN)📁 Fichier : $$file$(NC)"; \
		echo ""; \
		echo "$(YELLOW)🔊 Pistes audio :$(NC)"; \
		docker run --rm -v /Users/dev/data:/data jrottenberg/ffmpeg:4.4-alpine \
			-i "$$file" 2>&1 | grep "Audio:" | nl; \
		echo ""; \
		echo "$(YELLOW)📝 Sous-titres :$(NC)"; \
		docker run --rm -v /Users/dev/data:/data jrottenberg/ffmpeg:4.4-alpine \
			-i "$$file" 2>&1 | grep "Subtitle:" | nl || echo "Aucun sous-titre"; \
	fi

list-multi: ## Lister les films avec pistes audio multiples
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Films MULTi (plusieurs pistes audio)$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)🔍 Recherche en cours...$(NC)"
	@echo ""
	@count=0; \
	find /Users/dev/data/media/movies -type f \( -name "*.mkv" -o -name "*.mp4" \) 2>/dev/null | while read file; do \
		tracks=$$(docker run --rm -v /Users/dev/data:/data jrottenberg/ffmpeg:4.4-alpine \
			-i "$$file" 2>&1 | grep -c "Audio:" || echo "0"); \
		if [ "$$tracks" -ge 2 ]; then \
			basename=$$(basename "$$file"); \
			echo "$(GREEN)✅ $$basename$(NC) ($$tracks pistes)"; \
			count=$$((count + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "$(GREEN)Nombre total de films MULTi : $$count$(NC)"

count-languages: ## Compter les films par langue
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Statistiques des langues audio$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)📊 Analyse en cours (peut prendre quelques minutes)...$(NC)"
	@echo ""
	@multi=0; single=0; total=0; \
	find /Users/dev/data/media/movies -type f \( -name "*.mkv" -o -name "*.mp4" \) 2>/dev/null | while read file; do \
		tracks=$$(docker run --rm -v /Users/dev/data:/data jrottenberg/ffmpeg:4.4-alpine \
			-i "$$file" 2>&1 | grep -c "Audio:" || echo "0"); \
		if [ "$$tracks" -ge 2 ]; then \
			multi=$$((multi + 1)); \
		elif [ "$$tracks" -eq 1 ]; then \
			single=$$((single + 1)); \
		fi; \
		total=$$((total + 1)); \
	done; \
	echo "$(GREEN)📽️  Total de films       : $$total$(NC)"; \
	echo "$(GREEN)🌍 Films MULTi (VF+VO)  : $$multi$(NC)"; \
	echo "$(YELLOW)🗣️  Films mono-langue    : $$single$(NC)"; \
	echo ""

# ============================================================================
# CONFIGURATION - Setup et gestion
# ============================================================================

setup: ## Installation automatique complète
	@./scripts/setup.sh

export: ## Exporter configuration actuelle
	@./scripts/export-config.sh

import: ## Importer configuration sauvegardée
	@./scripts/import-config.sh

restore: ## Restauration complète (export → clean → import → recyclarr sync)
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  🔄 Restauration complète de la configuration$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Import via API (Radarr/Sonarr naming & mediamanagement)...$(NC)"
	@./scripts/import-config.sh
	@echo ""
	@echo "$(YELLOW)2. Sync Recyclarr (TRaSH Guides custom formats & profiles)...$(NC)"
	@$(COMPOSE) exec recyclarr recyclarr state repair --adopt 2>/dev/null || true
	@$(COMPOSE) exec recyclarr recyclarr sync
	@echo ""
	@echo "$(GREEN)✅ Restauration complète terminée !$(NC)"
	@echo ""
	@echo "$(YELLOW)📋 Services restaurés :$(NC)"
	@echo "  ✓ Radarr: Custom Formats + Quality Profiles"
	@echo "  ✓ Sonarr: Custom Formats + Quality Profiles"
	@echo "  ⊘ Prowlarr: Indexers doivent être reconfigurés manuellement"

package: ## Créer archive complète
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  📦 Création d'une archive de configuration$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)📤 Export de la configuration en cours...$(NC)"
	@./scripts/export-config.sh
	@echo ""
	@echo "$(YELLOW)📦 Création de l'archive...$(NC)"
	@tar -czf arrstack-config-$(TIMESTAMP).tar.gz \
		docker-compose.yml \
		.env.example \
		config-exports/ \
		config-templates/ \
		recyclarr/recyclarr.yml recyclarr/settings.yml \
		scripts/ \
		prowlarr/ radarr/ sonarr/ \
		Makefile \
		README.md \
		2>/dev/null || true
	@echo "$(GREEN)✅ Archive créée : arrstack-config-$(TIMESTAMP).tar.gz$(NC)"
	@echo ""
	@echo "$(YELLOW)📋 Contenu de l'archive :$(NC)"
	@tar -tzf arrstack-config-$(TIMESTAMP).tar.gz | head -20
	@echo ""
	@echo "$(GREEN)🎉 Archive prête à partager !$(NC)"
	@ls -lh arrstack-config-$(TIMESTAMP).tar.gz

show-api-keys: ## Afficher toutes les API keys
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  🔑 API Keys des services$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Prowlarr :$(NC)"
	@docker exec prowlarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "  $(RED)❌ Non trouvée$(NC)"
	@echo ""
	@echo "$(YELLOW)Radarr :$(NC)"
	@docker exec radarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "  $(RED)❌ Non trouvée$(NC)"
	@echo ""
	@echo "$(YELLOW)Sonarr :$(NC)"
	@docker exec sonarr cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "  $(RED)❌ Non trouvée$(NC)"
	@echo ""
	@echo "$(GREEN)💡 Ajoutez ces clés dans votre fichier .env$(NC)"

# Default target
.DEFAULT_GOAL := help
