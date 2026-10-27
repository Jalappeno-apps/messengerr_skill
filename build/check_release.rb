#!/usr/bin/env ruby
# check_release.rb TAG [--notes]
# Release guard, shared by CI and the release workflow:
#   * TAG must be v<version> and equal the plugin, marketplace and SKILL.md versions;
#   * CHANGELOG.md must have a DATED entry for that version (not "unreleased").
# With --notes it prints that changelog section (used for the GitHub release body).
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__) unless defined?(ROOT)

def read(path) = File.read(File.join(ROOT, path), encoding: "utf-8")

def versions
  skill = YAML.safe_load(read("skills/messengerr/SKILL.md")[/\A---\n(.*?)\n---/m, 1]).dig("metadata", "version")
  {
    "plugin.json" => JSON.parse(read(".claude-plugin/plugin.json"))["version"],
    "marketplace.json" => JSON.parse(read(".claude-plugin/marketplace.json")).dig("plugins", 0, "version"),
    "SKILL.md metadata" => skill
  }
end

def heading_for(version, changelog)
  changelog.lines.find { |line| line.match?(/\A## \[?#{Regexp.escape(version)}\]?(\s|\z)/) }
end

# → [String] problems (empty means ready)
def problems(tag, changelog, found = versions)
  list = []
  version = tag.to_s.sub(/\Av/, "")
  list << "tag #{tag.inspect} must look like vX.Y.Z" unless tag.to_s.match?(/\Av\d+\.\d+\.\d+\z/)
  found.each { |where, value| list << "#{where} says #{value.inspect}, but the tag is for #{version}" unless value == version }
  heading = heading_for(version, changelog)
  if heading.nil?
    list << "CHANGELOG.md has no entry for #{version}"
  elsif heading.match?(/unreleased/i)
    list << "CHANGELOG.md still marks #{version} as unreleased (give it a date)"
  end
  list
end

def notes(version, changelog)
  lines = changelog.lines
  start = lines.index { |line| line.match?(/\A## \[?#{Regexp.escape(version)}\]?(\s|\z)/) }
  raise "CHANGELOG.md has no entry for #{version}" unless start

  lines[(start + 1)..].take_while { |line| !line.start_with?("## ") }.join.strip
end

if $PROGRAM_NAME == __FILE__
  tag = ARGV[0] || abort("usage: check_release.rb TAG [--notes]")
  changelog = read("CHANGELOG.md")
  found = problems(tag, changelog)
  abort("Not ready to release:\n  - #{found.join("\n  - ")}") unless found.empty?

  puts(ARGV.include?("--notes") ? notes(tag.sub(/\Av/, ""), changelog) : "Ready to release #{tag}")
end
