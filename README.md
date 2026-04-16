# devops-backup-automation

Automated backup system with timestamped archives, configurable retention,
rotation of old backups, and Slack alerting on success or failure.

## What it does

- Creates timestamped .tar.gz archives of any directory
- Compresses with gzip — reduces file size by ~60-80%
- Auto-rotates archives older than N days (default: 7)
- Sends Slack notifications on success and failure
- Logs every operation with timestamps to a persistent log file
- Restore script for verified recovery testing

## Project structure

```
devops-backup-automation/
├── scripts/
│   ├── backup.sh     # main backup script
│   └── restore.sh    # restore from archive
├── sample-data/      # example source data
├── backups/          # .gitignored — archives stored here
├── logs/             # .gitignored — operation logs
└── README.md
```

## Usage

### Run a backup
```bash
# Backup sample-data/ → backups/ keeping 7 days
./scripts/backup.sh

# Custom: backup /etc → /var/backups keeping 14 days
./scripts/backup.sh /etc /var/backups 14
```

### Restore from a backup
```bash
./scripts/restore.sh ./backups/backup_20240416_142201.tar.gz ./restored
```

### Enable Slack alerts
```bash
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
./scripts/backup.sh
```

### Schedule with cron (Linux/WSL)
```bash
# Run backup every day at 2am
crontab -e
0 2 * * * /path/to/devops-backup-automation/scripts/backup.sh >> /path/to/logs/cron.log 2>&1
```

## What I learned

- Bash best practices: set -euo pipefail for safe scripting
- tar + gzip for cross-platform archive creation and extraction
- Log rotation and retention policies (core DevOps/SRE concept)
- Slack webhook integration — same pattern used by Datadog, Alertmanager, PagerDuty
- Idempotent scripting — safe to run multiple times with predictable results

## Tech stack

Bash · gzip · tar · cron · Slack webhooks · Git