import Config

# This file is loaded when running releases in production.
# It is executed after compilation and before the system starts.
# For compile-time configuration, see config/prod.exs

# DISABLE Oban completely on free tier - only 2 DB connections available
# Oban requires at least 1 connection even with queues disabled
# We need both connections for the web app
config :habit_tracker, Oban, testing: :manual
