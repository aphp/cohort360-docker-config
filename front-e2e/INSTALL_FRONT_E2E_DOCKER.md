# Tests E2E Cohort360 (front-e2e) : lancement avec Docker

## Objet

Ce guide lance les tests de non-régression du front (dépôt `front-e2e`, Java 17 + Maven + Cucumber + Selenide) dans des conteneurs Docker. Il n'y a ni Java ni Maven à installer sur la machine.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace : les tests visent le **front local** (conteneur `front`) ;
- **Option B : sans Makefile**, avec les scripts du dépôt : les tests visent l'URL définie dans `run.env` (environnement de dev par défaut).

Résultat attendu dans les deux cas : un Chrome piloté par Selenium exécute les scénarios, visible en direct sur http://localhost:7900, et les rapports sont rangés dans `front-e2e/artifacts/e2e/<horodatage>/`.

Pour le débogage dans l'IDE, l'écriture de tests et l'analyse détaillée des échecs, voir le guide du dépôt : `front-e2e/doc/prise-en-main/README.md`.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès aux dépôts internes (voir [Accès à demander](../README.md#accès-à-demander)) | `git --version` |
| Ports **4444** (Selenium) et **7900** (noVNC) libres | `ss -ltnp 'sport = :4444 or sport = :7900'` (aucune ligne attendue ; Linux / WSL, pour macOS et Windows voir le [README](../README.md#vérifier-quun-port-est-libre)) |
| Option A : back-end et front démarrés (conteneur `front` sur `cohort360-network`) | `docker ps --format '{{.Names}}' \| grep -w front` |
| Un compte Cohort360 actif avec au minimum `DATA_READ_NOMINATIVE` | — |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                 # option A uniquement
├── Cohort360-Back-end/      # option A : à démarrer avant
├── Cohort360-FrontEnd/      # option A : à démarrer avant
├── ...
└── front-e2e/               # ce dépôt
    ├── docker-compose.vnc.yml    # campagne de tests
    ├── docker-compose.init.yml   # initialisation des données
    ├── run.env                   # à créer (non versionné)
    ├── doc/prise-en-main/run.env.example
    ├── scripts/                  # run-e2e.sh, run-init.sh, collect-e2e-artifacts.sh
    └── src/test/resources/       # features Gherkin
```

Cloner le dépôt dans le workspace (dépôt dépôt interne, URL à demander à l'équipe) :

```bash
cd <workspace>
git clone <URL du dépôt, à demander à l'équipe> front-e2e
```

## Principe

- **Deux conteneurs** :
  - `selenium` : image `selenium/standalone-chrome`, le navigateur. Ports 4444 (Selenium Grid) et 7900 (noVNC, sans mot de passe).
  - `tests` : image `maven:3.9-eclipse-temurin-17`, qui lance `mvn test` et pilote Chrome via `http://selenium:4444/wd/hub`.
- **Contenu** : le dépôt est **monté en volume** sur `/workspace` ; les dépendances Maven sont mises en cache dans `front-e2e/.m2/` (le premier lancement est long, les suivants non).
- **Configuration** : identifiants et paramètres viennent de `run.env` (`env_file` du compose).
- **Profils Maven** : `browser_chrome,headless_false,Cohort360-dev`.
- **Option A** : le Makefile branche le conteneur Selenium sur `cohort360-network` et force `COHORT360_URL_TEST=http://<IP du conteneur front>:3000/`, pour que Chrome atteigne le front local sur son port interne.

## Configuration : fichier `run.env`

Le fichier `run.env` est obligatoire et ne doit **jamais** être committé (il est dans `.gitignore`). Partir du modèle :

```bash
cd <workspace>/front-e2e
cp doc/prise-en-main/run.env.example run.env
```

Les valeurs se trouvent dans les variables CI/CD du projet dépôt interne `front-e2e` (**Settings → CI/CD → Variables**).

| Variable | Rôle |
| --- | --- |
| `COHORT360_LOGIN` | Identifiant de connexion |
| `COHORT360_PASSWORD` | Mot de passe, **encodé en base64** |
| `COHORT360_WELCOME` | Texte de bienvenue attendu après connexion |
| `COHORT360_LOGIN_PSEUDO` / `COHORT360_WELCOME_PSEUDO` | Identifiant / bienvenue du parcours pseudonymisé |
| `IMAGING_STUDY_PDF_IPP` | IPP du scénario imagerie/PDF |
| `COHORT360_IPP_FULL` | Lot d'IPP pour l'initialisation |
| `COHORT360_URL_TEST` | URL testée (option B ; ignorée par l'option A) |
| `FIX_LANG` | `false` avec l'image Docker Chrome |
| `AUTH_PORTAL_COOKIE` | Cookie `NSC_TMAS` si accès via Netscaler ; **commenté** sur l'intranet AP-HP |

## Initialiser les données (une fois par environnement)

Les features de `cohort360/` supposent des données préparées (cohortes par défaut, favoris, filtres d'export, onboarding). Lancer l'initialisation avant la première campagne :

```bash
cd <workspace>/front-e2e
sh scripts/run-init.sh
```

Elle exécute les features `src/test/resources/initialisation/001` à `006` via `docker-compose.init.yml`, puis range les résultats dans `artifacts/e2e/init-<horodatage>/`.

## Option A : avec le Makefile (front local)

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `front-e2e/`. Le back-end et le front doivent déjà tourner.

```bash
cd <workspace>
make e2e
```

| Commande | Effet |
| --- | --- |
| `make e2e` | Lance toutes les features contre le front local |
| `make e2e FEATURES=CriteresJson` | Lance une feature (nom du fichier sans `.feature`) |
| `make e2e FEATURES=CriteresJson,Connexion` | Lance plusieurs features |
| `make e2e-down` | Débranche Selenium de `cohort360-network` et l'arrête |

Le conteneur Selenium reste démarré entre deux `make e2e` : les lancements suivants sont plus rapides.

## Option B : sans Makefile (environnement de `run.env`)

Toutes les commandes se lancent **depuis le dossier `front-e2e/`**.

```bash
cd <workspace>/front-e2e

# Campagne complète (Selenium + tests), puis collecte des rapports
sh scripts/run-e2e.sh

# Équivalent sans le script (pas de collecte des rapports)
docker compose -f docker-compose.vnc.yml up --abort-on-container-exit --exit-code-from tests

# Une seule feature
docker compose -f docker-compose.vnc.yml run --rm tests \
  mvn -B -Dmaven.repo.local=/workspace/.m2/repository -DretryCount=0 \
  -P browser_chrome,headless_false,Cohort360-dev \
  -Dselenide.remote=http://selenium:4444/wd/hub \
  "-Dchromeoptions.args=--blink-settings=primaryPointerType=4 --lang=fr" \
  -Dcucumber.features=src/test/resources/cohort360/exploration/patient/Biologie.feature test

# Arrêter et supprimer les conteneurs
docker compose -f docker-compose.vnc.yml down
```

## Suivre et lire les résultats

- **Pendant le run** : http://localhost:7900 (navigateur en direct), http://localhost:4444 (Selenium Grid).
- **Après le run** : `artifacts/e2e/<horodatage>/`, à lire dans cet ordre en cas d'échec :
  1. `summary.txt` : bilan chiffré ;
  2. `front-e2e-tests-1.log` : logs Maven/Cucumber ;
  3. `target/cucumber-reports.html` : rapport lisible ;
  4. `build/reports/tests/*.png` : captures au moment de l'échec ;
  5. `target/failedrerun.txt` : scénarios en échec.

Les captures peuvent contenir des données patients : ne pas les diffuser hors périmètre autorisé.

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep selenium
# front-e2e-selenium-1  Up ... (healthy)  0.0.0.0:4444->4444/tcp, 0.0.0.0:7900->7900/tcp

curl -s http://localhost:4444/status | grep -o '"ready": *true'
# "ready": true

# Option A : Selenium est bien sur le réseau du front et l'atteint
docker network inspect cohort360-network --format '{{range .Containers}}{{.Name}} {{end}}'
# ... front ... front-e2e-selenium-1 ...

ls -1t artifacts/e2e/ | head -1
# dossier du dernier run
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `env file .../run.env not found` | `run.env` n'a pas été créé | `cp doc/prise-en-main/run.env.example run.env` puis le remplir |
| `make: *** No rule to make target 'e2e'` | `make` lancé depuis `front-e2e/` | `cd <workspace>` puis relancer |
| Option A : `Error: No such object: front`, erreur `nil pointer` ou URL `http://:3000/` | Le conteneur `front` n'est pas démarré ou pas sur `cohort360-network` | Démarrer le front (`make run-front`), puis relancer |
| `Bind for 0.0.0.0:4444 failed: port is already allocated` | Un autre Selenium tourne déjà | `docker ps \| grep selenium`, l'arrêter (`make e2e-down`) |
| La page s'ouvre mais rien n'est saisi, connexion en échec | `run.env` incomplet (login/mot de passe vides) | Renseigner les variables depuis la CI |
| Échec de connexion avec mot de passe correct | Mot de passe non encodé en base64 | `echo -n '<mot de passe>' \| base64` et reporter la valeur |
| Boucle de redirection à la connexion | Cookie `NSC_TMAS` vide sur l'intranet, ou expiré hors intranet | Intranet : commenter `AUTH_PORTAL_COOKIE` ; à distance : récupérer un cookie à jour |
| Features `cohort360/` en échec faute de données (cohorte, favori, filtre) | Initialisation non faite sur cet environnement | `sh scripts/run-init.sh` |
| Premier lancement très long | Téléchargement des dépendances Maven dans `.m2/` | Normal, les lancements suivants réutilisent le cache |
| Erreur de tests liée au clavier / caractères | `FIX_LANG` à `true` | Mettre `FIX_LANG=false` avec l'image Docker Chrome |

Dans le conteneur `tests`, `localhost` désigne ce conteneur : c'est pourquoi Selenium est joint par `http://selenium:4444` et le front local par son IP sur `cohort360-network`, jamais par `localhost`.
