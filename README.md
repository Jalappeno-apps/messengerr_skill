# messengerr_skill

A Claude Code **skill + plugin** for [messengerr](https://github.com/Jalappeno-apps/messengerr) — the CLI that sends templated email/SMS to a CSV contact list.

The skill helps Claude **prepare, preview, and troubleshoot** bulk sends: inspect the CSV, write the message (plain text or HTML letterhead), dry-run the whole thing, and explain ledgers/failures afterwards. **Claude never sends** — the human always runs the real command in their own terminal.

## Install

**Option 1 — via the CLI (easiest, once messengerr ≥ 0.2.0 is out):**

```sh
gem install messengerr
messengerr skill install
```

Downloads the verified, hash-pinned release tarball and installs to `~/.claude/skills/messengerr/` (`--project` for project-local).

**Option 2 — via the plugin marketplace:**

```
/plugin marketplace add Jalappeno-apps/messengerr_skill
```

Then install the `messengerr` plugin from the catalog.

**Option 3 — manual:**

```sh
git clone https://github.com/Jalappeno-apps/messengerr_skill
cp -r messengerr_skill/skills/messengerr ~/.claude/skills/
```

Start a new Claude Code session afterwards.

## What Claude may and may not do

| May | May not |
|---|---|
| `messengerr --version`, `credentials list`, `integrations`, `send --help` | Run `messengerr send` without `--dry-run` |
| `csv_check.rb` — CSV structure, counts only | Read/print/write credentials or the master key |
| `dry_run.sh` — forced `--dry-run` preview | Paste a full contact list into chat |
| `ledger_summary.rb` — send outcome counts | Use `--allow-non-interactive` or bypass a safeguard |
| Draft messages, letterheads, flag sets | Invent features — see `limitations` docs |

**Four safety layers:** skill instructions → `allowed-tools` allowlist → PreToolUse hook blocking unsafe commands → the CLI's own interactive-terminal guard on real sends. The hook is a seatbelt (a broken hook fails open by design); the CLI guard is the backstop.

## Contents

```
.claude-plugin/    plugin + marketplace manifests
hooks/             plugin-level PreToolUse guard
skills/messengerr/ the skill itself
  SKILL.md         workflow + hard rules + inline hook
  references/      commands, templates, html-email, ledger/resume, troubleshooting
  assets/          letterhead starter template
  scripts/         dry_run.sh, csv_check.rb, ledger_summary.rb, guard_send.sh
tests/             script tests + manual behavior evals (tests/evals.md)
build/             reproducible release tarball + commands.md generator
```

## Compatibility

Requires **messengerr ≥ 0.2.0** (the flag-based `send` interface and the interactive-terminal send guard ship in 0.2.0).

## Reviewing before install

The skill is instructions plus a few small scripts that later run as the user. Before installing, read `SKILL.md` and the four files under `scripts/` — they're short and make no network calls. `messengerr skill install` verifies a pinned SHA-256 before extracting and never executes downloaded content; `--from PATH` skips verification and says so.

## Development

```sh
rake test   # minitest suite over the scripts (no real sends anywhere)
```

Releases: tag `vX.Y.Z` — the release workflow validates manifests, runs tests, builds a **reproducible** tarball (sorted entries, zeroed mtimes/owner, normalized gzip header) plus `.sha256`, and attaches both to the GitHub release. The gem pins that SHA-256.

## Security

Report issues per `SECURITY.md`. Maintainers: keep MFA on, protect `main`, tag only via the release workflow.
