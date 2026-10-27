require_relative "test_helper"
require "tmpdir"
require "fileutils"

class DryRunTest < Minitest::Test
  def setup
    @bin = Dir.mktmpdir
    ENV["MESSENGERR_STUB_BIN"] = @bin
    write_stub("messengerr", <<~SH)
      #!/usr/bin/env bash
      if [ "$1" = "--version" ]; then echo "0.2.0"; exit 0; fi
      echo "STUB: $*" > "$MESSENGERR_STUB_LOG"
      exit 0
    SH
    @log = File.join(@bin, "stub.log")
    ENV["MESSENGERR_STUB_LOG"] = @log
  end

  def teardown
    ENV.delete("MESSENGERR_STUB_BIN")
    ENV.delete("MESSENGERR_STUB_LOG")
    FileUtils.remove_entry(@bin)
  end

  def write_stub(name, contents)
    path = File.join(@bin, name)
    File.write(path, contents)
    File.chmod(0o755, path)
  end

  def test_passes_dry_run_to_send
    _out, _err, status = run_script("dry_run.sh", "--csv", "x.csv", "--contact", "email")
    assert_equal 0, status.exitstatus
    assert_equal "STUB: send --dry-run --csv x.csv --contact email\n", File.read(@log)
  end

  def test_refuses_allow_non_interactive
    _out, err, status = run_script("dry_run.sh", "--allow-non-interactive")
    assert_equal 1, status.exitstatus
    assert_match(/not allowed/, err)
  end

  def test_refuses_old_cli
    write_stub("messengerr", <<~SH)
      #!/usr/bin/env bash
      if [ "$1" = "--version" ]; then echo "0.1.0"; exit 0; fi
      exit 0
    SH
    _out, err, status = run_script("dry_run.sh", "--csv", "x.csv")
    assert_equal 1, status.exitstatus
    assert_match(/too old/, err)
  end

  def test_missing_cli
    ENV.delete("MESSENGERR_STUB_BIN")
    empty = Dir.mktmpdir
    _out, err, status = run_script("dry_run.sh", "--csv", "x.csv",
                                   env: { "PATH" => "#{empty}:/usr/bin:/bin" })
    assert_equal 1, status.exitstatus
    assert_match(/not found/, err)
  ensure
    FileUtils.remove_entry(empty)
  end
end
