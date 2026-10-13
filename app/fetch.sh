#!/bin/sh
# Downloads a craft web release and prepares it for Caddy.
#
# Runs in the build stage of app/Dockerfile, which passes these build args:
#   APP, VERSION   e.g. photocraft and 0.7.0
#   ASSET_URL      release zip to download
#   SHA256         optional; the build fails if the zip doesn't match
#
# The finished site ends up in /site.
set -eu

SITE_DIR=${SITE_DIR:-/site}

log() { echo "fetch: $*"; }
die() { echo "fetch: $*" >&2; exit 1; }

[ -n "${APP:-}" ]       || die "APP build arg is required"
[ -n "${VERSION:-}" ]   || die "VERSION build arg is required"
[ -n "${ASSET_URL:-}" ] || die "ASSET_URL build arg is required"

work=$(mktemp -d)
zip="$work/release.zip"

log "downloading $ASSET_URL"
curl -fsSL --retry 3 -o "$zip" "$ASSET_URL"

if [ -n "${SHA256:-}" ]; then
    log "verifying sha256"
    echo "$SHA256  $zip" | sha256sum -c -
else
    log "no SHA256 given, skipping verification"
fi

unzip -q "$zip" -d "$work/unpacked"

# Releases unpack to <app>-web-<version>/. If one ever doesn't, use its only top-level folder.
src="$work/unpacked/$APP-web-$VERSION"
if [ ! -d "$src" ]; then
    src=$(find "$work/unpacked" -mindepth 1 -maxdepth 1 -type d | head -n 1)
fi
[ -n "$src" ] && [ -f "$src/index.html" ] || die "no index.html found in the release zip"

mv "$src" "$SITE_DIR"

# Sample header files for Apache and Netlify. Caddy sets the same headers itself.
rm -f "$SITE_DIR/.htaccess" "$SITE_DIR/_headers"

# Precompress once here, so Caddy serves .br/.gz files instead of compressing every request.
log "precompressing"
find "$SITE_DIR" -type f \( \
        -name '*.wasm' -o -name '*.js'   -o -name '*.html' -o -name '*.css' -o \
        -name '*.svg'  -o -name '*.json' -o -name '*.txt'  -o -name '*.md' \
    \) |
while read -r file; do
    gzip -9 -k -n "$file"
    brotli -q 11 -k "$file"
done

rm -rf "$work"
log "done, $(find "$SITE_DIR" -type f | wc -l) files in $SITE_DIR"