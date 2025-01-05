#!/bin/bash

# Variables pour le dépôt Git et le répertoire cible
REPO_URL="https://$username:$password@git.merizel.net/archy/clevercraft-backup.git"
TARGET_DIR="/"
BACKUP_FOLDER="Backup-$(date +%m%d%y-%H%M)" # Horodatage pour le dossier de sauvegarde
LOCAL_FSB_DIR="/" # Répertoire temporaire pour télécharger les fichiers du FS Bucket

# Étape 1 : Créer un répertoire temporaire pour télécharger les fichiers
mkdir -p "$LOCAL_FSB_DIR"

# Étape 2 : Télécharger les fichiers du FS Bucket via FTP
echo "Downloading files from FS Bucket..."
lftp -e "
open -u $BUCKET_FTP_USERNAME,$BUCKET_FTP_PASSWORD $BUCKET_HOST
mirror --verbose / $LOCAL_FSB_DIR
bye
" || { echo "FTP download failed"; exit 1; }

# Étape 3 : Cloner ou mettre à jour le dépôt Git
if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "Cloning repository..."
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo "Updating repository..."
    cd "$TARGET_DIR" || exit
    git pull origin main
fi

# Étape 4 : Créer un dossier de sauvegarde dans le dépôt Git
BACKUP_PATH="$TARGET_DIR/$BACKUP_FOLDER"
mkdir -p "$BACKUP_PATH"

# Étape 5 : Copier les fichiers téléchargés dans le répertoire de sauvegarde
echo "Copying files to $BACKUP_PATH..."
rsync -av --progress "$LOCAL_FSB_DIR/" "$BACKUP_PATH"

# Étape 6 : Ajouter les fichiers au dépôt Git
cd "$TARGET_DIR" || exit
git add "$BACKUP_FOLDER"
git commit -m "Backup created on $(date)"
git push origin main

# Étape 7 : Nettoyer les fichiers locaux du FS Bucket
echo "Cleaning up local FS Bucket files..."
rm -rf "$LOCAL_FSB_DIR"

echo "Backup completed successfully at $(date)"
