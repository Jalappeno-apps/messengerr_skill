# Security Policy

The skill ships instructions and small scripts that later run with the
installing user's privileges — treat release integrity as security-critical.

## Reporting

Report vulnerabilities via a GitHub private security advisory on this repo,
or email the maintainers listed on the Jalappeno-apps org page. Do not open a
public issue for credential-handling or send-guard bypasses.

## Supported versions

Latest release only.

## Notes for users

- `messengerr skill install` verifies a pinned SHA-256 before writing; use
  `--from PATH` only for sources you built or reviewed yourself.
- Review `SKILL.md` and `scripts/*` before installing — they are small by
  design and make no network calls.
