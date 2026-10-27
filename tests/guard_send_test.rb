require_relative "test_helper"

class GuardSendTest < Minitest::Test
  BLOCKED = [
    "messengerr send",
    "messengerr send --resume old.jsonl",
    "messengerr send --batch-size 10",
    "echo y | messengerr send",
    "bash -c 'messengerr send'",
    "ls && messengerr send",
    "ls; messengerr send",
    "MESSENGERR_CONFIG_DIR=/tmp messengerr send",
    "/usr/local/bin/messengerr send",
    "cd /tmp && messengerr send --ledger out.jsonl",
    "messengerr send --dry-run --allow-non-interactive",
    "messengerr send --allow-non-interactive --dry-run",
    "cat ~/.config/messengerr/credentials.yml.enc",
    "cat ~/.config/messengerr/master.key",
    "echo $MESSENGERR_MASTER_KEY",
    "export MESSENGERR_MASTER_KEY=abc && messengerr send --dry-run"
  ].freeze

  ALLOWED = [
    "messengerr send --dry-run",
    "messengerr send --dry-run --csv contacts.csv --contact email",
    "messengerr send --help",
    "messengerr --version",
    "messengerr credentials list",
    "messengerr integrations",
    "ls -la",
    "ruby skills/messengerr/scripts/csv_check.rb contacts.csv",
    "git status"
  ].freeze

  def test_blocks_real_sends
    BLOCKED.each do |command|
      _out, err, status = run_guard(command)
      assert_equal 2, status.exitstatus, "expected block for: #{command}"
      assert_match(/messengerr guard/, err, "expected reason for: #{command}")
    end
  end

  def test_allows_safe_commands
    ALLOWED.each do |command|
      _out, err, status = run_guard(command)
      assert_equal 0, status.exitstatus, "expected allow for: #{command} (stderr: #{err})"
    end
  end

  def test_allows_empty_and_malformed_payloads
    _out, _err, status = run_script("guard_send.sh", stdin: "")
    assert_equal 0, status.exitstatus

    _out, _err, status = run_script("guard_send.sh", stdin: "not json")
    assert_equal 0, status.exitstatus
  end

  # Mutation checks: weaken a pattern and a test must fail.
  def test_mutation_block_list_is_reached
    assert_includes BLOCKED.map { |c| run_guard(c)[2].exitstatus }.uniq, 2
  end
end
