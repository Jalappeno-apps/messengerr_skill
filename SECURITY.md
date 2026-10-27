# Security policy

This skill ships instructions and small scripts that later run with the installing user's privileges, so release integrity is security-critical.

## Reporting a vulnerability

Please **do not open a public issue** for a send-guard bypass, a credential-handling problem or a supply-chain concern.

Report it privately by either:

- GitHub's private vulnerability reporting (this repository's **Security** tab, then **Report a vulnerability**), or
- email to developers@daiwick.com with "messengerr_skill security" in the subject.

Include what you found and steps to reproduce it. **Never include real credentials, API keys or contact lists.** We will acknowledge your report and tell you what we plan to do. Please allow a reasonable time to fix a problem before disclosing it.

## What is in scope

- Any way to make Claude run a real `messengerr send` while this skill is active.
- Any way to read, print or write messengerr credentials or the master key through a tool the guard claims to cover.
- A tarball or release that contains more or different files than the tracked skill files.
- Scripts that print contact data or credentials.

Known limits (a crashing hook fails open, shell indirection, a faked terminal) are documented in the README and are not vulnerabilities by themselves, but a concrete new bypass of the guard **is** in scope and will get a test.

## Supported versions

The latest release only.
