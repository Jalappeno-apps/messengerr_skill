#!/usr/bin/env ruby
# ledger_summary.rb PATH
# Summarises a messengerr send ledger (JSONL): counts by status, how many are
# uncertain (may already be delivered — retrying can duplicate), and which row
# numbers failed and why. Prints row numbers and reasons only, never contacts.
require "json"

path = ARGV[0]
abort("usage: ledger_summary.rb PATH") if path.nil?
abort("ledger_summary: file not found: #{path}") unless File.file?(path)

counts = Hash.new(0)
uncertain = 0
failures = []
torn = 0

File.readlines(path, chomp: true).each do |line|
  entry =
    begin
      JSON.parse(line)
    rescue JSON::ParserError
      torn += 1
      next
    end
  status = entry["status"] || "unknown"
  counts[status] += 1
  uncertain += 1 if entry["uncertain"]
  failures << entry unless status == "sent"
end

puts "file: #{path}"
counts.each { |status, n| puts "#{status}: #{n}" }
puts "uncertain (retry may duplicate): #{uncertain}" if uncertain.positive?
puts "torn/blank lines skipped: #{torn}" if torn.positive?

unless failures.empty?
  puts "failures:"
  failures.each do |f|
    flag = f["uncertain"] ? " [uncertain]" : ""
    puts "  row #{f['row_number']}: #{f['reason']}#{flag}"
  end
end
