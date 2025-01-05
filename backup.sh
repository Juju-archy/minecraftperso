#!/bin/bash

# Variables pour le répertoire temporaire et le backup
BACKUP_FOLDER="Backup-$(date +%m%d%y-%H%M)" # Horodatage pour le dossier de sauvegarde
FSBUCKET_LOCAL_DIR="./tmp/" # Répertoire temporaire pour télécharger les fichiers du FS Bucket

# Variables pour Cellar S3 (utilisation du bucket world-daily)
S3_BUCKET="s3://world-daily/$BACKUP_FOLDER"

# Créer un répertoire temporaire pour télécharger les fichiers
mkdir -p "$FSBUCKET_LOCAL_DIR"

# Télécharger les fichiers du FS Bucket via FTP
echo "Downloading files from FS Bucket..."
lftp -u $BUCKET_FTP_USERNAME,$BUCKET_FTP_PASSWORD $BUCKET_HOST << EOF
get /usercache.json -o $FSBUCKET_LOCAL_DIR/usercache.json
mirror --verbose --continue --parallel=2 /world $FSBUCKET_LOCAL_DIR/world
mirror --verbose --continue --parallel=2 /world_nether $FSBUCKET_LOCAL_DIR/world_nether
mirror --verbose --continue --parallel=2 /world_the_end $FSBUCKET_LOCAL_DIR/world_the_end
EOF

if [ $? -ne 0 ]; then
    echo "FTP download failed"
    exit 1
fi

echo "FTP download completed successfully"

# Créer un dossier de sauvegarde local temporaire
BACKUP_PATH="./$BACKUP_FOLDER"
mkdir -p "$BACKUP_PATH"

# Copier les fichiers téléchargés dans le répertoire de sauvegarde
echo "Copying files to $BACKUP_PATH..."
rsync -av --progress "$FSBUCKET_LOCAL_DIR/" "$BACKUP_PATH"

# Uploader les fichiers sur Cellar S3 avec s3cmd
echo "Uploading backup to Cellar S3..."
# Exécution de la commande s3cmd avec les variables d'environnement
s3cmd --access_key="$CELLAR_ADDON_KEY_ID" --secret_key="$CELLAR_ADDON_KEY_SECRET" --host="$CELLAR_ADDON_HOST" --use-https="$use_https" put --recursive "$BACKUP_PATH/" "$S3_BUCKET/"

if [ $? -ne 0 ]; then
    echo "Failed to upload backup to Cellar S3 using s3cmd"
    exit 1
fi

echo "Backup successfully uploaded to Cellar S3"

# Nettoyer les fichiers locaux
echo "Cleaning up local files..."
rm -rf "$FSBUCKET_LOCAL_DIR"
rm -rf "$BACKUP_PATH"

echo "Backup completed successfully at $(date)"
