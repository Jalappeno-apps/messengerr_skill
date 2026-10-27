---
name: messengerr
description: >
  Prepare, preview, and troubleshoot bulk email/SMS sends from a CSV with the
  `messengerr` CLI: mail merges, newsletters, letterhead emails, dry runs, and
  resuming an interrupted send. Use when the user wants to send a campaign or
  newsletter to a contact list, SMS a list, mail-merge from a CSV, mentions
  "messengerr", wants an HTML letterhead email, or needs to retry or resume a
  failed bulk send. Claude prepares and dry-runs; the human always sends.
allowed-tools: >-
  Bash(messengerr --version)
  Bash(messengerr credentials list)
  Bash(messengerr integrations)
  Bash(messengerr send --help)
  Bash(${CLAUDE_SKILL_DIR}/scripts/csv_check.rb *)
  Bash(${CLAUDE_SKILL_DIR}/scripts/dry_run.sh *)
  Bash(${CLAUDE_SKILL_DIR}/scripts/ledger_summary.rb *)
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Grep|Glob|Edit|Write"
      hooks:
        - type: command
          command: |
            # Guard: block real sends and credential access while this skill is active.
            # Runs scripts/guard.rb when it can find it; otherwise a strict built-in rule.
            # Exit 2 blocks. Any other exit lets the call through, so this is a seatbelt,
            # not the safety mechanism: the CLI's own terminal check is the backstop.
            d=""
            for c in "${CLAUDE_SKILL_DIR:-}" "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/messengerr}" \
                     "$HOME/.claude/skills/messengerr" "${CLAUDE_PROJECT_DIR:-.}/.claude/skills/messengerr"; do
              if [ -n "$c" ] && [ -f "$c/scripts/guard.rb" ]; then d="$c"; break; fi
            done
            if [ -n "$d" ] && command -v ruby >/dev/null 2>&1; then exec ruby "$d/scripts/guard.rb"; fi
            input=$(cat)
            deny() { echo "messengerr guard: $1" >&2; exit 2; }
            case "$input" in
              *messengerr*send*)
                case "$input" in
                  *'&&'*|*'||'*|*';'*|*'|'*|*'$('*|*'`'*|*'\n'*|*'#'*|*allow-non-interactive*)
                    deny "refusing a compound or unclear 'messengerr send' (guard.rb not found; strict mode)" ;;
                  *' --dry-run'*|*' --help'*|*' -h"'*|*' -h '*) : ;;
                  *) deny "refusing 'messengerr send' without --dry-run. Claude prepares and dry-runs; the human sends." ;;
                esac ;;
              *credentials*setup*|*credentials*delete*|*.config/messengerr*|*MESSENGERR_MASTER_KEY*)
                deny "refusing to touch the messengerr credentials; the human manages them." ;;
            esac
            exit 0
metadata:
  version: "0.1.0"
  requires: "messengerr >= 0.2.0"
---

# Messengerr: prepare bulk sends, never send them

`messengerr` is a command-line tool that sends templated email or SMS to the
people in a CSV file. This skill helps the user prepare a send: inspect the CSV,
write the message, and preview exactly what will go out. It also helps read the
result afterwards. **Every real send is done by the human**, in their own
terminal.

## Hard rules

- **Never run `messengerr send` without `--dry-run`.** Not to test, not for one
  recipient, not ever. Prepare, dry-run, then hand the user the exact command.
  (The CLI itself refuses a real send without an interactive terminal, and a
  guard hook blocks the attempt. Do not try to get around either.)
- **Never read, print, ask for or write credentials.** That includes
  `~/.config/messengerr/`, `credentials.yml.enc`, `master.key`, and the
  `MESSENGERR_MASTER_KEY` variable. Do not run `messengerr credentials setup`
  or `delete`: those are for the human. If no integration is configured, tell
  them to run `messengerr credentials setup <name>` themselves.
- **Never paste a contact list into the conversation.** Use counts, headers,
  row numbers, and at most the few previewed messages the user asked to see.
- **Never suggest bypassing a safeguard:** no `--allow-non-interactive`, no
  faking a terminal, no editing credential files.
- **Compliance is the sender's job.** Remind the user, when relevant, that they
  need consent from recipients and a working opt-out (CAN-SPAM, GDPR/PECR, and
  TCPA for SMS). The letterhead template does not add an unsubscribe link.
- **Do not invent features.** Check `messengerr send --help` and
  `references/commands.md`. Gaps are listed in the gem's Limitations docs.

## Workflow

### 1. Check the CLI

```bash
messengerr --version
```

Missing? Ask the user to run `gem install messengerr`. Older than 0.2.0? The
flags used below do not exist: ask them to run `gem update messengerr`.

### 2. Check what is configured (read-only)

```bash
messengerr credentials list
messengerr integrations
```

"Configured" means credentials are stored. If nothing is configured for the
delivery method the user needs, stop and tell them to run
`messengerr credentials setup <name>` themselves.

### 3. Inspect the CSV

```bash
${CLAUDE_SKILL_DIR}/scripts/csv_check.rb /path/to/contacts.csv
```

Reports headers, duplicate headers (messengerr rejects those), blank rows and
empty cells per column: counts only, never contact values. **One row is one
message**: a repeated address is sent to once per row, so mention duplicates.

### 4. Help write the message

Three ways to give messengerr the message (see `references/commands.md`):

- **One line:** `--message "Hi {{name}}, ..."`
- **Several lines:** `--message-file copy.txt` (plain text, email or SMS)
- **HTML email:** `--html letter.html` (email only, and only for integrations
  that can send HTML; it is HTML only, with no plain-text version)

Placeholders are `{{column_name}}` and nothing else: no logic, no loops, no
conditionals. Every placeholder in the message **and** the subject needs a
`--map placeholder=column`. Rules and escaping: `references/templates.md`. HTML
recipe and client quirks: `references/html-email.md`; a neutral starter is
`assets/letterhead-template.html`.

### 5. Dry-run the whole thing

```bash
${CLAUDE_SKILL_DIR}/scripts/dry_run.sh \
  --method email --csv contacts.csv --contact email \
  --map name=name --message-file copy.txt --subject "Welcome, {{name}}"
```

The script forces `--dry-run`, never prompts (give it every flag), and stops with
a clear error if a flag is missing. Read the result back to the user: the number
of recipients, any contacts with defects (they are listed and dropped for the
preview), and the first rendered messages. For HTML it writes
`messengerr-preview.html` in the current directory: offer to open it.

If a row cannot be rendered (an unmapped placeholder or an empty cell), the
**whole run stops** with that row's number. Fix the CSV or the mapping and dry-run
again. A dry run costs nothing and sends nothing.

### 6. Hand off: the human sends

The script ends by printing the command for the real send. Give it to the user
exactly as printed, and tell them:

- Run it **in their own terminal window** (a real send is refused anywhere else).
- messengerr shows the preview again and asks `Send N message(s)? [y/n]`.
  Nothing goes out until they type `y`.
- Results are written to a ledger (`./messengerr-ledger-<time>.jsonl`, or
  `--ledger PATH`) as each one lands. If the run is interrupted, they run the
  same command again with `--resume <ledger>`.
- **Do not edit the CSV between the run and a resume**: resume matches by row
  number plus contact, so changed rows can be skipped or sent twice.

### 7. Afterwards

```bash
${CLAUDE_SKILL_DIR}/scripts/ledger_summary.rb messengerr-ledger-<time>.jsonl
```

Counts sent, failed and uncertain, and lists failed rows with their reasons
(addresses and numbers are masked). **Uncertain** failures (timeouts, dropped
connections, server errors) may already have been delivered: warn the user that
retrying them can send duplicates, and suggest checking the provider's activity
log first. Details: `references/ledger-and-resume.md`.

## What goes wrong most

- A column mapped to the wrong header: the preview shows wrong values or the run
  stops at the first row that cannot render. That is what the dry run is for.
- Local-format phone numbers without `MESSENGERR_DEFAULT_COUNTRY`: every number
  is reported as invalid. The user sets the variable (for example `US`).
- `--html` with SMS, or with an integration that cannot send HTML: refused.
- "refusing to send without an interactive terminal": correct behaviour. The
  human runs the command in their own terminal.

## References

- `references/commands.md`: every command, flag and exit code
- `references/templates.md`: `{{placeholder}}` rules
- `references/html-email.md`: email-safe HTML
- `references/ledger-and-resume.md`: ledger fields, uncertain failures, resume
- `references/troubleshooting.md`: messages, causes and fixes
