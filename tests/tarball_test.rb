require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "rubygems/package"
require "zlib"

class TarballTest < Minitest::Test
  BUILDER = File.join(ROOT, "build/build_tarball.rb")

  def build(dir, version = "9.9.9")
    Open3.capture3({ "DIST_DIR" => dir }, RbConfig.ruby, BUILDER, version, chdir: ROOT)
  end

  def entries(tarball)
    list = []
    File.open(tarball, "rb") do |file|
      Zlib::GzipReader.wrap(file) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each { |e| list << { name: e.full_name, mode: e.header.mode, mtime: e.header.mtime.to_i, uid: e.header.uid, gid: e.header.gid, file: e.file? } }
        end
      end
    end
    list
  end

  def tracked
    out, = Open3.capture2("git", "ls-files", "-z", "--", "skills/messengerr", chdir: ROOT)
    out.split("\0").sort
  end

  def test_contains_exactly_the_tracked_skill_files
    Dir.mktmpdir do |dir|
      _out, err, status = build(dir)
      assert status.success?, err
      names = entries(File.join(dir, "messengerr-skill-9.9.9.tar.gz")).map { |e| e[:name] }

      assert_equal tracked, names.sort
      assert(names.all? { |n| n.start_with?("skills/messengerr/") })
    end
  end

  def test_no_dotfiles_symlinks_or_unexpected_types
    Dir.mktmpdir do |dir|
      build(dir)
      list = entries(File.join(dir, "messengerr-skill-9.9.9.tar.gz"))

      assert(list.none? { |e| e[:name].split("/").any? { |part| part.start_with?(".") } })
      assert(list.all? { |e| e[:file] })
      assert(list.all? { |e| %w[.md .html .rb .sh].include?(File.extname(e[:name])) })
    end
  end

  def test_untracked_junk_in_the_skill_directory_is_left_out
    junk = File.join(ROOT, "skills/messengerr/.DS_Store")
    stray = File.join(ROOT, "skills/messengerr/notes-draft.md")
    File.write(junk, "finder junk")
    File.write(stray, "uncommitted draft")
    Dir.mktmpdir do |dir|
      build(dir)
      names = entries(File.join(dir, "messengerr-skill-9.9.9.tar.gz")).map { |e| e[:name] }

      refute_includes names, "skills/messengerr/.DS_Store"
      refute_includes names, "skills/messengerr/notes-draft.md"
    end
  ensure
    FileUtils.rm_f([ junk, stray ])
  end

  def test_scripts_are_executable_and_everything_else_is_not
    Dir.mktmpdir do |dir|
      build(dir)
      entries(File.join(dir, "messengerr-skill-9.9.9.tar.gz")).each do |e|
        expected = e[:name].include?("/scripts/") ? 0o755 : 0o644
        assert_equal expected, e[:mode] & 0o777, e[:name]
      end
    end
  end

  def test_normalised_metadata
    Dir.mktmpdir do |dir|
      build(dir)
      entries(File.join(dir, "messengerr-skill-9.9.9.tar.gz")).each do |e|
        assert_equal [ 0, 0, 0 ], [ e[:mtime], e[:uid], e[:gid] ], e[:name]
      end
    end
  end

  def test_two_builds_are_byte_identical_even_when_files_are_touched_in_between
    Dir.mktmpdir do |a|
      Dir.mktmpdir do |b|
        build(a)
        FileUtils.touch(Dir.glob(File.join(ROOT, "skills/messengerr/**/*")).select { |p| File.file?(p) })
        sleep 1.1
        build(b)

        assert_equal File.binread(File.join(a, "messengerr-skill-9.9.9.tar.gz")),
                     File.binread(File.join(b, "messengerr-skill-9.9.9.tar.gz"))
      end
    end
  end

  def test_the_sha256_file_matches_the_tarball
    Dir.mktmpdir do |dir|
      build(dir)
      tarball = File.join(dir, "messengerr-skill-9.9.9.tar.gz")
      recorded = File.read("#{tarball}.sha256").split.first

      assert_equal Digest::SHA256.file(tarball).hexdigest, recorded
      assert_match(/\A[0-9a-f]{64}\z/, recorded)
    end
  end

  def test_a_bad_version_is_rejected
    Dir.mktmpdir do |dir|
      _out, err, status = build(dir, "../evil")

      refute status.success?
      assert_match(/unexpected characters/, err)
    end
  end
end
