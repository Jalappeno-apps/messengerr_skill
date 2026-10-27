# messengerr command reference

<!-- GENERATED from the CLI's own --help output (see build/generate_commands.rb).
     Do not edit by hand — CI regenerates and diffs this file. -->

## Top level

```
Usage: messengerr <command>

Commands:
  credentials  Manage integration credentials (setup|list|verify|delete)
  send         Send a message to a CSV contact list (see `send --help`)
  integrations List registered integrations
  skill        Install the Claude Code skill (install|status|uninstall)

Options: -h/--help, -v/--version
```

## credentials

```
messengerr credentials setup <name>      Interactive key setup + live verification (human runs this)
messengerr credentials list              Registered integrations and configured state
messengerr credentials verify <name>     Re-check stored credentials against the provider API
messengerr credentials delete            Remove the encrypted credentials file (confirmed)
messengerr credentials delete --purge    Also remove the master key (confirmed)
```

## send

```
messengerr send [flags]
    --method email|sms           Delivery method (skips the chooser)
    --integration NAME           Integration to use (e.g. postmark, clicksend)
    --dry-run                    Preview the rendered messages; send nothing
    --csv PATH                   Contact CSV (skips the path prompt)
    --contact COLUMN             Column holding the email/phone contact value
    --map PLACEHOLDER=COLUMN     Map a {{placeholder}} to a CSV column (repeatable)
    --message TEXT               Message body as a literal argument
    --message-file FILE          Read a multi-line plain-text message from FILE
    --html FILE                  Send FILE as an HTML email (email only; HTML only, no text version)
    --subject TEXT               Email subject line ({{placeholders}} allowed)
    --resume LEDGER              Skip recipients already sent in this ledger (row + contact)
    --ledger PATH                Where to record results (default: ./messengerr-ledger-<time>.jsonl)
    --batch-size N               Messages per batch
    --rate-limit N               Batches per second
    --from ADDRESS               Override the sender address/ID
    --allow-non-interactive      Send without an interactive terminal (human scripts only)
    -h, --help                   Show this help
```

Without flags the wizard prompts for everything interactively. Flags skip
their prompts; anything still missing is asked for.

**Exit codes:** `0` = all sent (or dry run), `1` = failures remain / aborted /
error.

**Send guard:** a non-`--dry-run` send requires an interactive terminal (stdin
TTY). Agents and CI hit "Refusing to send without an interactive terminal" —
that is the intended behaviour; `--allow-non-interactive` is the documented
escape hatch for the user's own scripts.

## integrations

Lists registered integrations grouped by delivery method (`email`, `sms`)
with configured/not-configured state.

## skill

```
messengerr skill install               Install the Claude Code skill to ~/.claude/skills/messengerr
messengerr skill install --project     Install to ./.claude/skills/messengerr
messengerr skill install --force       Overwrite without prompting
messengerr skill install --from PATH   Install from a local tarball/directory (unverified)
messengerr skill status                Installed vs pinned skill version
messengerr skill uninstall             Remove the installed skill (confirmed)
```
