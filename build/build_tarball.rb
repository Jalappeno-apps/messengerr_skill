#!/usr/bin/env ruby
# build_tarball.rb [VERSION]
# Builds the reproducible release tarball
#   dist/messengerr-skill-<VERSION>.tar.gz  (+ .sha256)
# containing only skills/messengerr/**. Reproducible: sorted entries, mtime 0,
# uid/gid 0, gzip -n — identical inputs produce identical bytes.
require "rubygems/package"
require "pathname"
require "digest"
require "fileutils"
require "zlib"
require "yaml"

ENV["SOURCE_DATE_EPOCH"] ||= "0" # zero tar header mtimes for reproducibility

ROOT = File.expand_path("..", __dir__)
SKILL_DIR = File.join(ROOT, "skills/messengerr")
abort("build: #{SKILL_DIR} not found") unless Dir.exist?(SKILL_DIR)

version = ARGV[0] || YAML.safe_load(File.read(File.join(SKILL_DIR, "SKILL.md"))[/\A---\n(.*?)\n---/m, 1])["metadata"]["version"] rescue nil
abort("usage: build_tarball.rb VERSION") unless version && !version.empty?

DIST = File.join(ROOT, "dist")
FileUtils.mkdir_p(DIST)
tarball = File.join(DIST, "messengerr-skill-#{version}.tar.gz")

entries = Dir.glob(File.join(SKILL_DIR, "**", "*"), File::FNM_DOTMATCH)
            .reject { |p| File.basename(p) == "." || File.basename(p) == ".." }
            .sort

File.open(tarball, "wb") do |file|
  Zlib::GzipWriter.wrap(file) do |gz|
    Gem::Package::TarWriter.new(gz) do |tar|
      entries.each do |path|
        rel = Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
        if File.directory?(path)
          tar.mkdir(rel, 0o755)
        else
          mode = rel.include?("/scripts/") ? 0o755 : 0o644
          tar.add_file_simple(rel, mode, File.size(path)) { |io| io.write(File.binread(path)) }
        end
      end
    end
  end
end

# Normalize gzip header (mtime + OS byte) for reproducibility.
data = File.binread(tarball)
data[4, 4] = "\x00\x00\x00\x00".b # mtime = 0
data[9] = "\xff".b               # os = unknown
File.binwrite(tarball, data)

digest = Digest::SHA256.file(tarball).hexdigest
File.write("#{tarball}.sha256", "#{digest}  #{File.basename(tarball)}\n")
puts "#{tarball}"
puts "sha256: #{digest}"
