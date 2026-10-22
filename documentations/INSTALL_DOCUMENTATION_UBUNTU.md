# Documentation Cohort360 : installation locale sur Ubuntu

## Objet

Ce guide permet de lancer en local, sur Ubuntu, le site de documentation fonctionnelle de Cohort360 en une dizaine de minutes. Il s'adresse à toute personne qui rédige ou relit cette documentation.

Le dépôt `documentation` est un site **MkDocs Material**. Les pages Markdown sont dans `docs/`, le menu latéral est défini par les fichiers `SUMMARY.md`, et la CI publie le site à chaque merge sur `main`.

Résultat attendu : le site tourne sur http://127.0.0.1:8001/design-et-produit/ipa/documentation/ et se recharge automatiquement à chaque modification d'un fichier.

## Prérequis

Il faut Git, un accès aux dépôts internes et **uv** pour installer Python 3.12, la version utilisée par la CI.

| Outil | Pourquoi | Vérifier |
| --- | --- | --- |
| Git | Cloner le dépôt ; le plugin `git-revision-date-localized` lit aussi l'historique Git | `git --version` |
| un accès aux dépôts internes | Le dépôt est cloné en SSH | `— |
| uv | Installe Python 3.12 et les dépendances sans toucher au Python du système | `uv --version` |
| Accès internet | Téléchargement des paquets et du script `tablesort` (CDN unpkg) | — |

Installer ce qui manque :

```bash
sudo apt update
sudo apt install -y git curl
curl -LsSf https://astral.sh/uv/install.sh | sh
```

En télétravail, le cookie NSC_TMAS doit être à jour pour joindre dépôt interne (voir la page wiki « christmas-token » du projet gestion-de-projet).

## Installation

Trois étapes : cloner, créer un environnement virtuel Python 3.12, installer les dépendances.

1. Cloner le dépôt (URL à demander à l'équipe) :

    ```bash
    git clone <URL SSH du dépôt> documentation
    cd documentation
    ```

2. Créer l'environnement virtuel dans `venv/` (nom attendu par les scripts de `bin/`, déjà ignoré par Git) :

    ```bash
    uv venv venv --python 3.12
    ```

3. Installer les dépendances de `requirements.txt` :

    ```bash
    uv pip install --python venv -r requirements.txt
    ```

Vérification : `venv/bin/mkdocs --version` affiche une version 1.x.

> **Attention au Python 3.14 d'Ubuntu.** `python3 -m venv venv` échoue à moitié si le paquet `python3-venv` n'est pas installé : le dossier `venv/` est créé, mais sans pip. Le script `bin/runMkdocsLocally.sh` le croit alors prêt et ne réinstalle rien. Dans ce cas, lancer `sudo apt install python3-venv`, puis supprimer `venv/` avant de recommencer.

## Lancer le site en local

Le serveur se lance depuis la racine du dépôt, sur le port **8001** : le port 8000 par défaut est déjà pris par le conteneur `backend` de Cohort360 quand la stack Docker tourne.

```bash
cd documentation
DISABLE_MKDOCS_2_WARNING=true PYTHONPATH=. venv/bin/mkdocs serve -a 127.0.0.1:8001
```

Ouvrir ensuite http://127.0.0.1:8001/design-et-produit/ipa/documentation/. La racine http://127.0.0.1:8001/ répond 404 : c'est normal, MkDocs reprend le chemin de `site_url` défini dans `mkdocs.yml`.

- `PYTHONPATH=.` est obligatoire : sans lui, l'extension maison `docs/scripts/cards.py` (les cases de la page d'accueil) est introuvable et le build échoue.
- `DISABLE_MKDOCS_2_WARNING=true` masque seulement un long avertissement sur MkDocs 2.0 ; il ne change rien au site.
- Le site se recharge tout seul à chaque modification dans `docs/` ou `docs_includes/`. Arrêter le serveur avec `Ctrl+C`.

## Vérifier avant une MR

Si `mkdocs build` passe en local, la CI passera : elle exécute la même commande, avec Python 3.12.3, et seulement sur `main`.

```bash
PYTHONPATH=. venv/bin/mkdocs build
```

Le site est généré dans `public/`, ignoré par Git. Pour un contrôle plus sévère, `--strict` transforme chaque avertissement en erreur. C'est plus exigeant que la CI, mais utile pour repérer un lien cassé ou une image mal référencée.

- [ ] La nouvelle page est déclarée dans le `SUMMARY.md` de sa section, sinon elle n'apparaît pas dans le menu.
- [ ] Les images sont dans `docs/assets/<section>/` et appelées par un chemin relatif.
- [ ] La page s'affiche correctement sur http://127.0.0.1:8001/design-et-produit/ipa/documentation/.

## Problèmes fréquents

| Message | Cause | Correctif |
| --- | --- | --- |
| `mkdocs: command not found` alors que `venv/` existe | Le venv a été créé sans pip (paquet `python3-venv` absent). Le script `bin/runMkdocsLocally.sh` ne réinstalle pas si le dossier existe déjà. | `rm -rf venv`, puis refaire l'installation avec uv |
| `ModuleNotFoundError: No module named 'ensurepip'` | Le Python d'Ubuntu n'embarque pas venv par défaut | `sudo apt install python3-venv`, ou utiliser uv |
| `error: No virtual environment found` (uv) | uv ne détecte tout seul que `.venv` ; ici le dossier s'appelle `venv` | Ajouter `--python venv` à la commande, ou faire `source venv/bin/activate` dans le même terminal |
| `OSError: [Errno 98] Address already in use` | Le port 8000 est occupé, en général par le conteneur `backend` | Lancer avec `-a 127.0.0.1:8001`. Voir qui occupe le port : `ss -ltnp 'sport = :8000'` |
| Encadré « MkDocs 2.0 / ProperDocs » au démarrage | Avertissement affiché par un plugin, sans effet sur le site | `DISABLE_MKDOCS_2_WARNING=true` |

Les nombreuses lignes `INFO` du build (pages absentes du menu, liens absolus `/design-et-produit/...`, liens `tbc`) sont normales et ne bloquent rien. Seules les lignes `WARNING` ou `ERROR` méritent qu'on s'y arrête.

## Aide-mémoire

Première installation :

```bash
sudo apt install -y git curl
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone <URL SSH du dépôt> documentation
cd documentation
uv venv venv --python 3.12
uv pip install --python venv -r requirements.txt
```

Au quotidien :

```bash
cd documentation
git switch main && git pull --ff-only
git switch -c <numeroticket>-<sujet>
DISABLE_MKDOCS_2_WARNING=true PYTHONPATH=. venv/bin/mkdocs serve -a 127.0.0.1:8001
```

Avant de pousser :

```bash
PYTHONPATH=. venv/bin/mkdocs build
```
