require_relative "test_helper"

# The first version of the references described a CLI that did not exist and made
# claims the real CLI contradicts. These tests tie the prose to the generated
# reference (references/commands.md, produced from the real CLI) and ban known-false claims.
class DocsTest < Minitest::Test
  SKILL = File.join(ROOT, "skills/messengerr")
  PROSE = (Dir.glob(File.join(SKILL, "**/*.md")) + [ File.join(ROOT, "README.md") ]).sort.freeze
  GENERATED = File.join(SKILL, "references/commands.md")

  def read(path) = File.read(path, encoding: "utf-8")

  def commands_text = read(GENERATED)

  # Flags the CLI really has, from its own --help as captured in commands.md.
  def real_flags
    commands_text.scan(/^\s+(?:-\w, )?(--[a-z][a-z-]*)/).flatten.uniq
  end

  # Flags that are legitimately mentioned but belong to other tools or are not send flags.
  # --bogus is the deliberate example of an unknown flag in the troubleshooting table
  OTHER_FLAGS = %w[--version --help --purge --dry-run --html --bogus].freeze

  def test_every_flag_mentioned_in_the_prose_exists_in_the_real_cli
    PROSE.reject { |p| p == GENERATED }.each do |path|
      read(path).scan(/(?<![\w-])(--[a-z][a-z-]+)/).flatten.uniq.each do |flag|
        known = real_flags.include?(flag) || OTHER_FLAGS.include?(flag)
        assert known, "#{File.basename(path)} mentions #{flag}, which is not in the generated CLI reference"
      end
    end
  end

  def test_only_real_subcommands_are_mentioned
    allowed = %w[send credentials integrations --version --help]
    PROSE.each do |path|
      read(path).scan(/`messengerr\s+([a-z-]+)/).flatten.uniq.each do |sub|
        next if allowed.include?(sub)
        next if %w[skill].include?(sub) && File.basename(path) == "CHANGELOG.md"

        flunk "#{File.basename(path)} mentions `messengerr #{sub}`, which the CLI does not have"
      end
    end
  end

  # (pattern, why it is wrong). Each was a real claim in an earlier draft.
  BANNED = [
    [ /duplicate of row/, "duplicates are not detected: one row is one message" ],
    [ /Refusing to send/, "the real message is lowercase: `refusing to send...`" ],
    [ /unexpected end of input.*Don't pipe/i, "obsolete advice" ],
    [ /you subscribed|you signed up/i, "the template must not assert consent for the user" ],
    [ /messengerr skill (install|status|uninstall)/, "that command does not exist" ],
    [ /\{\{unsubscribe_line\}\}|\{\{sender_name\}\}/, "removed starter placeholders (the template has only {{name}})" ],
    [ /matched? by (the )?contact(?! plus| and)/i, "resume matches row number PLUS contact" ],
    [ /skips? every contact already/i, "resume skips by row + contact, not contact alone" ]
  ].freeze

  def test_no_known_false_claims
    PROSE.each do |path|
      text = read(path)
      BANNED.each do |pattern, why|
        refute_match pattern, text, "#{File.basename(path)}: #{why}"
      end
    end
  end

  def test_no_reference_calls_an_uncertain_failure_safe_to_retry
    text = read(File.join(SKILL, "references/troubleshooting.md"))
    row = text.lines.find { |l| l.include?("integration returned no result") }
    assert row, "the troubleshooting table should explain this message"
    assert_match(/uncertain/i, row)
    refute_match(/safe to retry/i, row)
  end

  def test_the_whole_run_abort_is_described_not_a_per_row_failure
    text = read(File.join(SKILL, "references/templates.md"))
    assert_match(/whole run/i, text)
    refute_match(/the row fails/i, text)
  end

  def test_the_generated_reference_says_where_it_came_from_and_is_current
    text = commands_text
    assert_match(/Generated from \*\*messengerr \d+\.\d+\.\d+\*\*/, text)
    assert_equal text[/messengerr (\d+\.\d+\.\d+)\*\*/, 1], File.read(File.join(ROOT, ".messengerr-version")).strip
  end

  def test_the_generated_reference_documents_the_send_guard_and_exit_codes
    assert_match(/refusing to send without an interactive terminal/, commands_text)
    assert_match(/\| `130` \|/, commands_text)
  end
end
