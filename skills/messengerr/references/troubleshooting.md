# Troubleshooting — real messages → cause → fix

| Message | Cause | Fix |
|---|---|---|
| `messengerr: command not found` | Gem not installed | User runs `gem install messengerr` |
| `dry_run: messengerr 0.1.x is too old` | Flag-based dry run needs ≥ 0.2.0 | User runs `gem update messengerr` |
| `No sms integrations are configured` | No credentials stored for that method | Human runs `messengerr credentials setup <name>` |
| `Postmark verification failed` / `ClickSend verification failed` | Bad keys at setup or revoked token | Human reruns `credentials setup <name>` |
| `CSV file not found` | Wrong path (directories and URLs are rejected too) | Pass a real local file path |
| `CSV has duplicate headers: X` | Two columns share a name | Rename one column in the CSV |
| `could not parse CSV ... Invalid byte sequence` | Non-UTF-8 encoding | Convert to UTF-8 (or strip the bad bytes) |
| `invalid email address` / `invalid phone number` defects | Malformed contacts; also `empty value` and `duplicate of row N` | Fix rows, or accept dropping them at the prompt |
| `invalid phone number` on every local number | `MESSENGERR_DEFAULT_COUNTRY` unset | `export MESSENGERR_DEFAULT_COUNTRY=US` (or the right code) |
| `no column mapped for placeholder {{x}}` | Missing `--map` for a placeholder | Map every `{{placeholder}}` in body AND subject |
| `unrenderable placeholder left in message` | `{{` remains after rendering (e.g. `{{first-name}}`, `{{ }}`) | Fix the template — only `{{word}}` is a placeholder |
| `--html` refused for this integration | Integration can't send HTML (or SMS method picked) | Use a text message |
| `subject is required for email sends` | Email send without `--subject` and none prompted | Pass `--subject` |
| `Refusing to send without an interactive terminal` | Real send attempted from a non-TTY shell (agent, CI) | Human runs the command; scripts use `--allow-non-interactive` |
| `unexpected end of input` in the wizard | Wizard ran out of piped answers | Don't pipe answers — use flags, or run interactively |
| `credentials file is truncated or malformed` | Corrupted `.enc` (crash mid-write, bad edit) | `credentials delete` and set up again |
| `credentials exist but no master key is available` | `master.key` lost and `MESSENGERR_MASTER_KEY` unset | `credentials delete` and set up again; keep the env key next time |
| `credentials could not be decrypted` | Wrong master key | Check `MESSENGERR_MASTER_KEY` value |
| `[uncertain — may already be delivered]` on failures | Timeout/unreadable response; provider may have sent it | Don't blind-retry; check provider dashboard first |
| `integration returned no result` | A community integration misbehaved | Update/report the integration; those rows are safe to retry |

## Escape hatches worth knowing (for the user, not for Claude)

- `--allow-non-interactive` — documented escape for the user's own scripts.
- `--ledger` / `--resume` — see `ledger-and-resume.md`.
- `MESSENGERR_CONFIG_DIR` — relocates the credentials directory.
- `MESSENGERR_SKILLS_DIR` — relocates the installed skill directory.
