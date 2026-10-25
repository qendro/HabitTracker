# syntax=docker/dockerfile:1
ARG ELIXIR_IMAGE=hexpm/elixir:1.19.5-erlang-28.3.3-debian-trixie-20260824-slim
FROM ${ELIXIR_IMAGE} AS builder
ENV MIX_ENV=prod ERL_FLAGS="+S 4:4" HEX_CACERTS_PATH=/etc/ssl/certs/ca-certificates.crt
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY . .
RUN mix local.hex --force && mix local.rebar --force \
    && mix deps.get --only prod && mix deps.compile \
    && mix assets.deploy && mix compile --warnings-as-errors && mix release
FROM debian:trixie-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libncurses6 libssl3t64 ca-certificates imagemagick libheif1 libheif-plugin-libde265 zip curl tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 journal && useradd --uid 1000 --gid 1000 --no-create-home journal \
    && mkdir -p /app /data && chown -R journal:journal /app /data && chmod 700 /data
WORKDIR /app
COPY --from=builder --chown=journal:journal /app/_build/prod/rel/habit_tracker ./
COPY docker/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml
ENV PHX_SERVER=true MEDIA_ROOT=/data MAGICK_TEMPORARY_PATH=/tmp ERL_FLAGS="+S 2:2" LANG=C.UTF-8
USER journal
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s CMD curl -fsS http://127.0.0.1:4000/health || exit 1
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/bin/habit_tracker", "start"]
