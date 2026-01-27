#!/usr/bin/env sh
set -eu

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
  echo "Running database migrations..."
  /app/bin/habit_tracker eval "HabitTracker.Release.migrate()"
fi

exec /app/bin/habit_tracker "$@"
