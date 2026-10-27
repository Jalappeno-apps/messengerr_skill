Read this before changing anything: this repo ships a Claude skill, which is instructions and scripts that run as the installing user.

- Never weaken the send guard, the credential protections, or the "Claude never sends" rule without a deliberate reason in the PR and a test that fails without it.
- `scripts/guard.rb` has a table-driven corpus (`tests/guard_test.rb`) and a mutation test (`tests/guard_mutation_test.rb`). Every new bypass found gets a corpus entry first. Every new rule in the guard needs a mutation entry.
- Scripts print counts and row numbers only, never contact values or credentials. They stay small, readable and network-free.
- `skills/messengerr/references/commands.md` is generated from the real CLI. Never hand-edit it. Regenerate with `ruby build/generate_commands.rb` (pointing `MESSENGERR_BIN` at the CLI) after changing the pinned version in `.messengerr-version`.
- Docs must match the real CLI: `tests/docs_test.rb` checks every flag mentioned against the generated reference. Do not describe features the CLI does not have.
- `tests/real_cli_test.rb` runs the scripts against the real CLI (set `MESSENGERR_BIN`). A stub CLI accepts anything, so only that test proves the flags exist.
- The tarball is built from `git ls-files`. Do not add dotfiles, symlinks or unusual file types under `skills/messengerr/`.
- Run `rake test` before pushing. The behaviour evals are manual: see `tests/evals.md`.
