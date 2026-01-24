#!/bin/sh
# Migration script for production releases
# This script runs database migrations before starting the application

set -e

echo "Running database migrations..."

# Run migrations
bin/habit_tracker eval "HabitTracker.Release.migrate()"

echo "Migrations completed successfully!"
