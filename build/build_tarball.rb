#!/usr/bin/env ruby
# build_tarball.rb [VERSION]
# Builds the release tarball  dist/messengerr-skill-<VERSION>.tar.gz (+ .sha256)
# containing ONLY the tracked files under skills/messengerr/.
#
#   * The file list comes from `git ls-files`, so Finder/editor junk (.DS_Store, *.swp)
#     and anything uncommitted can never end up in a pinned artifact.
#   * Only an allow-list of plain file types is accepted; dotfiles, symlinks, paths
#     that escape the skill directory, and unexpected extensions abort the build.
#   * Reproducible on one machine: sorted entries, mtime 0, owner/group fixed, gzip
#     header normalised. NOTE: the compressed bytes depend on the zlib build, so a
#     laptop and CI can differ. The hash that matters is the one CI computes for the
#     release asset; always pin THAT one, never a locally built hash.
#
# DIST_DIR overrides the output directory (used by the tests).
require "rubygems/package"
require "pathname"
require "digest"
require "fileutils"
require "zlib"
require "yaml"
require "open3"

ENV["SOURCE_DATE_EPOCH"] ||= "0"

ROOT = File.expand_path("..", __dir__)
SKILL_REL = "skills/messengerr"
ALLOWED_EXTENSIONS = %w[.md .html .rb .sh].freeze

def fail_build(message)
  warn "build: #{message}"
  exit 1
end

def default_version
  text = File.read(File.join(ROOT, SKILL_REL, "SKILL.md"), encoding: "utf-8")
  YAML.safe_load(text[/\A---\n(.*?)\n---/m, 1]).dig("metadata", "version")
end

version = ARGV[0] || default_version
fail_build("usage: build_tarball.rb VERSION") if version.to_s.empty?
fail_build("version #{version.inspect} contains unexpected characters") unless version.match?(/\A[0-9A-Za-z.+-]+\z/)

listing, status = Open3.capture2("git", "ls-files", "-z", "--", SKILL_REL, chdir: ROOT)
fail_build("git ls-files failed (build from a git checkout)") unless status.success?
paths = listing.split("\0").sort
fail_build("no tracked files under #{SKILL_REL}/") if paths.empty?

paths.each do |rel|
  parts = rel.split("/")
  fail_build("path escapes the skill directory: #{rel}") if parts.include?("..") || !rel.start_with?("#{SKILL_REL}/")
  fail_build("dotfile in the skill directory: #{rel}") if parts.any? { |part| part.start_with?(".") }
  full = File.join(ROOT, rel)
  fail_build("symlink in the skill directory: #{rel}") if File.symlink?(full)
  fail_build("tracked file is missing from the working tree: #{rel}") unless File.file?(full)
  fail_build("unexpected file type #{File.extname(rel).inspect}: #{rel}") unless ALLOWED_EXTENSIONS.include?(File.extname(rel))
end
fail_build("SKILL.md is missing") unless paths.include?("#{SKILL_REL}/SKILL.md")

dist = ENV["DIST_DIR"] || File.join(ROOT, "dist")
FileUtils.mkdir_p(dist)
tarball = File.join(dist, "messengerr-skill-#{version}.tar.gz")

File.open(tarball, "wb") do |file|
  Zlib::GzipWriter.wrap(file) do |gz|
    Gem::Package::TarWriter.new(gz) do |tar|
      paths.each do |rel|
        full = File.join(ROOT, rel)
        mode = rel.start_with?("#{SKILL_REL}/scripts/") ? 0o755 : 0o644
        data = File.binread(full)
        tar.add_file_simple(rel, mode, data.bytesize) { |io| io.write(data) }
      end
    end
  end
end

# Normalise the gzip header: mtime = 0 and OS = unknown.
data = File.binread(tarball)
data[4, 4] = "\x00\x00\x00\x00".b
data[9] = "\xff".b
File.binwrite(tarball, data)

digest = Digest::SHA256.file(tarball).hexdigest
File.write("#{tarball}.sha256", "#{digest}  #{File.basename(tarball)}\n")
puts tarball
puts "sha256: #{digest}"
puts "files: #{paths.length}"
