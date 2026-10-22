# =============================================================================
# Makefile Cohort360 : raccourcis Docker Compose pour les 4 composants
#                      et la documentation (MkDocs)
#
#   make run       -> menu interactif pour lancer un composant
#   make restart   -> menu interactif pour redémarrer un composant
#   make down      -> menu interactif pour arrêter un composant
#   make down-all  -> arrête tous les composants
#   make <cible>   -> cibles détaillées ci-dessous (build, run, down...)
# =============================================================================

# Dossiers des 4 dépôts du workspace
FRONTEND_FOLDER = Cohort360-FrontEnd
BACKEND_FOLDER = Cohort360-Back-end
QUERYEXECUTOR_FOLDER = Cohort360-QueryExecutor
ADMINISTRATION_PORTAL_FOLDER = Cohort360-AdministrationPortal
DOCUMENTATION_FOLDER = documentation

# Commande docker compose et fichier compose utilisé dans chaque dépôt
DOCKER_COMPOSE = docker compose
DOCKER_FILE = docker-compose.dev.yml

# Sous-commandes docker compose :
#   BUILD    -> rebuild complet des images, sans cache
#   UP_BUILD -> rebuild puis démarre (au premier plan)
#   UP       -> démarre (au premier plan, logs affichés)
#   RESTART  -> redémarre les conteneurs existants
#   DOWN     -> arrête et supprime les conteneurs
BUILD = build --no-cache
UP_BUILD = up --build
UP = up
RESTART = restart
DOWN = down

# --- MENUS INTERACTIFS -------------------------------------------------------
# Les menus sont dans cohort360.sh (flèches ↑/↓ + Entrée)
.PHONY: run restart down down-all

# Affiche la liste des composants, "(démarré)" à côté de ceux qui tournent,
# et lance en arrière-plan (up -d) celui qui est choisi
run:
	@./cohort360.sh run

# Affiche la liste des composants, redémarre celui qui est choisi,
# attend qu'il soit prêt (running / healthy) puis affiche un message de succès
restart:
	@./cohort360.sh restart

# Affiche la liste des composants et arrête (docker compose down)
# celui qui est choisi
down:
	@./cohort360.sh down

# Arrête (docker compose down) tous les composants : Front, Back-end,
# QueryExecutor, AdministrationPortal et Documentation
down-all:
	@./cohort360.sh down-all

# --- DOCKER ------------------------------------------------------------------
# ATTENTION : supprime TOUS les conteneurs arrêtés, images, réseaux et cache
# de build non utilisés (tous projets confondus, pas seulement Cohort360)
remove-all: 
	docker system prune -a -f

# --- FRONT -------------------------------------------------------------------
# Rebuild l'image du front sans cache
build-front:
	cd $(FRONTEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(BUILD)

# Rebuild puis démarre le front (premier plan)
run-front-build:
	cd $(FRONTEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP_BUILD)

# Démarre le front (premier plan)
run-front:
	cd $(FRONTEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP)

# Redémarre le conteneur du front
restart-front:
	cd $(FRONTEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(RESTART)

# Arrête et supprime le conteneur du front
down-front:
	cd $(FRONTEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(DOWN)

# Lance les tests unitaires (vitest) une fois dans le conteneur "front"
unit-test-front:
	docker exec -it front npm test -- --run

# --- BACKEND -----------------------------------------------------------------
# Rebuild les images du backend sans cache
build-backend:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(BUILD)

# Rebuild puis démarre le backend (postgres, redis, backend...) au premier plan
run-backend-build:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP_BUILD)

# Démarre le backend (premier plan)
run-backend:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP)

# Redémarre les conteneurs du backend
restart-backend:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(RESTART)

# Arrête et supprime les conteneurs du backend
down-backend:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(DOWN)

# Génère les migrations Django dans le conteneur "backend"
migrations:
	docker exec backend python manage.py makemigrations

# Applique les migrations Django
migrate:
	docker exec backend python manage.py migrate

# Lance les tests Django du backend
unit_tests:
	docker exec -it backend python manage.py test

# Formate le code Python avec ruff (depuis le dossier courant)
format-backend:
	uv tool run ruff@0.15.22 format .

# --- CELERY ------------------------------------------------------------------
# Redémarre uniquement le service celery du backend
restart-celery:
	cd $(BACKEND_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(RESTART) celery

# --- QUERYEXECUTOR -----------------------------------------------------------
# Rebuild l'image du QueryExecutor sans cache
build-queryexecutor:
	cd $(QUERYEXECUTOR_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(BUILD)

# Rebuild puis démarre le QueryExecutor (premier plan)
run-queryexecutor-build:
	cd $(QUERYEXECUTOR_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP_BUILD)

# Démarre le QueryExecutor (premier plan)
run-queryexecutor:
	cd $(QUERYEXECUTOR_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP)

# Redémarre le QueryExecutor
restart-queryexecutor:
	cd $(QUERYEXECUTOR_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(RESTART)

# Arrête et supprime le QueryExecutor
down-queryexecutor:
	cd $(QUERYEXECUTOR_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(DOWN)

# --- ADMINISTRATION PORTAL ---------------------------------------------------
# Rebuild l'image du portail d'administration sans cache
build-administrationportal:
	cd $(ADMINISTRATION_PORTAL_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(BUILD)

# Rebuild puis démarre le portail d'administration (premier plan)
run-administrationportal-build:
	cd $(ADMINISTRATION_PORTAL_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP_BUILD)

# Démarre le portail d'administration (premier plan)
run-administrationportal:
	cd $(ADMINISTRATION_PORTAL_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(UP)

# Redémarre le portail d'administration
restart-administrationportal:
	cd $(ADMINISTRATION_PORTAL_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(RESTART)

# Arrête et supprime le portail d'administration
down-administrationportal:
	cd $(ADMINISTRATION_PORTAL_FOLDER) && $(DOCKER_COMPOSE) -f $(DOCKER_FILE) $(DOWN)

# --- DOCUMENTATION (MkDocs) --------------------------------------------------
# Site sur http://127.0.0.1:8001/design-et-produit/ipa/documentation/
# Le conteneur tourne avec l'UID/GID de l'hôte (fichiers générés non-root)
DOCS_COMPOSE = DOCS_UID=$$(id -u) DOCS_GID=$$(id -g) $(DOCKER_COMPOSE) -f $(DOCKER_FILE)

# Rebuild l'image de la documentation sans cache (après un changement de requirements.txt)
build-documentation:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) $(BUILD)

# Rebuild puis démarre le serveur MkDocs (premier plan, rechargement auto)
run-documentation-build:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) $(UP_BUILD)

# Démarre le serveur MkDocs (premier plan, rechargement auto)
run-documentation:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) $(UP)

# Redémarre le serveur MkDocs
restart-documentation:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) $(RESTART)

# Arrête et supprime le conteneur de la documentation
down-documentation:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) $(DOWN)

# Génère le site comme la CI (mkdocs build -> documentation/public/)
build-site-documentation:
	cd $(DOCUMENTATION_FOLDER) && $(DOCS_COMPOSE) run --rm docs mkdocs build

# --- TESTS E2E (front-e2e) ---------------------------------------------------
# Lance les tests e2e contre le front local (Selenium + Maven dans Docker)
#   make e2e                                  -> tous les tests
#   make e2e FEATURES=CriteresJson            -> une feature (nom du fichier sans .feature)
#   make e2e FEATURES=CriteresJson,Connexion  -> plusieurs features
#   make e2e-down                             -> arrête Selenium
# Navigateur visible pendant le run : http://localhost:7900
# Rapports : front-e2e/artifacts/e2e/
E2E_FOLDER = front-e2e
E2E_COMPOSE = $(DOCKER_COMPOSE) -f docker-compose.vnc.yml

.PHONY: e2e e2e-down
e2e:
	@cd $(E2E_FOLDER) && $(E2E_COMPOSE) up -d selenium
	@docker network connect cohort360-network front-e2e-selenium-1 2>/dev/null || true
	@FRONT_IP=$$(docker inspect -f '{{(index .NetworkSettings.Networks "cohort360-network").IPAddress}}' front); \
	PATHS=""; \
	for f in $$(echo "$(FEATURES)" | tr ',' ' '); do \
		p=$$(cd $(E2E_FOLDER) && find src/test/resources -name "$$f.feature" | head -1); \
		[ -n "$$p" ] || { echo "Feature introuvable : $$f"; exit 1; }; \
		PATHS="$${PATHS:+$$PATHS,}$$p"; \
	done; \
	cd $(E2E_FOLDER) && $(E2E_COMPOSE) run --rm -e COHORT360_URL_TEST=http://$$FRONT_IP:3000/ tests \
		mvn -B -Dmaven.repo.local=/workspace/.m2/repository -DretryCount=0 \
		-P browser_chrome,headless_false,Cohort360-dev -Dselenide.remote=http://selenium:4444/wd/hub \
		"-Dchromeoptions.args=--blink-settings=primaryPointerType=4 --lang=fr" \
		$${PATHS:+-Dcucumber.features=$$PATHS} test; \
	EXIT=$$?; \
	sh scripts/collect-e2e-artifacts.sh e2e-$$(date +%Y%m%d-%H%M%S); \
	exit $$EXIT

# Arrête Selenium (tests e2e) et le débranche du réseau du front
e2e-down:
	@docker network disconnect cohort360-network front-e2e-selenium-1 2>/dev/null || true
	cd $(E2E_FOLDER) && $(E2E_COMPOSE) down
