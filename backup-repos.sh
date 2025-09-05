#!/bin/bash

#########################################
# UN-SWRIL Repository Backup Script
# Creates compressed archive backups with 8-week rolling retention
# Email notifications on failure
#########################################

# Load environment variables from .env file if it exists
if [ -f "$(dirname "$0")/.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/.env" | xargs)
elif [ -f "/usr/local/bin/.env" ]; then
    export $(grep -v '^#' "/usr/local/bin/.env" | xargs)
elif [ -f "/opt/backup/.env" ]; then
    export $(grep -v '^#' "/opt/backup/.env" | xargs)
fi

# Configuration - use environment variables with fallback defaults
ORG_NAME="${BACKUP_ORG_NAME:-UN-SWRIL}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/un-swril}"
LOG_FILE="${BACKUP_LOG_FILE:-/var/log/un-swril-backup.log}"
RETENTION_WEEKS="${BACKUP_RETENTION_WEEKS:-8}"
SNS_TOPIC_ARN="${BACKUP_SNS_TOPIC_ARN:-arn:aws:sns:us-east-1:651706782157:un-swril-backup-notifications}"
AWS_REGION="${BACKUP_AWS_REGION:-us-east-1}"
SCRIPT_NAME="UN-SWRIL Repository Backup"

# GitHub token - prefer environment variable, fallback to GitHub CLI authentication
if [ -n "$GITHUB_TOKEN" ]; then
    export GITHUB_TOKEN="$GITHUB_TOKEN"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "${RED}ERROR: $1${NC}"
    send_failure_notification "$1"
    exit 1
}

# Success logging function
log_success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

# Warning logging function
log_warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Send failure notification via SNS
send_failure_notification() {
    local error_message="$1"
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create notification message
    local message="$SCRIPT_NAME failed on $hostname at $timestamp

Error Details:
$error_message

Server: $hostname
Backup Directory: $BACKUP_DIR
Log File: $LOG_FILE

Please check the server and resolve the issue.

Last 10 lines of log file:
$(tail -10 "$LOG_FILE" 2>/dev/null || echo "Log file not accessible")

---
Automated backup system"

    # Send notification using AWS SNS
    if command -v aws >/dev/null 2>&1; then
        if aws sns publish \
            --topic-arn "$SNS_TOPIC_ARN" \
            --subject "[ALERT] $SCRIPT_NAME Failed on $hostname" \
            --message "$message" \
            --region "$AWS_REGION" >/dev/null 2>&1; then
            log "Failure notification sent via SNS"
        else
            log_warning "Failed to send SNS notification"
            log_warning "Message: $message"
        fi
    else
        log_warning "AWS CLI not available. SNS notification not sent."
        log_warning "Message: $message"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if git is installed
    if ! command -v git >/dev/null 2>&1; then
        error_exit "git is not installed"
    fi
    
    # Check if gh CLI is installed and configured
    if ! command -v gh >/dev/null 2>&1; then
        error_exit "GitHub CLI (gh) is not installed"
    fi
    
    # Test GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        error_exit "GitHub CLI is not authenticated"
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws >/dev/null 2>&1; then
        error_exit "AWS CLI is not installed"
    fi
    
    # Test AWS credentials/permissions
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error_exit "AWS CLI is not configured or lacks permissions"
    fi
    
    # Create backup directory if it doesn't exist
    if ! mkdir -p "$BACKUP_DIR"; then
        error_exit "Failed to create backup directory: $BACKUP_DIR"
    fi
    
    # Create log directory if it doesn't exist
    if ! mkdir -p "$(dirname "$LOG_FILE")"; then
        error_exit "Failed to create log directory: $(dirname "$LOG_FILE")"
    fi
    
    log_success "Prerequisites check completed"
}

# Function to get repository list
get_repositories() {
    # Log to stderr to avoid mixing with return value
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Fetching repository list from $ORG_NAME organization..." >> "$LOG_FILE"
    
    local repo_list
    if ! repo_list=$(gh repo list "$ORG_NAME" --limit 100 --json name --jq '.[].name' 2>/dev/null); then
        error_exit "Failed to fetch repository list from GitHub"
    fi
    
    if [ -z "$repo_list" ]; then
        error_exit "No repositories found in organization $ORG_NAME"
    fi
    
    # Return only the repository list
    printf "%s" "$repo_list"
}

# Function to create backup for a single repository
backup_repository() {
    local repo_name="$1"
    local backup_date="$2"
    local temp_dir="/tmp/backup_${repo_name}_$$"
    local archive_name="${repo_name}_${backup_date}.tar.gz"
    local archive_path="$BACKUP_DIR/$archive_name"
    
    log "Backing up repository: $repo_name"
    
    # Clone repository to temporary directory
    if ! gh repo clone "$ORG_NAME/$repo_name" "$temp_dir" 2>/dev/null; then
        log_warning "Failed to clone repository: $repo_name"
        return 1
    fi
    
    # Create compressed archive
    if ! tar -czf "$archive_path" -C "$(dirname "$temp_dir")" "$(basename "$temp_dir")" 2>/dev/null; then
        log_warning "Failed to create archive for repository: $repo_name"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    # Get archive size for logging
    local archive_size
    if command -v du >/dev/null 2>&1; then
        archive_size=$(du -h "$archive_path" | cut -f1)
        log_success "Repository $repo_name backed up successfully (Size: $archive_size)"
    else
        log_success "Repository $repo_name backed up successfully"
    fi
    
    return 0
}

# Function to clean up old backups (8-week retention)
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_WEEKS weeks..."
    
    local cutoff_date
    if command -v date >/dev/null 2>&1; then
        # Calculate cutoff date (8 weeks ago)
        cutoff_date=$(date -d "$RETENTION_WEEKS weeks ago" +%Y%m%d 2>/dev/null || date -v-${RETENTION_WEEKS}w +%Y%m%d 2>/dev/null)
        
        if [ -n "$cutoff_date" ]; then
            local deleted_count=0
            
            # Find and remove old backup files
            for backup_file in "$BACKUP_DIR"/*.tar.gz; do
                if [ -f "$backup_file" ]; then
                    # Extract date from filename (format: reponame_YYYYMMDD.tar.gz)
                    local file_date
                    file_date=$(basename "$backup_file" .tar.gz | grep -o '[0-9]\{8\}$')
                    
                    if [ -n "$file_date" ] && [ "$file_date" -lt "$cutoff_date" ]; then
                        if rm "$backup_file" 2>/dev/null; then
                            log "Deleted old backup: $(basename "$backup_file")"
                            ((deleted_count++))
                        else
                            log_warning "Failed to delete old backup: $(basename "$backup_file")"
                        fi
                    fi
                fi
            done
            
            log_success "Cleanup completed. Deleted $deleted_count old backup(s)"
        else
            log_warning "Could not calculate cutoff date for cleanup"
        fi
    else
        log_warning "date command not available. Skipping cleanup."
    fi
}

# Function to generate backup report
generate_backup_report() {
    local start_time="$1"
    local end_time="$2"
    local total_repos="$3"
    local successful_repos="$4"
    local failed_repos="$5"
    
    log "=== BACKUP REPORT ==="
    log "Start Time: $start_time"
    log "End Time: $end_time"
    log "Total Repositories: $total_repos"
    log "Successful Backups: $successful_repos"
    log "Failed Backups: $failed_repos"
    
    # Calculate total backup size
    if command -v du >/dev/null 2>&1; then
        local total_size
        total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
        log "Total Backup Size: $total_size"
    fi
    
    # List current backup files
    log "Current Backup Files:"
    if ls -la "$BACKUP_DIR"/*.tar.gz >/dev/null 2>&1; then
        ls -lah "$BACKUP_DIR"/*.tar.gz | while read -r line; do
            log "  $line"
        done
    else
        log "  No backup files found"
    fi
    
    log "======================"
}

# Main backup function
main() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local backup_date=$(date '+%Y%m%d')
    
    log "Starting $SCRIPT_NAME"
    log "Backup Date: $backup_date"
    
    # Check prerequisites
    check_prerequisites
    
    # Get repository list
    local repositories
    repositories=$(get_repositories)
    
    local total_repos=0
    local successful_repos=0
    local failed_repos=0
    
    # Convert to array and count
    readarray -t repo_array <<< "$repositories"
    total_repos=${#repo_array[@]}
    
    log "Found $total_repos repositories to backup"
    
    # Backup each repository
    for repo_name in "${repo_array[@]}"; do
        # Skip empty lines and trim whitespace
        repo_name=$(echo "$repo_name" | xargs)
        if [ -n "$repo_name" ]; then
            if backup_repository "$repo_name" "$backup_date"; then
                ((successful_repos++))
            else
                ((failed_repos++))
            fi
        fi
    done
    
    # Clean up old backups
    cleanup_old_backups
    
    # Generate report
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    generate_backup_report "$start_time" "$end_time" "$total_repos" "$successful_repos" "$failed_repos"
    
    # Check if any backups failed
    if [ "$failed_repos" -gt 0 ]; then
        error_exit "Backup completed with $failed_repos failed repository backups"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
    log_success "All $successful_repos repositories backed up successfully"
}

# Run main function
main "$@"
