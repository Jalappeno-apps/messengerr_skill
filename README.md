# messengerr_skill

A [Claude Code](https://code.claude.com) **skill and plugin** for [messengerr](https://github.com/Jalappeno-apps/messengerr), the command-line tool that sends templated email and SMS to a CSV contact list.

With it, Claude can **prepare, preview and troubleshoot** a bulk send: inspect the CSV, help write the message (plain text or an HTML letterhead), dry-run the whole thing, and explain the ledger afterwards. **Claude never sends.** It hands you the exact command, and you run it in your own terminal.

## Install

Requires **messengerr 0.2.0 or newer** (`gem install messengerr`), because the skill relies on its send flags and its "a real send needs a terminal" check.

**Option 1: plugin marketplace** (updates through the marketplace)

```
/plugin marketplace add Jalappeno-apps/messengerr_skill
```

Then install the `messengerr` plugin from the catalog.

**Option 2: copy the skill** (a personal skill, available in every project)

```sh
git clone https://github.com/Jalappeno-apps/messengerr_skill
cp -r messengerr_skill/skills/messengerr ~/.claude/skills/
```

Use `.claude/skills/` inside a repository instead to share it with a project. Start a new Claude Code session afterwards. The skill loads on its own when you ask for something like "send this newsletter to my CSV", or you can run it with `/messengerr`.

## What Claude may and may not do

| May | May not |
|---|---|
| `messengerr --version`, `credentials list`, `integrations`, `send --help` | Run `messengerr send` without `--dry-run` |
| `csv_check.rb`: CSV structure, counts only | Read, print, ask for or write credentials or the master key |
| `dry_run.sh`: a forced `--dry-run` preview that prints the real command for you | Run `credentials setup` or `delete` |
| `ledger_summary.rb`: send outcome counts, addresses masked | Paste a full contact list into the chat |
| Draft messages, letterheads and flag sets | Use `--allow-non-interactive` or fake a terminal |

## How the safety works (and where it stops)

No single mechanism is trusted. A skill is instructions, not enforcement, so there are four layers:

1. **The skill's rules.** Hard rules sit at the top of `SKILL.md`.
2. **A narrow allow-list.** `allowed-tools` pre-approves only the safe commands and the three helper scripts, never a real send, so a real send would raise a normal permission prompt.
3. **A guard hook** (`scripts/guard.rb`). It parses each command like a shell (quotes, `&&`, `;`, pipes, `$( )`, comments, variables, `bash -c`) and blocks a real send, `credentials setup/delete`, and access to the messengerr config directory through Bash, Read, Grep, Glob, Edit and Write. It runs from the skill (registered when the skill is used) and from the plugin.
4. **The CLI itself.** `messengerr send` refuses a real send unless standard input is an interactive terminal. Claude's shell has none. **This is the backstop that matters.**

Honest limits:

- A hook that crashes or exits with anything other than 2 **lets the call through**. It is a seatbelt, not a security boundary.
- Shell indirection can always hide a command from a static check. The hook blocks the common and the sneaky forms and fails closed on what it cannot parse, but it is not exhaustive.
- A program can fake a terminal, which defeats layer 4. It stops accidents, not a determined bypass.
- In "bypass permissions" mode only layers 3 and 4 apply.
- A person can always run `messengerr send` themselves. That is the point.

If a hook script cannot be found, the skill falls back to a stricter built-in rule rather than skipping the check.

## Contents

```
.claude-plugin/      plugin and marketplace manifests
hooks/hooks.json     plugin-level guard registration
skills/messengerr/
  SKILL.md           workflow, hard rules, allow-list, hook
  references/        commands (generated from the real CLI), templates, HTML email, ledger/resume, troubleshooting
  assets/            neutral letterhead starter
  scripts/           guard.rb, dry_run.sh, csv_check.rb, ledger_summary.rb
tests/               automated suite and the manual behaviour checks (tests/evals.md)
build/               release tarball builder and the commands.md generator
```

## Reviewing before you install

A skill is instructions plus a few scripts that run as you. Read `SKILL.md` and the four files in `scripts/` first: they are short and make no network calls. Never install a skill you have not read.

## Development

```sh
rake test          # unit tests, structure tests, the guard corpus and its mutation test
MESSENGERR_BIN=messengerr rake test   # also runs the tests that drive the REAL CLI
ruby build/generate_commands.rb       # regenerate references/commands.md (see AGENT.md)
```

- The guard has a large table-driven corpus, and a mutation test breaks a copy of the guard in about twenty ways and requires the corpus to fail each time.
- `references/commands.md` is generated from the real CLI. The CLI version it was generated from is pinned in `.messengerr-version`, and CI fails if regenerating changes it.
- `claude plugin validate .` (Claude Code 2.1.233 or newer) checks the plugin manifests and `SKILL.md`.
- The behaviour of the skill inside a real Claude Code session cannot be tested automatically. Follow `tests/evals.md`.

## Releasing

Tag `vX.Y.Z` (it must match the plugin version). The release workflow runs the full test suite against the real CLI, builds the tarball once, and attaches it and its `.sha256` to the GitHub release. The tarball contains only the tracked files under `skills/messengerr/`. Its hash depends on the build machine's zlib, so always use the hash of the **released asset**, never one built locally.

## Security

See [SECURITY.md](SECURITY.md). Maintainers: keep MFA on, protect `main`, and tag only through the release workflow.

## License

[MIT](LICENSE). Maintained by [Daiwick](https://daiwick.com).
