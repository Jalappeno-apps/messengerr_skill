#!/usr/bin/env ruby
# csv_check.rb PATH
# Structural report on a contact CSV: headers, duplicate headers, row counts,
# blank rows, per-column empty-cell counts, and encoding problems. Prints
# counts and row numbers only — never contact values.
require "csv"

path = ARGV[0]
abort("usage: csv_check.rb PATH") if path.nil?
abort("csv_check: file not found: #{path}") unless File.file?(path)

raw = File.binread(path)
puts "file: #{path}"
puts "bytes: #{raw.bytesize}"
puts "bom: #{raw.start_with?("\xEF\xBB\xBF".b) ? "utf-8" : "none"}"

begin
  text = raw.start_with?("\xEF\xBB\xBF".b) ? raw.byteslice(3..) : raw.dup
  text.force_encoding("utf-8")
  table = CSV.parse(text, headers: true)
rescue CSV::MalformedCSVError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
  abort("csv_check: unparseable CSV: #{e.message}")
end

headers = table.headers.compact
puts "headers: #{headers.join(', ')}"

dupes = headers.tally.select { |_, n| n > 1 }
puts "duplicate headers: #{dupes.empty? ? "none" : dupes.keys.join(', ') + " (MESSENGERR WILL REJECT THIS FILE)"}"

rows = table.to_a[1..] || []
blank_rows = rows.each_with_index.count { |row, _| row.compact.empty? }
puts "data rows: #{rows.length}"
puts "blank rows: #{blank_rows}"

headers.each do |header|
  empties = table[header].each_with_index.count do |value, index|
    next false if index >= rows.length
    value.nil? || value.to_s.strip.empty?
  end
  puts "  #{header}: #{empties} empty"
end
