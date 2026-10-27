# Ledger and resume

Every real send is recorded as it happens in a JSONL ledger, one line per recipient. Default path:
`./messengerr-ledger-<UTC-time>.jsonl` (`--ledger PATH` to choose). It is created owner-only (`0600`).
A crash, Ctrl-C or lost connection loses nothing already recorded. `--dry-run` writes no ledger.

## Line format

```json
{"row_number":2,"contact":"a@x.com","status":"sent","reason":null,"provider_id":"abc-123","uncertain":false,"sent_at":"2026-10-27T09:15:02Z"}
```

| Field | Meaning |
|---|---|
| `row_number` | The CSV row (the header is row 1) |
| `contact` | The normalised address or E.164 number |
| `status` | `sent` or `failed`. `sent` means the provider **accepted** it, not that it was delivered |
| `reason` | Why it failed, or `null` |
| `uncertain` | `true`: the provider **may have delivered anyway** |

## Uncertain failures

A failure is **definite** when the provider clearly rejected it (for example an invalid address or a 4xx). It is
**uncertain** when messengerr did not get a clear answer: a timeout after sending, a dropped connection, a 5xx, an
unreadable response, a missing per-message status, an interrupted run (`interrupted`), or
`integration returned no result`. Retrying an uncertain failure can send a duplicate.

Tell the user this before any retry, and suggest checking the provider's activity log first.

## Resume

```bash
messengerr send --resume messengerr-ledger-<time>.jsonl <the same flags as before>
```

The human runs this in their own terminal. messengerr skips every recipient the ledger records as `sent`, prints
`Resuming: N already sent, M remaining.`, shows the preview and asks for confirmation as usual. New results are
appended to the same ledger.

- **A recipient is matched by row number plus contact**, never by contact alone: if an address appears on rows 2 and
  5 and only row 2 was sent, row 5 is still sent (one row is one message).
- Because row numbers are part of the match, **the CSV must not change between the run and its resume**. Inserted or
  removed rows shift the numbers and can cause skips or duplicates.
- The ledger does not store the message or the mapping, so the same flags are needed again.
- If any earlier attempt ended uncertain and never succeeded, resume warns about those contacts before the
  confirmation (`... may receive duplicates`).
- A wrong `--resume` path stops with `resume ledger not found` instead of sending to everyone.

## Privacy

The ledger contains contact addresses and numbers. Treat it like the CSV: do not paste it into chat, do not commit it.
`ledger_summary.rb` prints counts, row numbers and reasons only, and masks addresses and numbers inside reasons.

## Ctrl-C

Everything already reported is in the ledger. Sends that were in flight and had not reported back are recorded as
failed and uncertain with the reason `interrupted`. messengerr prints the ledger path and the `--resume` command, and
exits with code `130`.
