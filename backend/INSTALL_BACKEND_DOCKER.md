# Back-end Cohort360 : lancement avec Docker

## Objet

Ce guide lance le back-end Cohort360 (dépôt `Cohort360-Back-end`, Django / DRF) dans Docker, en mode développement. Il n'y a ni Python, ni `uv`, ni PostgreSQL, ni Redis à installer sur la machine.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace (commandes courtes, menus interactifs) ;
- **Option B : sans Makefile**, directement avec `docker compose`.

Résultat attendu dans les deux cas : l'API Django répond sur http://localhost:8000, les WebSockets (Daphne) sur le port 8005, et le code se recharge automatiquement à chaque modification d'un fichier Python.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès à l'organisation GitHub `aphp` (voir [Accès à demander](../README.md#accès-à-demander)) | `git --version` |
| Ports **8000**, **8005**, **5433** et **6380** libres sur la machine | `ss -ltnp | grep -E ':(8000|8005|5433|6380) '` (aucune ligne attendue ; Linux / WSL, pour macOS et Windows voir le [README](../README.md#vérifier-quun-port-est-libre)) |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                 # option A uniquement
├── cohort360.sh             # option A uniquement (menus interactifs)
├── Cohort360-Back-end/      # ce dépôt
│   ├── Dockerfile
│   ├── docker-compose.dev.yml
│   ├── docker-entrypoint.sh
│   ├── .dockerignore
│   ├── .env                 # à créer (non versionné)
│   ├── .local/env.docker.example
│   ├── pyproject.toml
│   └── uv.lock
├── Cohort360-FrontEnd/      # à démarrer après le back
└── ...
```

Cloner le dépôt dans le workspace :

```bash
cd <workspace>
git clone git@github.com:aphp/Cohort360-Back-end.git Cohort360-Back-end
```

## Principe

Le `docker-compose.dev.yml` démarre 5 conteneurs :

| Service | Conteneur | Rôle | Port machine → conteneur |
| --- | --- | --- | --- |
| `postgres` | `postgres` | Base PostgreSQL 16 | `5433` → `5432` |
| `redis` | `redis` | Broker Celery, cache, canaux WebSocket | `6380` → `6379` |
| `backend` | `backend` | `migrate` puis `runserver 0.0.0.0:8000` | `8000` → `8000` |
| `celery` | `celery` | Worker Celery (tâches asynchrones) | aucun |
| `daphne` | `daphne` | Serveur ASGI pour les WebSockets | `8005` → `8005` |

- **Image** : `python:3.12-slim` + dépendances installées par `uv sync --frozen` (depuis `uv.lock`). La même image sert à `backend`, `celery` et `daphne`.
- **Contenu** : le dépôt est **monté en volume**, donc `runserver` recharge le code à chaque modification. Le `.venv` reste celui de l'image (volume anonyme) : celui de la machine n'est pas utilisé.
- **Migrations** : appliquées automatiquement au démarrage du conteneur `backend`.
- **Données** : la base est conservée dans le volume Docker `cohort360_pgdata`, même après un `down`.
- **Réseau** : le compose crée le réseau `cohort360-network`. Le front et les autres composants le rejoignent pour joindre `backend` et `daphne` par leur nom de service. **Le back-end doit donc être démarré en premier.**
- **Services sur la machine** (FHIR, QueryExecutor, Keycloak...) : accessibles depuis le conteneur via `host.docker.internal` (déclaré dans le compose pour `backend`).

## Configuration : fichier `.env`

Le fichier `.env` est obligatoire (`required: true` dans le compose). Partir de l'exemple fourni :

```bash
cd <workspace>/Cohort360-Back-end
cp .local/env.docker.example .env
```

Le `.env` est la seule source de configuration : `backend`, `celery` et `daphne` le lisent tel quel, et le conteneur `postgres` y prend aussi son utilisateur, son mot de passe et le nom de la base à créer (`DB_USER`, `DB_PASSWORD`, `DB_NAME`).

Vérifier que le `.env` contient ces valeurs :

```env
DB_NAME=cohort_db
DB_USER=cohort_dev
DB_PASSWORD=cohort_dev_pwd
DB_HOST=postgres
DB_PORT=5432
PERIMETERS_SOURCE_DB_NAME=cohort_db
PERIMETERS_SOURCE_DB_USER=cohort_dev
PERIMETERS_SOURCE_DB_PASSWORD=cohort_dev_pwd
PERIMETERS_SOURCE_DB_HOST=postgres
PERIMETERS_SOURCE_DB_PORT=5432
CELERY_BROKER_URL=redis://redis:6379/0
```

Puis vérifier au minimum ces variables :

| Variable | Rôle | Valeur en Docker |
| --- | --- | --- |
| `DJANGO_SECRET_KEY` | Clé secrète Django | une chaîne quelconque en dev |
| `DB_NAME` | Base utilisée par Django, créée par `postgres` au premier démarrage | `cohort_db` |
| `DB_USER` / `DB_PASSWORD` | Identifiants PostgreSQL, créés par `postgres` au premier démarrage | `cohort_dev` / `cohort_dev_pwd` |
| `DB_HOST` / `DB_PORT` | Hôte PostgreSQL | `postgres` / `5432` |
| `PERIMETERS_SOURCE_DB_*` | Base source des périmètres | mêmes valeurs que `DB_*` |
| `CELERY_BROKER_URL` | Redis (Celery, cache, WebSockets) | `redis://redis:6379/0` |
| `PERIMETER_TYPES` | Types de périmètres (obligatoire) | déjà rempli dans l'exemple |
| `FHIR_URL` | API FHIR | `http://host.docker.internal:<port>/fhir` |
| `QUERY_EXECUTOR_URL` | QueryExecutor | `http://host.docker.internal:8091` ou `http://<service QE>:8091` s'il est sur `cohort360-network` |
| `FRONTEND_URL` / `FRONTEND_URLS` | URL(s) du front autorisées | `http://localhost:9808` |
| `JWT_*`, `OIDC_*` | Authentification | voir `.local/loca-env.template` |

Points d'attention :

- **Ce `.env` est propre à Docker.** `DB_HOST` vaut `postgres` et non `localhost` : il ne fonctionne pas tel quel pour un `runserver` lancé hors Docker.
- **`DB_NAME`, `DB_USER` et `DB_PASSWORD` ne sont pris en compte par `postgres` qu'au tout premier démarrage du volume `cohort360_pgdata`.** Les modifier ensuite ne crée ni la base ni l'utilisateur : créer la base à la main (`docker exec postgres createdb -U <DB_USER> <DB_NAME>`), ou repartir d'un volume vide avec `docker volume rm cohort360_pgdata` (la base est alors perdue).
- Dans un conteneur, `localhost` désigne le conteneur lui-même : utiliser les noms de service (`postgres`, `redis`) avec leurs ports **internes** (`5432`, `6379`), pas `localhost:5433`.

Après une modification du `.env`, redémarrer les conteneurs : il n'est lu qu'au démarrage.

## Option A : avec le Makefile

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `Cohort360-Back-end/`.

Premier lancement :

```bash
cd <workspace>
make run-backend-build
```

Commandes disponibles :

| Commande | Effet |
| --- | --- |
| `make run` | Menu interactif : choisir **Back-end** → démarre en arrière-plan |
| `make restart` | Menu interactif : redémarre le composant choisi |
| `make down` | Menu interactif : arrête le composant choisi |
| `make down-all` | Arrête tous les composants, back-end compris |
| `make run-backend-build` | Construit l'image puis lance le back (premier plan, logs affichés) |
| `make run-backend` | Lance le back (premier plan) |
| `make restart-backend` | Redémarre les conteneurs du back |
| `make down-backend` | Arrête et supprime les conteneurs (la base est conservée) |
| `make build-backend` | Reconstruit l'image sans cache (après un changement de `pyproject.toml` / `uv.lock`) |
| `make migrations` | `makemigrations` dans le conteneur `backend` |
| `make migrate` | `migrate` dans le conteneur `backend` |
| `make unit_tests` | Lance les tests Django dans le conteneur `backend` |
| `make restart-celery` | Redémarre uniquement le worker Celery (après une modification d'une tâche) |

## Option B : sans Makefile

Toutes les commandes se lancent **depuis le dossier `Cohort360-Back-end/`**.

```bash
cd <workspace>/Cohort360-Back-end

# Premier lancement : construit l'image puis démarre la stack (premier plan)
docker compose -f docker-compose.dev.yml up --build

# Lancements suivants
docker compose -f docker-compose.dev.yml up

# Démarrer en arrière-plan
docker compose -f docker-compose.dev.yml up -d

# Redémarrer (après une modification du .env)
docker compose -f docker-compose.dev.yml restart

# Redémarrer uniquement Celery (le worker ne recharge pas le code tout seul)
docker compose -f docker-compose.dev.yml restart celery

# Reconstruire l'image sans cache (après un changement de pyproject.toml / uv.lock)
docker compose -f docker-compose.dev.yml build --no-cache

# Migrations
docker exec backend python manage.py makemigrations
docker exec backend python manage.py migrate

# Tests
docker exec -it backend python manage.py test

# Arrêter et supprimer les conteneurs (la base est conservée dans le volume)
docker compose -f docker-compose.dev.yml down
```

## Initialiser la base de données

Le développeur crée sa propre base PostgreSQL, vide, avec **les mêmes valeurs que les variables d'environnement du `.env`** : nom de base `DB_NAME`, utilisateur `DB_USER`, mot de passe `DB_PASSWORD`. Django se connecte avec ces valeurs : si la base porte un autre nom ou appartient à un autre utilisateur, les migrations ne s'appliquent pas dessus.

### 1. Créer la base

Au premier démarrage du volume `cohort360_pgdata`, le conteneur `postgres` crée automatiquement la base `DB_NAME` et l'utilisateur `DB_USER` / `DB_PASSWORD` à partir du `.env`. Il n'y a rien à faire si le `.env` est rempli avant le premier lancement.

Si le volume existe déjà (créé avec d'autres valeurs), créer la base à la main avec les valeurs du `.env` :

```bash
# Remplacer <DB_USER> et <DB_NAME> par les valeurs du .env (ex. cohort_dev et cohort_db)
docker exec postgres createdb -U <DB_USER> <DB_NAME>
```

Ou repartir d'un volume vide, qui sera recréé avec les valeurs du `.env` (toutes les données de `postgres` sont perdues) :

```bash
docker compose -f docker-compose.dev.yml down
docker volume rm cohort360_pgdata
docker compose -f docker-compose.dev.yml up
```

### 2. Appliquer les migrations

Le conteneur `backend` lance `python manage.py migrate` à chaque démarrage : les tables de Cohort360 sont créées directement dans la base `DB_NAME`. Pour les relancer à la main :

```bash
docker exec backend python manage.py migrate
```

Vérifier que la table des utilisateurs (`user`) existe :

```bash
docker exec postgres psql -U <DB_USER> -d <DB_NAME> -c '\dt "user"'
# public | user | table | cohort_dev
```

### 3. Créer un utilisateur

Créer son propre utilisateur administrateur :

```bash
docker exec backend python manage.py create_user_admin --username USERNAME --password PASSWORD
```

Remplacer `USERNAME` et `PASSWORD` par les valeurs voulues.

Avec le Makefile, la même commande se lance depuis la racine du workspace avec `docker exec` (il n'y a pas de cible dédiée).

## Accéder au back-end

- API : http://localhost:8000
- WebSockets : `ws://localhost:8005`
- PostgreSQL depuis la machine (DBeaver, psql...) : `localhost:5433`
- Redis depuis la machine : `localhost:6380`

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'backend|celery|daphne|postgres|redis'
# 5 conteneurs "Up" ; postgres et redis "(healthy)"

docker logs backend 2>&1 | grep -E 'Starting development server|Error'
# Starting development server at http://0.0.0.0:8000/

curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/
# un code HTTP (200, 302, 404...) : Django répond

docker logs celery 2>&1 | grep -E 'ready|Error'
# celery@... ready.

# celery et daphne joignent bien postgres et redis depuis leur conteneur
docker exec celery python -c "import socket; socket.create_connection(('redis', 6379), 2); socket.create_connection(('postgres', 5432), 2); print('OK')"
# OK
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `env file .../.env not found` | Le fichier `.env` n'a pas été créé | `cp .local/env.docker.example .env` puis l'adapter |
| `Conflict. The container name "/postgres" is already in use` | Un autre conteneur nommé `postgres` existe déjà sur la machine (autre projet) | `docker ps -a --filter name=^postgres$` pour l'identifier, puis l'arrêter et le supprimer (`docker rm -f postgres`) ou le renommer (`docker rename postgres <autre-nom>`) |
| `make: *** No rule to make target 'run-backend'` | `make` lancé depuis `Cohort360-Back-end/` au lieu de la racine du workspace | `cd <workspace>` puis relancer |
| `Bind for 0.0.0.0:8000 failed: port is already allocated` | Un `runserver` lancé hors Docker (ou un autre service) occupe déjà le port | `ss -ltnp 'sport = :8000'` pour l'identifier et l'arrêter |
| `ImproperlyConfigured: Set the XXX environment variable` | Variable obligatoire absente du `.env` | Ajouter la variable (ex. `PERIMETER_TYPES`, `DJANGO_SECRET_KEY`), puis redémarrer |
| `FATAL: database "xxx" does not exist` | `DB_NAME` ne correspond à aucune base de `postgres` (volume créé avec d'autres valeurs) | Créer la base avec les valeurs du `.env` : voir [Créer la base](#1-créer-la-base) |
| `relation "user" does not exist` | Les migrations n'ont pas été appliquées sur la base `DB_NAME` | Voir [Appliquer les migrations](#2-appliquer-les-migrations) |
| `password authentication failed` | Le volume a été initialisé avec d'autres identifiants que ceux du `.env` | Remettre dans le `.env` les identifiants d'origine (modifier `DB_USER` / `DB_PASSWORD` n'a plus d'effet sur `postgres` après le premier démarrage), ou `docker volume rm cohort360_pgdata` pour repartir de zéro |
| Warning `The "DB_USER" variable is not set`, puis `postgres` s'arrête (`superuser password is not specified`) | `DB_NAME`, `DB_USER` ou `DB_PASSWORD` absent du `.env` | Ajouter les variables (voir le bloc `.env` ci-dessus) |
| `Connection refused` vers `localhost:5432` ou `localhost:6379` | `DB_HOST`, `DB_PORT` ou `CELERY_BROKER_URL` absents du `.env` | Ajouter `DB_HOST=postgres`, `DB_PORT=5432`, `PERIMETERS_SOURCE_DB_HOST=postgres`, `PERIMETERS_SOURCE_DB_PORT=5432`, `CELERY_BROKER_URL=redis://redis:6379/0` |
| `Name or service not known` sur `host.docker.internal` dans `celery` / `daphne` | `extra_hosts` n'est déclaré que pour `backend` | Appeler ces services depuis `backend`, ou ajouter `extra_hosts` au service concerné |
| Une tâche Celery modifiée garde l'ancien comportement | Le worker Celery ne recharge pas le code automatiquement | `make restart-celery` |
| Une dépendance ajoutée à `pyproject.toml` est introuvable | Le `.venv` vient de l'image, construite avant la modification | Mettre à jour `uv.lock`, reconstruire l'image sans cache, puis relancer |
| Le front affiche `network cohort360-network ... could not be found` | Le back-end n'a jamais été démarré | Démarrer le back-end d'abord |

## Fichiers Docker du dépôt

À la racine de `Cohort360-Back-end/` :

- `Dockerfile`
- `docker-compose.dev.yml`
- `docker-entrypoint.sh` (non utilisé en dev : le compose le remplace par `entrypoint: []`)
- `.dockerignore`

Dans le conteneur, Django et Daphne doivent écouter sur `0.0.0.0` et non sur `127.0.0.1` : sinon ils ne sont pas joignables depuis la machine malgré le mapping de port.
