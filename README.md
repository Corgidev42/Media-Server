# ArrStack

Stack Docker automatisee : Jellyfin + Jellyseerr + Radarr + Sonarr + Prowlarr + Jackett + qBittorrent + RDTClient (AllDebrid) + VPN + Recyclarr

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

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Jellyfin | 8096 | http://localhost:8096 | Serveur multimedia (lecture) |
| Jellyseerr | 5055 | http://localhost:5055 | Interface de requetes (films/series) |
| Radarr | 7878 | http://localhost:7878 | Gestionnaire de films |
| Sonarr | 8989 | http://localhost:8989 | Gestionnaire de series |
| Prowlarr | 9696 | http://localhost:9696 | Gestionnaire d'indexeurs |
| Jackett | 9117 | http://localhost:9117 | Indexeur YGGTorrent (tracker prive) |
| qBittorrent | 8090 | http://localhost:8090 | Client torrent (via VPN NordVPN) |
| RDTClient | 6500 | http://localhost:6500 | Client debrid (AllDebrid / Real-Debrid) |
| Jellystat | 6555 | http://localhost:6555 | Statistiques Jellyfin |
| Flaresolverr | 8191 | http://localhost:8191 | Contournement Cloudflare |
| Recyclarr | - | - | Sync auto TRaSH Guides (quality profiles) |

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

### Ce que `make setup` configure automatiquement

| Service | Configuration automatique |
|---------|-------------------------|
| **Radarr / Sonarr / Prowlarr** | API keys, auth (forms + local bypass), root folders |
| **Prowlarr** | FlareSolverr, 1337x, YGGTorrent (via Jackett) |
| **Jackett** | FlareSolverr, YGGTorrent (si credentials dans .env) |
| **RDTClient** | Compte, AllDebrid provider + API key, download path |
| **Radarr / Sonarr** | Download client RDTClient (rdtclient:6500) |
| **Jellyfin** | Wizard, admin, bibliotheques Films/Series, plugin Trakt |
| **Jellyseerr** | Connexion Jellyfin + Radarr + Sonarr |
| **Jellystat** | Connexion Jellyfin (API key auto) |
| **Recyclarr** | TRaSH Guides (quality profiles, custom formats) |

### Config manuelle (optionnel)

Si vous preferez configurer manuellement apres `make setup` :

1. **qBittorrent** - Desactiver "Host header validation" (http://localhost:8090)
2. **Trakt** - Jellyfin > Dashboard > Plugins > Trakt > Authorize
3. **Infuse** - Ajouter serveur Jellyfin

Puis sauvegarder votre config :
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
ArrStack/
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
└── backups/                 # Archives tar.gz des volumes Docker
```

---

## Architecture

```
Jellyseerr (requetes)
    |
    v
Radarr / Sonarr (gestion media)
    |
    v
Prowlarr / Jackett (indexeurs) ──> recherche torrents
    |
    v
RDTClient (AllDebrid)          ──> telecharge via debrid (instantane)
qBittorrent (VPN NordVPN)      ──> telecharge via torrent (backup)
    |
    v
/data/downloads ──> atomic move ──> /data/media
    |
    v
Jellyfin (lecture) ──> Infuse / clients
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
