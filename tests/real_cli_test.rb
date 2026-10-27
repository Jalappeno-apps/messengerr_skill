require_relative "test_helper"
require "tmpdir"
require "fileutils"

# Runs the skill's scripts and assets against the REAL messengerr CLI. A stub CLI
# accepts anything, so only this can catch a mismatch with the actual flags and
# behaviour. Opt in by pointing MESSENGERR_BIN at a command (CI does):
#   MESSENGERR_BIN="messengerr" rake test
class RealCliTest < Minitest::Test
  BIN = ENV["MESSENGERR_BIN"]

  def setup
    skip "set MESSENGERR_BIN to run the tests against the real CLI" unless BIN
    @dir = Dir.mktmpdir("real-cli")
    @bin = File.join(@dir, "bin")
    FileUtils.mkdir_p(@bin)
    # The launcher must call the REAL command by absolute path. If MESSENGERR_BIN is just
    # "messengerr", a launcher named messengerr that runs `messengerr` would find itself
    # first on PATH and loop forever.
    shim = File.join(@bin, "messengerr")
    File.write(shim, "#!/usr/bin/env bash\nexec #{absolute_command(BIN)} \"$@\"\n")
    File.chmod(0o755, shim)
    @config = File.join(@dir, "config")
    @work = File.join(@dir, "work")
    FileUtils.mkdir_p(@work)
    File.write(File.join(@work, "people.csv"), "name,email\nAnn,ann@example.com\nBob,not-an-email\nCy,cy@example.com\n")
    FileUtils.cp(File.join(ROOT, "skills/messengerr/assets/letterhead-template.html"), File.join(@work, "letter.html"))
    configure_postmark
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  # "messengerr" -> "/full/path/to/messengerr"; "ruby -I lib exe/messengerr" is left as is.
  def absolute_command(command)
    first, *rest = Shellwords.split(command)
    return command if first.include?("/")

    found = ENV["PATH"].split(File::PATH_SEPARATOR).map { |dir| File.join(dir, first) }.find { |path| File.file?(path) && File.executable?(path) }
    raise "cannot find #{first.inspect} on PATH" unless found

    ([ found ] + rest).shelljoin
  end

  def env
    { "PATH" => "#{@bin}:#{ENV['PATH']}", "MESSENGERR_CONFIG_DIR" => @config, "MESSENGERR_MASTER_KEY" => nil }
  end

  def cli(*args, stdin: "")
    out, err, status = Open3.capture3(env, File.join(@bin, "messengerr"), *args, stdin_data: stdin, chdir: @work)
    [ out.force_encoding(Encoding::UTF_8), err.force_encoding(Encoding::UTF_8), status ]
  end

  # Store throwaway credentials the way a human would: through the CLI's own prompts.
  # `credentials setup` verifies against the network, so write throwaway credentials
  # straight into a temp config dir instead (MESSENGERR_LIB points at a source checkout if needed).
  def configure_postmark
    code = %(require "messengerr"; Messengerr::Credentials.new.write(:postmark, "server_token" => "x", "from" => "me@example.com"))
    lib = ENV["MESSENGERR_LIB"] ? [ "-I", ENV["MESSENGERR_LIB"] ] : []
    system(env, RbConfig.ruby, *lib, "-e", code, exception: true)
  end

  def dry_run(*extra)
    out, err, status = Open3.capture3(env, File.join(SCRIPTS, "dry_run.sh"),
                                      "--method", "email", "--csv", "people.csv", "--contact", "email", "--map", "name=name",
                                      "--subject", "News for {{name}}", *extra, chdir: @work)
    [ out.force_encoding(Encoding::UTF_8), err.force_encoding(Encoding::UTF_8), status ]
  end

  def test_the_flags_the_skill_uses_exist_in_this_cli
    out, _err, _status = cli("send", "--help")
    %w[--method --integration --dry-run --csv --contact --map --message --message-file --html --subject
       --resume --ledger --allow-non-interactive].each do |flag|
      assert_includes out, flag, "the skill relies on #{flag}, which this CLI does not have"
    end
  end

  def test_dry_run_with_the_letterhead_template_previews_and_prints_the_handoff
    out, err, status = dry_run("--html", "letter.html")

    assert status.success?, "dry run failed:\n#{out}\n#{err}"
    assert_match(/1 contact\(s\) have defects/, out)
    assert_match(/Dry run — nothing sent/, out)
    assert_match(/Body: HTML, \d+ characters/, out)
    assert File.file?(File.join(@work, "messengerr-preview.html"))
    assert_match(/Hi Ann,/, File.read(File.join(@work, "messengerr-preview.html"), encoding: "utf-8"))
    assert_match(/hand-off/, out)
  end

  def test_a_plain_text_dry_run
    File.write(File.join(@work, "copy.txt"), "Hi {{name}},\n\nSecond paragraph.\n")
    out, err, status = dry_run("--message-file", "copy.txt")

    assert status.success?, "dry run failed:\n#{out}\n#{err}"
    assert_match(/Subject: News for Ann/, out)
    assert_match(/Second paragraph\./, out)
  end

  def test_the_handoff_command_is_refused_without_a_terminal_and_writes_nothing
    out, _err, status = dry_run("--message", "Hi {{name}}")
    handoff = out.lines.last.chomp
    args = Shellwords.split(handoff).drop(1) # drop "messengerr"

    refusal, _err, refused = cli(*args)

    refute refused.success?
    assert_match(/refusing to send without an interactive terminal/, refusal)
    assert_empty Dir.glob(File.join(@work, "messengerr-ledger-*")), "a refused send must not write a ledger"
  end

  def test_a_missing_flag_stops_cleanly_instead_of_hanging
    out, err, status = Open3.capture3(env, File.join(SCRIPTS, "dry_run.sh"), "--method", "email", chdir: @work)

    refute status.success?
    assert_match(/unexpected end of input/, (out + err).force_encoding(Encoding::UTF_8))
  end
end
