require_relative "test_helper"
require "tmpdir"
require "fileutils"

class DryRunTest < Minitest::Test
  def setup
    @bin = Dir.mktmpdir
    @args_log = File.join(@bin, "args.log")
    @stdin_log = File.join(@bin, "stdin.log")
    write_stub("0.2.0")
  end

  def teardown
    FileUtils.remove_entry(@bin)
  end

  # A stand-in for the CLI that records what it was asked and what it was fed.
  def write_stub(version, exit_status: 0)
    path = File.join(@bin, "messengerr")
    File.write(path, <<~SH)
      #!/usr/bin/env bash
      if [ "$1" = "--version" ]; then echo "#{version}"; exit 0; fi
      printf '%s\\n' "$*" > "#{@args_log}"
      cat > "#{@stdin_log}"
      echo "PREVIEW OUTPUT"
      exit #{exit_status}
    SH
    File.chmod(0o755, path)
  end

  def run_dry(*args, path: nil)
    env = { "PATH" => path || "#{@bin}:#{ENV['PATH']}" }
    Open3.capture3(env, File.join(SCRIPTS, "dry_run.sh"), *args)
  end

  def test_forces_dry_run_and_forwards_the_flags
    _out, _err, status = run_dry("--method", "email", "--csv", "x.csv", "--contact", "email")

    assert_equal 0, status.exitstatus
    assert_equal "send --dry-run --method email --csv x.csv --contact email\n", File.read(@args_log)
  end

  def test_never_reads_the_callers_input_and_answers_exactly_one_y
    run_dry("--csv", "x.csv")

    assert_equal "y\n", File.read(@stdin_log)
  end

  def test_ends_with_the_command_for_the_human_to_run
    out, _err, _status = run_dry("--method", "email", "--message", "Hi {{name}}, it's ready", "--subject", "A b")

    assert_match(/hand-off: the HUMAN runs this/, out)
    handoff = out.lines.last.chomp
    assert handoff.start_with?("messengerr send "), handoff
    refute_includes handoff, "--dry-run"
    # shell-quoted so a copy-paste into a terminal reproduces the exact arguments
    assert_equal [ "messengerr", "send", "--method", "email", "--message", "Hi {{name}}, it's ready", "--subject", "A b" ],
                 Shellwords.split(handoff)
  end

  def test_refuses_allow_non_interactive
    _out, err, status = run_dry("--allow-non-interactive")

    assert_equal 1, status.exitstatus
    assert_match(/not allowed/, err)
    refute File.exist?(@args_log), "the CLI must not even be called"
  end

  def test_refuses_a_cli_older_than_0_2_0
    %w[0.1.0 0.1.9 0.0.5].each do |version|
      write_stub(version)
      _out, err, status = run_dry("--csv", "x.csv")

      assert_equal 1, status.exitstatus, version
      assert_match(/too old/, err, version)
    end
  end

  def test_accepts_newer_versions_including_double_digit_minors
    %w[0.2.0 0.2.1 0.10.0 0.100.3 1.0.0 2.3.4].each do |version|
      write_stub(version)
      _out, _err, status = run_dry("--csv", "x.csv")

      assert_equal 0, status.exitstatus, version
    end
  end

  def test_passes_a_failure_through_and_prints_no_handoff
    write_stub("0.2.0", exit_status: 1)
    out, _err, status = run_dry("--csv", "x.csv")

    assert_equal 1, status.exitstatus
    refute_match(/hand-off/, out)
  end

  def test_missing_cli
    empty = Dir.mktmpdir
    _out, err, status = run_dry("--csv", "x.csv", path: "#{empty}:/usr/bin:/bin")

    assert_equal 1, status.exitstatus
    assert_match(/not found/, err)
  ensure
    FileUtils.remove_entry(empty)
  end
end
