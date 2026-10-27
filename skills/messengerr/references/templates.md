# Message templates

Templates are **placeholders only**: no logic, no loops, no conditionals, no filters. If different people need
different wording, use separate CSVs and separate runs, or put the variation in a CSV column.

## Syntax

`{{column_name}}`: letters, digits and underscores. Spaces just inside the braces are fine (`{{ name }}`).

- Every placeholder in the **message and the subject** must be mapped: `--map placeholder=column`.
- Values are trimmed of leading and trailing whitespace.
- Substitution happens once: a CSV value that itself contains `{{x}}` is inserted as-is, never expanded again.
- The subject follows the same rules (email only).

## What aborts the run

Rows are rendered while building the preview. The **first** row that cannot render stops the whole run, with its
row number, before anything is sent:

- `no column mapped for placeholder {{x}}`: a placeholder without a `--map`.
- `column "X" is empty for {{y}}`: an empty cell for a mapped placeholder.
- `unrenderable placeholder left in message: ...`: any `{{` or `}}` still present after substitution. So
  `{{first-name}}`, `{{first name}}`, `{{}}`, and logic such as `{{#if x}}...{{/if}}` or `{{ name | upcase }}` are
  refused rather than sent as literal text. Nothing inside braces is ever evaluated.

A literal `{{` or `}}` therefore cannot appear in a message.

## HTML escaping

With `--html`, every substituted CSV value is HTML-escaped (`Tom & <b>Jerry</b>` appears as that literal text), so
CSV data cannot add markup. The template's own HTML is trusted. A value placed inside an `href` is not checked as a
URL. The subject is plain text and is never escaped.

## Example

```
Hi {{first_name}}, your code {{code}} expires Friday.
```

With `--map first_name=first_name --map code=code` and a row `first_name=Alice, code=A7Q`, the message is
`Hi Alice, your code A7Q expires Friday.` Email subjects take placeholders too:
`--subject "Welcome aboard, {{first_name}}"`.
