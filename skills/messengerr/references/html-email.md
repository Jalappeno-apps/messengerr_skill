# HTML email with messengerr

`--html FILE` sends the file as an HTML email. It is **HTML only**: there is no plain-text version. It works for
the email method only, and only for integrations that can send HTML (Postmark). Otherwise messengerr refuses it, so
markup never arrives as literal text.

## What email clients honour

- **Tables for layout**, not `div`, flex or grid.
- **Inline CSS only**: many clients strip `<style>` blocks and external stylesheets.
- **Images only from a public `https://` address**, always with `alt` text. Many clients block images by default;
  data URIs are blocked by many.
- **No** JavaScript, forms, video, custom web fonts or CSS animations. Outlook for Windows uses Word's renderer and
  supports the least.
- Keep the width to about 600px in a single centred column. Gmail clips messages over roughly 100 KB.

## Workflow

1. Start from `assets/letterhead-template.html`: a neutral table layout. **Write the message text directly in the
   template.** Only `{{name}}` is a placeholder; edit the marked regions.
2. Every placeholder you add needs a `--map placeholder=column`, and the CSV needs that column.
3. Dry-run with `dry_run.sh ... --html letter.html`, then open the `messengerr-preview.html` it writes in the current
   directory. It shows the first recipient's message as it will be sent.
4. Any `{{` or `}}` in the file (including inside CSS or comments) is treated as a placeholder and aborts the run.

## Gotchas

- A column used as a body slot (for example `{{content}}`) is HTML-**escaped**, so markup stored in a CSV cell shows
  up as text. Put markup in the template, not in the data.
- No plain-text fallback exists: say so when accessibility or spam filtering matters.
- messengerr does not add an unsubscribe link or any consent wording. The sender must include whatever the law
  requires for their recipients.
