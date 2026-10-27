#!/usr/bin/env bash
# dry_run.sh <messengerr send flags...>
#
# Previews a send and NEVER sends one: it runs `messengerr send --dry-run "$@"`.
#   * --dry-run is hard-coded and --allow-non-interactive is refused.
#   * It never prompts. Give it every flag (--method, --csv, --contact, --map,
#     --message / --message-file / --html, --subject for email). If one is missing
#     the CLI stops with a clear error instead of waiting for input.
#   * It answers exactly one "y" to the question "drop the contacts with defects
#     and continue?" so the preview can be shown (the defects are listed first),
#     then closes input.
#   * On success it prints the command the HUMAN runs for the real send.
# Needs messengerr >= 0.2.0 (the flags that skip the wizard's questions).
set -u
set -o pipefail

command -v messengerr >/dev/null 2>&1 || {
  echo "dry_run: the 'messengerr' command was not found. Ask the user to run: gem install messengerr" >&2
  exit 1
}

version=$(messengerr --version 2>/dev/null | tr -d '[:space:]')
if [ -z "$version" ] || [ "$(printf '%s\n0.2.0\n' "$version" | sort -V | head -n1)" != "0.2.0" ]; then
  echo "dry_run: messengerr ${version:-?} is too old: the flags this needs arrived in 0.2.0. Ask the user to run: gem update messengerr" >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --allow-non-interactive)
      echo "dry_run: --allow-non-interactive is not allowed here: this script only previews." >&2
      exit 1
      ;;
  esac
done

printf 'y\n' | messengerr send --dry-run "$@"
status=$?
[ "$status" -eq 0 ] || exit "$status"

printf '\n--- hand-off: the HUMAN runs this in their own terminal to send for real ---\nmessengerr send'
printf ' %q' "$@"
printf '\n'
