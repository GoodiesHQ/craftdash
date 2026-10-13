# syntax=docker/dockerfile:1

# Image for one craft web app: downloads a release, precompresses it and serves it
# with Caddy. Built by ./craft build and ./craft update, or by hand:
#
#   docker build --build-arg APP=photocraft --build-arg VERSION=0.7.0 -t photocraft:0.7.0 app/

ARG CADDY_VERSION=2.11

# ======= fetch
FROM alpine:3 AS fetch

RUN apk add --no-cache curl unzip gzip brotli

# Build args come after apk so the package layer is shared by every app and version.
ARG APP
ARG VERSION
ARG REPO=storytold/${APP}
ARG ASSET_URL=https://github.com/${REPO}/releases/download/v${VERSION}/${APP}-web-${VERSION}.zip
ARG SHA256=

COPY fetch.sh /usr/local/bin/fetch.sh
RUN sh /usr/local/bin/fetch.sh


FROM caddy:${CADDY_VERSION}-alpine

# The base image gives caddy a file capability so it can bind ports below 1024.
# We listen on 8080, and under cap_drop: ALL that capability stops caddy starting.
RUN apk add --no-cache libcap && setcap -r /usr/bin/caddy

ARG APP
ARG VERSION
ARG REPO=storytold/${APP}

LABEL org.opencontainers.image.title="${APP}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/${REPO}" \
      org.opencontainers.image.description="${APP} ${VERSION} served by Caddy"

# Caddy writes a little state. /tmp stays writable when the root filesystem is read-only.
ENV CRAFT_APP=${APP} \
    CRAFT_VERSION=${VERSION} \
    XDG_DATA_HOME=/tmp/caddy/data \
    XDG_CONFIG_HOME=/tmp/caddy/config

COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=fetch /site /srv

USER nobody
EXPOSE 8080

# --start-interval needs Docker Engine 25+. Older engines wait for the first 30s check.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=1s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]