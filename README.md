# Media Server Stack

Stack Docker automatisee : Plex + Radarr + Sonarr + Prowlarr + qBittorrent + VPN

---

## Installation rapide

```bash
# 1. Configuration
cp .env.example .env
nano .env  # Ajouter NordVPN credentials + API keys

# 2. Installation
make setup

# ou manuellement :
./scripts/setup.sh
```

---

## Services

| Service | Port | Description |
|---------|------|-------------|
| Plex | 32400 | http://localhost:32400/web |
| Radarr | 7878 | http://localhost:7878 (Films) |
| Sonarr | 8989 | http://localhost:8989 (Series) |
| Prowlarr | 9696 | http://localhost:9696 (Indexeurs) |
| qBittorrent | 8090 | http://localhost:8090 (via VPN) |
| Seerr | 5055 | http://localhost:5055 (Requetes) |
| Tautulli | 8181 | http://localhost:8181 (Stats Plex) |
| Jackett | 9117 | http://localhost:9117 (Indexeurs alt.) |
| Flaresolverr | 8191 | http://localhost:8191 (Anti-Cloudflare) |
| PlexTraktSync | - | Sync Plex <-> Trakt.tv |
| Recyclarr | - | TRaSH Guides auto-sync |

---

## Commandes principales

```bash
make help               # Aide complete

# Gestion
make start / stop / restart
make status / logs

# Configuration
make setup              # Installation auto
make export             # Sauvegarder config (nettoyee)
make import             # Restaurer config
make restore            # Restauration complete (import + recyclarr)
make package            # Creer archive

# VPN
make vpn-check          # Verifier IP
make vpn-rotate         # Changer serveur

# Maintenance
make update             # Mise a jour images
make backup-all         # Sauvegarde volumes Docker
make clean              # Nettoyage images
```

---

## Configuration

### Config auto (recommande)

Si vous avez une config exportee :
```bash
make import
```

### Config manuelle

1. **Prowlarr** - Ajouter indexeurs + connecter Radarr/Sonarr
2. **qBittorrent** - Desactiver "Host header validation"
3. **Radarr** - Root `/data/media/movies` + Download client `gluetun:8090`
4. **Sonarr** - Root `/data/media/tv` + Download client `gluetun:8090`
5. **Plex** - Ajouter bibliotheques

Puis sauvegarder :
```bash
make export
```

---

## Migration / Sauvegarde

```bash
# Sauvegarder
make export
git add config-exports/ && git commit -m "config backup"

# Restaurer (nouvelle machine)
git clone <repo>
cp .env.example .env && nano .env
make setup  # Import auto si config-exports/ existe
```

---

## Structure du projet

```
Media-Server/
├── docker-compose.yml      # Definition des services
├── Makefile                 # Commandes raccourcies
├── .env.example             # Template variables d'environnement
├── .env                     # Variables reelles (non versionne)
│
├── scripts/                 # Scripts d'automatisation
│   ├── setup.sh             # Installation premiere fois
│   ├── export-config.sh     # Export config API (nettoyee)
│   ├── import-config.sh     # Import config API
│   ├── cleanup.sh           # Nettoyage radical
│   ├── install-ygg.sh       # YGGTorrent pour Prowlarr
│   └── vpn.sh               # Gestion VPN
│
├── config-exports/          # Configs JSON exportees (source de verite)
│   ├── prowlarr-*.json
│   ├── radarr-*.json
│   ├── sonarr-*.json
│   └── qbittorrent-*.json
│
├── config-templates/        # Templates XML (utilises par setup.sh)
│   ├── prowlarr-config.xml
│   ├── radarr-config.xml
│   └── sonarr-config.xml
│
├── prowlarr/config.xml      # Config XML generee (API key + auth)
├── radarr/config.xml        # Config XML generee (API key + auth)
├── sonarr/config.xml        # Config XML generee (API key + auth)
│
├── recyclarr/               # TRaSH Guides (quality profiles, custom formats)
│   ├── recyclarr.yml        # Config principale
│   └── settings.yml         # Settings
│
├── plextraktsync/           # Sync Plex <-> Trakt.tv
│   ├── config.yml
│   └── servers.yml
│
└── backups/                 # Archives tar.gz des volumes Docker
```

---

## Troubleshooting

```bash
# VPN ne marche pas
make vpn-check
make logs-gluetun

# API Keys manquantes
make show-api-keys

# Services ne demarrent pas
make status
make logs

# Restauration complete
make restore
```
