# Ledger and resume

Every send is recorded as it happens in a JSONL ledger — one line per
recipient. Default path: `./messengerr-ledger-<UTC-timestamp>.jsonl`
(`--ledger PATH` to choose). The ledger is the durable record: a crash,
Ctrl-C, or dead laptop loses nothing already recorded.

## Line format

```json
{"row_number":2,"contact":"a@x.com","status":"sent","reason":null,
 "provider_id":"abc-123","uncertain":false,"sent_at":"...Z"}
```

- `status`: `sent` or `failed`.
- `reason`: provider/render error text for failures (null when sent).
- `provider_id`: the provider's message id when accepted.
- `uncertain`: **true means the provider may have delivered anyway** —
  timeouts, dropped connections, unreadable responses. Definite rejections
  (4xx, invalid recipient) are `uncertain: false`.

## Privacy

The ledger contains contact addresses. Treat it like the CSV — don't paste it
into chat, don't commit it. `ledger_summary.rb` prints counts, row numbers,
and reasons only.

## Resume

```bash
messengerr send --resume messengerr-ledger-<time>.jsonl ...same flags
```

`--resume` implies `--ledger` on the same file: every contact already
`sent` is skipped, everything else retries. Always resume with the same
message/mapping or you'll mix sends in one ledger.

## Retrying failures

Before retrying anything `uncertain`, tell the user: these may already be
delivered, so a retry can send duplicates. The CLI warns at the retry prompt
as well. Definite failures (invalid recipient, 4xx) are safe to retry after
the cause is fixed.
