# Configuration PlexTraktSync

Ce dossier contient la configuration de PlexTraktSync.

## 🚀 Setup Initial (OBLIGATOIRE)

### 1. Créer un compte Trakt.tv (gratuit)
https://trakt.tv/auth/join

### 2. Créer une application Trakt API
https://trakt.tv/oauth/applications/new

**Paramètres :**
- **Name**: PlexTraktSync (ou ce que vous voulez)
- **Redirect uri**: `urn:ietf:wg:oauth:2.0:oob`
- **Permissions**: Laissez toutes les cases décochées
- Cliquez sur "Save App"

Notez votre **Client ID** et **Client Secret** affichés

### 3. Lancer la configuration

```bash
cd /Users/dev/Documents/Workspace/Doker/Media-Server
docker-compose run --rm plextraktsync login
```

**Suivez les instructions interactives :**

1. Entrez votre **Client ID** Trakt
2. Entrez votre **Client Secret** Trakt
3. Une URL sera affichée → Ouvrez-la dans votre navigateur
4. Autorisez l'application sur Trakt
5. Copiez le code d'autorisation et collez-le dans le terminal
6. Sélectionnez votre serveur Plex (devrait détecter automatiquement `plex`)

### 4. Démarrer PlexTraktSync en mode watch

```bash
docker-compose up -d plextraktsync
```

Le conteneur écoutera en continu les événements Plex et synchronisera automatiquement avec Trakt !

## 📋 Commandes utiles

```bash
# Sync manuel complet
docker-compose run --rm plextraktsync sync

# Sync uniquement les films
docker-compose run --rm plextraktsync sync --sync=movies

# Sync uniquement les séries
docker-compose run --rm plextraktsync sync --sync=shows

# Sync uniquement la watchlist
docker-compose run --rm plextraktsync sync --sync=watchlist

# Voir les médias non matchés
docker-compose run --rm plextraktsync unmatched

# Voir les logs
docker logs -f plextraktsync

# ou
make logs-plextraktsync

# Info sur la config
docker-compose run --rm plextraktsync info
```

## 📁 Fichiers de configuration

Après le setup, vous aurez ces fichiers dans ce dossier :

- `.env` - Credentials Trakt
- `.pytrakt.json` - Token d'accès Trakt
- `servers.yml` - Configuration serveur(s) Plex
- `config.yml` - Configuration du sync
- `plextraktsync.log` - Logs

## ⚙️ Configuration avancée

Éditez `config.yml` pour personnaliser :

- Bibliothèques à exclure
- Options de sync (collection, watchlist, ratings, watched status)
- Mode debug
- Filtres

## 🔄 Mode de fonctionnement

Le conteneur tourne en **mode watch** (écoute continue) :
- Détecte automatiquement les lectures Plex
- Scrobble en temps réel vers Trakt
- Sync bidirectionnelle (Plex ↔ Trakt)

## 📖 Documentation complète

https://github.com/Taxel/PlexTraktSync
