#!/usr/bin/env bash
# dry_run.sh [messengerr send flags...]
# Runs `messengerr send --dry-run <args>` — a rendered preview, never a send.
# --dry-run is hard-coded; --allow-non-interactive is refused. Requires the
# flag-based send interface (messengerr >= 0.2.0).
set -u

command -v messengerr >/dev/null 2>&1 || {
  echo "dry_run: 'messengerr' CLI not found. Ask the user to run: gem install messengerr" >&2
  exit 1
}

version=$(messengerr --version 2>/dev/null | tr -d '[:space:]')
major=${version%%.*}
minor=$(printf '%s' "$version" | cut -d. -f2)
if [ "${major:-0}" -eq 0 ] && [ "${minor:-0}" -lt 2 ]; then
  echo "dry_run: messengerr $version is too old — the flag-based dry run needs >= 0.2.0. Ask the user to: gem update messengerr" >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --allow-non-interactive)
      echo "dry_run: '--allow-non-interactive' is not allowed here — this script is for previewing only." >&2
      exit 1
      ;;
  esac
done

exec messengerr send --dry-run "$@"
