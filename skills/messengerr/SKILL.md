---
name: messengerr
description: >
  Prepare, preview, and troubleshoot bulk email/SMS sends from a CSV with the
  `messengerr` CLI — mail merges, newsletters, letterhead emails, dry runs,
  and ledger/resume after an interrupted send. Triggers on: send a campaign or
  newsletter to a contact list, SMS a list, mail-merge from a CSV, "messengerr",
  letterhead email, retry/resume a failed bulk send. Claude prepares and
  dry-runs — the human always sends.
allowed-tools:
  - "Bash(messengerr --version)"
  - "Bash(messengerr credentials list)"
  - "Bash(messengerr integrations)"
  - "Bash(messengerr send --help)"
  - "Bash(*csv_check.rb*)"
  - "Bash(*ledger_summary.rb*)"
  - "Bash(*dry_run.sh*)"
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: |
            # Inline guard: block real sends and credential access while this
            # skill is active. Self-contained — uses no external files.
            # Exit 2 blocks; anything else is non-blocking (fails open).
            input=$(cat)
            if command -v jq >/dev/null 2>&1; then
              cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
            else
              cmd=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"[[:space:]]*,\?[[:space:]]*}.*/\1/p')
            fi
            [ -z "${cmd:-}" ] && exit 0
            case "$cmd" in
              *master.key*|*credentials.yml.enc*|*MESSENGERR_MASTER_KEY*|*.config/messengerr*)
                echo "messengerr guard: never touch credential files or the master key" >&2; exit 2;;
            esac
            case "$cmd" in
              *--allow-non-interactive*)
                echo "messengerr guard: '--allow-non-interactive' is not for this skill" >&2; exit 2;;
              *messengerr*send*)
                case "$cmd" in
                  *--dry-run*|*--help*|*-h*) : ;;
                  *) echo "messengerr guard: 'messengerr send' without --dry-run is blocked — the human sends" >&2; exit 2;;
                esac;;
            esac
            exit 0
metadata:
  requires: "messengerr >= 0.2.0"
---

# Messengerr: prepare bulk sends, never send them

`messengerr` is a CLI that sends templated email/SMS to a CSV contact list.
This skill helps the user prepare a send — inspect the CSV, write the message,
preview the rendered output — and troubleshoot a completed run. **Every real
send is done by the human**, in their own terminal.

## Hard rules — these are not negotiable

- **Never run `messengerr send` without `--dry-run`.** Not "to test", not for
  one recipient, not ever. Prepare, dry-run, then hand the user the exact
  command to run themselves.
- **Never read, print, ask for, or write credentials.** That includes
  `~/.config/messengerr/`, `credentials.yml.enc`, `master.key`, and the
  `MESSENGERR_MASTER_KEY` environment variable. Credential setup is
  `messengerr credentials setup <name>` — run **by the human**.
- **Never paste a full contact list into the conversation.** Counts, headers,
  row numbers, and at most the few previewed messages the user asked to see.
- **Never suggest bypassing a safeguard** — no `--allow-non-interactive`, no
  editing credential files, no piping `yes` into the send wizard.
- **Compliance is the sender's job.** When relevant, remind the user they need
  recipients' consent and a working unsubscribe/opt-out path (CAN-SPAM,
  GDPR/PECR, TCPA for SMS).
- **Don't invent features.** If something seems missing, check
  `messengerr send --help` or the references below — and see
  `references/troubleshooting.md` and the gem's `limitations` docs.

## Workflow

### 1. Check the CLI

```bash
messengerr --version
```

Missing? Tell the user to run `gem install messengerr`. Below 0.2.0? The
flag-based dry-run path won't work — ask them to `gem update messengerr`.

### 2. Check configuration — read-only

```bash
messengerr credentials list
messengerr integrations
```

"Configured" means credentials exist. If nothing is configured for the needed
method, stop and tell the user to run `messengerr credentials setup <name>`
themselves — do not run it, do not ask for tokens.

### 3. Inspect the CSV

```bash
${CLAUDE_SKILL_DIR}/scripts/csv_check.rb /path/to/contacts.csv
```

Reports headers, duplicate headers (the CLI rejects those), blank rows, and
per-column empty counts — counts only, never contact values. One data row
= one message. Flag bad shapes before writing anything else.

### 4. Help write the message

Three forms, all flag-driven (see `references/commands.md`):

- **One-liner** — `--message "Hi {{name}}, ..."`
- **File** — `--message-file copy.txt` for multi-line plain text
- **HTML** — `--html letterhead.html` for HTML email (email only; the CLI
  refuses it for integrations that can't send HTML)

Placeholders are `{{column_name}}`, logic-free — no loops, no conditionals.
Every `{{placeholder}}` in the message **and** the subject gets mapped to a CSV
column at send time. Rules and escaping: `references/templates.md`. HTML email
recipe and client quirks: `references/html-email.md`; a neutral starter is
`assets/letterhead-template.html`.

### 5. Dry-run the whole thing

```bash
${CLAUDE_SKILL_DIR}/scripts/dry_run.sh \
  --method email --csv contacts.csv --contact email \
  --map name=name --message-file copy.txt --subject "Welcome, {{name}}"
```

The script forces `--dry-run` and refuses `--allow-non-interactive`. Read the
preview aloud: recipient count, defects/drops, and the first rendered messages
(for HTML, the generated `messengerr-preview.html` — offer to open it). If the
preview is wrong, fix the message or mapping and dry-run again.

### 6. Hand off — the human sends

Print the **exact command** for the user to run in their own terminal, same
flags minus the helper script:

```bash
messengerr send --method email --csv contacts.csv --contact email \
  --map name=name --message-file copy.txt --subject "Welcome, {{name}}"
```

Tell them what to expect: the preview shows again, they confirm, sends are
recorded in a JSONL ledger (`./messengerr-ledger-<time>.jsonl`, `--ledger` to
choose), Ctrl-C or a crash is safe — rerun with `--resume <ledger>` to skip
already-sent contacts.

### 7. Afterwards

```bash
${CLAUDE_SKILL_DIR}/scripts/ledger_summary.rb messengerr-ledger-<time>.jsonl
```

Counts sent/failed/uncertain and lists failed rows with reasons.
**Uncertain** failures (timeouts, unreadable responses) may already be
delivered — warn the user before they retry those. Details:
`references/ledger-and-resume.md`.

## What goes wrong most

- Wrong column mapping → placeholders still in the output or wrong values in
  the preview. The dry-run exists to catch this; the send itself refuses rows
  that render badly.
- Local phone numbers without `MESSENGERR_DEFAULT_COUNTRY` → "invalid phone
  number" defects.
- `--html` to an SMS method → the CLI refuses; pick a text message instead.
- "Refusing to send without an interactive terminal" — correct behaviour; the
  user runs the command themselves.

## References

- `references/commands.md` — every command, flag, exit code
- `references/templates.md` — `{{placeholder}}` rules
- `references/html-email.md` — email-safe HTML
- `references/ledger-and-resume.md` — ledger fields, uncertain failures, resume
- `references/troubleshooting.md` — real error messages → cause → fix
