require_relative "test_helper"
require "tmpdir"

# Mutation testing for the guard: break a COPY of guard.rb in one specific way and
# require the corpus in guard_test.rb to fail. If a mutation survives, the corpus
# has a blind spot. Each entry is [what was broken, exact text, replacement].
class GuardMutationTest < Minitest::Test
  GUARD = File.join(SCRIPTS, "guard.rb")

  MUTATIONS = [
    [ "safe flags matched by substring (the -h bug)",
      "return nil if args.any? { |arg| SAFE_SEND_FLAGS.include?(arg) }",
      "return nil if args.any? { |arg| SAFE_SEND_FLAGS.any? { |f| arg.include?(f) } }" ],
    [ "--allow-non-interactive tolerated",
      "if args.include?(\"--allow-non-interactive\")", "if false" ],
    [ "comments not stripped (so # --dry-run counts)",
      "if word.empty? && !has_word\n          i += 1", "if false\n          i += 1" ],
    [ "commands not split on ; & | ( )",
      "when \"\\n\", \";\", \"&\", \"|\", \"(\", \")\", \"`\" then finish.call",
      "when \"\\n\" then finish.call" ],
    [ "substitutions inside quotes not analysed",
      "nested.each do |inner|", "[].each do |inner|" ],
    [ "variables not resolved",
      "words = resolve_variables(raw, vars)", "words = raw" ],
    [ "config dir check removed",
      "return CRED_MSG if inside_config?(abs, ctx[:cfgs])", "nil" ],
    [ "glob matching against the config dir removed",
      "return CRED_MSG if glob?(abs) && glob_hits_config?(abs, ctx[:cfgs])", "nil" ],
    [ "cd tracking removed",
      "local = local.merge(cwd: target) if target", "nil" ],
    [ "ancestor (~/.config) rule removed",
      "return CRED_MSG if reader_program && ancestor_of_config?(abs, ctx[:cfgs])", "nil" ],
    [ "environment dumps allowed",
      "dumps ? \"refusing to print environment variables: they can include MESSENGERR_MASTER_KEY.\" : nil", "nil" ],
    [ "credentials setup/delete allowed",
      "%w[setup delete].include?(action)", "[].include?(action)" ],
    [ "messengerr only recognised as the first word (wrappers slip by)",
      "next unless File.basename(word) == \"messengerr\"", "next unless index.zero? && File.basename(word) == \"messengerr\"" ],
    [ "bash -c / sh -c not analysed",
      "return analyze(words[c + 1], ctx, depth + 1)", "return nil" ],
    [ "eval not analysed",
      "return analyze(words.drop(1).join(\" \"), ctx, depth + 1) if prog == \"eval\"", "nil" ],
    [ "text piped into a shell not analysed",
      "return nil unless all_commands.any? { |c| SHELLS.include?(File.basename(c.first.to_s)) }", "return nil" ],
    [ "ruby -e / python -c not scanned",
      "return nil unless text.match?(/messengerr/) && text.match?(/\\bsend\\b/)", "return nil" ],
    [ "script files not inspected",
      "return nil unless path && File.file?(path) && File.size(path) <= MAX_FILE", "return nil" ],
    [ "Read/Edit/Write/Grep/Glob not covered",
      "when \"Read\", \"Edit\", \"Write\", \"NotebookEdit\", \"MultiEdit\"", "when \"NeverMatches\"" ],
    [ "indirection through $var or globs allowed",
      "return nil unless hidden", "return nil" ],
    [ "nesting depth not limited",
      "return \"command nesting is too deep to inspect; blocked to be safe\" if depth > MAX_DEPTH", "nil" ],
    [ "internal errors fail open",
      "      stderr.puts \"messengerr guard: internal error (\#{e.class}); blocked to be safe.\"\n      2", "      0" ]
  ].freeze

  def run_corpus(guard_path)
    Open3.capture3({ "GUARD_PATH" => guard_path }, RbConfig.ruby, "-I", File.join(ROOT, "tests"), File.join(ROOT, "tests/guard_test.rb"))
  end

  # A mutant only counts as caught if the corpus ran and FAILED an assertion. A
  # crash or load error is not a catch, it would hide a broken test setup.
  def caught?(out, status)
    return false if status.success?

    summary = out.lines.grep(/\d+ runs, \d+ assertions, (\d+) failures, (\d+) errors/).last
    return false unless summary

    summary =~ /(\d+) failures, (\d+) errors/
    Regexp.last_match(1).to_i.positive?
  end

  def test_the_unmutated_corpus_passes
    out, err, status = run_corpus(GUARD)
    assert status.success?, "the corpus must pass against the real guard first:\n#{out}\n#{err}"
    assert_match(/\d+ runs, \d+ assertions, 0 failures, 0 errors/, out)
  end

  def test_every_mutation_is_caught_by_the_corpus
    source = File.read(GUARD)
    survivors = []

    MUTATIONS.each do |name, from, to|
      assert_includes source, from, "mutation text not found in guard.rb: #{name}"
      Dir.mktmpdir do |dir|
        mutant = File.join(dir, "guard.rb")
        File.write(mutant, source.sub(from) { to })
        refute_equal source, File.read(mutant), "mutation changed nothing: #{name}"

        out, _err, status = run_corpus(mutant)
        survivors << name unless caught?(out, status)
      end
    end

    assert_empty survivors, "mutations the corpus did NOT catch:\n  - #{survivors.join("\n  - ")}"
  end
end
