#!/bin/bash

# ULTRA COMPREHENSIVE DEBUGGING SCRIPT

# Redirect ALL output to multiple log files
exec > >(tee -a /tmp/init-db-debug.log /tmp/init-db-full.log) 2>&1

# Extremely verbose error handling
set -x
set -euo pipefail

# Comprehensive logging function
log_debug() {
    echo "DEBUG: $*" >&2
}

# Extreme environment investigation
log_debug "=== COMPREHENSIVE SYSTEM AND ENVIRONMENT INVESTIGATION ==="
log_debug "Timestamp: $(date)"
log_debug "Hostname: $(hostname)"
log_debug "Kernel: $(uname -a)"
log_debug "Current User: $(whoami)"
log_debug "Working Directory: $(pwd)"
log_debug "Shell: $SHELL"
log_debug "Shell Version: $(bash --version | head -n 1)"

# Dump ALL environment variables with source
log_debug "=== COMPLETE ENVIRONMENT VARIABLE DUMP ==="
env | sort

# Specific database variable investigation
log_debug "=== DATABASE ENVIRONMENT VARIABLES ==="
log_debug "DB_HOST raw: '$DB_HOST'"
log_debug "DB_PORT raw: '$DB_PORT'"
log_debug "DB_PORT_STRING raw: '$DB_PORT_STRING'"

# Validate environment variables
[ -z "${DB_HOST:-}" ] && {
    log_debug "CRITICAL: DB_HOST is empty or unset"
    exit 1
}

# Validate and sanitize port
PORT_TO_USE="${DB_PORT:-${DB_PORT_STRING:-5432}}"

# Ensure PORT_TO_USE is a valid number
if [[ ! "$PORT_TO_USE" =~ ^[0-9]+$ ]]; then
    log_debug "CRITICAL: Invalid port number: $PORT_TO_USE"
    log_debug "Port contents (hexdump):"
    log_debug "$(echo -n "$PORT_TO_USE" | hexdump -C)"
    exit 1
}

log_debug "Using validated port: $PORT_TO_USE"

# Network and DNS diagnostics
log_debug "=== NETWORK DIAGNOSTICS ==="
log_debug "Resolving DB_HOST:"
nslookup "$DB_HOST" || log_debug "Hostname resolution failed"

log_debug "Host IP Addresses:"
getent hosts "$DB_HOST" || log_debug "Could not resolve host IPs"

log_debug "Traceroute to DB_HOST:"
traceroute "$DB_HOST" || log_debug "Traceroute failed"

log_debug "Network Interfaces:"
ip addr || log_debug "Could not list network interfaces"

log_debug "Routing Table:"
route -n || log_debug "Could not display routing table"

log_debug "DNS Configuration:"
cat /etc/resolv.conf || log_debug "Could not read resolv.conf"

# Comprehensive connection test using psql
PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$PORT_TO_USE" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -w \
    -c "SELECT NOW()" || {
    log_debug "PSQL Connection Failed"
    exit 1
}

# Run database migrations
if [ "$AUTO_MIGRATE" = "true" ]; then
    log_debug "Running database migrations..."
    cd /app
    node extra/migrate.js
fi

# Start the application
log_debug "Starting Uptime Kuma..."
exec node server/server.js 