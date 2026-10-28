# Portail d'administration Cohort360 : lancement avec Docker

## Objet

Ce guide lance le portail d'administration de Cohort360 (dépôt `Cohort360-AdministrationPortal`, React + Vite) dans un conteneur Docker, en mode développement. Il n'y a ni Node.js ni `npm install` à faire sur la machine.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace (commandes courtes, menus interactifs) ;
- **Option B : sans Makefile**, directement avec `docker compose`.

Résultat attendu dans les deux cas : le portail tourne sur http://localhost:3000 (ou le port choisi dans `LOCAL_PORT`) et se recharge automatiquement à chaque modification d'un fichier de `src/`.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès à l'organisation GitHub `aphp` (voir [Accès à demander](../README.md#accès-à-demander)) | `git --version` |
| Le back-end démarré (il crée le réseau `cohort360-network`) | `docker network ls \| grep cohort360-network` |
| Port **3000** (ou `LOCAL_PORT`) libre sur la machine | `ss -ltnp 'sport = :3000'` (aucune ligne attendue ; Linux / WSL, pour macOS et Windows voir le [README](../README.md#vérifier-quun-port-est-libre)) |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                          # option A uniquement
├── cohort360.sh                      # option A uniquement (menus interactifs)
├── Cohort360-Back-end/               # à démarrer avant le portail
├── Cohort360-AdministrationPortal/   # ce dépôt
│   ├── Dockerfile
│   ├── docker-compose.dev.yml
│   ├── .dockerignore
│   ├── .env                          # à créer (non versionné)
│   ├── vite.config.ts                # copié depuis le kit (remplace celui du dépôt)
│   └── vite-dev-proxy.ts             # copié depuis le kit
└── ...
```

Cloner le dépôt dans le workspace :

```bash
cd <workspace>
git clone git@github.com:aphp/Cohort360-AdministrationPortal.git Cohort360-AdministrationPortal
```

## Principe

- **Image** : `node:22` + `npm install` des dépendances de `package.json`.
- **Contenu** : le dépôt est **monté en volume** sur `/app`, donc Vite recharge le portail à chaque modification. Les `node_modules` restent ceux de l'image (volume anonyme `/app/node_modules`) : ceux de la machine ne sont pas utilisés.
- **Commande** : `npm start -- --host 0.0.0.0` (serveur de dev Vite, port 3000 dans le conteneur).
- **Ports** : le port `LOCAL_PORT` de la machine pointe sur le port 3000 du conteneur.
- **Réseau** : le conteneur `administration_portal` rejoint le réseau externe `cohort360-network`, créé par le `docker-compose.dev.yml` du back-end. Il peut ainsi joindre `backend` par son nom de service.
- **Appels API** : avec `VITE_BACK_API_URL=/api/back`, le navigateur appelle une URL relative ; le proxy de Vite (`vite-dev-proxy.ts`) la redirige vers Django en retirant le préfixe `/api/back`. Pas besoin de Nginx en dev.

## Configuration : fichier `.env`

Le fichier `.env` est obligatoire (`env_file` dans le compose, et `LOCAL_PORT` est utilisé pour le mapping de port). Le dépôt ne fournit pas d'exemple : le créer à la racine de `Cohort360-AdministrationPortal/`.

| Variable | Rôle | Exemple en Docker |
| --- | --- | --- |
| `LOCAL_PORT` | Port de la machine pour accéder au portail (obligatoire) | `3000` |
| `VITE_BACK_API_URL` | URL de l'API back utilisée par le navigateur | `/api/back` |
| `VITE_DEV_PROXY_BACK` | Cible de `/api/back` (Django) ; à défaut `BACK_URL` | `http://backend:8000` |
| `VITE_DEV_PROXY_SECURE` | `false` pour accepter un certificat auto-signé | `true` |
| `VITE_OIDC_PROVIDER_URL` | URL du fournisseur OIDC | selon l'environnement |
| `VITE_OIDC_CLIENT_ID` | Client OIDC du portail | selon l'environnement |
| `VITE_OIDC_REDIRECT_URI` | URL de retour après connexion | `http://localhost:3000/login` (à adapter) |
| `VITE_OIDC_RESPONSE_TYPE`, `VITE_OIDC_SCOPE`, `VITE_OIDC_STATE` | Paramètres OIDC | selon l'environnement |
| `VITE_USERNAME_REGEX`, `VITE_MAIL_REGEX`, `VITE_MAIL_SUPPORT` | Validation des identifiants / e-mails, contact support | selon l'environnement |
| `VITE_SESSION_TIMEOUT`, `VITE_REFRESH_TOKEN_INTERVAL` | Durée de session, rafraîchissement du token | selon l'environnement |
| `VITE_CODE_DISPLAY_JWT`, `VITE_ROOT_PERIMETER_TYPE` | Affichage JWT, type de périmètre racine | selon l'environnement |
| `VITE_USE_CHECKED_PROFILES`, `VITE_ENABLE_DATALABS` | Fonctionnalités optionnelles (`true` / `false`) | `false` |

Si `VITE_DEV_PROXY_BACK` et `BACK_URL` sont vides, aucune route `/api/back` n'est créée.

Dans le conteneur, `localhost` désigne le conteneur `administration_portal` lui-même : la cible du proxy doit utiliser le nom de service Docker `backend` et son port interne, pas `localhost:8000`.

Après une modification du `.env`, redémarrer le conteneur : Vite ne lit le `.env` qu'au démarrage.

## Option A : avec le Makefile

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `Cohort360-AdministrationPortal/`.

Premier lancement (le back-end doit déjà tourner) :

```bash
cd <workspace>
make run-administrationportal-build
```

Commandes disponibles :

| Commande | Effet |
| --- | --- |
| `make run` | Menu interactif : choisir **AdministrationPortal** → démarre en arrière-plan |
| `make restart` | Menu interactif : redémarre le composant choisi |
| `make down` | Menu interactif : arrête le composant choisi |
| `make down-all` | Arrête tous les composants, portail compris |
| `make run-administrationportal-build` | Construit l'image puis lance le portail (premier plan, logs affichés) |
| `make run-administrationportal` | Lance le portail (premier plan) |
| `make restart-administrationportal` | Redémarre le conteneur |
| `make down-administrationportal` | Arrête et supprime le conteneur |
| `make build-administrationportal` | Reconstruit l'image sans cache (après un changement de `package.json`) |

## Option B : sans Makefile

Toutes les commandes se lancent **depuis le dossier `Cohort360-AdministrationPortal/`**.

```bash
cd <workspace>/Cohort360-AdministrationPortal

# Premier lancement : construit l'image puis démarre le portail (premier plan)
docker compose -f docker-compose.dev.yml up --build

# Lancements suivants
docker compose -f docker-compose.dev.yml up

# Démarrer en arrière-plan
docker compose -f docker-compose.dev.yml up -d

# Redémarrer (après une modification du .env)
docker compose -f docker-compose.dev.yml restart

# Reconstruire l'image sans cache (après un changement de package.json)
docker compose -f docker-compose.dev.yml build --no-cache

# Tests unitaires
docker exec -it administration_portal npm test

# Arrêter et supprimer le conteneur
docker compose -f docker-compose.dev.yml down
```

## Accéder au portail

Ouvrir http://localhost:3000 (ou le port défini dans `LOCAL_PORT`).

Passer par cette URL et non par un autre serveur : c'est le serveur Vite qui route l'URL relative `/api/back` vers Django.

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep administration_portal
# administration_portal  0.0.0.0:3000->3000/tcp

docker logs administration_portal 2>&1 | grep -E 'dev proxy|Local|Network'
# [admin-portal] dev proxy /api/back → http://backend:8000
# ➜  Local:   http://localhost:3000/

curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/
# 200

# Le portail joint bien le back depuis le conteneur (et pas depuis la machine)
docker exec administration_portal curl -s -o /dev/null -w '%{http_code}\n' http://backend:8000/
# un code HTTP (200, 301, 404...) : le back est joignable
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `network cohort360-network declared as external, but could not be found` | Le back-end n'a jamais été démarré, le réseau n'existe pas | Démarrer le back-end d'abord (`make run-backend`), ou `docker network create cohort360-network` |
| `env file .../.env not found` | Le fichier `.env` n'a pas été créé | Créer le `.env` (voir la section Configuration) |
| `invalid published port` / `"LOCAL_PORT" variable is not set` | `LOCAL_PORT` absent du `.env` | Ajouter `LOCAL_PORT=3000` dans le `.env` |
| `Bind for 0.0.0.0:3000 failed: port is already allocated` | Un `npm start` lancé hors Docker (ou un autre service) occupe déjà le port | `ss -ltnp 'sport = :3000'` pour l'identifier, l'arrêter, ou changer `LOCAL_PORT` |
| `make: *** No rule to make target 'run-administrationportal'` | `make` lancé depuis `Cohort360-AdministrationPortal/` au lieu de la racine du workspace | `cd <workspace>` puis relancer |
| `/api/back/...` renvoie la page HTML du portail, aucune ligne `dev proxy` dans les logs | `vite-dev-proxy.ts` et `vite.config.ts` du kit n'ont pas été copiés | Copier les deux fichiers (voir [Fichiers Docker du dépôt](#fichiers-docker-du-dépôt)), puis redémarrer le conteneur |
| Warning `Aucun VITE_DEV_PROXY_BACK/BACK_URL` dans les logs, appels `/api/back` en 404 | Aucune cible de proxy renseignée dans le `.env` | Renseigner `VITE_DEV_PROXY_BACK`, puis redémarrer |
| `ECONNREFUSED 127.0.0.1:8000` dans les logs Vite | Cible du proxy en `localhost` : dans le conteneur, c'est le conteneur du portail | Utiliser `http://backend:8000` |
| `getaddrinfo ENOTFOUND backend` | Le conteneur `backend` est arrêté ou pas sur `cohort360-network` | `docker ps`, puis `docker network inspect cohort360-network` |
| Erreurs 401 sur `/api/back` | Le back est joint, mais l'authentification échoue | Problème côté back / OIDC, pas côté réseau |
| Une dépendance ajoutée à `package.json` est introuvable | Les `node_modules` viennent de l'image, construite avant la modification | Reconstruire l'image sans cache, puis relancer |
| Le portail ne se recharge pas après une modification | Sous Docker Desktop (Mac/Windows), les événements de fichiers du volume arrivent mal | Redémarrer le conteneur |

## Fichiers Docker du dépôt

Copier à la racine de `Cohort360-AdministrationPortal/` les fichiers du dossier `administration-portail/` du kit :

- `Dockerfile`
- `docker-compose.dev.yml`
- `vite-dev-proxy.ts` : proxy de dev qui redirige `/api/back` vers Django (nouveau fichier)
- `vite.config.ts` : branche le proxy sur le serveur Vite (**remplace le fichier du dépôt**)

Le `.dockerignore` est déjà fourni par le dépôt.

Sans `vite-dev-proxy.ts` et ce `vite.config.ts`, il n'y a pas de proxy : les appels à `/api/back` renvoient la page HTML du portail au lieu de joindre Django.

**Ne pas committer `vite.config.ts`.** C'est un fichier suivi par git : après la copie, `git status` le montre modifié. Ne pas l'inclure dans un commit (pas de `git add .`). Pour revenir à la version du dépôt : `git checkout vite.config.ts`. Après un `git pull` qui modifie `vite.config.ts`, vérifier que la copie du kit est toujours à jour avant de la recoller.

Dans le conteneur, Vite doit écouter sur `0.0.0.0` (option `--host 0.0.0.0`) et non sur `127.0.0.1` : sinon il n'est pas joignable depuis la machine malgré le mapping de port.
