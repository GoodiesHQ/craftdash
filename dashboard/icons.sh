#!/bin/sh
# Downloads the app icons shown on the dashboard.
#
# Runs in the build stage of dashboard/Dockerfile, which passes these build args:
#   ICONS      space-separated app names, e.g. "photocraft lightcraft"
#   ICON_URL   URL pattern where {name} is replaced by each app name
#
# Writes <name>.<ext> files and an index.json ({"photocraft": "photocraft.webp", ...})
# to /icons. A missing icon, or a response that isn't an image, is skipped and the
# page shows a letter tile for that app instead. A missing icon never fails the build.
set -eu

ICON_DIR=${ICON_DIR:-/icons}
DEFAULT_ICON_URL='https://getartcraft.com/images/apps/{name}/icon.webp'
ICON_URL=${ICON_URL:-$DEFAULT_ICON_URL}

mkdir -p "$ICON_DIR"
index=""

for name in ${ICONS:-}; do
    url=$(printf '%s' "$ICON_URL" | sed "s|{name}|$name|g")

    # Keep the URL's extension (minus any query string) if it's an image type.
    ext=${url##*.}
    ext=${ext%%\?*}
    case "$ext" in
        webp|png|svg|jpg|jpeg|gif|avif|ico) ;;
        *) ext=img ;;
    esac
    file="$name.$ext"

    type=$(curl -fsSL --retry 2 --max-time 20 -w '%{content_type}' \
        -o "$ICON_DIR/$file" "$url" 2>/dev/null) || type=""

    case "$type" in
        image/*)
            echo "icons: $name <- $url"
            index="${index:+$index,}\"$name\":\"$file\""
            ;;
        *)
            echo "icons: $name not available (${type:-no response}), using a letter tile"
            rm -f "$ICON_DIR/$file"
            ;;
    esac
done

printf '{%s}\n' "$index" > "$ICON_DIR/index.json"
echo "icons: wrote $ICON_DIR/index.json"