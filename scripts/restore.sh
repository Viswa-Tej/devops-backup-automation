#!/usr/bin/env bash
# =============================================================
# restore.sh — Restore from a backup archive
# Usage: ./scripts/restore.sh [backup_file] [restore_dir]
# Example: ./scripts/restore.sh ./backups/backup_20240416_120000.tar.gz ./restored
# =============================================================

set -euo pipefail

BACKUP_FILE="${1:-}"
RESTORE_DIR="${2:-./restored}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }

# Validate arguments
if [[ -z "$BACKUP_FILE" ]]; then
  echo -e "${RED}Usage: $0  [restore_dir]${NC}"
  echo "Available backups:"
  ls -lh ./backups/*.tar.gz 2>/dev/null || echo "  No backups found"
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  log "ERROR" "Backup file not found: $BACKUP_FILE"
  exit 1
fi

log "INFO" "Restoring from: $BACKUP_FILE"
log "INFO" "Restore destination: $RESTORE_DIR"

# Create restore directory
mkdir -p "$RESTORE_DIR"

# Extract the archive
# tar flags:
# -x = extract
# -z = decompress gzip
# -f = filename follows
# -v = verbose (show each file being extracted)
# -C = change to this directory before extracting
if tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"; then
  log "INFO" "Restore completed successfully"
  log "INFO" "Files restored to: $RESTORE_DIR"
  echo -e "${GREEN}Contents:${NC}"
  ls -lh "$RESTORE_DIR"
else
  log "ERROR" "Restore FAILED"
  exit 1
fi