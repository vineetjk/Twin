#!/bin/sh
# Entrypoint for the web and backend images: make the data directory writable by the unprivileged
# user ($TWIN_USER, uid 10001), then run the command as that user.
#
# Docker volumes take the image's ownership of /data, but a platform disk (Render) is mounted
# root-owned, which would leave the SQLite database read-only. Started as another user
# (docker run --user …), the command runs unchanged.
set -e
if [ "$(id -u)" = 0 ]; then
  dir="${TWIN_DATA_DIR:-/data}"
  mkdir -p "$dir"
  chown "$TWIN_USER" "$dir"
  exec setpriv --reuid="$TWIN_USER" --regid="$(id -g "$TWIN_USER")" --init-groups -- "$@"
fi
exec "$@"
