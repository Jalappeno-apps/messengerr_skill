# Message templates

Templates are **placeholders only** — no logic, no loops, no conditionals,
no filters. If a message needs per-recipient logic, put the logic in the CSV
(a precomputed column) not in the template.

## Syntax

`{{column_name}}` — letters, digits, underscores; surrounding spaces are
tolerated: `{{ name }}` works.

- Every placeholder found in the **message body and the subject** must be
  mapped to a CSV column (interactively, or `--map placeholder=column`).
- Rendering substitutes the row's value for that column, stripped of
  surrounding whitespace.
- Rendering is a single pass — a CSV value that itself contains `{{...}}` is
  inserted literally and **not** re-expanded.

## Failures

- Unmapped placeholder → row fails with `no column mapped for placeholder`.
- Empty column value for a mapped placeholder → row fails with
  `column "X" is empty for {{y}}`.
- **Anything left that looks like `{{` or `}}` after rendering → the row
  fails.** `{{first-name}}` and `{{first name}}` are not placeholders — they
  don't match the pattern, they never get mapped, and the send refuses them
  rather than sending literal braces. Use `[brackets]` or single braces in
  prose that mentions the syntax.

## Examples

Message:

```
Hi {{first_name}}, your code {{code}} expires Friday.
```

With `--map first_name=first_name --map code=code` and a CSV row
`first_name=Alice, code=A7Q`, the rendered body is
`Hi Alice, your code A7Q expires Friday.`

Email subjects take placeholders too:

```
--subject "Welcome aboard, {{first_name}}"
```
