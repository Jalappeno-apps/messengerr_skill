# Changelog

## [0.1.0] - 2026-10-27

First release: a Claude Code skill and plugin for [messengerr](https://github.com/Jalappeno-apps/messengerr) 0.2.0 or newer.

- **Workflow:** check the CLI, check what is configured (read-only), inspect the CSV, write the message (one line, a multi-line file, or an HTML email), dry-run, hand the exact command to the human, then summarise the ledger.
- **Claude prepares and dry-runs; the human sends.** Hard rules, a narrow `allowed-tools` list, a guard hook, and the CLI's own "a real send needs a terminal" check.
- **`scripts/guard.rb`:** a PreToolUse guard that parses commands like a shell (quotes, `&&` `;` `|`, `$( )`, backticks, comments, variables, `bash -c`, `eval`, script files) instead of matching substrings. It blocks a real `messengerr send` (a standalone `--dry-run`, `--help` or `-h` is the only exemption), `--allow-non-interactive`, `credentials setup|delete`, and access to the messengerr config directory through Bash, Read, Grep, Glob, Edit and Write. Registered by the skill (with a strict built-in fallback if the script cannot be found) and by the plugin. It does not interfere with other projects' own `config/master.key`.
- **Scripts:** `dry_run.sh` (never prompts, prints the real command for the human), `csv_check.rb` (counts only), `ledger_summary.rb` (addresses and numbers in provider reasons are masked).
- **References:** `commands.md` is generated from the real CLI (pinned in `.messengerr-version`); templates, HTML email, ledger and resume, and troubleshooting written against the real behaviour and messages.
- **Letterhead starter:** one placeholder, no consent claim, no external resources.
- **Tests:** a table-driven guard corpus plus a mutation test, structure tests (manifests, `hooks.json` shape, `allowed-tools`), docs-versus-CLI checks, tarball tests, and tests that drive the real CLI.
- **Release tarball:** built from `git ls-files` with an allow-list, reproducible on one machine, hash recorded by CI.
