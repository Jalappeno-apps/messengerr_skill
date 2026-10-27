require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "stringio"

# The guard under test. GUARD_PATH lets the mutation tests point this suite at a
# deliberately broken copy; it must fail there.
GUARD_FILE = ENV.fetch("GUARD_PATH", File.join(SCRIPTS, "guard.rb"))
load GUARD_FILE

class GuardTest < Minitest::Test
  def setup
    @home = Dir.mktmpdir("guard-home")
    @project = File.join(@home, "project")
    FileUtils.mkdir_p(File.join(@home, ".config", "messengerr"))
    FileUtils.mkdir_p(@project)
    @saved_home = ENV["HOME"]
    ENV["HOME"] = @home
    @custom = File.join(@home, "elsewhere", "msgr")
    @script = File.join(@project, "campaign.sh")
  end

  def teardown
    ENV["HOME"] = @saved_home
    FileUtils.remove_entry(@home)
  end

  # → reason string when blocked, nil when allowed
  def verdict(command, tool: "Bash", extra: {}, env: {})
    input = tool == "Bash" ? { "command" => command } : extra
    MessengerrGuard.check({ "tool_name" => tool, "tool_input" => input, "cwd" => @project }, env: env)
  end

  def assert_blocked(command, **opts)
    refute_nil verdict(command, **opts), "expected BLOCK for: #{command.inspect}"
  end

  def assert_allowed(command, **opts)
    assert_nil verdict(command, **opts), "expected ALLOW for: #{command.inspect}"
  end

  # ------------------------------------------------------------ real sends

  REAL_SENDS = [
    "messengerr send",
    "messengerr send --resume old.jsonl",
    "messengerr send --batch-size 10",
    "messengerr send --method email --csv contacts.csv --contact email --map name=name --message hi --subject s",
    # the audit's bypasses: a "-h" SUBSTRING is not the help flag
    "messengerr send --html letter.html",
    "messengerr send --ledger my-holiday.jsonl",
    "messengerr send --from sales-hq@x.com",
    "messengerr send --message-file dry-run.txt",
    "messengerr send --message 'finish with --dry-run later'",
    # comments and later lines are not part of the command
    "messengerr send # --dry-run",
    "messengerr send\necho --dry-run",
    "messengerr send \\\n  --csv a.csv",
    # chained / piped
    "messengerr send --dry-run && messengerr send",
    "messengerr send --dry-run; messengerr send",
    "messengerr send --dry-run || messengerr send",
    "messengerr send --dry-run | messengerr send",
    "messengerr send --dry-run & messengerr send",
    "ls && messengerr send",
    "ls; messengerr send",
    "echo y | messengerr send",
    "yes | messengerr send",
    "cd /tmp && messengerr send --ledger out.jsonl",
    "MESSENGERR_CONFIG_DIR=/tmp messengerr send",
    "/usr/local/bin/messengerr send",
    "~/.local/bin/messengerr send",
    # the escape hatch is never for Claude
    "messengerr send --dry-run --allow-non-interactive",
    "messengerr send --allow-non-interactive --dry-run",
    "messengerr send --allow-non-interactive",
    # substitutions, groups, functions
    "echo $(messengerr send)",
    "echo `messengerr send`",
    'echo "$(messengerr send)"',
    'echo "`messengerr send`"',
    "( messengerr send )",
    "{ messengerr send; }",
    "f() { messengerr send; }; f",
    "if true; then messengerr send; fi",
    "for i in 1 2; do messengerr send; done",
    # wrappers
    "sudo messengerr send",
    "env messengerr send",
    "env FOO=1 messengerr send",
    "time messengerr send",
    "nohup messengerr send &",
    "bundle exec messengerr send",
    "ruby exe/messengerr send",
    "ruby -S messengerr send",
    "xargs messengerr send",
    "timeout 5 messengerr send",
    "script -q /dev/null messengerr send",
    "ssh host messengerr send",
    "command messengerr send",
    "exec messengerr send",
    # variables and globs hiding the program
    "m=messengerr; $m send",
    "m=messengerr\n$m send",
    "m=messeng; ${m}err send",
    'cmd="messengerr send"; $cmd',
    'cmd="messengerr send"; eval "$cmd"',
    "mess* send",
    "m?ssengerr send",
    # nested interpreters
    "bash -c 'messengerr send'",
    'sh -c "messengerr send"',
    'bash -lc "messengerr send"',
    "zsh -c 'cd /tmp && messengerr send'",
    "eval messengerr send",
    "eval 'messengerr send'",
    "echo 'messengerr send' | bash",
    "printf 'messengerr send\\n' | sh",
    "echo bWVzc2VuZ2VyciBzZW5k | base64 -d | sh",
    "ruby -e 'system(\"messengerr send\")'",
    %q(python3 -c "import os; os.system('messengerr send')"),
    "node -e \"require('child_process').execSync('messengerr send')\"",
    # secrets handling is the human's job
    "messengerr credentials setup postmark",
    "messengerr credentials delete",
    "messengerr credentials delete --purge"
  ].freeze

  def test_blocks_every_real_send
    REAL_SENDS.each { |command| assert_blocked(command) }
  end

  def test_blocks_scripts_that_contain_a_real_send
    File.write(@script, "#!/bin/bash\nmessengerr send --csv x.csv\n")
    ["bash #{@script}", "sh #{@script}", "source #{@script}", ". #{@script}", "bash campaign.sh"].each do |command|
      assert_blocked(command)
    end
    File.write(@script, "puts `messengerr send`\n")
    assert_blocked("ruby #{@script}")
  end

  def test_allows_a_script_that_only_dry_runs
    File.write(@script, "messengerr send --dry-run --csv x.csv\n")
    assert_allowed("bash #{@script}")
  end

  # ------------------------------------------------------------ safe commands

  SAFE = [
    "messengerr send --dry-run",
    "messengerr send --help",
    "messengerr send -h",
    "messengerr --version",
    "messengerr credentials list",
    "messengerr credentials verify postmark",
    "messengerr integrations",
    "messengerr send --dry-run --html letter.html",
    "messengerr send --html letter.html --dry-run",
    "messengerr send --method email --csv contacts.csv --contact email --map name=name --message 'Hi {{name}}' --subject Hello --dry-run",
    "messengerr send --method email \\\n  --csv contacts.csv --dry-run",
    "env VAR=x messengerr send --dry-run",
    "ls && messengerr send --dry-run",
    "gem install messengerr",
    "gem update messengerr",
    "gem uninstall messengerr",
    "ls ~/messengerr-sendgrid-notes",
    "cd messengerr && ls",
    'git commit -m "docs: messengerr send --html flag"',
    'echo "run messengerr send later"',
    'grep -rn "messengerr send" docs',
    "git status",
    "bundle exec rspec",
    "ruby skills/messengerr/scripts/csv_check.rb contacts.csv",
    "skills/messengerr/scripts/dry_run.sh --method email --csv contacts.csv",
    "bash -c 'ls -la'",
    "ruby -e 'puts 1'",
    "python3 -c 'print(1)'",
    "echo $HOME",
    "printenv HOME",
    "env FOO=bar ls",
    "export FOO=1",
    "set -e",
    "ls ~/.config/git",
    "cat ~/.config/git/config",
    "grep -r TODO .",
    "find . -name '*.rb'",
    "echo hello # a comment mentioning messengerr send"
  ].freeze

  def test_allows_safe_commands
    SAFE.each { |command| assert_allowed(command) }
  end

  def test_allows_rails_secrets_in_other_projects
    # Rails has config/master.key and config/credentials.yml.enc too. Blocking by
    # file NAME would break every Rails user who enables the plugin.
    ["cat config/master.key", "cat config/credentials.yml.enc", "rails credentials:edit", "cat ./config/master.key"].each do |command|
      assert_allowed(command)
    end
  end

  # ------------------------------------------------------------ credentials

  def cred(path) = File.join(@home, ".config", "messengerr", path)

  CRED_COMMANDS = [
    "cat ~/.config/messengerr/master.key",
    "cat ~/.config/messengerr/credentials.yml.enc",
    "base64 < ~/.config/messengerr/credentials.yml.enc",
    "cp ~/.config/messengerr/master.key /tmp/k",
    "cat $HOME/.config/messengerr/master.key",
    'cat "${HOME}/.config/messengerr/master.key"',
    "cat ~/.config/messengerr/../messengerr/master.key",
    "cat ~/.config/messeng*/master.*",
    "cat ~/.config/messengerr/*",
    "cat ~/.config/messengerr/{master.key,credentials.yml.enc}",
    "cd ~/.config && cat messengerr/m*",
    "cd ~/.config/messengerr && cat master.key",
    "cd ~/.config/messengerr; ls",
    "ls ~/.config/messengerr",
    "grep -r . ~/.config",
    "find ~/.config -type f",
    "tar czf x.tgz ~/.config",
    "rsync -a ~/.config/ /tmp/x/",
    "echo $MESSENGERR_MASTER_KEY",
    "printenv MESSENGERR_MASTER_KEY",
    "export MESSENGERR_MASTER_KEY=abc && messengerr send --dry-run",
    "env",
    "printenv",
    "env | grep -i master",
    "export -p",
    "set",
    "declare -p",
    "declare -x",
    "compgen -v",
    "rm ~/.config/messengerr/master.key",
    "echo x > ~/.config/messengerr/master.key",
    "2>&1 cat ~/.config/messengerr/master.key",
    "ruby -e 'puts File.read(File.expand_path(\"~/.config/messengerr/master.key\"))'",
    "python3 -c \"print(open('/home/u/.config/messengerr/master.key').read())\""
  ].freeze

  def test_blocks_credential_access_through_bash
    CRED_COMMANDS.each { |command| assert_blocked(command) }
  end

  def test_blocks_a_custom_config_dir
    env = { "MESSENGERR_CONFIG_DIR" => @custom }
    assert_blocked("cat #{@custom}/master.key", env: env)
    assert_blocked("cat $MESSENGERR_CONFIG_DIR/master.key", env: env)
    assert_blocked("cd #{@custom} && cat credentials.yml.enc", env: env)
    assert_blocked("cat ~/.config/messengerr/master.key", env: env) # the default store stays protected too
    assert_allowed("ls #{@home}/elsewhere", env: env)
  end

  def test_blocks_credential_access_through_other_tools
    cfg = File.join(@home, ".config", "messengerr")
    assert_blocked(nil, tool: "Read", extra: { "file_path" => "#{cfg}/master.key" })
    assert_blocked(nil, tool: "Read", extra: { "file_path" => "~/.config/messengerr/credentials.yml.enc" })
    assert_blocked(nil, tool: "Read", extra: { "file_path" => "../.config/messengerr/master.key" })
    assert_blocked(nil, tool: "Edit", extra: { "file_path" => "#{cfg}/master.key" })
    assert_blocked(nil, tool: "Write", extra: { "file_path" => "#{cfg}/credentials.yml.enc" })
    assert_blocked(nil, tool: "Grep", extra: { "pattern" => "x", "path" => cfg })
    assert_blocked(nil, tool: "Grep", extra: { "pattern" => "x", "path" => "~/.config" })
    assert_blocked(nil, tool: "Glob", extra: { "pattern" => "#{cfg}/*" })
    assert_blocked(nil, tool: "Glob", extra: { "pattern" => "~/.config/messeng*/master.*" })
    assert_blocked(nil, tool: "Glob", extra: { "pattern" => "*.enc", "path" => "~/.config" })
  end

  def test_allows_ordinary_tool_use
    assert_allowed(nil, tool: "Read", extra: { "file_path" => "#{@project}/README.md" })
    assert_allowed(nil, tool: "Read", extra: { "file_path" => "~/.config/git/config" })
    assert_allowed(nil, tool: "Read", extra: { "file_path" => "config/master.key" }) # a Rails project's own file
    assert_allowed(nil, tool: "Edit", extra: { "file_path" => "#{@project}/CHANGELOG.md" })
    assert_allowed(nil, tool: "Write", extra: { "file_path" => "#{@project}/copy.txt" })
    assert_allowed(nil, tool: "Grep", extra: { "pattern" => "TODO", "path" => "lib" })
    assert_allowed(nil, tool: "Glob", extra: { "pattern" => "**/*.rb" })
    assert_allowed(nil, tool: "WebFetch", extra: { "url" => "https://example.com" })
  end

  # ------------------------------------------------------------ edge cases

  def test_empty_and_odd_inputs_are_allowed
    assert_allowed("")
    assert_allowed("   ")
    assert_allowed("# just a comment")
    assert_nil MessengerrGuard.check({ "tool_name" => "Bash", "tool_input" => nil }, env: {})
    assert_nil MessengerrGuard.check({}, env: {})
  end

  def test_deep_nesting_fails_closed
    command = "ls"
    9.times { command = "bash -c #{command.inspect}" }
    refute_nil verdict(command)
  end

  def test_moderate_nesting_is_still_analysed
    assert_blocked("bash -c \"bash -c 'messengerr send'\"")
    assert_allowed("bash -c \"bash -c 'ls'\"")
  end

  def test_the_reason_never_echoes_the_command
    reason = verdict("messengerr send --ledger secret-token-123.jsonl")
    refute_includes reason, "secret-token-123"
  end

  # A crashing hook exits non-2, and Claude Code then lets the call through. So when
  # the guard itself breaks on something that looks like a send, it must still block.
  def run_with_crash(command)
    payload = JSON.dump("tool_name" => "Bash", "tool_input" => { "command" => command })
    err = StringIO.new
    original = MessengerrGuard.method(:check)
    MessengerrGuard.singleton_class.send(:define_method, :check) { |*| raise "boom" }
    begin
      code = MessengerrGuard.run(stdin: StringIO.new(payload), stderr: err, env: {})
    ensure
      MessengerrGuard.singleton_class.send(:define_method, :check, original)
    end
    [ code, err.string ]
  end

  def test_an_internal_error_on_a_send_still_blocks
    code, message = run_with_crash("messengerr send --csv x.csv")
    assert_equal 2, code
    assert_match(/internal error \(RuntimeError\); blocked to be safe/, message)
  end

  def test_an_internal_error_on_something_harmless_does_not_block
    assert_equal 0, run_with_crash("ls -la").first
    assert_equal 0, run_with_crash("messengerr send --dry-run").first
  end

  # ------------------------------------------------------------ real process

  def run_guard_process(payload_json)
    out, err, status = Open3.capture3({ "HOME" => @home }, RbConfig.ruby, GUARD_FILE, stdin_data: payload_json, chdir: @project)
    [ out, err, status.exitstatus ]
  end

  def test_process_exit_codes_and_messages
    blocked = JSON.dump("tool_name" => "Bash", "tool_input" => { "command" => "messengerr send --html x.html" })
    out, err, code = run_guard_process(blocked)
    assert_equal 2, code
    assert_empty out
    assert_match(/\Amessengerr guard: refusing/, err)

    allowed = JSON.dump("tool_name" => "Bash", "tool_input" => { "command" => "messengerr send --dry-run" })
    out, err, code = run_guard_process(allowed)
    assert_equal [ 0, "", "" ], [ code, out, err ]
  end

  def test_unreadable_payloads
    assert_equal 0, run_guard_process("")[2]
    assert_equal 0, run_guard_process("not json")[2]
    assert_equal 2, run_guard_process("messengerr send --csv x")[2] # raw text with a real send fails closed
    assert_equal 0, run_guard_process("messengerr send --dry-run")[2]
  end
end
