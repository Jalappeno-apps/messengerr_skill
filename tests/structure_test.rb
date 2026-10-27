require_relative "test_helper"
require "yaml"
require "tmpdir"
require "fileutils"

# Structural checks on the files Claude Code reads. These exist because the first
# version shipped a hooks.json in the wrong shape and an allowed-tools list that
# approved any command merely CONTAINING a script's name, and CI only checked JSON syntax.
class StructureTest < Minitest::Test
  SKILL_DIR = File.join(ROOT, "skills/messengerr")
  SKILL_MD = File.join(SKILL_DIR, "SKILL.md")

  def skill_text = File.read(SKILL_MD, encoding: "utf-8")
  def frontmatter = YAML.safe_load(skill_text[/\A---\n(.*?)\n---/m, 1])
  def body = skill_text.sub(/\A---\n.*?\n---\n/m, "")

  # ------------------------------------------------------------ SKILL.md

  def test_name_and_description
    fm = frontmatter
    assert_equal "messengerr", fm["name"]
    assert_operator fm["description"].length, :<=, 1536
    %w[CSV email SMS messengerr dry].each { |word| assert_match(/#{word}/i, fm["description"]) }
    assert_match(/human always sends/, fm["description"])
  end

  def test_is_well_under_the_length_limit
    assert_operator skill_text.lines.length, :<, 300
  end

  def test_allowed_tools_is_a_string_of_narrow_patterns
    tools = frontmatter["allowed-tools"]
    assert_kind_of String, tools, "the docs show a space-separated string"

    patterns = tools.scan(/Bash\((.*?)\)(?=\s|\z)/).flatten
    assert_operator patterns.length, :>=, 6
    patterns.each do |pattern|
      refute_match(/\A\*/, pattern, "a leading * approves ANY command containing the text: #{pattern}")
      refute_match(/\*.*\*/, pattern, "wildcards on both sides are substring matches: #{pattern}")
      refute_match(/messengerr send(?! --help)/, pattern, "a real send must never be pre-approved: #{pattern}")
      refute_match(/allow-non-interactive|credentials (setup|delete)/, pattern)
    end

    scripts = patterns.grep(/scripts\//)
    assert_equal %w[csv_check.rb dry_run.sh ledger_summary.rb], scripts.map { |p| p[%r{scripts/([\w.]+)}, 1] }.sort
    scripts.each do |pattern|
      assert_match(%r{\A\$\{CLAUDE_SKILL_DIR\}/scripts/[\w.]+ \*\z}, pattern)
      assert File.executable?(File.join(SKILL_DIR, "scripts", pattern[%r{scripts/([\w.]+)}, 1])), "#{pattern} must be executable"
    end
  end

  def test_hook_is_registered_for_every_tool_the_guard_covers
    entry = frontmatter.dig("hooks", "PreToolUse", 0)
    assert_equal %w[Bash Edit Glob Grep Read Write], entry["matcher"].split("|").sort
    assert_equal "command", entry.dig("hooks", 0, "type")
    assert_kind_of String, entry.dig("hooks", 0, "command")
  end

  def test_every_script_and_reference_mentioned_exists
    body.scan(%r{\$\{CLAUDE_SKILL_DIR\}/(scripts/[\w.]+)}).flatten.uniq.each do |path|
      assert File.exist?(File.join(SKILL_DIR, path)), "#{path} is referenced but missing"
    end
    body.scan(%r{`(references/[\w.-]+|assets/[\w.-]+)`}).flatten.uniq.each do |path|
      assert File.exist?(File.join(SKILL_DIR, path)), "#{path} is referenced but missing"
    end
  end

  def test_states_the_hard_rules
    assert_match(/Never run `messengerr send` without `--dry-run`/, body)
    assert_match(/Never read, print, ask for or write credentials/, body)
    assert_match(/Never paste a contact list/, body)
    assert_match(/Compliance is the sender's job/, body)
  end

  def test_requires_the_release_that_has_the_flags
    assert_equal "messengerr >= 0.2.0", frontmatter.dig("metadata", "requires")
  end

  def test_the_body_never_tells_claude_to_run_a_real_send
    code_blocks = body.scan(/```(?:bash|sh)?\n(.*?)```/m).flatten
    code_blocks.each do |block|
      block.lines.each do |line|
        next unless line.match?(/\bmessengerr send\b/)

        flunk "a code block shows a bare `messengerr send` command Claude could run: #{line.strip}" unless line.match?(/--dry-run|--help/) || block.include?("dry_run.sh")
      end
    end
  end

  # ------------------------------------------------------------ hook stub

  # The hook in SKILL.md finds guard.rb itself and falls back to a strict built-in rule.
  def stub_script = frontmatter.dig("hooks", "PreToolUse", 0, "hooks", 0, "command")

  def run_stub(command, env: {}, path: nil)
    payload = JSON.dump("tool_name" => "Bash", "tool_input" => { "command" => command })
    run_env = { "HOME" => @home, "PATH" => path || ENV["PATH"] }.merge(env)
    out, err, status = Open3.capture3(run_env, "/bin/bash", "-c", stub_script, stdin_data: payload, chdir: @home)
    [ out, err, status.exitstatus ]
  end

  def setup
    @home = Dir.mktmpdir("stub-home")
  end

  def teardown
    FileUtils.remove_entry(@home)
  end

  def test_stub_delegates_to_guard_rb_when_it_can_find_it
    env = { "CLAUDE_SKILL_DIR" => SKILL_DIR }
    # --html contains "-h": only the real parser gets this right
    assert_equal 2, run_stub("messengerr send --html letter.html", env: env)[2]
    assert_equal 0, run_stub("messengerr send --dry-run --html letter.html", env: env)[2]
    assert_equal 2, run_stub("messengerr send --dry-run && messengerr send", env: env)[2]
    assert_equal 2, run_stub("cat ~/.config/messeng*/master.*", env: env)[2]
  end

  def test_stub_finds_the_script_through_the_plugin_root_and_the_personal_install
    FileUtils.mkdir_p(File.join(@home, ".claude/skills"))
    FileUtils.ln_s(SKILL_DIR, File.join(@home, ".claude/skills/messengerr"))
    assert_equal 2, run_stub("messengerr send --html letter.html")[2], "personal install location"

    FileUtils.rm(File.join(@home, ".claude/skills/messengerr"))
    assert_equal 2, run_stub("messengerr send --html letter.html", env: { "CLAUDE_PLUGIN_ROOT" => ROOT })[2], "plugin root"
  end

  STRICT_BLOCKED = [
    "messengerr send",
    "messengerr send --html letter.html",
    "messengerr send --dry-run && messengerr send",
    "messengerr send --dry-run; messengerr send",
    "echo y | messengerr send",
    "messengerr send --dry-run --allow-non-interactive",
    "messengerr send # --dry-run",
    "messengerr send\necho --dry-run",
    "echo $(messengerr send)",
    "messengerr credentials setup postmark",
    "cat ~/.config/messengerr/master.key",
    "echo $MESSENGERR_MASTER_KEY"
  ].freeze

  STRICT_ALLOWED = [
    "messengerr send --dry-run",
    "messengerr send --method email --csv a.csv --dry-run",
    "messengerr send --help",
    "messengerr --version",
    "messengerr credentials list",
    "ls -la",
    "git status",
    "cat config/master.key"
  ].freeze

  def test_strict_fallback_when_guard_rb_cannot_be_found
    # no CLAUDE_* variables, an empty HOME, and the project dir has no .claude/skills
    STRICT_BLOCKED.each do |command|
      assert_equal 2, run_stub(command)[2], "strict fallback should block: #{command.inspect}"
    end
    STRICT_ALLOWED.each do |command|
      assert_equal 0, run_stub(command)[2], "strict fallback should allow: #{command.inspect}"
    end
  end

  def test_strict_fallback_when_ruby_is_missing
    bin = File.join(@home, "bin")
    FileUtils.mkdir_p(bin)
    FileUtils.ln_s("/bin/cat", File.join(bin, "cat"))
    env = { "CLAUDE_SKILL_DIR" => SKILL_DIR }

    assert_equal 2, run_stub("messengerr send --html letter.html", env: env, path: bin)[2]
    assert_equal 0, run_stub("messengerr send --dry-run", env: env, path: bin)[2]
  end

  def test_stub_blocks_with_a_message_on_stderr
    _out, err, code = run_stub("messengerr send")
    assert_equal 2, code
    assert_match(/\Amessengerr guard: /, err)
  end

  # ------------------------------------------------------------ plugin manifests

  def read_json(path) = JSON.parse(File.read(File.join(ROOT, path), encoding: "utf-8"))

  def test_hooks_json_has_the_documented_shape
    json = read_json("hooks/hooks.json")
    assert_kind_of Hash, json["hooks"], "the top-level `hooks` must be an object keyed by event"
    entries = json["hooks"]["PreToolUse"]
    assert_kind_of Array, entries

    entries.each do |entry|
      assert_kind_of String, entry["matcher"]
      assert_kind_of Array, entry["hooks"]
      entry["hooks"].each do |handler|
        assert_equal "command", handler["type"]
        assert_kind_of String, handler["command"]
        refute handler.key?("event"), "`event` belongs to the object key, not the handler"
      end
    end
  end

  def test_hooks_json_points_at_a_real_script_through_the_plugin_root_variable
    handler = read_json("hooks/hooks.json").dig("hooks", "PreToolUse", 0, "hooks", 0)
    assert_equal "ruby", handler["command"]
    script = handler["args"].first
    assert script.start_with?("${CLAUDE_PLUGIN_ROOT}/"), script
    assert File.file?(script.sub("${CLAUDE_PLUGIN_ROOT}", ROOT)), "#{script} does not exist"
  end

  def test_plugin_and_skill_hooks_guard_the_same_tools
    plugin = read_json("hooks/hooks.json").dig("hooks", "PreToolUse", 0, "matcher").split("|").sort
    skill = frontmatter.dig("hooks", "PreToolUse", 0, "matcher").split("|").sort
    assert_equal skill, plugin
  end

  def test_versions_agree_everywhere
    plugin = read_json(".claude-plugin/plugin.json")
    market = read_json(".claude-plugin/marketplace.json")
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"), encoding: "utf-8")[/^## \[?([\d.]+)\]?/, 1]

    versions = {
      "plugin.json" => plugin["version"],
      "marketplace.json" => market["plugins"][0]["version"],
      "SKILL.md metadata" => frontmatter.dig("metadata", "version"),
      "CHANGELOG top entry" => changelog
    }
    assert_equal 1, versions.values.uniq.length, "versions disagree: #{versions}"
  end

  def test_manifests_are_consistent
    plugin = read_json(".claude-plugin/plugin.json")
    market = read_json(".claude-plugin/marketplace.json")

    assert_equal "messengerr", plugin["name"]
    assert_equal "./skills", plugin["skills"]
    assert Dir.exist?(File.join(ROOT, plugin["skills"])), "skills path must exist"
    assert_equal "messengerr", market["plugins"][0]["name"]
    assert_equal "./", market["plugins"][0]["source"]
    assert_equal plugin["author"]["name"], market["plugins"][0]["author"]["name"]
  end

  # ------------------------------------------------------------ letterhead template

  PLACEHOLDER = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/ # the same rule messengerr uses

  def test_letterhead_has_only_valid_placeholders_and_no_stray_braces
    html = File.read(File.join(SKILL_DIR, "assets/letterhead-template.html"), encoding: "utf-8")
    placeholders = html.scan(PLACEHOLDER).flatten.uniq
    assert_equal %w[name], placeholders, "keep the starter to one placeholder so it works with any CSV that has a name column"

    leftover = html.gsub(PLACEHOLDER, "")
    refute_match(/\{\{|\}\}/, leftover, "stray {{ or }} makes messengerr abort the run")
  end

  def test_letterhead_makes_no_consent_claim_and_uses_no_external_resources
    html = File.read(File.join(SKILL_DIR, "assets/letterhead-template.html"), encoding: "utf-8")
    refute_match(/you subscribed|you signed up|you opted/i, html)
    refute_match(/<script|<link |@import|<style/i, html)
    refute_match(/https?:\/\//, html, "no remote resources in the starter")
  end

  def test_letterhead_is_email_safe_table_layout_with_inline_styles
    html = File.read(File.join(SKILL_DIR, "assets/letterhead-template.html"), encoding: "utf-8")
    assert_match(/<table/, html)
    refute_match(/display:\s*(flex|grid)/i, html)
    assert_match(/style="/, html)
  end
end
