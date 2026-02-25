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

3. **Ajouter les meilleurs indexeurs publics (2026)** :

   **🔥 Indexeurs recommandés** :
   
   | Nom | Langue | Qualité MULTi | Flaresolverr |
   |-----|--------|--------------|-------------|
   | **Torrent9** | FR/MULTi | ⭐⭐⭐⭐⭐ | ✅ Requis |
   | **1337x** | EN/MULTi | ⭐⭐⭐⭐⭐ | ✅ Requis |
   | **The Pirate Bay** | EN/FR/MULTi | ⭐⭐⭐⭐ | ✅ Requis |
   | **YGGTorrent** | FR/MULTi | ⭐⭐⭐⭐⭐ | ❌ Pas besoin |
   | **TorrentGalaxy** | EN/MULTi | ⭐⭐⭐⭐ | ✅ Recommandé |
   | **LimeTorrents** | EN/MULTi | ⭐⭐⭐ | ✅ Recommandé |
   | **EZTV** | EN (TV only) | ⭐⭐⭐⭐ | ❌ Pas besoin |
   
   **⚠️ Notes importantes** :
   - **RARBG** a fermé définitivement en mai 2023 (RIP 🪦)
   - **🇫🇷 ESSENTIEL pour MULTi** : Les indexeurs **français** (Torrent9, YGGTorrent) utilisent la nomenclature "MULTi" dans les noms de release. Les indexeurs internationaux (1337x, TorrentGalaxy) indiquent "Multi-Language" mais **PAS dans le nom du fichier**, donc votre Custom Format MULTi ne fonctionnera pas avec eux seuls.
   - **Solution** : Configurez AU MOINS **Torrent9** OU **YGGTorrent** pour avoir des releases MULTi détectables par Radarr.
   
   **Configuration détaillée par indexeur** :
   
   **a) Torrent9** (Meilleur pour FR/MULTi) :
   ```
   Indexer Priority: 5 (priorité maximale)
   Minimum Seeders: 5
   Tags: flaresolverr
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ❌ Replace MULTi by another language (DÉCOCHÉ)
   ❌ Replace VOSTFR and SUBFRENCH with ENGLISH (DÉCOCHÉ)
   ```
   
   **b) 1337x** :
   ```
   Indexer Priority: 10
   Minimum Seeders: 10
   Multi Languages: English, French
   Tags: flaresolverr
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ```
   
   **c) The Pirate Bay** :
   ```
   Indexer Priority: 15
   Minimum Seeders: 10
   Multi Languages: English, French
   Tags: flaresolverr
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ```
   
   **d) TorrentGalaxy** :
   ```
   Indexer Priority: 25
   Minimum Seeders: 5
   Multi Languages: English, French
   Tags: flaresolverr
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ```
   
   **e) EZTV** (Séries TV uniquement) :
   ```
   Indexer Priority: 30
   Minimum Seeders: 5
   Tags: (aucun)
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ```
   
   **f) LimeTorrents** :
   ```
   Indexer Priority: 35
   Minimum Seeders: 5
   Tags: flaresolverr
   ✅ Enable RSS
   ✅ Enable Automatic Search
   ✅ Enable Interactive Search
   ```
   
   **⚠️ IMPORTANT - Options "Replace MULTi"** :
   
   Pour les indexeurs français (Torrent9, etc.), vous verrez ces options :
   - **"Replace MULTi by another language in release name"** → ❌ **LAISSER DÉCOCHÉ**
   - **"Replace VOSTFR and SUBFRENCH with ENGLISH"** → ❌ **LAISSER DÉCOCHÉ**
   
   **Pourquoi ?** Si vous cochez ces options, Prowlarr remplacera le mot "MULTi" par "FRENCH" dans le nom du torrent. Résultat : Radarr pensera que c'est un film VF uniquement (pas MULTi), et votre Custom Format "MULTi" ne fonctionnera plus !
   
   **Pourquoi Flaresolverr ?**
   - Contourne Cloudflare et les protections DDOS
   - Réduit les erreurs "Request Limit reached" (HTTP 429)
   - **Requis** pour : 1337x, The Pirate Bay, Torrent9, TorrentGalaxy, LimeTorrents
   - **Pas nécessaire** pour : YGGTorrent, EZTV

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

> **📋 Résumé de la configuration optimale** :
> - ✅ Root Folder : `/data/media/movies`
> - ✅ Download Client : `gluetun:8090` (qBittorrent via VPN)
> - ✅ Custom Formats : MULTi (Score: 100) pour VF+VO+VOSTFR
> - ✅ Taille max : 15 GB pour 1080p
> - ✅ Indexeurs : Torrent9 (Priority: 5), 1337x (Priority: 10), YGG (Priority: 3)
> - ✅ Multi Languages : English + French dans chaque indexeur

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
   
   **🎯 Configuration optimale pour MULTi/VOSTFR/VFF avec système de scores**
   
   **Le principe** : Utiliser un système de scores pour prioriser automatiquement les meilleures releases :
   - **MULTi** (1000 pts) : Objectif final, contient VF + VO
   - **VOSTFR** (500 pts) : Très bon compromis en attendant le MULTi
   - **VFF** (200 pts) : Minimum acceptable pour les films français
   - Le système upgrade automatiquement vers le MULTi quand il apparaît
   
   **a) Créer les Custom Formats** (Settings → Custom Formats → Add) :
   
   **Formats de Langue (l'essentiel)** :
   
   **1. MULTi** (Score: **1000**) - Priorité maximale
   ```json
   {
     "name": "MULTi",
     "includeCustomFormatWhenRenaming": true,
     "specifications": [
       {
         "name": "Multi",
         "implementation": "ReleaseTitleSpecification",
         "negate": false,
         "required": true,
         "fields": {
           "value": "\\b(Multi)(?![ ._-]?sub(s)?)(\\b|\\d)"
         }
       }
     ]
   }
   ```
   - Regex : `\b(Multi)(?![ ._-]?sub(s)?)(\b|\d)`
   - Exclut "Multi-subs" (sous-titres seulement)
   
   **2. VOSTFR** (Score: **500**) - Excellent compromis
   ```json
   {
     "name": "VOSTFR",
     "includeCustomFormatWhenRenaming": true,
     "specifications": [
       {
         "name": "VOSTFR",
         "implementation": "ReleaseTitleSpecification",
         "negate": false,
         "required": false,
         "fields": {
           "value": "\\b(VOST.*?FR(E|A)?)\\b"
         }
       },
       {
         "name": "SUBFRENCH",
         "implementation": "ReleaseTitleSpecification",
         "negate": false,
         "required": false,
         "fields": {
           "value": "\\b(SUBFR(A|ENCH)?)\\b"
         }
       }
     ]
   }
   ```
   - Regex 1 : `\b(VOST.*?FR(E|A)?)\b` (VOSTFR, VOSTFRE, VOSTFRA)
   - Regex 2 : `\b(SUBFR(A|ENCH)?)\b` (SUBFRENCH, SUBFRA)
   
   **3. VFF** (Score: **200**) - Minimum pour films français
   ```json
   {
     "name": "VFF",
     "includeCustomFormatWhenRenaming": true,
     "specifications": [
       {
         "name": "FRENCH / TRUEFRENCH",
         "implementation": "ReleaseTitleSpecification",
         "negate": false,
         "required": true,
         "fields": {
           "value": "\\b(TRUEFRENCH|VFF|FRENCH)\\b"
         }
       },
       {
         "name": "Not VF2",
         "implementation": "ReleaseTitleSpecification",
         "negate": true,
         "required": true,
         "fields": {
           "value": "\\b(VF2|(VF(F|Q)[ .]VF(F|Q)))\\b"
         }
       }
     ]
   }
   ```
   - Regex : `\b(TRUEFRENCH|VFF|FRENCH)\b`
   - Exclut VF2 (piste audio secondaire de moindre qualité)
   
   **Formats Techniques (bonus)** :
   
   - **x265/HEVC** (Score: **100**) - Meilleure compression, économie d'espace
     - Regex : `\b(x265|HEVC|h265)\b`
   
   - **Freeleech** (Score: **40**) - Bonus pour trackers privés
     - Condition : Indexer Flag → Freeleech
   
   - **Dolby Vision** (Score: **30**) - HDR avancé
     - Regex : `\b(DV|DoVi|Dolby.?Vision)\b`
   
   - **HDR** (Score: **20**) - High Dynamic Range
     - Regex : `\b(HDR|HDR10|HDR10\+)\b`
   
   - **Atmos** (Score: **15**) - Audio immersif
     - Regex : `\b(ATMOS|Atmos)\b`
   
   **Formats à ÉVITER** (scores négatifs) :
   
   - **YIFY/YTS** (Score: **-100**) - Qualité vidéo très basse
     - Regex : `\b(YIFY|YTS)\b`
   
   - **CAM/TS** (Score: **-200**) - Enregistrements cinéma
     - Regex : `\b(CAM|TS|TELESYNC|HDTS|PDVD|Screener|SCR)\b`
   
   **b) Configuration du Quality Profile** (Settings → Profiles) :
   
   **Paramètres cruciaux** :
   ```
   Name: HD Rapide (ou votre nom)
   Upgrade Until: Bluray-1080p (ou 2160p pour 4K)
   Language: Any (IMPORTANT : ne pas filtrer par langue)
   
   Minimum Custom Format Score: 200 (accepte VFF minimum)
   Upgrade Until Custom Format Score: 1000 (continue jusqu'au MULTi)
   Minimum Custom Format Score Increment: 50 (évite upgrades mineurs)
   ```
   
   **Custom Formats appliqués** :
   ```
   MULTi          : 1000
   VOSTFR         : 500
   VFF            : 200
   x265/HEVC      : 100
   Freeleech      : 40
   Dolby Vision   : 30
   HDR            : 20
   Atmos          : 15
   YIFY/YTS       : -100
   CAM/TS         : -200
   ```
   
   **📊 Comment ça fonctionne** :
   
   Exemple : Film américain F1 (2025)
   1. **Jour 1** : Release WEB-DL anglais → Score 150 (HDR+x265) → Téléchargé (< 200 mais accepté)
   2. **Jour 30** : Release VOSTFR → Score 500 → **Upgrade automatique**
   3. **Jour 90** : Release MULTi Remux → Score 1160 (1000+100+30+20) → **Upgrade final, arrêt des recherches**
   
   Exemple : Film français Intouchables
   - Release VFF 1080p → Score 200 (VFF) → Téléchargé et suffisant (pas de MULTi possible pour un film FR)
   
   **⚠️ IMPORTANT** :
   - **Language = "Any"** : Ne mettez PAS "French" ou "Original", ça bloquerait certaines releases
   - **Minimum Score = 200** : Le VFF est acceptable, pas besoin d'attendre
   - **Upgrade Until = 1000** : Continue de chercher le MULTi
   - **Increment = 50** : N'upgrade pas pour un simple bonus HDR (+20), seulement pour un changement significatif
   
   Avec cette configuration, Radarr gère automatiquement tous les cas : MULTi prioritaire, VOSTFR en backup, VFF pour films français !
   
   **c) Comment importer les Custom Formats** :
   
   Au lieu de créer manuellement chaque Custom Format, vous pouvez **importer les JSON** :
   
   1. **Radarr** → Settings → Custom Formats
   2. Cliquez sur **Import** (en bas à gauche)
   3. Collez le JSON d'un Custom Format (voir ci-dessus)
   4. Cliquez **Import** → Le Custom Format est créé automatiquement
   5. Répétez pour MULTi, VOSTFR, VFF, x265, etc.
   6. N'oubliez pas d'aller dans **Settings → Profiles** pour attribuer les **scores** à chaque Custom Format

5. **📏 Limiter la taille des fichiers** :

   **Pourquoi ?** Éviter de télécharger des Remux 4K à 80 GB quand 15 GB suffisent pour du 1080p.
   
   **Méthode 1 : Via Quality Profile** (Recommandé)
   
   Settings → Profiles → Sélectionnez votre profil (ex: "HD-1080p") :
   - **Upgrade Until** : `Bluray-1080p` (au lieu de `Bluray-2160p` ou `Remux-1080p`)
   - Cela empêche Radarr de chercher des versions 4K ou Remux (très volumineuses)
   
   **Méthode 2 : Via Restrictions** (Plus précis)
   
   Settings → Indexers → **Restrictions** → Add :
   ```
   Name: Max Size 1080p
   Maximum Size: 15000 (MB = 15 GB)
   Tags: (vide = appliqué à tous les films)
   ```
   
   Pour les films 4K :
   ```
   Name: Max Size 4K
   Maximum Size: 40000 (MB = 40 GB)
   Tags: 4k (créez un tag spécifique)
   ```
   
   **Tailles recommandées** :
   - **720p** : Max 8 GB
   - **1080p** : Max 15 GB (recommandé pour la plupart des films)
   - **1080p Remux** : Max 35 GB (qualité Blu-ray originale)
   - **4K** : Max 40 GB
   - **4K Remux** : Max 80 GB (pour les puristes)
   
   **Custom Format pour économiser de l'espace** :
   
   Privilégiez **x265/HEVC** (Score: +15) déjà créé plus haut :
   - x265 offre 30-50% d'économie d'espace pour la même qualité que x264
   - Exemple : Film en x264 = 12 GB, même film en x265 = 6-8 GB

6. **🎬 Comment choisir entre VF et VO (Version Française / Version Originale)** :

   **✅ Configuration actuelle : Releases MULTi (Recommandé)**
   
   Les releases **MULTi** contiennent plusieurs pistes audio dans un seul fichier :
   - 🇫🇷 VF (Version Française)
   - 🇬🇧 VO (Version Originale - généralement anglais)
   - 📝 VOSTFR (Sous-titres français)
   
   **Avantage** : Un seul fichier à télécharger, vous changez la piste audio dans Plex !
   
   **a) Changer la piste audio dans Plex** :
   - Lancez la lecture du film/série
   - Cliquez sur l'icône **⚙️ Paramètres** (en bas à droite)
   - Onglet **Audio** → Sélectionnez :
     - `Français (VF)` pour la version française
     - `English (VO)` pour la version originale
   - Plex mémorise votre choix pour les prochaines lectures
   
   **b) Définir une langue par défaut dans Plex** :
   - **Global** : Plex Web → **Paramètres** → **Compte** → **Langue audio par défaut**
     - Choisissez : `Français`, `Original`, ou `Auto`
   - **Par utilisateur** : Paramètres → **Utilisateurs** → Sélectionner → **Langue audio**
   
   **c) Vérifier qu'un film est MULTi** :
   - Dans Radarr : Movies → Film → **Files** → Cherchez `MULTi` dans le nom
   - Dans Plex : Film → **⋮** → **Obtenir les informations** → **Fichiers** → Section **Pistes audio**
   - Commande rapide : `make check-audio` (puis entrez le nom du film)
   
   **d) Lister tous vos films MULTi** :
   ```bash
   make list-multi          # Liste tous les films avec plusieurs pistes audio
   make count-languages     # Statistiques des langues audio
   ```
   
   **e) Si vous voulez UNIQUEMENT des films en VF** (sans MULTi) :
   - Settings → Custom Formats → Modifiez **French Audio** : Score `100`
   - Settings → Custom Formats → Modifiez **MULTi** : Score `-50` (désactive MULTi)
   - ⚠️ Vous perdrez la possibilité de basculer en VO !
   
   **f) Si vous voulez UNIQUEMENT des films en VO** (sans VF) :
   - Settings → Custom Formats → Créez **English Only** (Score: 100)
     - Condition: Release Title → `\b(ENGLISH|ENG)\b`
   - Settings → Custom Formats → Modifiez **French Audio** : Score `-100`
   - Settings → Custom Formats → Modifiez **MULTi** : Score `-100`

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

5. **📏 Limiter la taille des fichiers (par épisode)** :
   
   Settings → Indexers → **Restrictions** → Add :
   ```
   Name: Max Size Episode 1080p
   Maximum Size: 4000 (MB = 4 GB par épisode)
   Tags: (vide)
   ```
   
   **Tailles recommandées par épisode** :
   - **720p** : Max 2 GB
   - **1080p** : Max 4 GB
   - **4K** : Max 10 GB
   
   **Note** : Les séries WEBDL (Netflix, Amazon) sont généralement bien compressées (2-3 GB/épisode).

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

### 📋 Indexeurs recommandés (2026)

**⚠️ Note** : RARBG a fermé définitivement en mai 2023.

**Tier 1 - Priorité maximale (contenu FR/MULTi)** :
- **Torrent9** (Public FR) - Priority: 5 - Seeders ⭐⭐⭐⭐⭐ - Flaresolverr requis ✅
- **YGGTorrent** (Semi-privé FR) - Priority: 3 - Seeders ⭐⭐⭐⭐⭐ - Seed Ratio 1.0 requis
- **1337x** (Public) - Priority: 10 - Seeders ⭐⭐⭐⭐⭐ - Flaresolverr requis ✅

**Tier 2 - Contenu international** :
- **The Pirate Bay** - Priority: 15 - Flaresolverr requis ✅
- **TorrentGalaxy** (Public) - Priority: 25 - Seeders ⭐⭐⭐⭐⭐ - Flaresolverr requis ✅
- **EZTV** (Public TV seul) - Priority: 30 - Seeders ⭐⭐⭐⭐ - Pas de Flaresolverr

**Tier 3 - Backup** :
- **LimeTorrents** - Priority: 35 - Flaresolverr requis ✅
- **Cpasbien** (FR) - Priority: 40 - Flaresolverr recommandé

**⚠️ À éviter** :
- **YTS/YIFY** - Qualité vidéo très basse (compression excessive)

### ⚙️ Configuration avancée Prowlarr

**Configuration complète d'un indexeur (exemple avec Torrent9)** :

1. **Indexers** → Cliquez sur **Torrent9** → **Edit**
2. **Indexer Priority** : `5` (1 = plus haute priorité, 50 = plus basse)
   - Plus le chiffre est bas, plus Radarr privilégie cet indexeur en cas d'égalité
3. **Minimum Seeders** : `5` (minimum de sources)
4. **Seed Ratio** : (vide pour indexeurs publics)
5. **Seed Time** : (vide pour indexeurs publics)
6. **Multi Languages** : `English`, `French` (si disponible)
7. **Tags** : `flaresolverr` ⚠️ **OBLIGATOIRE pour la plupart**
8. **Enable RSS** : ✅ (surveillance nouveautés)
9. **Enable Automatic Search** : ✅ (recherche auto)
10. **Enable Interactive Search** : ✅ (recherche manuelle)
11. **Replace MULTi by another language** : ❌ **DÉCOCHÉ** (important !)
12. **Replace VOSTFR and SUBFRENCH** : ❌ **DÉCOCHÉ** (important !)

**Comprendre "Indexer Priority"** :
- Utilisé comme **tiebreaker** quand plusieurs releases sont équivalentes
- Radarr utilise TOUS les indexeurs activés pour RSS et la recherche
- Valeurs recommandées :
  - `5` : Torrent9 (meilleur pour FR/MULTi)
  - `10` : 1337x
  - `15` : The Pirate Bay
  - `25` : TorrentGalaxy
  - `30` : EZTV (séries uniquement)
  - `35` : LimeTorrents

**Multi Languages - Explication** :
Cette option dit à Prowlarr : "Quand cet indexeur propose un MULTi, accepte-le **seulement** s'il contient ces langues"
- Exemple : Si vous sélectionnez `English` + `French`, seuls les MULTi avec VF + VO seront acceptés

**Seed Ratio / Seed Time** :
- **Indexeurs publics** : Laissez vide (pas de ratio obligatoire)
- **Trackers privés** (YGG, etc.) : 
  - Seed Ratio : `1.0` (partager autant que téléchargé)
  - Seed Time : `72` heures (minimum 3 jours)

**Global Minimum Seeders** :
- Settings → Indexers → **Minimum Seeders** : `3`
- Ignore les torrents avec moins de 3 sources (fichiers morts)

---

### 📊 Tableau récapitulatif - Configuration indexeurs

| Indexeur | Priority | Min Seeds | Multi Lang | Tags | RSS | Auto | Interactive | Seed Ratio | Notes |
|----------|----------|-----------|------------|------|-----|------|-------------|------------|-------|
| **YGGTorrent** | 3 | 3 | EN + FR | - | ✅ | ✅ | ✅ | 1.0 | 🏆 Meilleur FR/MULTi |
| **Torrent9** | 5 | 5 | - | flaresolverr | ✅ | ✅ | ✅ | - | 🇫🇷 Top FR/MULTi |
| **1337x** | 10 | 10 | EN + FR | flaresolverr | ✅ | ✅ | ✅ | - | 🔥 Excellent MULTi |
| **The Pirate Bay** | 15 | 10 | EN + FR | flaresolverr | ✅ | ✅ | ✅ | - | 🏴‍☠️ Gros catalogue |
| **TorrentGalaxy** | 25 | 5 | EN + FR | flaresolverr | ✅ | ✅ | ✅ | - | Bon backup |
| **EZTV** | 30 | 5 | EN | - | ✅ | ✅ | ✅ | - | 📺 TV uniquement |
| **LimeTorrents** | 35 | 5 | EN + FR | flaresolverr | ✅ | ✅ | ✅ | - | Backup général |

**Légende** :
- **Priority** : Plus le chiffre est bas, plus l'indexeur est prioritaire (1-50)
- **Multi Lang** : Langues à sélectionner dans "Multi Languages"
- **Seed Ratio** : Ratio de partage obligatoire (trackers privés uniquement)
- **`-`** : Non applicable ou laisser vide

**⚠️ Rappel important** :
- ❌ **NE JAMAIS COCHER** "Replace MULTi by another language" sur Torrent9 et indexeurs FR
- ✅ **TOUJOURS AJOUTER** le tag `flaresolverr` pour les indexeurs protégés par Cloudflare
- ✅ **CONFIGURER** "Multi Languages" avec `English` + `French` pour garantir VF+VO

---

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
   - Créez un CF "High Seeders Groups" → Conditions : Release Title contains `TGx|GalaxyRG|YIFY|PSA|EVO`
   - Score : `+100` (bonus de priorité pour groupes fiables)
   - **Note** : YIFY est à éviter pour la qualité, mais a beaucoup de seeders

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

**🔧 Infrastructure** :
- [ ] Docker Desktop installé et démarré
- [ ] Script de nettoyage exécuté (`./cleanup.sh`)
- [ ] Structure `/Users/dev/data` créée
- [ ] Fichier `.env` configuré avec credentials NordVPN
- [ ] `docker-compose up -d` exécuté
- [ ] VPN testé et fonctionnel (`make vpn-check`)

**🔍 Prowlarr - Indexeurs** :
- [ ] Flaresolverr configuré (`http://flaresolverr:8191`, tag: `flaresolverr`)
- [ ] YGGTorrent installé (`./install-ygg.sh`) avec Passkey
- [ ] Torrent9 ajouté (Priority: 5, Tags: `flaresolverr`)
- [ ] 1337x ajouté (Priority: 10, Tags: `flaresolverr`, Multi Languages: EN+FR)
- [ ] The Pirate Bay ajouté (Priority: 15, Tags: `flaresolverr`, Multi Languages: EN+FR)
- [ ] TorrentGalaxy ajouté (Priority: 25, Tags: `flaresolverr`)
- [ ] EZTV ajouté (Priority: 30, pas de tag)
- [ ] Global Minimum Seeders = `3` (Settings → Indexers)
- [ ] ⚠️ "Replace MULTi by another language" = DÉCOCHÉ sur tous les indexeurs FR
- [ ] Apps configurées (Radarr + Sonarr synchronisés)

**📥 qBittorrent** :
- [ ] Mot de passe changé (défaut récupéré dans les logs)
- [ ] Host validation désactivée (Web UI → Options)
- [ ] Chemins configurés (`/data/downloads/complete` et `/incomplete`)
- [ ] Max connections = 500

**🎬 Radarr** :
- [ ] Root folder : `/data/media/movies`
- [ ] Download client : `gluetun:8090` configuré
- [ ] Custom Format "MULTi" créé (Score: **1000**)
- [ ] Custom Format "VOSTFR" créé (Score: **500**)
- [ ] Custom Format "VFF" créé (Score: **200**)
- [ ] Custom Format "x265/HEVC" créé (Score: 100)
- [ ] Quality Profile configuré : 
  - Language = **Any** (pas French/Original)
  - Minimum Custom Format Score = **200**
  - Upgrade Until Custom Format Score = **1000**
  - Minimum Custom Format Score Increment = **50**
- [ ] Restriction de taille : Max 15000 MB (15 GB) pour 1080p (optionnel)
- [ ] **Au moins un indexeur français** (Torrent9 OU YGGTorrent) configuré

**📺 Sonarr** :
- [ ] Root folder : `/data/media/tv`
- [ ] Download client : `gluetun:8090` configuré
- [ ] Custom Formats identiques à Radarr (MULTi 1000, VOSTFR 500, VFF 200)
- [ ] Quality Profile avec mêmes paramètres que Radarr
- [ ] Restriction de taille : Max 4000 MB (4 GB) par épisode (optionnel)

**🎭 Plex** :
- [ ] Bibliothèques ajoutées (Films + Séries)
- [ ] Langue audio par défaut : `Français` ou `Original`
- [ ] Remote Access activé (Settings → Remote Access)

**🎯 Tests finaux** :
- [ ] Test VPN : `make vpn-check` (IP différente de votre IP publique)
- [ ] Test download : Ajouter un film dans Radarr → Vérifier download
- [ ] Test Plex : Film téléchargé → Visible dans Plex avec pistes VF + VO
- [ ] Test changement de langue : Plex → ⚙️ → Audio → Basculer VF ⇄ VO
- [ ] Plex : Remote Access activé
- [ ] Plex Watchlist configurée (Radarr + Sonarr)
- [ ] Test : Film ajouté à Watchlist → Téléchargé automatiquement ✅

---

**🎉 Félicitations ! Votre stack Servarr est opérationnelle et optimisée !**
