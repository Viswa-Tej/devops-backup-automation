#!/usr/bin/env bash
#============================================================
#backup.sh -Automated backup with rotation and slack alerts
#Author:Viswa Teja Payam
#Usage :  ./scripts/backup.sh [source_dir] [backup_dir] [keep_days]
#============================================================

set -euo pipefail
#set -e = exit immediately if any command fails
#set -u = treat unset variables as errors
#set -o pipefail = if any pipe command fails, the whole pipe fails
#together : the script stops at first sign of trouble -- safe behaviour

#--------------------CONFIGURATION-----------------------------
SOURCE_DIR="${1:-../sample-data}" # what to back -up (default:sample-data)
BACKUP_DIR="${2:-../backups}" #what to store archives
KEEP_DAYS="${3:-7}" #how many days of backup to keep
LOG_FILE="../logs/backup.log" #log file path
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}" #optional: set via environment variable

#-----------------COLOURS FOR TERMINAL OUTPUT-------------------
RED='\033[0,31m'
GREEN='\033[0,32m'
YELLOW='\033[1,33m'
BLUE='\033[0,34m'
NC='\033[0m' #No colour reset

#------------------HELPER FUNCTIONS-------------------------------
# ── Helper functions ───────────────────────────────────────────
log() {
  # Writes a timestamped message to both terminal AND log file
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_line="[$timestamp] [$level] $message"

  # Print to terminal with colour
  case "$level" in
    INFO)  echo -e "${GREEN}${log_line}${NC}" ;;
    WARN)  echo -e "${YELLOW}${log_line}${NC}" ;;
    ERROR) echo -e "${RED}${log_line}${NC}" ;;
    *)     echo "$log_line" ;;
  esac

  # Also write plain text (no colour codes) to log file
  echo "$log_line" >> "$LOG_FILE"
}
send_slack() {
  # Sends a message to Slack via webhook — skips if no webhook configured
  local message="$1"
  if [[ -z "$SLACK_WEBHOOK" ]]; then
    log "INFO" "Slack webhook not configured — skipping notification"
    return 0
  fi
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H 'Content-type: application/json' \
    -d "{\"text\": \"$message\"}" \
    && log "INFO" "Slack notification sent" \
    || log "WARN" "Slack notification failed"
}
check_dependencies() {
  # Verify required tools are installed before we start
  log "INFO" "Checking dependencies..."
  for cmd in tar gzip date du find; do
    if ! command -v "$cmd" &>/dev/null; then
      log "ERROR" "Required command not found: $cmd"
      exit 1
    fi
  done
  log "INFO" "All dependencies found"
}
create_backup() {
  # Creates a timestamped compressed archive of the source directory
  local timestamp
  timestamp=$(date '+%Y%m%d_%H%M%S')
  local backup_name="backup_${timestamp}.tar.gz"
  local backup_path="${BACKUP_DIR}/${backup_name}"

  log "INFO" "Starting backup of: $SOURCE_DIR"
  log "INFO" "Archive name: $backup_name"

  # Create the backup directory if it doesn't exist
  mkdir -p "$BACKUP_DIR"
    # tar flags explained:
  # -c = create a new archive
  # -z = compress with gzip (.gz)
  # -f = the archive filename follows
  # -v = verbose (lists each file as it's added — remove for quiet mode)
  # --exclude = skip these patterns (no need to back up existing backups or logs)
  if tar -czf "$backup_path" \
      --exclude="./backups" \
      --exclude="./logs" \
      --exclude=".git" \
      "$SOURCE_DIR"; then

    local size
    size=$(du -sh "$backup_path" | cut -f1)  # human-readable size (e.g. "4.2K")
    log "INFO" "Backup created successfully: $backup_name (size: $size)"
    echo "$backup_path"  # return the path for use by caller
    return 0
  else
    log "ERROR" "Backup creation FAILED for $SOURCE_DIR"
    return 1
  fi
}
rotate_backups() {
  # Delete backups older than KEEP_DAYS — keeps disk usage bounded
  log "INFO" "Rotating backups older than ${KEEP_DAYS} days..."

  local deleted_count=0
  # find: look in BACKUP_DIR for files matching *.tar.gz older than KEEP_DAYS days
  # -mtime +N means "modified more than N days ago"
  while IFS= read -r old_backup; do
    log "INFO" "Deleting old backup: $(basename "$old_backup")"
    rm -f "$old_backup"
    ((deleted_count++))
  done < <(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$KEEP_DAYS" 2>/dev/null)

  if [[ $deleted_count -eq 0 ]]; then
    log "INFO" "No old backups to rotate"
  else
    log "INFO" "Rotated $deleted_count old backup(s)"
  fi
}
show_summary() {
  # Print a summary of all current backups
  log "INFO" "Current backups in ${BACKUP_DIR}:"
  local count=0
  while IFS= read -r backup; do
    local size
    size=$(du -sh "$backup" | cut -f1)
    log "INFO" "  $(basename "$backup") — $size"
    ((count++))
  done < <(find "$BACKUP_DIR" -name "*.tar.gz" | sort)

  local total_size
  total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
  log "INFO" "Total: $count backup(s), $total_size disk usage"
}
# ── Main execution ─────────────────────────────────────────────
main() {
  log "INFO" "========================================="
  log "INFO" "Backup job started"
  log "INFO" "Source: $SOURCE_DIR | Keep: ${KEEP_DAYS} days"
  log "INFO" "========================================="

  # Step 1: check all tools are present
  check_dependencies

  # Step 2: validate source directory exists
  if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ERROR" "Source directory does not exist: $SOURCE_DIR"
    send_slack ":x: *Backup FAILED* — source directory not found: $SOURCE_DIR"
    exit 1
  fi
    # Step 3: create the backup
  if backup_path=$(create_backup); then
    log "INFO" "Backup phase: SUCCESS"
    send_slack ":white_check_mark: *Backup succeeded* — $(basename "$backup_path")"
  else
    log "ERROR" "Backup phase: FAILED"
    send_slack ":x: *Backup FAILED* — check logs for details"
    exit 1
  fi

  # Step 4: rotate old backups
  rotate_backups

  # Step 5: show current state
  show_summary

  log "INFO" "Backup job completed successfully"
  log "INFO" "========================================="
}
# Run main — passing all script arguments through
main "$@"