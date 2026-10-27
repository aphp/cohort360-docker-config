# cohort360-docker-config

Configuration Docker pour lancer l'environnement de développement Cohort360 en local, sans installer Node.js, Python, Java, Maven ou Spark sur la machine.

Le dépôt contient, pour chaque composant, un `Dockerfile`, un `docker-compose.dev.yml`, un script d'entrée et un guide d'installation. Il contient aussi un `Makefile` et un script `cohort360.sh` pour piloter l'ensemble.

## Contenu

| Dossier | Dépôt cible | Guide |
| --- | --- | --- |
| `backend/` | `Cohort360-Back-end` (Django, Postgres, Redis, Celery) | [INSTALL_BACKEND_DOCKER.md](backend/INSTALL_BACKEND_DOCKER.md) |
| `front/` | `Cohort360-FrontEnd` (React + Vite) | [INSTALL_FRONTEND_DOCKER.md](front/INSTALL_FRONTEND_DOCKER.md) |
| `query-executor/` | `Cohort360-QueryExecutor` (Scala + Spark) | [INSTALL_QUERYEXECUTOR_DOCKER.md](query-executor/INSTALL_QUERYEXECUTOR_DOCKER.md) |
| `administration-portail/` | `Cohort360-AdministrationPortal` (React + Vite) | [INSTALL_ADMINISTRATIONPORTAL_DOCKER.md](administration-portail/INSTALL_ADMINISTRATIONPORTAL_DOCKER.md) |
| `documentations/` | `documentation` (MkDocs) | [INSTALL_DOCUMENTATION_DOCKER.md](documentations/INSTALL_DOCUMENTATION_DOCKER.md) |
| `front-e2e/` | `front-e2e` (tests Selenium + Cucumber) | [INSTALL_FRONT_E2E_DOCKER.md](front-e2e/INSTALL_FRONT_E2E_DOCKER.md) |

## Utilisation

1. Cloner les dépôts Cohort360 dans un même dossier `<workspace>/`.  (liste des URLs à demander à l'équipe)
2. Copier les fichiers de chaque dossier ci-dessus à la racine du dépôt correspondant, et copier `Makefile` et `cohort360.sh` à la racine de `<workspace>/` :

   ```
   <workspace>/
   ├── Makefile
   ├── cohort360.sh
   ├── Cohort360-Back-end/
   ├── Cohort360-FrontEnd/
   ├── Cohort360-QueryExecutor/
   ├── Cohort360-AdministrationPortal/
   ├── documentation/
   └── front-e2e/
   ```

3. Créer le fichier `.env` de chaque dépôt (voir le guide du composant).
4. Démarrer le **back-end en premier** : il crée le réseau `cohort360-network` utilisé par les autres composants.

## Commandes principales

```bash
make run        # menu interactif : lancer un composant
make restart    # menu interactif : redémarrer un composant
make down       # menu interactif : arrêter un composant
make down-all   # arrêter tous les composants

make run-<composant>-build   # premier lancement (build + up)
make e2e FEATURES=Connexion  # tests e2e contre le front local
```

`<composant>` vaut `front`, `backend`, `queryexecutor`, `administrationportal` ou `documentation`. La liste complète des cibles est commentée dans le [Makefile](Makefile).

Sans Makefile, chaque guide décrit aussi les commandes `docker compose` équivalentes.

## Prérequis

- Docker Engine + plugin Compose v2 (Docker Desktop sous Windows et macOS)
- Git avec un accès aux dépôts internes
- `make` et `bash`, pour l'option A (Makefile et menus `cohort360.sh`) uniquement :
  - Linux : déjà présents (sinon `sudo apt install make`) ;
  - macOS : `xcode-select --install` ;
  - Windows : voir ci-dessous.

### Sous Windows : travailler dans WSL2

Les guides sont écrits pour un shell Linux (`make`, `bash`, `ss`, `sudo`). Sous Windows, travailler dans **WSL2** (distribution Ubuntu) :

1. Installer WSL2 et Ubuntu (`wsl --install` dans PowerShell en administrateur), puis activer l'intégration WSL dans Docker Desktop (*Settings → Resources → WSL integration*).
2. Dans le terminal Ubuntu : `sudo apt install make git`.
3. Cloner les dépôts **dans le système de fichiers WSL** (par exemple `~/cohort360/`), pas dans `C:\` (`/mnt/c/...`) : les volumes Docker y sont beaucoup plus rapides et le rechargement à chaud y fonctionne.

Toutes les commandes des guides fonctionnent alors telles quelles.

Sans WSL, seule l'option B (commandes `docker compose` de chaque guide, dans PowerShell) est utilisable.

### Vérifier qu'un port est libre

Les guides utilisent `ss` (Linux / WSL). Équivalents, exemple avec le port 8000 (aucune ligne attendue) :

| Système | Commande |
| --- | --- |
| Linux / WSL | `ss -ltnp 'sport = :8000'` |
| macOS | `lsof -iTCP:8000 -sTCP:LISTEN` |
| Windows (PowerShell) | `Get-NetTCPConnection -LocalPort 8000 -State Listen` |
