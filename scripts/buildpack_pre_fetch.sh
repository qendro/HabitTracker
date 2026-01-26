#!/usr/bin/env bash
set -euo pipefail

export HEX_HOME="${HEX_HOME:-.hex}"
export MIX_HOME="${MIX_HOME:-.mix}"

mkdir -p "$HEX_HOME" "$MIX_HOME"

mix local.hex --force
mix local.rebar --force
