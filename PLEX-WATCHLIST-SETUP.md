# 🎯 Configuration Plex Watchlist - Utilisez UNIQUEMENT Plex !

## ✨ Qu'est-ce que c'est ?

**Plex Watchlist** vous permet d'utiliser **UNIQUEMENT Plex** pour demander des films/séries.

**Workflow ultra-simple** :
1. Vous ajoutez un film/série à votre Watchlist Plex (⭐)
2. Radarr/Sonarr détectent l'ajout automatiquement
3. Le téléchargement se lance via qBittorrent
4. Le fichier apparaît dans votre bibliothèque Plex

**➡️ Plus besoin d'aller dans Seerr, Radarr ou Sonarr !**

---

## 📋 Configuration (10 minutes)

### Étape 1 : Configurer Radarr (Films)

1. Ouvrez **Radarr** : http://localhost:7878

2. Allez dans **Settings → Lists**

3. Cliquez sur **➕ Add List** → Cherchez **"Plex Watchlist"**

4. Configurez :
   - **Name** : `Ma Watchlist Plex`
   - **Enable Automatic Add** : ✅ **COCHEZ CETTE CASE !**
   - **Monitor** : `Movie Only`
   - **Minimum Availability** : `Released` (ou `Announced` si vous voulez être notifié avant la sortie)
   - **Quality Profile** : Sélectionnez votre profil de qualité (ex: "Any Quality")
   - **Root Folder** : `/data/media/movies`

5. **Authentification Plex** :
   - Cliquez sur le bouton **"Authenticate with Plex.tv"**
   - Une fenêtre Plex s'ouvre → Connectez-vous avec votre compte Plex
   - Cliquez sur **"Allow"** pour autoriser Radarr
   - La fenêtre se ferme automatiquement

6. Cliquez sur **Test** (doit afficher ✅ Success)

7. Cliquez sur **Save**

---

### Étape 2 : Configurer Sonarr (Séries)

1. Ouvrez **Sonarr** : http://localhost:8989

2. Allez dans **Settings → Import Lists**

3. Cliquez sur **➕ Add List** → Cherchez **"Plex Watchlist"**

4. Configurez :
   - **Name** : `Ma Watchlist Plex (Séries)`
   - **Enable Automatic Add** : ✅ **COCHEZ CETTE CASE !**
   - **Monitor** : `All Episodes` (télécharge tout)
     - _Ou `Future Episodes` si vous voulez seulement les nouveaux épisodes_
   - **Quality Profile** : Votre profil de qualité
   - **Root Folder** : `/data/media/tv`
   - **Series Type** : `Standard`
   - **Season Folder** : ✅ (organise par saisons)

5. **Authentification Plex** :
   - Cliquez sur **"Authenticate with Plex.tv"**
   - Connectez-vous → Allow

6. **Test & Save**

---

### Étape 3 : Test

1. Ouvrez **Plex** (web, mobile, TV, etc.) : http://localhost:32400/web

2. Cherchez un film (ex: "Interstellar")

3. Cliquez sur le film → **"Add to Watchlist"** ⭐

4. **Forcer la vérification dans Radarr** (au lieu d'attendre 6h) :
   - Radarr → Library → Import Lists
   - Cliquez sur l'icône **↻ Update All Lists**

5. **Vérifiez** :
   - Le film devrait apparaître dans **Radarr → Movies**
   - Status : "Wanted" (recherche en cours) ou "Downloading" (téléchargement actif)

6. **Faites pareil pour une série** :
   - Plex → Cherchez "Breaking Bad" → Add to Watchlist ⭐
   - Sonarr → Library → Import Lists → ↻ Update All Lists
   - La série apparaît dans Sonarr

---

## 🚀 Utilisation quotidienne

**Depuis n'importe quelle app Plex** (PC, mobile, TV, web) :

1. Recherchez un film ou série
2. Cliquez sur **"Add to Watchlist"** ⭐
3. **Attendez** (ou forcez la mise à jour dans Radarr/Sonarr)
4. Le téléchargement se lance automatiquement
5. Le fichier apparaît dans Plex quand c'est terminé

**C'est tout ! Plus besoin d'aller dans Seerr, Radarr ou Sonarr !**

---

## ⏱️ Fréquence de vérification

Par défaut, Radarr/Sonarr vérifient votre Watchlist **toutes les 6 heures**.

### Pour vérifier immédiatement :

**Radarr** :
- Library → Import Lists → Cliquez sur **↻ Update All Lists**

**Sonarr** :
- Library → Import Lists → Cliquez sur **↻ Update All Lists**

### Modifier la fréquence (optionnel) :

1. **Radarr** → System → Tasks → "Import List Sync"
2. Cliquez sur l'icône ⚙️ (engrenage)
3. Modifiez **Interval** : `60` (pour 1 heure) ou `30` (pour 30 minutes)
4. Save

Même chose dans **Sonarr**.

---

## 🎬 Workflow complet (exemple)

**Scénario** : Vous voulez regarder "Inception" ce soir.

1. **Sur votre téléphone** :
   - Ouvrez l'app Plex
   - Cherchez "Inception"
   - Cliquez sur ⭐ "Add to Watchlist"

2. **Sur votre ordi** :
   - Ouvrez Radarr : http://localhost:7878
   - Library → Import Lists → ↻ Update All Lists
   - Inception apparaît dans Movies avec status "Wanted"

3. **Radarr fait le reste** :
   - Demande à Prowlarr de chercher "Inception"
   - Prowlarr cherche sur YGG, 1337x, etc.
   - Radarr envoie le torrent à qBittorrent
   - qBittorrent télécharge via VPN

4. **Quand c'est terminé** :
   - Radarr déplace le fichier dans `/data/media/movies/Inception (2010)/`
   - Plex détecte automatiquement le nouveau film
   - Vous recevez une notification Plex (si activée)
   - Le film est prêt à regarder dans Plex !

**Temps total** : 2 clics dans Plex + 5 minutes d'attente

---

## 🔧 Dépannage

### Problème : "Aucune liste n'apparaît dans Radarr/Sonarr"

**Solution** :
1. Vérifiez que **Enable Automatic Add** est ✅ coché
2. Vérifiez l'authentification Plex : Ré-authentifiez si nécessaire
3. Cliquez sur **Test** dans la configuration de la liste

---

### Problème : "Les films ajoutés n'apparaissent pas dans Radarr"

**Solution** :
1. Allez dans Radarr → Library → Import Lists
2. Cliquez sur **↻ Update All Lists**
3. Attendez 10 secondes
4. Vérifiez dans **Movies** (filtrez par status "Wanted")

---

### Problème : "Authentication failed" lors de la connexion Plex

**Solution** :
1. Assurez-vous d'être connecté à Plex.tv dans votre navigateur
2. Essayez en navigation privée si ça ne marche pas
3. Vérifiez que Radarr/Sonarr peuvent accéder à internet (pas de problème de réseau Docker)

---

## 🗑️ Désactiver Seerr (optionnel)

Si vous utilisez **uniquement Plex Watchlist**, vous n'avez plus besoin de Seerr.

### Arrêter Seerr :

```bash
docker-compose stop seerr
```

### Retirer complètement Seerr du docker-compose :

1. Éditez `docker-compose.yml`
2. Commentez (ou supprimez) toute la section `seerr:` (lignes ~80-100)
3. Relancez la stack :
   ```bash
   docker-compose down
   docker-compose up -d
   ```

---

## 📱 Applications Plex recommandées

Pour ajouter facilement des films/séries à la Watchlist :

- **iOS** : Plex pour iPhone/iPad (gratuite)
- **Android** : Plex pour Android (gratuite)
- **TV** : Plex pour Apple TV, Android TV, Roku, etc.
- **Web** : http://localhost:32400/web ou https://app.plex.tv

**Toutes les apps** se synchronisent automatiquement. Ajouter sur le téléphone = visible sur TV et PC !

---

## ✅ Checklist de vérification

- [ ] Radarr : Plex Watchlist configurée avec "Enable Automatic Add" ✅
- [ ] Sonarr : Plex Watchlist configurée avec "Enable Automatic Add" ✅
- [ ] Test réussi : Film ajouté à Watchlist Plex apparaît dans Radarr
- [ ] Test réussi : Série ajoutée à Watchlist Plex apparaît dans Sonarr
- [ ] Téléchargement automatique fonctionne
- [ ] Seerr désactivé (optionnel)

---

**🎉 Félicitations ! Vous pouvez maintenant utiliser UNIQUEMENT Plex pour gérer vos films et séries !**

**Plus besoin d'aller dans Seerr, Radarr ou Sonarr au quotidien.**
