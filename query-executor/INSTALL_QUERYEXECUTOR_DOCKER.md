# QueryExecutor Cohort360 : lancement avec Docker

## Objet

Ce guide lance le QueryExecutor de Cohort360 (dépôt `Cohort360-QueryExecutor`, Scala + Spark, serveur HTTP Scalatra) dans un conteneur Docker. Il n'y a ni Java, ni Maven, ni Spark à installer sur la machine : la compilation se fait dans l'image.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace (commandes courtes, menus interactifs) ;
- **Option B : sans Makefile**, directement avec `docker compose`.

Résultat attendu dans les deux cas : le QueryExecutor répond sur http://localhost:9804 (ou le port choisi dans `QUERY_EXECUTOR_LOCAL_PORT`) et le back-end le joint sur `http://query_executor:8091`.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès aux dépôts internes | `git --version` |
| Le back-end démarré (il crée le réseau `cohort360-network`) | `docker network ls \| grep cohort360-network` |
| Port choisi pour `QUERY_EXECUTOR_LOCAL_PORT` libre (ex. **9804**) | `ss -ltnp 'sport = :9804'` (aucune ligne attendue) |
| Accès à la base OMOP (PostgreSQL), à Solr et/ou à l'API FHIR | selon le résolveur utilisé |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                     # option A uniquement
├── cohort360.sh                 # option A uniquement (menus interactifs)
├── Cohort360-Back-end/          # à démarrer avant le QueryExecutor
├── Cohort360-QueryExecutor/     # ce dépôt
│   ├── Dockerfile
│   ├── docker-compose.dev.yml
│   ├── entrypoint.sh
│   ├── .env                     # à créer (non versionné)
│   ├── .local/env.example
│   ├── pom.xml
│   └── src/main/resources/application.conf
└── ...
```

Cloner le dépôt dans le workspace :

```bash
cd <workspace>
git clone <URL SSH du dépôt> Cohort360-QueryExecutor
```

## Principe

- **Image** : build en deux étapes. Étape 1 (`eclipse-temurin:11`) : `./mvnw clean install -DskipTests` produit `cohort-requester.jar` et `cohort-requester-libs.jar`, et récupère le driver `postgresql.jar`. Étape 2 (`eclipse-temurin:11`) : ne garde que les JAR et `entrypoint.sh`, exécutés par l'utilisateur `spark`.
- **Contenu** : le code est **copié dans l'image**, pas monté en volume. Toute modification du code Scala demande donc de **reconstruire l'image** (pas de rechargement automatique).
- **Démarrage** : `entrypoint.sh` écrit `~/.pgpass` (accès OMOP) et `solr_auth.txt` (accès Solr) à partir des variables d'environnement, puis lance `java -jar cohort-requester.jar`.
- **Ports** : le port `QUERY_EXECUTOR_LOCAL_PORT` de la machine pointe sur le port **8091** du conteneur.
- **Réseau** : le conteneur `query_executor` rejoint le réseau externe `cohort360-network`, créé par le `docker-compose.dev.yml` du back-end. Le back-end le joint par son nom de service, et le QueryExecutor rappelle Django sur `backend:8000`.
- **Routes HTTP** : `/` (santé), `/jobs` (POST : lancer un job, GET : lister, DELETE `/jobs/<id>` : annuler), `/api-docs` (Swagger).

## Configuration : fichier `.env`

Le fichier `.env` est obligatoire (`required: true` dans le compose). Partir de l'exemple fourni :

```bash
cd <workspace>/Cohort360-QueryExecutor
cp .local/env.example .env
```

Puis vérifier au minimum ces variables :

| Variable | Rôle | Exemple en Docker |
| --- | --- | --- |
| `QUERY_EXECUTOR_LOCAL_PORT` | Port de la machine pour accéder au QueryExecutor (absente de l'exemple, **à ajouter**) | `9804` |
| `SJS_APP_PORT` | Port d'écoute du serveur dans le conteneur. **Doit valoir 8091** (le compose mappe vers 8091, le défaut de `application.conf` est 8090) | `8091` |
| `DJANGO_CALLBACK_URL` | URL du back-end Django, appelée en fin de job | `http://backend:8000` |
| `SJS_TOKEN` | Jeton envoyé à Django lors du callback ; doit correspondre à `QUERY_EXECUTOR_TOKEN` du `.env` du back-end | (secret) |
| `FHIR_URL` / `FHIR_URL_COHORT` | API FHIR (résolveur FHIR, création de cohortes FHIR) | URL de l'API FHIR |
| `FHIR_ACCESS_TOKEN` | Jeton d'accès FHIR, si nécessaire | (secret) |
| `PG_HOST`, `PG_PORT`, `PG_DB`, `PG_SCHEMA`, `PG_USER`, `DB_OMOP_PASSWORD` | Base OMOP (création des listes de cohortes) | hôte joignable depuis le conteneur |
| `SOLR_ZK`, `SOLR_USER`, `SOLR_PASSWORD` | Accès Solr (ZooKeeper + authentification) | hôte joignable depuis le conteneur |
| `SPARK_MASTER` | Spark en local dans le conteneur | `local[*]` |
| `SPARK_DRIVER_HOST` | Hôte du driver Spark | `localhost` |
| `DEFAULT_RESOLVER` | Source de résolution des critères (`solr` par défaut) | `solr` |
| `DEFAULT_COHORT_CREATION_SERVICE` | Service de création de cohortes (`pg` par défaut) | `pg` |

Les autres variables (`JOBS_THREADS`, `COHORT_CREATION_LIMIT`, `USE_ACTIVE_FILTER`...) ont des valeurs par défaut dans `src/main/resources/application.conf`.

Dans le conteneur, `localhost` désigne le conteneur `query_executor` lui-même : les valeurs de `env.example` (`localhost:8085`, `PG_HOST=localhost`, ...) sont prévues pour un lancement hors Docker et doivent être remplacées par des noms de service Docker ou des hôtes réels.

Côté back-end, le `.env` de `Cohort360-Back-end` doit pointer vers le QueryExecutor par le réseau Docker :

```
QUERY_EXECUTOR_URL=http://query_executor:8091
```

Après une modification du `.env`, redémarrer le conteneur (pas besoin de reconstruire l'image).

## Utilisateur applicatif dans la base du back-end

Quand le QueryExecutor rappelle Django, il envoie `SJS_TOKEN`. Le back-end reconnaît ce jeton (`QUERY_EXECUTOR_TOKEN`) et charge l'utilisateur nommé dans `QUERY_EXECUTOR_USERNAME` dans la table `user`. **Si cet utilisateur n'existe pas, le callback échoue** (`User.DoesNotExist`, erreur 500) et le statut des jobs n'est jamais mis à jour.

Dans le `.env` de `Cohort360-Back-end` :

```
QUERY_EXECUTOR_USERNAME=SPARK_JOB_SERVER
QUERY_EXECUTOR_TOKEN=<même valeur que SJS_TOKEN du QueryExecutor>
```

Créer ensuite l'utilisateur `SPARK_JOB_SERVER` dans la table `user`, **sans mot de passe** (l'authentification se fait uniquement par le jeton). Au choix :

Avec le shell Django (recommandé, il applique les valeurs par défaut du modèle) :

```bash
docker exec -it backend python manage.py shell -c "
from admin_cohort.models import User
User.objects.get_or_create(username='SPARK_JOB_SERVER', defaults={'firstname': 'Query', 'lastname': 'EXECUTOR'})
"
```

Ou en SQL, directement dans PostgreSQL (`user` est un mot réservé, d'où les guillemets) :

```bash
docker exec -it pg-db psql -U <POSTGRES_USER> -d <POSTGRES_DB> -c "
INSERT INTO \"user\" (username, firstname, lastname, password, onboarding_step, insert_datetime)
VALUES ('SPARK_JOB_SERVER', 'Query', 'EXECUTOR', NULL, 0, now())
ON CONFLICT (username) DO NOTHING;"
```

Vérifier :

```bash
docker exec -it pg-db psql -U <POSTGRES_USER> -d <POSTGRES_DB> -c "SELECT username, password, delete_datetime FROM \"user\" WHERE username = 'SPARK_JOB_SERVER';"
# 1 ligne, password vide, delete_datetime vide
```

Le nom dans la table doit être **exactement** celui de `QUERY_EXECUTOR_USERNAME`. Attention : si la variable est absente, le back-end utilise `SPARK_JOB_SERVER` pour l'authentification, mais la commande `load_initial_data` crée un utilisateur `QUERY_EXECUTOR`. Il faut donc toujours renseigner la variable.

Après une modification du `.env` du back-end, redémarrer `backend` (la variable n'est lue qu'au démarrage).

## Option A : avec le Makefile

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `Cohort360-QueryExecutor/`.

Premier lancement (le back-end doit déjà tourner ; la compilation Maven prend plusieurs minutes) :

```bash
cd <workspace>
make run-queryexecutor-build
```

Commandes disponibles :

| Commande | Effet |
| --- | --- |
| `make run` | Menu interactif : choisir **QueryExecutor** → démarre en arrière-plan |
| `make restart` | Menu interactif : redémarre le composant choisi |
| `make down` | Menu interactif : arrête le composant choisi |
| `make down-all` | Arrête tous les composants, QueryExecutor compris |
| `make run-queryexecutor-build` | Construit l'image puis lance le QueryExecutor (premier plan, logs affichés) |
| `make run-queryexecutor` | Lance le QueryExecutor (premier plan) |
| `make restart-queryexecutor` | Redémarre le conteneur (après une modification du `.env`) |
| `make down-queryexecutor` | Arrête et supprime le conteneur |
| `make build-queryexecutor` | Reconstruit l'image sans cache (après une modification du code ou du `pom.xml`) |

## Option B : sans Makefile

Toutes les commandes se lancent **depuis le dossier `Cohort360-QueryExecutor/`**.

```bash
cd <workspace>/Cohort360-QueryExecutor

# Premier lancement : construit l'image puis démarre le QueryExecutor (premier plan)
docker compose -f docker-compose.dev.yml up --build

# Lancements suivants
docker compose -f docker-compose.dev.yml up

# Démarrer en arrière-plan
docker compose -f docker-compose.dev.yml up -d

# Redémarrer (après une modification du .env)
docker compose -f docker-compose.dev.yml restart

# Après une modification du code : reconstruire et relancer
docker compose -f docker-compose.dev.yml up --build -d

# Reconstruire l'image sans cache
docker compose -f docker-compose.dev.yml build --no-cache

# Arrêter et supprimer le conteneur
docker compose -f docker-compose.dev.yml down
```

Utiliser `docker-compose.dev.yml` et non `docker-compose.yml` : ce dernier lance une autre architecture (image `sjs:latest` + cluster Spark master/workers) qui n'est pas utilisée avec le reste du workspace.

## Accéder au QueryExecutor

- Santé : http://localhost:9804/
- Liste des jobs : http://localhost:9804/jobs
- Swagger : http://localhost:9804/api-docs

(remplacer 9804 par la valeur de `QUERY_EXECUTOR_LOCAL_PORT`)

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep query_executor
# query_executor  0.0.0.0:9804->8091/tcp

docker logs query_executor 2>&1 | tail -20
# pas d'exception au démarrage, serveur Jetty démarré sur 8091

curl -s -o /dev/null -w '%{http_code}\n' http://localhost:9804/jobs
# 200

# Le back-end joint bien le QueryExecutor depuis son conteneur (et pas depuis la machine)
docker exec backend curl -s -o /dev/null -w '%{http_code}\n' http://query_executor:8091/jobs
# 200
```

Si `curl` n'est pas disponible dans le conteneur `backend` :

```bash
docker exec backend python -c "import urllib.request;print(urllib.request.urlopen('http://query_executor:8091/jobs').status)"
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `network cohort360-network declared as external, but could not be found` | Le back-end n'a jamais été démarré, le réseau n'existe pas | Démarrer le back-end d'abord (`make run-backend`), ou `docker network create cohort360-network` |
| `env file .../.env not found` | Le fichier `.env` n'a pas été créé | `cp .local/env.example .env` puis l'adapter |
| `invalid published port` / port vide dans `docker compose config` | `QUERY_EXECUTOR_LOCAL_PORT` absente du `.env` | Ajouter `QUERY_EXECUTOR_LOCAL_PORT=9804` |
| Conteneur démarré mais `curl localhost:9804` → `connection reset` / `empty reply` | Le serveur écoute sur 8090 (défaut) alors que le compose mappe 8091 | Mettre `SJS_APP_PORT=8091` dans le `.env`, puis redémarrer |
| `Bind for 0.0.0.0:9804 failed: port is already allocated` | Un autre service (ou un QueryExecutor lancé hors Docker) occupe déjà le port | `ss -ltnp 'sport = :9804'` pour l'identifier, l'arrêter, ou changer `QUERY_EXECUTOR_LOCAL_PORT` |
| `make: *** No rule to make target 'run-queryexecutor'` | `make` lancé depuis `Cohort360-QueryExecutor/` au lieu de la racine du workspace | `cd <workspace>` puis relancer |
| Le back-end indique le QueryExecutor injoignable (`Connection refused` sur `127.0.0.1` / `localhost`) | `QUERY_EXECUTOR_URL` du back-end pointe sur `localhost` : dans le conteneur, c'est le conteneur `backend` | `QUERY_EXECUTOR_URL=http://query_executor:8091` |
| `Name or service not known: query_executor` côté back | Le conteneur `query_executor` est arrêté ou pas sur `cohort360-network` | `docker ps`, puis `docker network inspect cohort360-network` |
| Jobs terminés mais statut jamais mis à jour dans Cohort360 | Le callback vers Django échoue : `DJANGO_CALLBACK_URL` en `localhost`, ou `SJS_TOKEN` différent de `QUERY_EXECUTOR_TOKEN` (réponse 401) | Corriger l'URL (`http://backend:8000`) ou le jeton, puis redémarrer |
| Callback du QueryExecutor en erreur 500, `User matching query does not exist` dans les logs `backend` | L'utilisateur `QUERY_EXECUTOR_USERNAME` n'existe pas dans la table `user` | Créer l'utilisateur (section « Utilisateur applicatif dans la base du back-end ») |
| `Connection refused` vers PostgreSQL / Solr / FHIR dans les logs | Hôte en `localhost` dans le `.env` | Utiliser un hôte joignable depuis le conteneur |
| Une modification du code n'est pas prise en compte | Le code est copié dans l'image au build, pas monté en volume | Reconstruire : `make run-queryexecutor-build` ou `docker compose -f docker-compose.dev.yml up --build` |
| Build Maven très long ou en échec réseau | Toutes les dépendances Maven sont téléchargées à chaque build sans cache | Relancer ; vérifier l'accès à Maven Central (proxy éventuel) |

## Fichiers Docker du dépôt

À la racine de `Cohort360-QueryExecutor/`, coller les trois fichiers docker.

- `Dockerfile`
- `docker-compose.dev.yml`
- `.dockerignore`
