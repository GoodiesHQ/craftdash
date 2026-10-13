# syntax=docker/dockerfile:1

# Dashboard page for a craft environment. The list of enabled apps comes from
# CRAFT_CONFIG, which `craft compose` writes into the compose file, so this image only
# needs rebuilding when the page or the icons change. Built by ./craft dashboard.

ARG CADDY_VERSION=2.11


# Icons are downloaded here so browsers never fetch them from a third-party site.
FROM alpine:3 AS icons

RUN apk add --no-cache curl

ARG ICONS=""
ARG ICON_URL=https://getartcraft.com/images/apps/{name}/icon.webp

COPY icons.sh /usr/local/bin/icons.sh
RUN sh /usr/local/bin/icons.sh


FROM caddy:${CADDY_VERSION}-alpine

# The base image gives caddy a file capability so it can bind ports below 1024.
# We listen on 8080, and under cap_drop: ALL that capability stops caddy starting.
RUN apk add --no-cache libcap && setcap -r /usr/bin/caddy

ARG DASHBOARD_VERSION=dev

LABEL org.opencontainers.image.title="craft-dashboard" \
      org.opencontainers.image.version="${DASHBOARD_VERSION}" \
      org.opencontainers.image.description="Dashboard page for self-hosted craft web apps"

# CRAFT_CONFIG is replaced by the compose file. /tmp stays writable when the root
# filesystem is read-only, so Caddy keeps its state there.
ENV CRAFT_CONFIG='{"title":"ArtCraft","apps":[]}' \
    XDG_DATA_HOME=/tmp/caddy/data \
    XDG_CONFIG_HOME=/tmp/caddy/config

COPY Caddyfile /etc/caddy/Caddyfile
COPY index.html /srv/index.html
COPY --from=icons /icons /srv/icons

USER nobody
EXPOSE 8080

# --start-interval needs Docker Engine 25+. Older engines wait for the first 30s check.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=1s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]