# Troubleshooting: messages, causes, fixes

These are messengerr 0.2.0's own messages (errors print as `messengerr: <message>` and exit 1).
Claude may explain and suggest; the **human** runs anything that touches credentials or sends.

## Setup and configuration

| Message | Cause | Fix |
|---|---|---|
| `No email integrations are configured.` (or `sms`) | No credentials stored for that delivery method | The human runs `messengerr credentials setup <name>` |
| `Unknown integration 'x'. Available: clicksend, postmark` | Misspelt integration name | Use a name from `messengerr integrations` |
| `Integration 'x' is not configured for email. Configured: ...` | `--integration` names one that has no credentials for this method | Pick one from the list it prints, or set it up |
| `Postmark verification failed: ...` / `ClickSend verification failed (401)` | Bad or revoked keys at setup | The human re-runs `credentials setup <name>` |
| `credentials could not be decrypted — master key is missing or incorrect` | Wrong `MESSENGERR_MASTER_KEY`, or `master.key` replaced | Restore the right key, or `credentials delete` and set up again (human) |
| `credentials exist but no master key is available — set MESSENGERR_MASTER_KEY or run 'messengerr credentials delete' to reset` | `master.key` is gone and the variable is unset | Same |

## The CSV

| Message | Cause | Fix |
|---|---|---|
| `CSV file not found: PATH` | Wrong path, or it is a directory | Pass a real file path |
| `CSV has duplicate headers: name` | Two columns share a name | Rename one |
| `CSV has no header row` | The first row is empty | The first row must hold column names |
| `could not parse CSV PATH: Invalid byte sequence in UTF-8` | Not a UTF-8 file | Re-save as UTF-8 (a BOM is fine) |
| defects: `invalid email address`, `invalid phone number`, `empty value` | Bad contacts, listed by row | Fix the rows, or let the preview drop them |
| `invalid phone number` for every local-format number | `MESSENGERR_DEFAULT_COUNTRY` is unset | The user sets it (for example `US`) |

Repeated addresses are **not** reported: one row is one message.

## The message

| Message | Cause | Fix |
|---|---|---|
| `row N: no column mapped for placeholder {{x}}` | A placeholder has no `--map` | Map every placeholder in the message **and** the subject |
| `row N: column "X" is empty for {{y}}` | That row has no value for the placeholder | Fill the cell or remove the row |
| `row N: unrenderable placeholder left in message: {{first-name}}` | Braces remain after rendering (`{{first-name}}`, `{{ }}`, logic like `{{#if x}}`) | Only `{{letters_digits_underscores}}` are placeholders |
| `Aborted — fix the CSV or mapping and try again.` | Follows any of the three above | The **whole run stops** at the first such row; fix it and dry-run again |

## Flags

| Message | Cause | Fix |
|---|---|---|
| `invalid option: --bogus (see 'messengerr send --help')` | Unknown flag | `messengerr send --help` |
| `--message can't be blank` (also `--subject`, `--csv`, `--contact`, `--integration`) | An empty value, often an empty shell variable | Give a value or drop the flag |
| `--map X=Y: no such column in the CSV.` / `--contact X: no such column in the CSV.` | The column name does not match a header exactly | Copy the name from the `Columns:` line |
| `Note: --map X not used: no such {{placeholder}} in the message or subject.` | A warning: you mapped a placeholder the message does not contain (often a typo) | Fix the name |
| `--subject is only for email; SMS messages have no subject` | `--subject` with `--method sms` | Drop `--subject` |
| `--html is only for email; SMS messages are plain text (use --message-file)` | `--html` with SMS | Use `--message-file` |
| `<integration> can't send HTML email` | `--html` with an integration that has no HTML support | Use a text message |
| `use either --message or --message-file/--html, not both` | Two ways to give the message | Pick one |
| `unexpected end of input` | The CLI needed an answer and input closed. With `dry_run.sh` this means **a flag is missing** | Pass every flag |

## Sending (the human's side)

| Message | Cause | Fix |
|---|---|---|
| `refusing to send without an interactive terminal: ...` | A real send from a pipe, CI or an automated shell | Correct behaviour. The human runs the command in their own terminal |
| `cannot write ledger PATH: ...` | The ledger path is not writable | Choose another with `--ledger`. Nothing was sent |
| `Stopped early: ledger write failed (...)` | The ledger became unwritable mid-run | Free space or fix permissions, then `--resume` |
| `resume ledger not found: PATH` | The `--resume` path is wrong | Use the real ledger file |
| failures marked `[uncertain — may already be delivered]` | A timeout, dropped connection, server error or unreadable response | Check the provider's activity log before retrying |
| `integration returned no result` | An integration did not report a recipient | Treated as **uncertain**: the message may have gone out |
| `ClickSend rejected the request (4xx): ...` | ClickSend refused the whole batch | Fix what the response says, then retry |
| `subject is required for email sends` | A message reached the provider with no subject | Give `--subject` |

## Not for Claude

`--allow-non-interactive` (the human's own scripts), `messengerr credentials setup|delete`, and anything under `~/.config/messengerr`.
