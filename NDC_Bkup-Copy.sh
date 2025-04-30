#!/bin/bash

#Define LOG directory
LOGFILE="/mnt/nfs/backup.log"

> "$LOGFILE"

# Print timestamp for when the copy starts
echo "############### This is an Automated message ############" >> "$LOGFILE"
echo "Copy started at $(date) for NDC side" >> "$LOGFILE"


# Define source folders, destination users, hosts, and directories
SOURCE_FOLDERS=(
    "/usr/Systems/EML_1/BackupArea"
    "/usr/Systems/OTNE_2/BackupArea"
    "/usr/Systems/PKT_1/BackupArea"
)
DESTINATION_USERS=(
    "ndceml01"
    "ndcsdh01"
    "ndcpkt01"
)
DESTINATION_DIRS=(
    "/mnt/nfs/EML_app/ndc"
    "/mnt/nfs/OTNE_app/ndc"
    "/mnt/nfs/PKT_app/ndc"
)

# Copy each folder to its respective remote destination directory
for i in "${!SOURCE_FOLDERS[@]}"; {
    SOURCE_FOLDER="${SOURCE_FOLDERS[$i]}"
    DESTINATION_USER="${DESTINATION_USERS[$i]}"
    DESTINATION_DIR="${DESTINATION_DIRS[$i]}"

    scp -rp "$DESTINATION_USER:$SOURCE_FOLDER" "$DESTINATION_DIR"
    if [ $? -eq 0 ]; then
        echo "Folder copied from $DESTINATION_USER:$SOURCE_FOLDER to $DESTINATION_DIR at $(date)" >> "$LOGFILE"
    else
        echo "Failed to copy $SOURCE_FOLDER at $(date)" >> "$LOGFILE"
    fi
}

# Print timestamp when the copy ends
echo "Copy ended at $(date) for NDC side" >> "$LOGFILE"
echo "################$(pwd)##################################" >> "$LOGFILE"
