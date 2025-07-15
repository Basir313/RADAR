#!/bin/bash
# Ottengo l'hash dell'ultimo commit
commit_hash=$(git rev-parse --short HEAD)

# Creazione immagine docker
sudo docker build -f Dockerfile -t radar-backend:latest -t radar-backend:$commit_hash .

# Sovrascrivo il container docker in esecuzione con la nuova immagine
sudo docker rm radar-backend 2>/dev/null || true