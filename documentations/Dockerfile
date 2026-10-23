FROM python:3.12-slim

# git : requis par le plugin git-revision-date-localized (dates de modification)
# safe.directory : git accepte le dépôt monté, quel que soit son propriétaire
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/* \
 && git config --system --add safe.directory '*'

WORKDIR /docs

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# PYTHONPATH : nécessaire pour l'extension docs/scripts/cards.py
ENV PYTHONPATH=/docs \
    DISABLE_MKDOCS_2_WARNING=true \
    HOME=/tmp

EXPOSE 8000

CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
