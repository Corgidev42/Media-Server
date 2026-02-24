# 🎬 Guide de Configuration - Stack Servarr

## 📋 Table des matières
1. [Pré-requis](#pré-requis)
2. [Installation initiale](#installation-initiale)
3. [Configuration NordVPN](#configuration-nordvpn)
4. [Configuration des services](#configuration-des-services)
5. [Structure des dossiers](#structure-des-dossiers)
6. [Dépannage](#dépannage)

---

## 🔧 Pré-requis

- **Docker Desktop** installé et démarré
- **Compte NordVPN** actif (pour le VPN)
- **Espace disque** : minimum 100 GB recommandés
- **macOS** 11+ (Big Sur ou supérieur)

---

## 🚀 Installation initiale

### Étape 1 : Nettoyage de l'ancienne installation

```bash
# Rendre le script exécutable
chmod +x cleanup.sh

# Lancer le nettoyage (tapez 'oui' pour confirmer)
./cleanup.sh
```

⚠️ **ATTENTION** : Cette action supprime **TOUS** les conteneurs et configurations existants.

---

### Étape 2 : Créer la structure de dossiers

```bash
# Créer la structure atomique
mkdir -p /Users/dev/data/downloads/incomplete
mkdir -p /Users/dev/data/downloads/complete
mkdir -p /Users/dev/data/media/movies
mkdir -p /Users/dev/data/media/tv

# Vérifier les permissions
ls -la /Users/dev/data
```

**Explication de la structure "Atomic Moves"** :
```
/Users/dev/data/
├── downloads/           # Zone de téléchargement
│   ├── incomplete/      # Torrents en cours
│   └── complete/        # Torrents terminés
└── media/              # Bibliothèque finale
    ├── movies/         # Films organisés
    └── tv/             # Séries organisées
```

✅ **Avantage** : Radarr/Sonarr déplacent instantanément les fichiers sans les copier (même volume Docker).

---

## 🔐 Configuration NordVPN

### Option A : WireGuard (Recommandé - Plus rapide)

1. **Obtenir votre clé privée WireGuard** :
   - Connectez-vous sur [NordAccount](https://my.nordaccount.com/)
   - Allez dans **Dashboard** → **NordVPN** → **Advanced Settings**
   - Activez **WireGuard** et cliquez sur **Generate new private key**
   - Copiez la clé privée

2. **Modifier le fichier `.env`** :
   ```bash
   nano .env
   # ou
   code .env  # si VS Code est installé
   ```

3. **Coller votre clé** :
   ```env
   NORDVPN_PRIVATE_KEY=votre_vraie_cle_ici_ABC123xyz...
   NORDVPN_ADDRESSES=10.5.0.2/16
   ```

4. **Choisir un pays de serveur** (optionnel) :
   Dans `docker-compose.yml`, modifiez :
   ```yaml
   - SERVER_COUNTRIES=Netherlands  # France, Switzerland, etc.
   ```

### Option B : OpenVPN (Alternative)

1. Modifiez `docker-compose.yml` :
   ```yaml
   environment:
     - VPN_TYPE=openvpn  # au lieu de wireguard
     - OPENVPN_USER=${OPENVPN_USER}
     - OPENVPN_PASSWORD=${OPENVPN_PASSWORD}
   ```

2. Dans `.env` :
   ```env
   OPENVPN_USER=votre_email@nordvpn.com
   OPENVPN_PASSWORD=votre_mot_de_passe
   ```

---

### Étape 3 : Démarrer la stack

```bash
# Démarrer tous les services
docker-compose up -d

# Vérifier que tout fonctionne
docker-compose ps
```

### Étape 4 : Vérifier le VPN

```bash
# Votre IP publique (ne PAS partager)
curl https://ipinfo.io/ip

# IP du conteneur qBittorrent (doit être différente via VPN)
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

✅ Si les IP sont **différentes**, le VPN fonctionne !

---

## ⚙️ Configuration des services

### 🔗 Accès aux interfaces

Une fois les conteneurs démarrés :

| Service       | URL                        | Port  |
|---------------|----------------------------|-------|
| Prowlarr      | http://localhost:9696      | 9696  |
| Radarr        | http://localhost:7878      | 7878  |
| Sonarr        | http://localhost:8989      | 8989  |
| Seerr         | http://localhost:5055      | 5055  |
| qBittorrent   | http://localhost:8090      | 8090  |
| Flaresolverr  | http://localhost:8191      | 8191  |
| Plex          | http://localhost:32400/web | 32400 |

---

### 1️⃣ Prowlarr (Indexeurs)

**Accès** : http://localhost:9696

> **⚠️ Important - URLs Docker** :
> - 🌐 **Dans votre navigateur** : utilisez `localhost` (http://localhost:9696)
> - 🐳 **Configuration inter-conteneurs** : utilisez les noms Docker (`prowlarr`, `radarr`, `sonarr`, `gluetun`, `flaresolverr`)
> 
> Exemple : Prowlarr → Radarr = `http://radarr:7878` (pas `localhost`)

#### Configuration initiale :

1. **Ajouter Flaresolverr** :
   - Settings → Indexers → Add Flaresolverr
   - Tags : `flaresolverr`
   - Host : `http://flaresolverr:8191`

2. **Ajouter YGGTorrent avec le script automatique** :
   ```bash
   ./install-ygg.sh
   ```
   
   Ensuite dans Prowlarr :
   - **System → Tasks** → Lancer **"Indexer Definition Update"** (icône ▶️)
   - Attendre 30 secondes
   - **Indexers → Add Indexer** → Chercher **"YGGApi"**
   - Configurer avec votre **Passkey YGG** (récupérable sur YGG → Mon Compte)
   - Test → Save

3. **Ajouter d'autres indexeurs publics** (optionnel) :
   - Indexers → Add Indexer → Rechercher "1337x", "RARBG", etc.
   - **IMPORTANT** : Ajoutez le tag `flaresolverr` pour éviter les erreurs 429 (Too Many Requests)
   - Edit indexer → Scroll down → **Tags** → Ajoutez `flaresolverr` → Save
   
   **Pourquoi Flaresolverr ?**
   - Contourne Cloudflare et les protections DDOS
   - Réduit les erreurs "Request Limit reached" (HTTP 429)
   - Recommandé pour TOUS les indexeurs publics (1337x, RARBG, etc.)

4. **Synchroniser avec Radarr/Sonarr** :
   - Settings → Apps → Add Application
   - Choisir **Radarr** :
     - Prowlarr Server : `http://prowlarr:9696`
     - Radarr Server : `http://radarr:7878`
     - API Key : (récupérée depuis Radarr → Settings → General → API Key)
   - Répéter pour **Sonarr** :
     - Sonarr Server : `http://sonarr:8989`

---

### 2️⃣ qBittorrent (Client Torrent)

**Accès** : http://localhost:8090

#### Identifiants par défaut :
- **Username** : `admin`
- **Password** : Consultez les logs pour le mot de passe temporaire :
  ```bash
  docker logs qbittorrent 2>&1 | grep "temporary password"
  ```

#### Configuration obligatoire :

1. **Changer le mot de passe** :
   - Tools → Options → Web UI → Authentication
   - Nouveau mot de passe sécurisé

2. **Désactiver Host header validation** (CRITIQUE pour l'API) :
   - Tools → Options → Web UI
   - **Décocher** : "Enable Host header validation"
   - **Décocher** : "Enable Cross-Site Request Forgery (CSRF) protection" (optionnel)

3. **Configurer les chemins** :
   - Tools → Options → Downloads
   - Default Save Path : `/data/downloads/complete`
   - Keep incomplete torrents in : `/data/downloads/incomplete`
   - **Cocher** : "Run external program on torrent completion"
   - Commande : `chmod -R 775 /data/downloads/complete` (permissions correctes)

4. **Limites de connexion** (optionnel) :
   - BitTorrent → Connection Limits
   - Max connections : 500
   - Max uploads : 20

---

### 3️⃣ Radarr (Films)

**Accès** : http://localhost:7878

#### Configuration :

1. **Root Folder** :
   - Settings → Media Management → Add Root Folder
   - Path : `/data/media/movies`

2. **Download Client (qBittorrent)** :
   - Settings → Download Clients → Add → qBittorrent
   - Host : `gluetun` (car qBittorrent utilise le réseau de Gluetun)
   - Port : `8090`
   - Username : `admin`
   - Password : (votre mot de passe qBittorrent)
   - Category : `radarr-movies`

3. **Naming Convention** (optionnel mais recommandé) :
   - Settings → Media Management → Movie Naming
   - Renommage automatique : **Activé**
   - Format : `{Movie Title} ({Release Year}) {Quality Full}`

4. **Custom Formats (Qualité et Langues)** :
   
   **🎯 Configuration pour le contenu français multi-audio (VF/VO/VOSTFR)** :
   
   **a) Créer les Custom Formats** (Settings → Custom Formats → Add) :
   
   **Formats de Langue** :
   - **MULTi** (Score: 100) - Priorité maximale
     - Condition: Release Title → `\b(MULTi|MULTI)\b`
   
   - **French Audio** (Score: 50)
     - Condition: Release Title → `\b(FRENCH|VFF|VFQ|VF2|TRUEFRENCH|VF)\b`
   
   - **VOSTFR** (Score: 50)
     - Condition: Release Title → `\b(VOSTFR|SUBFRENCH)\b`
   
   **Formats de Qualité Vidéo** :
   - **x265/HEVC** (Score: 15) - Meilleure compression
     - Condition: Release Title → `\b(x265|HEVC|h265)\b`
   
   - **Remux** (Score: 80) - Qualité Blu-ray originale
     - Condition: Release Title → `\bREMUX\b`
   
   - **BluRay** (Score: 30)
     - Condition: Release Title → `\b(BluRay|Blu-ray|BD)\b`
   
   - **HDR** (Score: 40)
     - Condition: Release Title → `\b(HDR|HDR10)\b`
   
   - **Dolby Vision** (Score: 50)
     - Condition: Release Title → `\b(DV|DoVi|Dolby.Vision)\b`
   
   **Formats Audio Premium** :
   - **Atmos** (Score: 25)
     - Condition: Release Title → `\b(ATMOS|Atmos)\b`
   
   - **TrueHD** (Score: 20)
     - Condition: Release Title → `\b(TrueHD|TRUE-HD)\b`
   
   - **DTS** (Score: 15)
     - Condition: Release Title → `\b(DTS|DTS-HD|DTS-MA)\b`
   
   **Formats à ÉVITER** (scores négatifs) :
   - **YIFY** (Score: -100)
     - Condition: Release Title → `\b(YIFY|YTS)\b`
   
   - **CAM/TS** (Score: -200)
     - Condition: Release Title → `\b(CAM|TS|TELESYNC|HDTS|PDVD|Screener|SCR)\b`
   
   **b) Appliquer à votre profil** (Settings → Profiles) :
   - **Language** : `French` ou `Original`
   - **Upgrade Until** : `Bluray-1080p` (ou 4K)
   - **Upgrade Until Custom Format Score** : `100`
   - **Minimum Custom Format Score Increment** : `1`
   
   Avec cette configuration, Radarr priorisera toujours les releases MULTi (VF+VO+VOSTFR) !

---

### 4️⃣ Sonarr (Séries)

**Accès** : http://localhost:8989

#### Configuration (similaire à Radarr) :

1. **Root Folder** : `/data/media/tv`

2. **Download Client** :
   - Host : `gluetun` (car qBittorrent utilise le réseau de Gluetun)
   - Port : `8090`
   - Category : `sonarr-tv`

3. **Naming** :
   - Format : `{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}`

4. **Custom Formats pour les séries** :
   - Sonarr supporte également les Custom Formats (v4+)
   - Utilisez les mêmes configurations que Radarr (MULTi, x265, etc.)
   - Settings → Profiles → Release Profiles pour filtrer par mots-clés
   
   **Release Profiles recommandés** :
   - **Must Contain** : `MULTi, FRENCH, VFF, VOSTFR` (séries françaises)
   - **Must Not Contain** : `YIFY, YTS, CAM, TS, HDCAM`

---

### 5️⃣ Seerr (Interface de requêtes)

**Accès** : http://localhost:5055

#### Configuration :

1. **Wizard de configuration** :
   - Sélectionner **Plex** 
   - Hostname : `plex`
   - Port : `32400`
   - Use SSL : décoché
   - Save Changes
   - Testez la connexion (bouton avec icône de rafraîchissement)
   - Sélectionnez les bibliothèques Plex que Seerr pourra scanner

2. **Ajouter Radarr** :
   - Services → Radarr → Add Server
   - Hostname : `radarr`
   - Port : `7878`
   - API Key : (depuis Radarr)
   - Quality Profile : Votre profil créé
   - Root Folder : `/data/media/movies`

3. **Ajouter Sonarr** (idem) :
   - Hostname : `sonarr`
   - Port : `8989`
   - Root Folder : `/data/media/tv`

---

### 6️⃣ Plex Media Server (Lecteur multimédia)

**Accès** : http://localhost:32400/web

#### Configuration initiale :

1. **Premier lancement** :
   - Ouvrez http://localhost:32400/web
   - Connectez-vous avec votre compte Plex (créez-en un gratuitement si besoin)
   - Donnez un nom à votre serveur (ex: "Serveur Media Mac")

2. **Ajouter les bibliothèques** :
   - **Films** :
     - Type : Films
     - Dossier : `/data/media/movies`
     - Agent : Plex Movie
     - Langue : Français
   - **Séries** :
     - Type : Séries TV
     - Dossier : `/data/media/tv`
     - Agent : Plex Series
     - Langue : Français

3. **Paramètres recommandés** :
   - Settings → Library → Scan library automatically (Activé)
   - Settings → Library → Run partial scan when changes detected (Activé)
   - Settings → Transcoder → Transcoder temporary directory : `/transcode`
   - Settings → Network → List of IP addresses and networks allowed without auth : `172.20.0.0/16` (réseau Docker)

4. **Optimisation (optionnel)** :
   - Settings → Transcoder → Transcoder quality : Automatic
   - Settings → Transcoder → Use hardware acceleration : Activé (si Mac avec puce Apple Silicon/Intel récent)

#### Alternative : Claim Token (configuration automatique)

Si vous voulez que Plex se connecte automatiquement à votre compte au démarrage :

1. Obtenez un claim token : https://plex.tv/claim (valide 4 minutes)
2. Ajoutez-le dans `.env` :
   ```bash
   PLEX_CLAIM=claim-xxxxxxxxxxxxx
   ```
3. Redémarrez Plex : `docker-compose restart plex`

---

### 🎯 Configuration Plex Watchlist (Requêtes automatiques depuis Plex)

**✨ FONCTIONNALITÉ ULTIME** : Utilisez **UNIQUEMENT Plex** pour demander des films/séries !

**Comment ça marche** :
1. Vous ajoutez un film/série à votre **Watchlist Plex** (depuis l'app Plex sur PC/mobile/TV)
2. Radarr/Sonarr **détectent automatiquement** l'ajout
3. Ils **téléchargent** le contenu via qBittorrent
4. Le fichier apparaît dans votre bibliothèque Plex

**➡️ Aucun besoin d'aller dans Seerr, Radarr ou Sonarr !**

---

#### Configuration dans Radarr (Films) :

1. **Settings → Lists → Add List → Plex Watchlist**
2. Configurez :
   - **Name** : `Ma Watchlist Plex`
   - **Enable Automatic Add** : ✅ (cochez cette case !)
   - **Monitor** : `Movie Only`
   - **Minimum Availability** : `Announced` (ou `Released` si vous voulez attendre la sortie)
   - **Quality Profile** : Votre profil de qualité (ex: "Any Quality" ou "HD-1080p")
   - **Root Folder** : `/data/media/movies`
   - **Tags** : (vide)

3. **Authentification Plex** :
   - Cliquez sur **"Authenticate with Plex.tv"**
   - Une fenêtre s'ouvre → Connectez-vous à Plex
   - Autorisez Radarr à accéder à votre compte
   - Radarr récupère automatiquement votre Watchlist

4. **Test & Save** :
   - Cliquez sur **Test** (doit afficher ✅ Success)
   - Cliquez sur **Save**

5. **Test manuel** :
   - Allez dans **Library → Import Lists**
   - Cliquez sur le bouton ↻ **"Update All Lists"**
   - Vérifiez que les films de votre Watchlist Plex apparaissent dans Radarr

---

#### Configuration dans Sonarr (Séries) :

**Identique à Radarr** :

1. **Settings → Import Lists → Add List → Plex Watchlist**
2. Configurez :
   - **Name** : `Ma Watchlist Plex (Séries)`
   - **Enable Automatic Add** : ✅
   - **Monitor** : `All Episodes` (ou `Future Episodes` si vous ne voulez que les nouveaux)
   - **Quality Profile** : Votre profil
   - **Root Folder** : `/data/media/tv`
   - **Series Type** : `Standard`
   - **Season Folder** : ✅

3. **Authentification Plex** → Même processus
4. **Test & Save**

---

#### Utilisation quotidienne (workflow simplifié) :

**Depuis l'app Plex (PC, mobile, TV, web)** :

1. Cherchez un film ou série (ex: "Interstellar")
2. Cliquez sur le film → **"Add to Watchlist"** (⭐ ou ➕)
3. **C'EST TOUT !**

**Radarr/Sonarr vont :**
- Détecter l'ajout (vérification toutes les 6 heures par défaut)
- Chercher le torrent via Prowlarr
- Lancer le téléchargement dans qBittorrent
- Déplacer le fichier dans `/data/media/movies` ou `/tv`
- Plex détecte automatiquement le nouveau fichier

**Pour forcer une vérification immédiate** :
- Radarr → Library → Import Lists → ↻ Update All Lists
- Sonarr → Library → Import Lists → ↻ Update All Lists

---

#### Désactiver Seerr (optionnel) :

Si vous utilisez **uniquement Plex Watchlist**, vous n'avez plus besoin de Seerr !

Pour le désactiver :
```bash
# Arrêter Seerr
docker-compose stop seerr

# Pour le retirer complètement
# Éditez docker-compose.yml et commentez la section seerr
# Puis :
docker-compose down
docker-compose up -d
```

---

## 📂 Structure des dossiers finale

```
/Users/dev/data/
├── downloads/
│   ├── incomplete/          # Téléchargements en cours
│   │   └── [torrents actifs]
│   └── complete/            # Téléchargements terminés
│       ├── [film.mkv]
│       └── [serie.S01E01.mkv]
└── media/
    ├── movies/              # Bibliothèque films
    │   ├── Avatar (2009)/
    │   │   └── Avatar (2009) 1080p.mkv
    │   └── Inception (2010)/
    └── tv/                  # Bibliothèque séries
        └── Breaking Bad/
            ├── Season 01/
            │   ├── S01E01.mkv
            │   └── S01E02.mkv
            └── Season 02/
```

---

## 🛠️ Dépannage

### Problème : "qBittorrent refused connection"

**Cause** : Le VPN n'est pas démarré ou la liaison réseau échoue.

**Solutions** :
```bash
# Vérifier les logs de Gluetun
docker logs gluetun

# Redémarrer Gluetun et qBittorrent
docker-compose restart gluetun qbittorrent

# Tester la connexion VPN
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

---

### Problème : "Unauthorized" dans Radarr/Sonarr

**Cause** : Host header validation activée.

**Solution** :
1. Aller dans qBittorrent → Tools → Options → Web UI
2. Décocher **"Enable Host header validation"**
3. Relancer Radarr/Sonarr

---

### Problème : Fichiers non déplacés (copie lente)

**Cause** : Mauvaise structure de chemins.

**Solution** :
- Vérifier que Radarr/Sonarr pointent vers `/data` (pas `/downloads` et `/media` séparés)
- Le chemin Docker doit être identique dans qBittorrent et Radarr/Sonarr

---

### Problème : Indexeurs Prowlarr échouent (Cloudflare)

**Solution** :
- Activer Flaresolverr dans Prowlarr pour l'indexeur concerné
- Augmenter le timeout : Settings → Indexers → Advanced → Request Timeout (30s)

---

## 🔄 Commandes utiles

```bash
# Voir les logs d'un service
docker logs -f prowlarr

# Redémarrer un service
docker-compose restart radarr

# Arrêter toute la stack
docker-compose down

# Démarrer la stack
docker-compose up -d

# Mettre à jour les images
docker-compose pull
docker-compose up -d

# Sauvegarder les configurations (volumes)
docker run --rm -v prowlarr_config:/data -v $(pwd):/backup alpine tar czf /backup/prowlarr-backup.tar.gz /data
```

---

## 🎯 Workflow typique

1. **Requête** → Seerr (utilisateur demande un film/série)
2. **Recherche** → Radarr/Sonarr cherchent via Prowlarr
3. **Téléchargement** → qBittorrent (via VPN NordVPN)
4. **Déplacement** → Radarr/Sonarr déplacent dans `/data/media`
5. **Lecture** → Plex/Jellyfin scannent `/data/media`

---

## 🚚 Migration vers un NAS

Pour migrer vers un NAS (Synology, QNAP, etc.) :

1. **Sauvegarder les volumes Docker** :
   ```bash
   docker run --rm -v prowlarr_config:/data -v /path/to/backup:/backup alpine tar czf /backup/prowlarr.tar.gz /data
   # Répéter pour chaque service
   ```

2. **Copier les fichiers** :
   - `/Users/dev/data/` → `/volume1/data/` (NAS)
   - Sauvegardes des configs → NAS

3. **Sur le NAS** :
   - Installer Docker
   - Copier `docker-compose.yml` et `.env`
   - Modifier `DATA_PATH` dans `.env` : `/volume1/data`
   - Restaurer les volumes
   - Lancer `docker-compose up -d`

---

## 📚 Ressources

- [TRaSH Guides](https://trash-guides.info/) - Bible de la configuration Servarr
- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki) - Configuration VPN avancée
- [Servarr Wiki](https://wiki.servarr.com/) - Documentation officielle

---

## 🔍 Optimisation des Indexeurs (Vitesse & Qualité)

### 📋 Indexeurs recommandés

**Tier 1 - Priorité maximale** :
- **1337x** (Public) - Seeders ⭐⭐⭐⭐⭐ - Flaresolverr requis ✅
- **TorrentGalaxy** (Public) - Seeders ⭐⭐⭐⭐⭐ - Flaresolverr requis ✅
- **EZTV** (Public TV seul) - Seeders ⭐⭐⭐⭐ - Pas de Flaresolverr

**Tier 2 - Backup** :
- **The Pirate Bay** - Flaresolverr requis ✅
- **Torlock** - Flaresolverr requis ✅
- **YTS** (films petite taille)

### ⚙️ Configuration avancée Prowlarr

**Trier par seeders** (pour chaque indexeur) :

1. **Indexers** → Cliquez sur **1337x** → **Edit**
2. **Priority** : `1` (priorité maximale)
3. **Tags** : `flaresolverr` ⚠️ **OBLIGATOIRE**
4. **Sort** : `seeders` (trier par seeders)
5. **Order** : `desc` (décroissant)

**Minimum Seeders** :
- Settings → Indexers → **Minimum Seeders** : `5`
- Ignore les torrents avec <5 seeders

### 🎬 Profils Qualité Radarr

**Créer "HD Rapide"** :

1. Settings → Profiles → ➕ Add
2. **Name** : `HD Rapide`
3. **Qualities** (ordre de préférence) :
   - ✅ Bluray-1080p (préféré)
   - ✅ WEBDL-1080p
   - ✅ Bluray-720p
   - ❌ DVD (décochez)
4. **Custom Format Scores** :
   - Créez un CF "High Seeders Groups" → Conditions : Release Title contains `RARBG|TGx|YTS|GalaxyRG`
   - Score : `+100` (bonus de priorité)

**Tailles recommandées** :
- Settings → Quality → Bluray-1080p :
  - Min : `5 GB`
  - Preferred : `10 GB`
  - Max : `25 GB`

### 📺 Profils Qualité Sonarr

**Créer "HD Séries"** :

1. Settings → Profiles → ➕ Add
2. **Name** : `HD Séries`
3. **Qualities** :
   - ✅ WEBDL-1080p (préféré)
   - ✅ WEBRip-1080p
   - ✅ Bluray-720p

**Tailles recommandées par épisode** :
- WEBDL-1080p :
  - Min : `1 GB`
  - Preferred : `2 GB`
  - Max : `4 GB`

### 🚀 Optimisation qBittorrent

**Options → Connection** :
- Max connections : `500`
- Max connections per torrent : `100`
- Max uploads per torrent : `20`

**Options → BitTorrent** :
- ✅ Enable DHT
- ✅ Enable PeX
- ✅ Enable Local Peer Discovery

**Options → Speed** :
- Global Upload Limit : `5000 KiB/s` (pour ne pas saturer upload)

### 🔍 Voir le nombre de seeders

**Dans Radarr/Sonarr** :

1. **Movies** ou **Series** → Cliquez sur un film/série
2. **Search** (icône loupe)
3. **Interactive Search** → Cette vue montre :
   - **Seeders** (colonne visible)
   - **Peers** (leechers)
   - **Quality**
   - **Size**
4. Cliquez sur le torrent avec **le plus de seeders** → **Manual Download**

**Automatique** :
- Radarr/Sonarr choisissent automatiquement le meilleur torrent selon :
  - Quality Profile (préférence de qualité)
  - Custom Formats (seeders groups)
  - Protocole préféré (usenet vs torrent)

### 🎯 Configuration finale recommandée

**Prowlarr - Ordre de priorité** :

| Priority | Indexeur | Tag | Usage |
|----------|----------|-----|-------|
| 1 | 1337x | flaresolverr | Films + Séries |
| 1 | TorrentGalaxy | flaresolverr | Films + Séries |
| 1 | EZTV | - | Séries uniquement |
| 5 | The Pirate Bay | flaresolverr | Backup |

**Radarr** : Profile `HD Rapide` (Bluray-1080p → WEBDL-1080p, 5-25GB)

**Sonarr** : Profile `HD Séries` (WEBDL-1080p préféré, 1-4GB par épisode)

---

## 🛠️ Gestion des Services

### Commandes essentielles

```bash
# Voir l'état de tous les services
docker-compose ps

# Arrêter un service
docker-compose stop radarr

# Démarrer un service
docker-compose up -d radarr

# Redémarrer un service
docker-compose restart gluetun

# Arrêter TOUT
docker-compose down

# Démarrer TOUT
docker-compose up -d

# Voir les logs d'un service
docker logs -f prowlarr

# IP VPN actuelle
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

### Dépannage rapide

**Gluetun "unhealthy"** :
```bash
docker-compose restart gluetun
sleep 30
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

**qBittorrent inaccessible** :
```bash
docker-compose restart gluetun
sleep 30
docker-compose restart qbittorrent
```

### 📱 Accès distant Plex

**Sur le Mac** :
1. Plex → Settings → Remote Access
2. ✅ Enable Remote Access
3. Résultat : ✅ "Fully accessible outside your network"

**Sur PS5/Mobile** :
1. Téléchargez l'app "Plex" (gratuit)
2. Connectez-vous avec votre compte Plex
3. Votre serveur apparaît automatiquement
4. Profitez !

**Test en 4G** (pour vérifier l'accès distant) :
- Désactivez le WiFi sur votre mobile
- Ouvrez l'app Plex → Le serveur doit être visible

**Sécurité** :
- Settings → Network → **Require authentication** : ✅
- Settings → Network → **Secure connections** : `Preferred`

---

## ✅ Checklist de démarrage

- [ ] Docker Desktop installé et démarré
- [ ] Script de nettoyage exécuté
- [ ] Structure `/Users/dev/data` créée
- [ ] Clé privée NordVPN configurée dans `.env`
- [ ] `docker-compose up -d` exécuté
- [ ] VPN testé et fonctionnel
- [ ] Prowlarr : Flaresolverr configuré avec tag `flaresolverr`
- [ ] Prowlarr : 1337x + TorrentGalaxy avec tag `flaresolverr`
- [ ] Prowlarr : EZTV ajouté (séries)
- [ ] Prowlarr : Minimum Seeders = `5`
- [ ] qBittorrent : Host validation désactivée
- [ ] qBittorrent : Max connections = 500
- [ ] Radarr : Root folder + Download client configurés
- [ ] Radarr : Profile "HD Rapide" créé (5-25GB)
- [ ] Radarr : Custom Format "High Seeders" créé
- [ ] Sonarr : Root folder + Download client configurés
- [ ] Sonarr : Profile "HD Séries" créé (1-4GB/épisode)
- [ ] Plex : Remote Access activé
- [ ] Plex Watchlist configurée (Radarr + Sonarr)
- [ ] Test : Film ajouté à Watchlist → Téléchargé automatiquement ✅

---

**🎉 Félicitations ! Votre stack Servarr est opérationnelle et optimisée !**
