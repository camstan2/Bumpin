#!/bin/bash
#
# Auto-Backup Script for Bumpin
# This script automatically commits and pushes changes to GitHub
#
# Usage: Run manually with ./scripts/auto-backup.sh
#        Or let launchd run it automatically
#

set -e

# Configuration
PROJECT_DIR="/Users/camstanley/Desktop/Bumpin"
BACKUP_BRANCH="auto-backup"
LOG_FILE="$PROJECT_DIR/scripts/backup.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Navigate to project directory
cd "$PROJECT_DIR"

# Check if there are any changes
if [[ -z $(git status --porcelain) ]]; then
    log "✅ No changes to backup"
    exit 0
fi

# Count changes
CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
log "📦 Found $CHANGES file(s) with changes"

# Store current branch
CURRENT_BRANCH=$(git branch --show-current)

# Create timestamp for commit message
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
COMMIT_MSG="🔄 Auto-backup: $TIMESTAMP"

# Stage all changes
git add -A
log "📝 Staged all changes"

# Commit changes
git commit -m "$COMMIT_MSG" --no-verify 2>/dev/null || {
    log "⚠️ Nothing to commit after staging"
    exit 0
}
log "✅ Committed: $COMMIT_MSG"

# Check if backup branch exists on remote
if git ls-remote --heads origin "$BACKUP_BRANCH" | grep -q "$BACKUP_BRANCH"; then
    # Backup branch exists, push to it
    git push origin "$CURRENT_BRANCH:$BACKUP_BRANCH" --force 2>/dev/null && {
        log "☁️ Pushed to origin/$BACKUP_BRANCH"
    } || {
        log "⚠️ Could not push to remote (might be offline)"
    }
else
    # Create and push backup branch
    git push origin "$CURRENT_BRANCH:$BACKUP_BRANCH" 2>/dev/null && {
        log "☁️ Created and pushed to origin/$BACKUP_BRANCH"
    } || {
        log "⚠️ Could not push to remote (might be offline)"
    }
fi

log "🎉 Backup complete!"
echo ""
