# FrontEnd Cohort360 : lancement avec Docker

## Objet

Ce guide lance le frontend Cohort360 (dépôt `Cohort360-FrontEnd`, React + Vite) dans un conteneur Docker, en mode développement. Il n'y a ni Node.js ni `npm install` à faire sur la machine.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace (commandes courtes, menus interactifs) ;
- **Option B : sans Makefile**, directement avec `docker compose`.

Résultat attendu dans les deux cas : le front tourne sur http://localhost:9808 (ou le port choisi dans `FRONT_LOCAL_PORT`) et se recharge automatiquement à chaque modification d'un fichier de `src/`.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès aux dépôts internes | `git --version` |
| Le back-end démarré (il crée le réseau `cohort360-network`) | `docker network ls \| grep cohort360-network` |
| Port **9808** libre sur la machine | `ss -ltnp 'sport = :9808'` (aucune ligne attendue) |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                 # option A uniquement
├── cohort360.sh             # option A uniquement (menus interactifs)
├── Cohort360-Back-end/      # à démarrer avant le front
├── Cohort360-FrontEnd/      # ce dépôt
│   ├── Dockerfile
│   ├── docker-compose.dev.yml
│   ├── .env                 # à créer (non versionné)
│   ├── .env.dev-proxy.example
│   ├── vite.config.ts
│   └── vite-dev-proxy.ts
└── ...
```

Cloner le dépôt dans le workspace :

```bash
cd <workspace>
git clone <URL SSH du dépôt> Cohort360-FrontEnd
```

## Principe

- **Image** : `node:22` + `npm install` des dépendances de `package.json`.
- **Contenu** : le dépôt est **monté en volume** sur `/app`, donc Vite recharge le front à chaque modification. Les `node_modules` restent ceux de l'image (volume anonyme `/app/node_modules`) : ceux de la machine ne sont pas utilisés.
- **Commande** : `npm start -- --host 0.0.0.0` (serveur de dev Vite, port 9808 dans le conteneur).
- **Ports** : le port `FRONT_LOCAL_PORT` de la machine pointe sur le port 9808 du conteneur.
- **Réseau** : le conteneur `front` rejoint le réseau externe `cohort360-network`, créé par le `docker-compose.dev.yml` du back-end. Il peut ainsi joindre `backend` et `daphne` par leur nom de service.
- **Appels API** : le navigateur appelle des URLs relatives (`/api/back`, `/api/fhir`, ...) ; le proxy de Vite (`vite-dev-proxy.ts`) les redirige vers les services. Pas besoin de Nginx en dev.

## Configuration : fichier `.env`

Le fichier `.env` est obligatoire (`required: true` dans le compose). Partir de l'exemple fourni :

```bash
cd <workspace>/Cohort360-FrontEnd
cp .env.dev-proxy.example .env
```

Puis vérifier au minimum ces variables :

| Variable | Rôle | Exemple en Docker |
| --- | --- | --- |
| `FRONT_LOCAL_PORT` | Port de la machine pour accéder au front | `9808` |
| `VITE_CONFIG_URL` | URL du fichier de configuration chargé au démarrage | `/config.dev.json` (fichier de `public/`, voir ci-dessous) |
| `VITE_DEV_PROXY_BACK` | Cible de `/api/back` (Django) | `http://backend:8000` |
| `VITE_DEV_PROXY_BACK_WS` | Cible de `/api/back/ws` (WebSocket, Daphne) | `http://daphne:8005` |
| `VITE_DEV_PROXY_FHIR` | Cible de `/api/fhir` (réécrit en `/fhir`) | URL de l'API FHIR |
| `VITE_DEV_PROXY_REQUEST` | Cible de `/api/request` ; vide = même valeur que FHIR, `off` = désactivé | (vide) |
| `VITE_DEV_PROXY_DATAMODEL` | Cible de `/api/datamodel` | URL du service datamodel |
| `VITE_DEV_PROXY_PORTAIL` | Cible de `/api/portail` ; vide = même valeur que BACK | (vide) |
| `VITE_DEV_PROXY_SECURE` | `false` pour accepter un certificat auto-signé | `true` |
| `VITE_DEV_PROXY_FHIR_AUTH_METHOD` | `OIDC` ajoute l'en-tête `authorizationMethod: OIDC` sur FHIR | (vide) |

Une variable `VITE_DEV_PROXY_*` vide désactive la route correspondante.

### Fichier `public/config.dev.json`

Le fichier indiqué par `VITE_CONFIG_URL` n'est pas dans le dépôt : `public/config.*.json` est ignoré par git. **Le demander à l'équipe**, puis le placer dans `Cohort360-FrontEnd/public/config.dev.json`.

Au démarrage, le front télécharge ce fichier et le fusionne avec la configuration par défaut de `src/config.tsx`. S'il est absent, le front démarre quand même, mais avec la configuration par défaut (erreur `Error while fetching config` dans la console du navigateur).

> **À mettre à jour** : préciser où trouver `config.dev.json` (fichier fourni par le kit, dépôt, ou contact dans l'équipe).

Dans le conteneur, `localhost` désigne le conteneur `front` lui-même : les cibles du proxy doivent utiliser les noms de service Docker (`backend`, `daphne`) et leurs ports internes, pas `localhost:8000`.

Après une modification du `.env`, redémarrer le conteneur : Vite ne lit le `.env` qu'au démarrage.

## Option A : avec le Makefile

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `Cohort360-FrontEnd/`.

Premier lancement (le back-end doit déjà tourner) :

```bash
cd <workspace>
make run-front-build
```

Commandes disponibles :

| Commande | Effet |
| --- | --- |
| `make run` | Menu interactif : choisir **Front** → démarre en arrière-plan |
| `make restart` | Menu interactif : redémarre le composant choisi |
| `make down` | Menu interactif : arrête le composant choisi |
| `make down-all` | Arrête tous les composants, front compris |
| `make run-front-build` | Construit l'image puis lance le front (premier plan, logs affichés) |
| `make run-front` | Lance le front (premier plan) |
| `make restart-front` | Redémarre le conteneur |
| `make down-front` | Arrête et supprime le conteneur |
| `make build-front` | Reconstruit l'image sans cache (après un changement de `package.json`) |
| `make unit-test-front` | Lance les tests unitaires (vitest) dans le conteneur `front` |

## Option B : sans Makefile

Toutes les commandes se lancent **depuis le dossier `Cohort360-FrontEnd/`**.

```bash
cd <workspace>/Cohort360-FrontEnd

# Premier lancement : construit l'image puis démarre le front (premier plan)
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
docker exec -it front npm test -- --run

# Arrêter et supprimer le conteneur
docker compose -f docker-compose.dev.yml down
```

## Accéder au front

Ouvrir http://localhost:9808 (ou le port défini dans `FRONT_LOCAL_PORT`).

Passer par cette URL et non par un autre serveur : c'est le serveur Vite qui route les URLs relatives `/api/...` vers les services.

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -w front
# front  0.0.0.0:9808->9808/tcp

docker logs front 2>&1 | grep -E 'dev proxy|Local|Network'
# [cohort360] dev proxy (N règles) → back http://backend:8000
# ➜  Local:   http://localhost:9808/

curl -s -o /dev/null -w '%{http_code}\n' http://localhost:9808/
# 200

# Le front joint bien le back depuis le conteneur (et pas depuis la machine)
docker exec front curl -s -o /dev/null -w '%{http_code}\n' http://backend:8000/
# un code HTTP (200, 301, 404...) : le back est joignable
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `network cohort360-network declared as external, but could not be found` | Le back-end n'a jamais été démarré, le réseau n'existe pas | Démarrer le back-end d'abord (`make run-backend`), ou `docker network create cohort360-network` |
| `env file .../.env not found` | Le fichier `.env` n'a pas été créé | `cp .env.dev-proxy.example .env` puis l'adapter |
| `Error while fetching config` dans la console du navigateur | `public/config.dev.json` absent : le front tourne sur la configuration par défaut | Demander le fichier à l'équipe et le placer dans `public/` (voir [Fichier `public/config.dev.json`](#fichier-publicconfigdevjson)), puis recharger la page |
| `Bind for 0.0.0.0:9808 failed: port is already allocated` | Un `npm start` lancé hors Docker (ou un autre service) occupe déjà le port | `ss -ltnp 'sport = :9808'` pour l'identifier, l'arrêter, ou changer `FRONT_LOCAL_PORT` |
| `make: *** No rule to make target 'run-front'` | `make` lancé depuis `Cohort360-FrontEnd/` au lieu de la racine du workspace | `cd <workspace>` puis relancer |
| Warning `Aucun VITE_DEV_PROXY_*` dans les logs, appels `/api/back` en 404 | Aucune variable de proxy renseignée dans le `.env` | Renseigner `VITE_DEV_PROXY_BACK` (et les autres), puis redémarrer |
| `ECONNREFUSED 127.0.0.1:8000` dans les logs Vite | Cible du proxy en `localhost` : dans le conteneur, c'est le conteneur `front` | Utiliser `http://backend:8000` |
| `getaddrinfo ENOTFOUND backend` | Le conteneur `backend` est arrêté ou pas sur `cohort360-network` | `docker ps`, puis `docker network inspect cohort360-network` |
| Erreurs 401 sur `/api/back` | Le back est joint, mais l'authentification échoue | Problème côté back/authentification, pas côté réseau |
| Une dépendance ajoutée à `package.json` est introuvable | Les `node_modules` viennent de l'image, construite avant la modification | Reconstruire l'image sans cache, puis relancer |
| Le front ne se recharge pas après une modification | Sous Docker Desktop (Mac/Windows), les événements de fichiers du volume arrivent mal | Redémarrer le conteneur |

## Fichiers Docker du dépôt

À la racine de `Cohort360-FrontEnd/`, coller les trois fichiers docker.

- `Dockerfile`
- `docker-compose.dev.yml`
- `.dockerignore`

Dans le conteneur, Vite doit écouter sur `0.0.0.0` (option `--host 0.0.0.0`) et non sur `127.0.0.1` : sinon il n'est pas joignable depuis la machine malgré le mapping de port.
