#!/usr/bin/env ruby
# generate_commands.rb — regenerates references/commands.md from the installed
# CLI's --help output so the docs can't drift from the binary. CI runs this
# and diffs the result.
require "open3"

ROOT = File.expand_path("..", __dir__)
OUT = File.join(ROOT, "skills/messengerr/references/commands.md")

def help(*args)
  out, _err, status = Open3.capture3("messengerr", *args)
  abort("generate_commands: `messengerr #{args.join(' ')}` failed") unless status.success?
  out.strip
end

doc = <<~MD
  # messengerr command reference

  <!-- GENERATED from the CLI's own --help output (see build/generate_commands.rb).
       Do not edit by hand — CI regenerates and diffs this file. -->

  ## Top level

  ```
  #{help("--help")}
  ```

  ## credentials

  ```
  #{help("credentials", "--help")}
  ```

  ## send

  ```
  #{help("send", "--help")}
  ```

  Without flags the wizard prompts for everything interactively. Flags skip
  their prompts; anything still missing is asked for.

  **Exit codes:** `0` = all sent (or dry run), `1` = failures remain / aborted /
  error.

  **Send guard:** a non-`--dry-run` send requires an interactive terminal (stdin
  TTY). Agents and CI hit "Refusing to send without an interactive terminal" —
  that is the intended behaviour; `--allow-non-interactive` is the documented
  escape hatch for the user's own scripts.

  ## integrations

  Lists registered integrations grouped by delivery method (`email`, `sms`)
  with configured/not-configured state.

  ## skill

  ```
  #{help("skill", "--help")}
  ```
MD

File.write(OUT, doc)
puts "wrote #{OUT}"
