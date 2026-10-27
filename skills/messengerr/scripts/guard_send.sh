#!/usr/bin/env bash
# PreToolUse guard for the messengerr skill. Reads the hook JSON on stdin and
# exits 2 (block, stderr shown to Claude) when the Bash command would send real
# messages or read credential material. Any other exit is non-blocking — a
# broken guard fails open, so this is a seatbelt, not the safety mechanism.
# The CLI's own TTY guard is the hard backstop.
set -u

input=$(cat)

# Pull the "command" string out of the hook payload. Best-effort JSON field
# extraction without a JSON library; jq is used when available.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  cmd=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"[[:space:]]*,\?[[:space:]]*}.*/\1/p')
  cmd=${cmd//\\\"/\"}
fi

[ -z "${cmd:-}" ] && exit 0

block() {
  echo "messengerr guard: $1" >&2
  exit 2
}

# Credential material must never be read or exfiltrated.
case "$cmd" in
  *master.key*|*credentials.yml.enc*|*MESSENGERR_MASTER_KEY*|*.config/messengerr*)
    block "refusing to touch credential files or the master key. Credentials are managed by the human via 'messengerr credentials'."
    ;;
esac

# Split the command into pipeline/chain segments and inspect each for a real send.
rest=$cmd
while [ -n "$rest" ]; do
  segment=${rest%%[|\&\;]*}
  if [ "$segment" = "$rest" ]; then
    rest=""
  else
    rest=${rest#*[|\&\;]}
  fi

  case "$segment" in
    *messengerr*send*)
      case "$segment" in
        *--allow-non-interactive*)
          block "'--allow-non-interactive' is for the human's own scripts, not for this skill."
          ;;
        *--dry-run*|*--help*|*-h*)
          : # safe
          ;;
        *)
          block "refusing 'messengerr send' without --dry-run. Claude prepares and dry-runs; the human sends."
          ;;
      esac
      ;;
  esac
done

exit 0
