# ⚠️ Notes Importantes - Pièges à éviter

## 🔴 URLs Docker : localhost vs noms de conteneurs

**RÈGLE D'OR** :
- 🌐 **Dans votre navigateur** → utilisez `localhost`
- 🐳 **Dans les configurations Docker** → utilisez les noms de conteneurs

### Exemples concrets :

#### ✅ CORRECT
```
Prowlarr → Radarr : http://radarr:7878
Radarr → qBittorrent : Host "gluetun", Port 8090
Seerr → Plex : Host "plex", Port 32400
Prowlarr → Flaresolverr : http://flaresolverr:8191
```

#### ❌ INCORRECT (ne fonctionnera pas)
```
Prowlarr → Radarr : http://localhost:7878  ❌
Radarr → qBittorrent : Host "localhost"    ❌
Seerr → Plex : Host "localhost"             ❌
```

**Pourquoi ?** Les conteneurs Docker ne voient pas `localhost` de la même façon. Chaque conteneur a son propre `localhost`. Utilisez les noms définis dans `docker-compose.yml`.

---

## 🌟 Plex Watchlist : La méthode la plus simple pour demander du contenu

**✨ UTILISEZ UNIQUEMENT PLEX** pour demander des films/séries !

### Configuration (à faire UNE FOIS) :

**Dans Radarr** :
1. Settings → Lists → Add List → **Plex Watchlist**
2. **Enable Automatic Add** : ✅ (IMPORTANT)
3. Cliquez sur **"Authenticate with Plex.tv"** → Connectez-vous
4. Quality Profile : Votre profil de qualité
5. Root Folder : `/data/media/movies`
6. Test & Save

**Dans Sonarr** :
1. Settings → Import Lists → Add List → **Plex Watchlist**
2. **Enable Automatic Add** : ✅
3. Authentifiez-vous avec Plex.tv
4. Root Folder : `/data/media/tv`
5. Test & Save

### Utilisation quotidienne :

1. Ouvrez **Plex** (app mobile, web, TV, etc.)
2. Cherchez un film/série
3. Cliquez sur **"Add to Watchlist"** ⭐
4. **C'EST TOUT !**

**Radarr/Sonarr vont automatiquement** :
- Détecter l'ajout (vérification toutes les 6h)
- Chercher le torrent
- Télécharger via qBittorrent
- Importer dans votre bibliothèque Plex

**Plus besoin d'aller dans Seerr, Radarr ou Sonarr !**

**Forcer une vérification immédiate** :
- Radarr → Library → Import Lists → ↻ Update All Lists
- Sonarr → Library → Import Lists → ↻ Update All Lists

---

## 🔴 qBittorrent : Host Header Validation

**CRITIQUE** : Sans désactiver cette option, Radarr/Sonarr ne pourront PAS se connecter à qBittorrent.

### À faire IMPÉRATIVEMENT :
1. Allez dans qBittorrent → Tools → Options → Web UI
2. **Décochez** : "Enable Host header validation"
3. **Décochez** : "Enable Cross-Site Request Forgery (CSRF) protection" (recommandé)
4. Save

**Symptôme si oublié** : `Unauthorized` ou `Connection refused` dans Radarr/Sonarr

---

## 🔴 qBittorrent via VPN : Host = "gluetun"

qBittorrent utilise `network_mode: "service:gluetun"` dans le docker-compose.

**Conséquence** : Pour y accéder depuis Radarr/Sonarr :
- ✅ Host : `gluetun`
- ✅ Port : `8090`
- ❌ PAS `qbittorrent` ou `localhost`

---

## 🔴 Plex : Claim Token obligatoire pour premier démarrage

Si Plex affiche "Non autorisé" au premier lancement :

1. **Obtenez un claim token** : https://plex.tv/claim (valide 4 minutes)
2. Ajoutez-le dans `.env` :
   ```bash
   PLEX_CLAIM=claim-xxxxxxxxxx
   ```
3. **Recréez** le conteneur (pas juste restart) :
   ```bash
   docker-compose stop plex
   docker-compose rm -f plex
   docker-compose up -d plex
   ```

**Après le claim** : Vous pouvez vider `PLEX_CLAIM` dans `.env` (il ne sert qu'une fois)

---

## 🔴 YGGTorrent : Indexer Definition Update requis

L'installation de YGG se fait en 3 étapes :

1. **Exécutez le script** : `./install-ygg.sh`
2. **Dans Prowlarr** : System → Tasks → Cliquez sur ▶️ "Indexer Definition Update"
3. **Attendez 30 secondes** que la tâche se termine
4. **Ensuite seulement** : Indexers → Add Indexer → Cherchez "YGGApi"

**Si oublié** : YGGApi n'apparaîtra pas dans la liste des indexeurs disponibles.

---

## 🔴 NordVPN : Service Credentials vs Clé WireGuard

**En 2026, utilisez OpenVPN avec Service Credentials** (plus stable et disponible).

### Comment obtenir vos Service Credentials :
1. https://my.nordaccount.com/
2. Dashboard → Services → NordVPN
3. Méthode : **Manual Setup**
4. Copiez :
   - Service Username (commence par des lettres/chiffres aléatoires)
   - Service Password (idem)

❌ **Ne PAS utiliser** : Votre email/mot de passe NordVPN normal
✅ **Utiliser** : Les Service Credentials générés spécifiquement

```env
NORDVPN_SERVICE_USER=hgdQ2zeeRirS9gQzkiB9TsxY  # Exemple
NORDVPN_SERVICE_PASSWORD=ugPs2ACpVekfC5iKNoLQurfj
```

---

## 🔴 Structure atomique : /data obligatoire

Les chemins dans qBittorrent, Radarr et Sonarr doivent **tous** commencer par `/data` :

### ✅ CORRECT
```
qBittorrent :
  - Save Path: /data/downloads/complete
  - Incomplete: /data/downloads/incomplete

Radarr :
  - Root Folder: /data/media/movies

Sonarr :
  - Root Folder: /data/media/tv
```

**Pourquoi ?** Tous les conteneurs montent le même volume `/Users/dev/data` sur `/data`. Cela permet des **hardlinks instantanés** au lieu de copies lentes.

---

## 🔴 Port 5353 : Conflit avec macOS Bonjour

Le port 5353 (Bonjour/mDNS) est déjà utilisé par macOS.

**Solution** : Le port est retiré de la config Plex dans `docker-compose.yml`. Plex fonctionne sans.

**Si vous voyez** : `bind: address already in use` pour le port 5353
→ C'est déjà corrigé dans le docker-compose actuel.

---

## 🔴 Indexeurs publics : Erreurs 429 (Too Many Requests)

**1337x et d'autres indexeurs publics limitent le nombre de requêtes.**

### Symptôme :
```
[Warn] Cardigann: Request Limit reached for 1337x. Disabled for 00:00:10
HTTP/2.0 [GET] https://1337x.to/...: 429.TooManyRequests
```

### ✅ Solution 1 : Ajouter le tag Flaresolverr

1. Prowlarr → Indexers → 1337x → Edit
2. **Scroll down** → **Tags** → Ajoutez `flaresolverr`
3. Save

**Résultat** : Les requêtes passent par Flaresolverr qui contourne les protections Cloudflare et réduit les rate limiting.

### ✅ Solution 2 : Utiliser des indexeurs privés

YGGTorrent (installé via `./install-ygg.sh`) n'a **pas ces limitations**. Privilégiez-le pour les recherches intensives.

**Remarque** : Si 1337x est désactivé, il se **réactive automatiquement après 10 secondes**. Pas de panique !

---

## 🔴 Prowlarr : Synchronisation Apps

Pour que Prowlarr partage automatiquement les indexeurs avec Radarr/Sonarr :

**Settings → Apps → Add Application**

Pour chaque app (Radarr et Sonarr) :
- Prowlarr Server : `http://prowlarr:9696`
- Radarr Server : `http://radarr:7878`
- Sonarr Server : `http://sonarr:8989`
- API Key : Copiez depuis Radarr/Sonarr → Settings → General → API Key

**Résultat** : Quand vous ajoutez un indexeur dans Prowlarr, il apparaît automatiquement dans Radarr et Sonarr.

---

## 🔴 Rotation VPN automatique : Attention aux interruptions

**Le script `auto-rotate-vpn.sh` redémarre Gluetun, ce qui INTERROMPT qBittorrent !**

### ⚠️ Problèmes causés :
- **Téléchargements en cours** : Interrompus pendant le redémarrage VPN (~30 secondes)
- **qBittorrent inaccessible** : Pendant que Gluetun se reconnecte
- **Connexions tracker** : Déconnexions temporaires

### ✅ Recommandations :

**Option 1 : Rotation manuelle uniquement**
```bash
./rotate-vpn.sh  # Quand aucun téléchargement n'est actif
```

**Option 2 : Rotation automatique intelligente**
- ❌ NE PAS lancer `auto-rotate-vpn.sh` en continu
- ✅ Lancez-le uniquement quand qBittorrent est inactif (aucun torrent actif)
- ✅ Arrêtez-le si des téléchargements démarrent : `pkill -f auto-rotate-vpn.sh`

**Pourquoi ça arrive ?**

qBittorrent utilise `network_mode: "service:gluetun"`. Quand Gluetun redémarre, qBittorrent perd sa connexion réseau. C'est le prix de la sécurité VPN totale.

---

## ✅ Ordre de configuration recommandé

1. **Prowlarr** : Flaresolverr + YGG + autres indexeurs + Apps (Radarr/Sonarr)
2. **qBittorrent** : Désactiver Host header validation + chemins
3. **Radarr** : Root folder + Download client (gluetun)
4. **Sonarr** : Root folder + Download client (gluetun)
5. **Plex** : Claim + bibliothèques Movies/TV
6. **Seerr** : Connecter Plex + Radarr + Sonarr

---

## 📌 Commandes de dépannage rapide

```bash
# Vérifier l'IP VPN
docker exec gluetun wget -qO- https://ipinfo.io/ip

# Logs d'un service
docker logs -f prowlarr

# Redémarrer un service
docker-compose restart radarr

# Recréer complètement un service
docker-compose stop plex && docker-compose rm -f plex && docker-compose up -d plex

# Voir tous les conteneurs
docker-compose ps

# Tester si un service répond
curl -I http://localhost:9696
```

---

**💡 Conseil** : Gardez ce fichier ouvert pendant la configuration !
