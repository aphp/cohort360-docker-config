# Documentation Cohort360 : lancement avec Docker

## Objet

Ce guide lance le site de documentation fonctionnelle de Cohort360 (dépôt `documentation`, MkDocs Material) dans un conteneur Docker. Il n'y a ni Python ni venv à installer sur la machine.

Deux façons de faire, au choix :

- **Option A : avec le Makefile** du workspace (commandes courtes, menus interactifs) ;
- **Option B : sans Makefile**, directement avec `docker compose`.

Résultat attendu dans les deux cas : le site tourne sur http://127.0.0.1:8001/design-et-produit/ipa/documentation/ et se recharge automatiquement à chaque modification d'un fichier Markdown.

## Prérequis

| Outil | Vérifier |
| --- | --- |
| Docker Engine + plugin Compose v2 | `docker compose version` |
| Git et un accès aux dépôts internes | `git --version` |
| Port **8001** libre sur la machine | `ss -ltnp 'sport = :8001'` (aucune ligne attendue) |

## Organisation du workspace

Les commandes de ce guide supposent l'arborescence suivante, où `<workspace>` est le dossier dans lequel les dépôts Cohort360 sont clonés :

```
<workspace>/
├── Makefile                 # option A uniquement
├── cohort360.sh             # option A uniquement (menus interactifs)
├── Cohort360-FrontEnd/
├── Cohort360-Back-end/
├── ...
└── documentation/           # ce dépôt
    ├── Dockerfile
    ├── docker-compose.dev.yml
    ├── .dockerignore
    ├── mkdocs.yml
    └── requirements.txt
```

Cloner le dépôt dans le workspace (URL à demander à l'équipe) :

```bash
cd <workspace>
git clone <URL SSH du dépôt> documentation
```

## Principe

- **Image** : `python:3.12-slim` (même version que la CI) + `git` + les dépendances de `requirements.txt`.
- **Contenu** : le dépôt n'est pas copié dans l'image, il est **monté en volume** sur `/docs`. Le rechargement automatique fonctionne donc, et le plugin `git-revision-date-localized` a accès à `.git`.
- **Ports** : le port 8001 de la machine pointe sur le port 8000 du conteneur. Le port 8000 de la machine reste libre pour Django (conteneur `backend`) : chaque conteneur a son propre réseau, donc le 8000 interne de la doc n'entre pas en conflit avec lui.

## Option A : avec le Makefile

Toutes les commandes se lancent **depuis la racine du workspace**, là où se trouve le `Makefile`, et non depuis `documentation/`.

Premier lancement (construction de l'image puis démarrage) :

```bash
cd <workspace>
make run-documentation-build
```

Commandes disponibles :

| Commande | Effet |
| --- | --- |
| `make run` | Menu interactif : choisir **Documentation** → démarre en arrière-plan |
| `make restart` | Menu interactif : redémarre et attend que le conteneur soit `running` |
| `make down` | Menu interactif : arrête la documentation |
| `make down-all` | Arrête tous les composants, documentation comprise |
| `make run-documentation-build` | Construit l'image puis lance le serveur (premier plan, logs affichés) |
| `make run-documentation` | Lance le serveur (premier plan) |
| `make restart-documentation` | Redémarre le serveur |
| `make down-documentation` | Arrête et supprime le conteneur |
| `make build-documentation` | Reconstruit l'image sans cache (après un changement de `requirements.txt`) |
| `make build-site-documentation` | Génère le site comme la CI, dans `documentation/public/` |

## Option B : sans Makefile

Toutes les commandes se lancent **depuis le dossier `documentation/`**.

```bash
cd <workspace>/documentation

# Premier lancement : construit l'image puis démarre le serveur (premier plan)
docker compose -f docker-compose.dev.yml up --build

# Lancements suivants
docker compose -f docker-compose.dev.yml up

# Démarrer en arrière-plan
docker compose -f docker-compose.dev.yml up -d

# Redémarrer
docker compose -f docker-compose.dev.yml restart

# Reconstruire l'image sans cache (après un changement de requirements.txt)
docker compose -f docker-compose.dev.yml build --no-cache

# Générer le site comme la CI (résultat dans public/)
docker compose -f docker-compose.dev.yml run --rm docs mkdocs build

# Arrêter et supprimer le conteneur
docker compose -f docker-compose.dev.yml down
```

## Accéder au site

Ouvrir http://127.0.0.1:8001/design-et-produit/ipa/documentation/.

La racine http://127.0.0.1:8001/ répond 404 : c'est normal, MkDocs reprend le chemin de `site_url` défini dans `mkdocs.yml`.

Après une modification, un rechargement forcé du navigateur (`Ctrl+Shift+R`) évite le cache de `navigation.instant`.

## Vérification

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep cohort360-docs
# cohort360-docs  0.0.0.0:8001->8000/tcp

docker logs cohort360-docs | grep Serving
# Serving on http://0.0.0.0:8000/design-et-produit/ipa/documentation/

curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8001/design-et-produit/ipa/documentation/
# 200
```

## Problèmes fréquents

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `make: *** No rule to make target 'run-documentation'` | `make` lancé depuis `documentation/` au lieu de la racine du workspace | `cd <workspace>` puis relancer |
| `Bind for 0.0.0.0:8001 failed: port is already allocated` ou `address already in use` | Un `mkdocs serve` lancé hors Docker (ou un autre service) occupe déjà le 8001 | `ss -ltnp 'sport = :8001'` pour l'identifier, l'arrêter, puis relancer |
| Les images n'apparaissent pas dans les pages | `selectolax` 1.x casse `mkdocs-glightbox` 0.5.x : les `<img>` sont supprimées du HTML | Vérifier que `requirements.txt` contient `selectolax<1`, puis reconstruire l'image sans cache |
| `dubious ownership in repository` ou dates de modification absentes | Image construite avant l'ajout de `safe.directory` dans le Dockerfile | Reconstruire l'image sans cache |
| `public/` appartient à root et ne peut pas être supprimé | Le conteneur tourne en root ; `mkdocs build` crée donc `public/` en root | `sudo rm -rf public` (sans conséquence, le dossier est régénéré) |
| Le site ne se recharge pas après une modification | Sous Docker Desktop (Mac/Windows), les événements de fichiers du volume arrivent mal | Ajouter `--livereload` à la commande `mkdocs serve`, ou redémarrer le conteneur |
| Une dépendance ajoutée à `requirements.txt` est introuvable | L'image a été construite avant la modification | Reconstruire l'image sans cache, puis relancer |
| Encadré « MkDocs 2.0 / ProperDocs » dans les logs | Avertissement d'un plugin, sans effet | Déjà masqué par `DISABLE_MKDOCS_2_WARNING=true` dans le Dockerfile |

Les lignes `INFO` du build (pages absentes du menu, liens absolus `/design-et-produit/...`, liens `tbc`) sont normales.

## Fichiers Docker du dépôt

À la racine de `documentation/`, coller les trois fichiers docker.

- `Dockerfile`
- `docker-compose.dev.yml`
- `.dockerignore`

Dans le conteneur, MkDocs doit écouter sur `0.0.0.0` et non sur `127.0.0.1` : sinon il n'est pas joignable depuis la machine malgré le mapping de port.
