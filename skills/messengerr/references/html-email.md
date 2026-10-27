# HTML email with messengerr

`--html FILE` sends the file as an HTML email — **HTML only, no plain-text
part**. Email method only; the CLI refuses `--html` for integrations that
don't declare HTML support, so markup never arrives as literal text.

## What email clients honor

- **Tables for layout** — not `div`/`flex`/`grid`.
- **Inline CSS only** — most clients strip `<style>` blocks and all external
  stylesheets.
- **No external images unless hosted** — use fully-qualified `https://` URLs
  and always `alt` text; many clients block images by default.
- **No** JavaScript, forms, video, custom webfonts, `position`, or CSS
  animations. Outlook desktop uses Word's renderer — expect the least.
- Keep width ≤ 600px; a single centered table column reads fine everywhere.
- Background colors on `td`/`body` are more reliable than on wrappers.

## Workflow

1. Start from `assets/letterhead-template.html` — a neutral, table-based
   layout with inline styles and a `{{content}}` body area plus any
   `{{placeholders}}` you add.
2. Placeholders work in the HTML exactly like plain text — `{{first_name}}`
   inside the file is extracted and mapped. Preview via `dry_run.sh --html …`
   and open the generated `messengerr-preview.html` to eyeball it.
3. Watch for template-like sequences in HTML (e.g. `{{ }}` inside inline CSS
   or comments) — the leftover-placeholder guard refuses them.

## Gotchas

- `{{content}}`-style slots in the letterhead are just placeholders like any
  other — they still need a mapped column or they fail at render.
- Sending HTML means there is no text fallback for clients/users that prefer
  plain text — say so when it matters (accessibility, spam scores).
- Keep the file under typical message size limits (~100KB clipped in Gmail).
