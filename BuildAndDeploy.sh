#!/bin/bash
# Ottengo l'hash dell'ultimo commit
commit_hash=$(git rev-parse --short HEAD)
folder_name=$(basename "$PWD")
# Rimovo eventuali spazi bianchi
folder_name=$(echo "$folder_name" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

# Creazione immagine docker
sudo docker build -f Dockerfile -t $folder_name:latest -t $folder_name:$commit_hash .

# Sovrascrivo il container docker in esecuzione con la nuova immagine
sudo docker rm $folder_name 2>/dev/null || true