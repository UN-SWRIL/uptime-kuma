#!/bin/bash

# Wait for database to be ready
echo "Starting initialization script..."

# Use environment variables directly (no need for export)
echo "Waiting for database connection at ${DB_HOST}:${DB_PORT}..."

# Try to connect to the database
until nc -z -v -w5 "${DB_HOST}" "${DB_PORT}" 2>/dev/null; do
    echo "Retrying database connection..."
    sleep 5
done

echo "Database connection established"

# Start the application
exec node server/server.js 