require_relative "test_helper"

load File.join(ROOT, "build/check_release.rb")

class ReleaseTest < Minitest::Test
  CHANGELOG = <<~MD
    # Changelog

    ## [0.2.0] - 2026-11-01

    Newer.

    ## [0.1.0] - 2026-10-28

    First release.
    - A
  MD

  def ok_versions(version = "0.1.0") = { "plugin.json" => version, "marketplace.json" => version, "SKILL.md metadata" => version }

  def test_ready_when_everything_agrees
    assert_empty problems("v0.1.0", CHANGELOG, ok_versions)
  end

  def test_refuses_a_bad_tag_shape
    refute_empty problems("0.1.0", CHANGELOG, ok_versions)
    refute_empty problems("v0.1", CHANGELOG, ok_versions)
    refute_empty problems("v0.1.0-rc1", CHANGELOG, ok_versions)
  end

  def test_refuses_when_any_manifest_disagrees_with_the_tag
    ok_versions.each_key do |where|
      found = ok_versions.merge(where => "0.0.9")
      assert(problems("v0.1.0", CHANGELOG, found).any? { |p| p.include?(where) }, where)
    end
  end

  def test_refuses_an_unreleased_or_missing_changelog_entry
    unreleased = CHANGELOG.sub("## [0.1.0] - 2026-10-28", "## [0.1.0] - unreleased")
    assert(problems("v0.1.0", unreleased, ok_versions).any? { |p| p.include?("unreleased") })
    assert(problems("v0.3.0", CHANGELOG, ok_versions("0.3.0")).any? { |p| p.include?("no entry") })
  end

  def test_does_not_confuse_similar_versions
    changelog = "## [0.10.0] - 2026-10-28\n\nx\n"
    assert(problems("v0.1.0", changelog, ok_versions).any? { |p| p.include?("no entry") })
  end

  def test_notes_are_only_the_requested_section
    assert_equal "First release.\n- A", notes("0.1.0", CHANGELOG)
    assert_equal "Newer.", notes("0.2.0", CHANGELOG)
    assert_raises(RuntimeError) { notes("9.9.9", CHANGELOG) }
  end

  def test_the_real_repo_is_not_releasable_while_the_changelog_says_unreleased
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"), encoding: "utf-8")
    skip "already dated" unless changelog.match?(/unreleased/i)

    assert(problems("v0.1.0", changelog).any? { |p| p.include?("unreleased") })
  end

  def test_workflows_pin_third_party_actions_to_a_commit_and_limit_permissions
    %w[ci release].each do |name|
      text = File.read(File.join(ROOT, ".github/workflows/#{name}.yml"), encoding: "utf-8")
      text.scan(/uses:\s*([\w.-]+\/[\w.-]+)@(\S+)/).each do |action, ref|
        next if action.start_with?("actions/", "ruby/") # first-party

        assert_match(/\A[0-9a-f]{40}\z/, ref, "#{name}.yml: #{action} must be pinned to a full commit SHA")
      end
      assert_match(/^permissions:\n\s+contents: read/, text, "#{name}.yml should default to read-only permissions")
    end
  end

  def test_ci_covers_the_rubies_the_gem_supports_and_runs_against_the_real_cli
    ci = File.read(File.join(ROOT, ".github/workflows/ci.yml"), encoding: "utf-8")
    %w[3.2 3.3 3.4].each { |v| assert_includes ci, "\"#{v}\"" }
    assert_match(/MESSENGERR_BIN=messengerr rake test/, ci)
    refute_match(/\|\|\s*true/, ci, "a check that ends in `|| true` can never fail")
  end
end
